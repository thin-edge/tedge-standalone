#!/bin/sh
set -e
# Note: tedge-cli is used a lightweight wrapper around tedge to automatically include the custom --config-dir "$CONFIG_DIR" setting

if [ -f /data/tedge/env ]; then
    set -a
    # shellcheck disable=SC1091
    . /data/tedge/env
    set +a
fi

# Init (also creating the multi-call binary symlinks)
tedge-cli init --user root --group root

# Check if a certificate already exists
if [ -z "$(tedge-cli config get device.id 2>/dev/null)" ]; then
    tedge-cli cert create --device-id "$(/data/tedge/bin/tedge-identity 2>/dev/null)"
fi

# Show device certifcate
tedge-cli cert show

if [ -z "$(tedge-cli config get c8y.url 2>/dev/null)" ]; then
    if [ -z "$C8Y_URL" ]; then
        printf "Enter c8y.url: "
        read -r C8Y_URL
    fi

    C8Y_URL=$(echo "$C8Y_URL" | sed 's|^https?://||g')
    echo "Setting c8y.url to $C8Y_URL"
    tedge-cli config set c8y.url "$C8Y_URL"

    if [ -z "$C8Y_USER" ]; then
        printf "Enter your c8y username: "
        read -r C8Y_USER
    fi
    tedge-cli cert upload c8y --user "$C8Y_USER"
    tedge-cli connect c8y
fi

# Show info to user about important connection settings
DEVICE_ID="$(tedge-cli config get device.id 2>/dev/null)"
C8Y_URL="$(tedge-cli config get c8y.url 2>/dev/null)"
echo
echo "--------------------------- Summary ---------------------------"
echo "thin-edge.io"
echo "  device.id:      $DEVICE_ID"
echo "  c8y.url:        $C8Y_URL"
echo "  Cumulocity IoT: https://${C8Y_URL}/apps/devicemanagement/index.html#/assetsearch?filter=*${DEVICE_ID}*"
echo "---------------------------------------------------------------"
echo
