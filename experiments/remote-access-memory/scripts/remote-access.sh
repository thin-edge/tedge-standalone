#!/usr/bin/env bash
# Open a Cumulocity remote-access (PASSTHROUGH) session to the ssh-server target
# and, while the tunnel is live, sample the device's memory usage.
#
# Usage: remote-access.sh <device-id> [duration_seconds=15] [out.json]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$HERE/lib.sh"
load_env

DEVICE_ID="${1:?usage: remote-access.sh <device-id> [duration] [out.json]}"
DURATION="${2:-15}"
OUT="${3:-/dev/stdout}"
CONFIG_NAME="passthrough"
LPORT="${LPORT:-22022}"

# 1. Ensure a PASSTHROUGH configuration exists pointing at ssh-server:22.
if c8y remoteaccess configurations list --device "$DEVICE_ID" 2>/dev/null \
        | grep -q "\"name\":\"$CONFIG_NAME\""; then
    log "Remote-access configuration '$CONFIG_NAME' already exists"
else
    log "Creating remote-access PASSTHROUGH configuration -> ssh-server:22"
    c8y remoteaccess configurations create-passthrough \
        --device "$DEVICE_ID" \
        --name "$CONFIG_NAME" \
        --hostname ssh-server \
        --port 22 --force >&2
fi

# 2. Start a local proxy. The device-side plugin (and its upx-decompressed memory)
#    is spawned once a client actually connects to the local port, so we open a
#    holding TCP connection below to drive it.
log "Starting local remote-access proxy on 127.0.0.1:$LPORT"
c8y remoteaccess server --device "$DEVICE_ID" --configuration "$CONFIG_NAME" \
    --listen "127.0.0.1:$LPORT" >"$RESULTS_DIR/proxy-$DEVICE_ID.log" 2>&1 &
PROXY_PID=$!

cleanup() {
    kill "$HOLD_PID" 2>/dev/null || true
    kill "$PROXY_PID" 2>/dev/null || true
}
trap cleanup EXIT

# Wait for the local proxy to listen
for _ in $(seq 1 30); do
    if (exec 3<>"/dev/tcp/127.0.0.1/$LPORT") 2>/dev/null; then break; fi
    sleep 0.5
done

# 3. Hold a TCP connection open through the tunnel for the whole measurement.
log "Opening tunnel to device (holding connection to ssh-server via the cloud)"
( exec 3<>"/dev/tcp/127.0.0.1/$LPORT"; sleep "$((DURATION + 8))"; ) &
HOLD_PID=$!

# Give the device time to receive the 530, exec c8y-remote-access-plugin and
# connect to ssh-server (this is where the upx binary decompresses into RAM).
sleep 4

# 4. Sample memory inside the device container while the session is active.
log "Sampling device memory for ${DURATION}s"
dc exec -T device /opt/measure.sh "$DURATION" 2 > "$OUT"

log "Measurement written to $OUT"
