#!/bin/sh
set -e

FORCE=0
INSTALL_PATH="${INSTALL_PATH:-/data}"

usage() {
    cat << EOT
Remove thin-edge.io and all of its components.

USAGE
    $0 --force

ARGUMENTS
  --force                   Force removal of thin-edge.io.
                            If not provided then the script will not do anything
  --install-path <path>     Install path. Defaults to $INSTALL_PATH

EXAMPLE

    $0 --force
    # Remove thin-edge.io

    $0 --force --install-path /user
    # Remove thin-edge.io under the /user directory
EOT
}

while [ $# -gt 0 ]; do
    case "$1" in
        --force)
            FORCE=1
            ;;
        --install-path)
            INSTALL_PATH="$2"
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        --*|-*)
            echo "Unknown flags. $1" >&2
            exit 1
            ;;
        *)
            echo "Unexpected positional arguments" >&2
            exit 1
            ;;
    esac
    shift
done

if [ "$FORCE" != 1 ]; then
    echo "ERROR: You must call this script with '--force' to confirm the removal of thin-edge.io" >&2
    exit 1
fi

BASE_DIR="$INSTALL_PATH/tedge"

if [ ! -d "$BASE_DIR" ]; then
    echo "ERROR: tedge installation path was not found. path=$BASE_DIR"
    exit 1
fi

if [ -f "$BASE_DIR/env" ]; then
    # shellcheck disable=SC1091
    . "$BASE_DIR/env"
fi

echo "Stopping services" >&2
tedgectl stop tedge-mapper-c8y ||:
tedgectl stop tedge-agent ||:
tedgectl stop mosquitto ||:

# monit config (if present)
rm -f /etc/monit.d/tedge

# service definitions
echo "Removing service definitions" >&2
rm -f /etc/init.d/*tedge-agent*
rm -f /etc/init.d/*tedge-mapper*
rm -f /etc/init.d/*mosquitto*

if command -V update-rc.d >/dev/null 2>&1; then
    # remove old services which are no longer used
    update-rc.d -f tedge-reconnect remove >/dev/null 2>&1 ||:
fi

# logs
echo "Removing log files" >&2
rm -rf "$(tedge config get logs.path)"
rm -rf "$(tedge config get data.path)"
rm -rf /var/log/tedge-*.log

# shell profiles
rm -f /etc/profile.d/tedge

# app
if [ -d "$BASE_DIR" ]; then
    echo "Removing thin-edge.io directory. path=$BASE_DIR" >&2
    rm -rf "$BASE_DIR"
fi
