#!/bin/sh
set -e
INSTALL_PATH="${INSTALL_PATH:-/data}"

usage() {
    cat << EOT
Actility TAO Kerlink installation script which adds configuration
required to run thin-edge.io reliably.

USAGE
    $0 --install-path <path>

ARGUMENTS
  --install-path <path>         Install path. Defaults to $INSTALL_PATH

EXAMPLE

    $0 --install-path /data
    # Install under a custom location
EOT
}

while [ $# -gt 0 ]; do
    case "$1" in
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

if [ -f "$INSTALL_PATH/tedge/env" ]; then
	. "$INSTALL_PATH/tedge/env" ||:
fi

if [ -z "$TEDGE_CONFIG_DIR" ]; then
	echo "ERROR: The env variable 'TEDGE_CONFIG_DIR' has not been set. Check your /etc/profile" >&2
	exit 1
fi

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
		echo "echo Enable monit monitoring of thin-edge.io services"
		echo "monit monitor tedge-mosquitto tedge-mapper-c8y tedge-agent"
	} > "$TEDGE_CONFIG_DIR/bootstrap.d/10_enable_monit"
	chmod +x "$TEDGE_CONFIG_DIR/bootstrap.d/10_enable_monit"
fi

echo "Setting tedge settings to use a custom mqtt port (1884)" >&2
tedge config set mqtt.bind.port 1884 2>/dev/null
tedge config set mqtt.client.port 1884 2>/dev/null
