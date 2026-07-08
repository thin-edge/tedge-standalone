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
python3 - "$RESULTS_DIR" "$VARIANT" "${VERSIONS[@]}" <<'PY'
import json, sys, os
results_dir, variant = sys.argv[1], sys.argv[2]
versions = sys.argv[3:]

def slug(v): return v.replace('.', '-').replace('/', '-').replace('+', '-')

rows = []
for v in versions:
    p = os.path.join(results_dir, f"tedge-ramem-{slug(v+variant)}.json")
    if not os.path.exists(p):
        print(f"missing result for {v}{variant}: {p}"); continue
    with open(p) as f:
        rows.append(json.load(f))

def mb(kb): return f"{kb/1024:.1f} MB"
cols = [
    ("remote_access_largest_proc_hwm_kb", "RA plugin peak (1 proc)"),
    ("remote_access_peak_hwm_kb",         "RA plugin peak (all procs)"),
    ("remote_access_peak_rss_kb",         "RA plugin RSS (all procs)"),
    ("tedge_agent_peak_rss_kb",           "tedge-agent RSS"),
    ("tedge_mapper_peak_rss_kb",          "tedge-mapper RSS"),
    ("total_tedge_peak_rss_kb",           "total tedge RSS"),
]

print("\n================= Remote-access memory comparison =================")
hdr = f"{'metric':<28}" + "".join(f"{r['version']:>18}" for r in rows)
print(hdr); print("-" * len(hdr))
for key, label in cols:
    line = f"{label:<28}"
    for r in rows:
        line += f"{mb(r.get(key,0)):>18}"
    print(line)

if len(rows) == 2:
    a, b = rows
    key = "remote_access_largest_proc_hwm_kb"
    if a.get(key) and b.get(key):
        diff = a[key] - b[key]
        pct = 100.0 * diff / b[key] if b[key] else 0
        print("-" * len(hdr))
        print(f"\n{a['version']} uses {mb(abs(diff))} "
              f"({pct:+.0f}%) {'MORE' if diff>0 else 'LESS'} than {b['version']} "
              f"for the remote-access plugin (peak HWM of the largest process).")
print("==================================================================\n")
PY

log "Done. Raw results in: $RESULTS_DIR"
