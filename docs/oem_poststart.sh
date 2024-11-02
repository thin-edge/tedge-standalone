#!/bin/sh

# Activate Modem
# Wait before trying to activate the modem other it won't work
# TODO: Find a more reliable way to confirm that the activation worked
sleep 30
echo "Activating modem" > /dev/kmsg
# Read from the modem interface to get feedback when connecting
cat /dev/smd8 >/dev/smd8 &
MON_PID="\$!"
# Note /dev/smd8 only works on LE910C1 chips
# See the Telit LE91* manual for more details
(printf 'at#sgact=1,1\r' | socat - /dev/smd8) ||:
sleep 2
kill -9 "$MON_PID" ||:

# enable ssh
mkdir -p /data/ssh
echo 1 > /data/ssh/enable_sshd
if [ ! -f /data/ssh/sshd_config_readonly ]; then
    cp /etc/ssh/sshd_config_readonly /data/ssh/sshd_config_readonly
fi

/etc/init.d/sshd start ||:

# start thin-edge.io
. @CONFIG_DIR@/env
mkdir -p "$SVDIR"
tedgectl enable mosquitto
tedgectl enable tedge-agent
tedgectl enable tedge-mapper-c8y
runsvdir -P "$SVDIR/" &

# optional: Send event to cloud to indicate that thin-edge.io is running
sleep 5
MESSAGE=$(printf '{"text": "tedge started up 🚀 version=%s"}' "$(c --version | cut -d' ' -f2)")
tedge mqtt pub --qos 1 "te/device/main///e/startup" "$MESSAGE"
