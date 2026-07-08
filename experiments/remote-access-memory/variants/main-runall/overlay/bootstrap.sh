#!/bin/sh
# Run-all bootstrap: enrol via the Cumulocity CA, then bring everything up as a
# SINGLE process with `tedge run all c8y` (main-branch feature) instead of separate
# tedge-agent + tedge-mapper-c8y services.
#
# Accepts the same flags the harness passes to the standard bootstrap:
#   --ca <type> --c8y-url <url> --device-id <id> --one-time-password <otp>
#
# NOTE: this assumes `tedge run all c8y` brings up the built-in c8y bridge itself
# (mqtt.bridge.built_in=true in tedge.toml). If your main build still needs an
# explicit `tedge connect c8y` first, uncomment the marked line below.
set -e
CONFIG_DIR="@CONFIG_DIR@"

CA=c8y
C8Y_URL=""
DEVICE_ID=""
OTP=""

while [ $# -gt 0 ]; do
    case "$1" in
        --ca) CA="$2"; shift ;;
        --c8y-url) C8Y_URL="$2"; shift ;;
        --device-id) DEVICE_ID="$2"; shift ;;
        --one-time-password) OTP="$2"; shift ;;
        *) ;;
    esac
    shift
done

if [ -f "$CONFIG_DIR/env" ]; then
    # shellcheck disable=SC1091
    . "$CONFIG_DIR/env"
fi

# Multicall symlinks + config layout
tedge init

[ -n "$C8Y_URL" ]   && tedge config set c8y.url "$C8Y_URL"
[ -n "$DEVICE_ID" ] && tedge config set device.id "$DEVICE_ID"
tedge config set c8y.auth_method certificate

# Enrol with the Cumulocity Certificate Authority using the one-time password
DEVICE_CERT_PATH=$(tedge config get device.cert_path 2>/dev/null ||:)
if [ ! -f "$DEVICE_CERT_PATH" ]; then
    tedge cert download c8y --device-id "$DEVICE_ID" --one-time-password "$OTP" \
        --retry-every 5s --max-timeout 300s
else
    echo "Device certificate already exists" >&2
fi

tedge config upgrade      || echo "WARN: tedge config upgrade failed" >&2
tedge refresh-bridges     || echo "WARN: tedge refresh-bridges failed" >&2

# If your main build requires an explicit connect before run-all, uncomment:
tedge connect c8y || echo "WARN: tedge connect c8y failed" >&2

# Bring up the local broker and the single all-in-one process.
tedgectl enable mosquitto
tedgectl start  mosquitto

# Make sure the separate services are NOT running (the single "tedge" service replaces them)
tedgectl disable tedge-agent       2>/dev/null || true
tedgectl disable tedge-mapper-c8y  2>/dev/null || true

tedgectl enable tedge
tedgectl start  tedge

sleep 5
echo
echo "--------------------------- Summary (run-all) ---------------------------"
echo "  device.id:   $(tedge config get device.id 2>/dev/null ||:)"
echo "  c8y.url:     $(tedge config get c8y.url 2>/dev/null ||:)"
echo "  services:    mosquitto + tedge  (agent+mapper in one process)"
echo "-------------------------------------------------------------------------"
