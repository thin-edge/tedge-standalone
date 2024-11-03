#!/bin/sh
set -e
if [ -f @CONFIG_DIR@/env ]; then
    set -a
    # shellcheck disable=SC1091
    . @CONFIG_DIR@/env
    set +a
fi

# Init (also creating the multi-call binary symlinks)
tedge init --user root --group root

# Check if a certificate already exists
if [ -z "$(tedge config get device.id 2>/dev/null)" ]; then
    tedge cert create --device-id "$(@CONFIG_DIR@/bin/tedge-identity 2>/dev/null)"
fi

# Show device certifcate
tedge cert show

if [ -z "$(tedge config get c8y.url 2>/dev/null)" ]; then
    if [ -z "$C8Y_URL" ]; then
        printf "Enter c8y.url: "
        read -r C8Y_URL
    fi

    C8Y_URL=$(echo "$C8Y_URL" | sed 's|^https?://||g')
    echo "Setting c8y.url to $C8Y_URL"
    tedge config set c8y.url "$C8Y_URL"

    if [ -z "$C8Y_USER" ]; then
        printf "Enter your c8y username: "
        read -r C8Y_USER
    fi
    tedge cert upload c8y --user "$C8Y_USER"
    tedge connect c8y
fi

#
# Configure services if runit is installed
#
if command -V runsvdir >/dev/null 2>&1; then
    if ! grep -q '^SVDIR=/.*' @CONFIG_DIR@/env; then
        if [ -d /var/run ]; then
            SVDIR=/var/run/services
        elif [ -d /run ]; then
            SVDIR=/run/services
        elif [ -d /tmp ]; then
            SVDIR=/tmp/services
        else
            echo "Could not find a volatile directory for the runit services" >&2
            exit 1
        fi
        echo "SVDIR=$SVDIR" >> "@CONFIG_DIR@/env"
        export SVDIR
    fi

    mkdir -p "$SVDIR"
    tedgectl enable mosquitto
    tedgectl enable tedge-agent
    tedgectl enable tedge-mapper-c8y

    # Start runit in the background
    if ! pgrep -f "runsvdir -P $SVDIR" >/dev/null 2>&1; then
        echo "Starting services using runit: runsvdir -P \"$SVDIR/\" &" >&2
        runsvdir -P "$SVDIR/" &
    else
        echo "Services are already running via: runsvdir -P \"$SVDIR\""
    fi

    sleep 5
    MESSAGE=$(printf '{"text": "tedge started up 🚀 version=%s"}' "$(tedge --version | cut -d' ' -f2)")
    tedge mqtt pub --qos 1 "te/device/main///e/startup" "$MESSAGE"
else
    echo "WARNING: Could not start services as 'runsvdir' is not installed. You will need to start the services yourself" >&2
fi

# Show info to user about important connection settings
DEVICE_ID="$(tedge config get device.id 2>/dev/null)"
C8Y_URL="$(tedge config get c8y.url 2>/dev/null)"
echo
echo "--------------------------- Summary ---------------------------"
echo "thin-edge.io"
echo "  device.id:      $DEVICE_ID"
echo "  c8y.url:        $C8Y_URL"
echo "  Cumulocity IoT: https://${C8Y_URL}/apps/devicemanagement/index.html#/assetsearch?filter=*${DEVICE_ID}*"
echo "---------------------------------------------------------------"
echo
