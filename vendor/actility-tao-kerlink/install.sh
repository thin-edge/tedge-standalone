#!/bin/sh
set -e

if [ -f /etc/profile ]; then
	. /etc/profile
fi

if [ -n "$TEDGE_CONFIG_DIR" ]; then
	echo "Adding Actility tao kerlink tedge-identity to $TEDGE_CONFIG_DIR/bin/tedge-identity" >&2
	cat <<'EOT'	> "$TEDGE_CONFIG_DIR/bin/tedge-identity"
#!/bin/sh
set -eu

IDENTITY_PREFIX=${IDENTITY_PREFIX:-}
DEVICE_ID=${DEVICE_ID:-}

if [ -d /user/actility/FDB_lora/lUUID ]; then
    # try parsing it from the xml file
    DEVICE_ID=$(awk -F'<LRRuuid>|</LRRuuid>' '{print $2; exit}' /user/actility/FDB_lora/lUUID/* | head -n1)
    if [ -z "$DEVICE_ID" ]; then
        # fallback to using the filename
        DEVICE_ID=$(find /user/actility/FDB_lora/lUUID -type f -maxdepth 1 -exec basename {} \; | head -n1)
    fi
fi

if [ -n "$DEVICE_ID" ]; then
    if [ -n "$IDENTITY_PREFIX" ]; then
        echo "${IDENTITY_PREFIX}-${DEVICE_ID}"
    else
        echo "${DEVICE_ID}"
    fi
    exit 0
fi

exit 1
EOT
	chmod +x "$TEDGE_CONFIG_DIR/bin/tedge-identity"
fi

if [ -d /etc/monit.d ]; then
	echo "Adding tedge monit rules to /etc/monit.d/tedge" >&2
	cat <<EOT >/etc/monit.d/tedge
CHECK PROCESS tedge-mapper-c8y PIDFILE /var/run/lock/tedge-mapper-c8y.lock
	start program = "/etc/init.d/S99tedge-mapper-c8y start"
	stop program = "/etc/init.d/S99tedge-mapper-c8y stop"
	onreboot start

CHECK PROCESS tedge-agent PIDFILE /var/run/lock/tedge-agent.lock
	start program = "/etc/init.d/S99tedge-agent start"
	stop program = "/etc/init.d/S99tedge-agent stop"
	onreboot start

CHECK PROCESS tedge-mosquitto PIDFILE /var/run/lock/mosquitto.lock
	start program = "/etc/init.d/S99mosquitto start"
	stop program = "/etc/init.d/S99mosquitto stop"
	onreboot start
EOT

	# add bootstrap script to enable the monit rules
	# as it should only be enabled after tedge has been configured
	mkdir -p "$TEDGE_CONFIG_DIR/bootstrap.d"
	{
		echo "#!/bin/sh"
		echo "set -e"
		echo "monit monitor tedge-mosquitto tedge-mapper-c8y tedge-agent"
	} > "$TEDGE_CONFIG_DIR/bootstrap.d/10_enable_monit"
	chmod +x "$TEDGE_CONFIG_DIR/bootstrap.d/10_enable_monit"
fi

echo "Setting tedge settings to use a custom mqtt port (1884)" >&2
tedge config set mqtt.bind.port 1884 2>/dev/null
tedge config set mqtt.client.port 1884 2>/dev/null
