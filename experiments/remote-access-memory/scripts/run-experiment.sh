#!/usr/bin/env bash
# End-to-end experiment: for each tedge-standalone version, build the device
# image, bootstrap against Cumulocity, open a remote-access session to the
# ssh-server target, and record the peak memory used by the remote-access plugin.
# Finally, print a side-by-side comparison.
#
# Usage:
#   run-experiment.sh                 # compares 2.0.1-3 vs 0.11.0 (upx)
#   run-experiment.sh 2.0.1-3 0.11.0  # explicit versions
#   VARIANT=-noupx run-experiment.sh  # compare the uncompressed builds instead
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$HERE/lib.sh"
load_env

VERSIONS=("$@")
[ ${#VERSIONS[@]} -eq 0 ] && VERSIONS=("2.0.1-3" "0.11.0")
VARIANT="${VARIANT:-}"          # "" = upx (default), "-noupx" = uncompressed
DURATION="${DURATION:-15}"
DELETE_DEVICE="${DELETE_DEVICE:-1}"

mkdir -p "$RESULTS_DIR"
OUTFILES=()

wait_for_device_online() {
    local dev_id="$1"
    log "Waiting for device '$dev_id' to appear online in Cumulocity"
    for _ in $(seq 1 60); do
        if c8y devices list --name "$dev_id" 2>/dev/null | grep -q "\"name\":\"$dev_id\""; then
            return 0
        fi
        sleep 2
    done
    log "WARN: device '$dev_id' not confirmed online; continuing anyway"
}

run_one() {
    local version="$1"
    local dev_id="tedge-ramem-$(slug "${version}${VARIANT}")"
    local out="$RESULTS_DIR/$dev_id.json"

    log "==================================================================="
    log "VERSION $version${VARIANT}   device-id=$dev_id"
    log "==================================================================="

    export TEDGE_VERSION="$version"
    export TEDGE_VARIANT="$VARIANT"
    export PKG_LABEL="${version}${VARIANT}"
    OUTFILES+=("$out")

    dc down -v --remove-orphans >/dev/null 2>&1 || true
    log "Building images"
    dc build device ssh-server
    log "Starting containers"
    dc up -d

    # Give runsvdir + sshd a moment to come up
    sleep 4

    "$HERE/bootstrap-device.sh" "$dev_id"
    wait_for_device_online "$dev_id"

    "$HERE/remote-access.sh" "$dev_id" "$DURATION" "$out"

    echo "----- $version${VARIANT} result -----" >&2
    cat "$out" >&2

    if [ "$DELETE_DEVICE" = "1" ]; then
        log "Deleting test device '$dev_id' from Cumulocity"
        c8y devices delete --id "$dev_id" --force >/dev/null 2>&1 || true
    fi
    dc down -v --remove-orphans >/dev/null 2>&1 || true
}

for v in "${VERSIONS[@]}"; do
    run_one "$v"
done

# ---- Comparison summary ----
log "Building comparison report"
python3 "$HERE/summarize.py" "${OUTFILES[@]}"

log "Done. Raw results in: $RESULTS_DIR"
