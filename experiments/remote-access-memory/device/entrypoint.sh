#!/bin/sh
# PID 1 for the device container.
#
# We run runsvdir in the foreground so runit supervises the tedge services for
# the whole life of the container. Bootstrapping (cert download + tedge connect)
# is done separately via `docker compose exec` -> /data/tedge/bootstrap.sh, which
# detects this already-running runsvdir instance (via pgrep) and just enables the
# services into $SVDIR. runsvdir then picks them up automatically.
set -e

SVDIR=/run/services
mkdir -p "$SVDIR"

echo "[entrypoint] tedge-standalone version: ${STANDALONE_PKG_VERSION:-unknown}" >&2
echo "[entrypoint] starting runsvdir -P $SVDIR (PID 1)" >&2
echo "[entrypoint] bootstrap with: docker compose exec device /data/tedge/bootstrap.sh --ca c8y --c8y-url <url> --device-id <id> --one-time-password <otp>" >&2

exec runsvdir -P "$SVDIR"
