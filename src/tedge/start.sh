#!/bin/sh

export SSL_CERT_FILE=/data/tedge/c8y.crt

export PATH="/data/tedge/bin:$PATH"
export CONFIG_DIR=/data/tedge

# Init (also creating the symlinks if required)
tedge init --config-dir "$CONFIG_DIR" --user root --group root

# Check if a certificate already exists
if [ -z "$(tedge config get --config-dir "$CONFIG_DIR" device.id 2>/dev/null)" ]; then
    tedge cert create --config-dir "$CONFIG_DIR" --device-id "$(/data/tedge/bin/tedge-identity 2>/dev/null)"
fi

if [ -z "$(tedge config get --config-dir "$CONFIG_DIR" c8y.url 2>/dev/null)" ]; then
    if [ -z "$C8Y_URL" ]; then
        printf "Enter c8y.url: "
        read -r C8Y_URL
    fi

    C8Y_URL=$(echo "$C8Y_URL" | sed 's|^https?://||g')
    echo "Setting c8y.url to $C8Y_URL"
    tedge config set --config-dir "$CONFIG_DIR" c8y.url "$C8Y_URL"

    if [ -z "$C8Y_USER" ]; then
        printf "Enter your c8y username: "
        read -r C8Y_USER
    fi
    tedge cert upload c8y --config-dir "$CONFIG_DIR" --user "$C8Y_USER"
    tedge connect c8y --config-dir "$CONFIG_DIR"
fi

# killall -q mosquitto
if ! pgrep -f "supervise.sh mosquitto"; then
    nohup supervise.sh mosquitto mosquitto -c /data/tedge/mosquitto.conf > /tmp/tedge.log &
    sleep 1
else
    echo "mosquitto is already running supervised"
fi

if ! pgrep -f "supervise.sh tedge-agent"; then
    nohup supervise.sh tedge-agent tedge-agent --config-dir /data/tedge > /tmp/tedge.log &
    sleep 1
else
    echo "tedge-agent is already running supervised"
fi

if ! pgrep -f "supervise.sh tedge-mapper-c8y"; then
    nohup supervise.sh tedge-mapper-c8y tedge-mapper --config-dir /data/tedge c8y > /tmp/tedge.log &
else
    echo "tedge-mapper-c8y is already running supervised"
fi
