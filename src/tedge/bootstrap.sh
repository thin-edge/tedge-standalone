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
