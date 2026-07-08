#!/usr/bin/env bash
# Register the device against the Cumulocity Certificate Authority and bootstrap
# thin-edge.io inside the running `device` container using a one-time password.
#
# Usage: bootstrap-device.sh <device-id> [one-time-password]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$HERE/lib.sh"
load_env

DEVICE_ID="${1:?usage: bootstrap-device.sh <device-id> [one-time-password]}"
OTP="${2:-otp-${DEVICE_ID}-9x}"

log "Registering device with Cumulocity CA: id=$DEVICE_ID"
# Idempotent-ish: ignore failure if a request/device already exists.
c8y deviceregistration register-ca --id "$DEVICE_ID" --one-time-password "$OTP" --force \
    2>&1 | sed 's/^/[c8y] /' >&2 || log "register-ca returned non-zero (device may already be registered) — continuing"

log "Bootstrapping thin-edge.io inside the device container"
dc exec -T device /data/tedge/bootstrap.sh \
    --ca c8y \
    --c8y-url "$C8Y_URL_NOSCHEME" \
    --device-id "$DEVICE_ID" \
    --one-time-password "$OTP"

log "Bootstrap complete for $DEVICE_ID"
