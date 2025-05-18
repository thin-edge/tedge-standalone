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

#
# Configure services if runit is installed
#
if command -V runsvdir >/dev/null 2>&1; then
    #
    # Setup runit services
    #
    if ! grep -q '^export SVDIR=/.*' "$CONFIG_DIR/env"; then
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
        echo "export SVDIR=$SVDIR" >> "$CONFIG_DIR/env"
        export SVDIR
    fi

    mkdir -p "$SVDIR"

    # Start runit in the background
    if ! pgrep -f "runsvdir -P $SVDIR" >/dev/null 2>&1; then
        echo "Starting services using runit: runsvdir -P \"$SVDIR/\" &" >&2
        runsvdir -P "$SVDIR/" &
    else
        echo "Services are already running via: runsvdir -P \"$SVDIR\""
    fi
elif [ -d /etc/init.d ]; then
    #
    # Setup SysVInit services
    #
    echo "Using /etc/init.d service definitions" >&2
    cp "@CONFIG_DIR@/services-init.d"/S[0-9][0-9]* /etc/init.d/
    rm -f "@CONFIG_DIR@/bin/tedgectl"
    ln -s "@CONFIG_DIR@/services-init.d/tedgectl" "@CONFIG_DIR@/bin/tedgectl"
else
    echo "WARNING: Could not start services as 'runsvdir' is not installed. You will need to start the services yourself" >&2
fi



if [ $# -gt 0 ]; then
    DEVICE_ID="$1"
fi

#
# Detect authentication, get device.id from the credentials file
#
C8Y_AUTH_METHOD=$(tedge config get c8y.auth_method ||:)
C8Y_CREDENTIALS_PATH=$(tedge config get c8y.credentials_path ||:)
NEEDS_CERT_UPLOAD=1
if [ "$C8Y_AUTH_METHOD" = "basic" ] || [ "$C8Y_AUTH_METHOD" = "auto" ]; then
    if [ -f "$C8Y_CREDENTIALS_PATH" ]; then
        DEVICE_ID=$(grep username "$C8Y_CREDENTIALS_PATH" | sed 's/username *= *"\(.*\)"/\1/' | cut -d/ -f2- | sed 's|^device_||')
        echo "Using c8y.credentials_path as authentication. device.id=$DEVICE_ID" >&2
        NEEDS_CERT_UPLOAD=0
    fi
fi

post_bootstrap() {
    MESSAGE=$(printf '{"text": "tedge started up 🚀 version=%s"}' "$(tedge --version | cut -d' ' -f2)")
    tedge mqtt pub --qos 1 "te/device/main///e/startup" "$MESSAGE"
}

# Check if a certificate already exists
if [ -z "$(tedge config get device.id 2>/dev/null)" ]; then
    if [ -z "$DEVICE_ID" ]; then
        DEVICE_ID=$(@CONFIG_DIR@/bin/tedge-identity 2>/dev/null)
    fi
    tedge cert create --device-id "$DEVICE_ID"
fi

# Show device certificate
tedge cert show

if [ -z "$(tedge config get c8y.url 2>/dev/null)" ]; then
    if [ -z "$C8Y_URL" ]; then
        printf "Enter c8y.url: "
        read -r C8Y_URL
    fi

    C8Y_AUTH_METHOD=$(tedge config get c8y.auth_method ||:)
    C8Y_CREDENTIALS_PATH=$(tedge config get c8y.credentials_path ||:)
    NEEDS_CERT_UPLOAD=1
    if [ "$C8Y_AUTH_METHOD" = "basic" ] || [ "$C8Y_AUTH_METHOD" = "auto" ]; then
        if [ -f "$C8Y_CREDENTIALS_PATH" ]; then
            echo "Using c8y.credentials_path as authentication" >&2
            NEEDS_CERT_UPLOAD=0
        fi
    fi

    C8Y_URL=$(echo "$C8Y_URL" | sed 's|^https?://||g')
    echo "Setting c8y.url to $C8Y_URL"
    tedge config set c8y.url "$C8Y_URL"

    if [ "$NEEDS_CERT_UPLOAD" = 1 ]; then
        if [ -z "$C8Y_USER" ]; then
            printf "Enter your c8y username: "
            read -r C8Y_USER
        fi
        tedge cert upload c8y --user "$C8Y_USER"
    fi

    tedge connect c8y
fi


sleep 5
post_bootstrap

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
