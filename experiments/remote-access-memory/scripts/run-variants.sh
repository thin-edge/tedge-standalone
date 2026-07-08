#!/usr/bin/env bash
# Compare arbitrary build VARIANTS (not just released versions). Each variant is a
# directory under ./variants containing a variant.env with the build args and an
# optional overlay/ of files layered over the installed package.
#
# Usage:
#   run-variants.sh release tokio1          # does TOKIO_WORKER_THREADS=1 help?
#   run-variants.sh main main-runall        # does `tedge run all c8y` use less RAM?
#   run-variants.sh <v1> <v2> ...           # any variants under ./variants
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$HERE/lib.sh"
load_env

VARIANTS=("$@")
[ ${#VARIANTS[@]} -eq 0 ] && VARIANTS=("release" "tokio1")
DURATION="${DURATION:-15}"
DELETE_DEVICE="${DELETE_DEVICE:-1}"
mkdir -p "$RESULTS_DIR"
OUTFILES=()   # collected result paths, in variant order

wait_for_device_online() {
    local dev_id="$1"
    log "Waiting for device '$dev_id' to appear online in Cumulocity"
    for _ in $(seq 1 60); do
        if c8y devices list --name "$dev_id" 2>/dev/null | grep -q "\"name\":\"$dev_id\""; then return 0; fi
        sleep 2
    done
    log "WARN: device '$dev_id' not confirmed online; continuing anyway"
}

run_one() {
    local variant="$1"
    local vdir="$EXP_DIR/variants/$variant"
    [ -f "$vdir/variant.env" ] || { log "ERROR: no variants/$variant/variant.env"; return 1; }

    # Load the variant build args, then expose them to docker compose
    set -a; LABEL="$variant"; TEDGE_BINARY=none; TEDGE_CHANNEL=main
    TEDGE_BINARY_VERSION=latest; TEDGE_BINARY_UPX=0; OVERLAY=""; BASE_VARIANT=""
    LOCAL_PACKAGE=""; BUILD_FROM_SRC=0; PKG_CHANNEL=main; PKG_VERSION=latest
    # shellcheck disable=SC1090
    . "$vdir/variant.env"
    PKG_LABEL="$LABEL"
    set +a

    # Build the package from the local src/tedge tree if requested
    if [ "${BUILD_FROM_SRC:-0}" = "1" ]; then
        log "Building local package from src/tedge (channel=$PKG_CHANNEL version=$PKG_VERSION)"
        "$HERE/build-local-package.sh" "$EXP_DIR/$LOCAL_PACKAGE" "$PKG_CHANNEL" "$PKG_VERSION" "${TEDGE_ARCH:-arm64}"
    fi

    local dev_id="tedge-ramem-$(slug "$LABEL")"
    local out="$RESULTS_DIR/variant-$(slug "$LABEL").json"
    OUTFILES+=("$out")

    log "==================================================================="
    log "VARIANT $variant   label=$LABEL   binary=$TEDGE_BINARY${TEDGE_BINARY:+/$TEDGE_CHANNEL:$TEDGE_BINARY_VERSION}   overlay=${OVERLAY:-none}"
    log "device-id=$dev_id"
    log "==================================================================="

    dc down -v --remove-orphans >/dev/null 2>&1 || true
    log "Building images"
    dc build device ssh-server
    log "Starting containers"
    dc up -d
    sleep 4

    "$HERE/bootstrap-device.sh" "$dev_id"
    wait_for_device_online "$dev_id"
    "$HERE/remote-access.sh" "$dev_id" "$DURATION" "$out"

    echo "----- $LABEL result -----" >&2
    cat "$out" >&2

    if [ "$DELETE_DEVICE" = "1" ]; then
        log "Deleting test device '$dev_id' from Cumulocity"
        c8y devices delete --id "$dev_id" --force >/dev/null 2>&1 || true
    fi
    dc down -v --remove-orphans >/dev/null 2>&1 || true
}

for v in "${VARIANTS[@]}"; do run_one "$v"; done

log "Building comparison report"
python3 "$HERE/summarize.py" "${OUTFILES[@]}"
log "Done. Raw results in: $RESULTS_DIR"
