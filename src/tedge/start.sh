#!/bin/sh

export SSL_CERT_FILE=/data/tedge/c8y.crt

export PATH="/data/tedge/bin:$PATH"
CONFIG_DIR=/data/tedge

# Init (also creating the symlinks if required)
tedge init --config-dir "$CONFIG_DIR" --user root --group root

# Check if a certificate already exists
if [ -z "$(tedge config get --config-dir "$CONFIG_DIR" device.id >/dev/null 2>&1)" ]; then
    tedge cert create --config-dir "$CONFIG_DIR" --device-id "$(/data/tedge/bin/tedge-identity)"
fi

if [ -z "$(tedge config get --config-dir "$CONFIG_DIR" c8y.url >/dev/null 2>&1)" ]; then
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

echo "Starting mosquitto"
killall -q mosquitto
nohup mosquitto -c /data/tedge/mosquitto.conf > /tmp/tedge.log &
sleep 1

echo "Starting tedge-agent"
killall -q tedge-agent
nohup tedge-agent --config-dir /data/tedge > /tmp/tedge.log &

echo "Starting tedge-mapper-c8y"
killall -q tedge-mapper
nohup tedge-mapper --config-dir /data/tedge c8y > /tmp/tedge.log &
