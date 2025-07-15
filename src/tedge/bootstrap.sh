#!/bin/sh
set -e
CONFIG_DIR="@CONFIG_DIR@"

CA=${CA:-c8y}
C8Y_URL="${C8Y_URL:-}"
DEVICE_ID="${DEVICE_ID:-}"
DEVICE_USER="${DEVICE_USER:-}"
DEVICE_PASSWORD="${DEVICE_PASSWORD:-}"
DEVICE_ONE_TIME_PASSWORD="${DEVICE_ONE_TIME_PASSWORD:-}"
OFFLINE_MODE="${OFFLINE_MODE:-0}"

usage() {
    cat << EOT
Install thin-edge.io standalone package for running on resource constrained devices
without any accessible init system.

USAGE
    $0 [--install-path <path>] [--version <version>] [--no-upx]

ARGUMENTS
  --c8y-url <url>               Cumulocity URL
  --device-user <name>          Device tenant and username, e.g. t12345/device_tedge01 (Used in Basic Auth mode only).
                                Note: The device-id will be derived from the device user
  --device-password <path>      Device user name (Used in Basic Auth mode only)
  --device-id <name>            Device ID (Cumulocity External ID). tedge-identity will be used if the value is not provided
  --ca <type>                   Certificate Authority Type, e.g. c8y or self-signed. Defaults to c8y (when basic auth is not being used)
  --offline                     Start thin-edge.io without internet (skips registration check). Ideally your device should be pre-registered
                                when using this option

NOTES:

* If mandatory values are not provided, then the script will prompt you for the values. However you can pre-configure all of the settings
  yourself by adding the required settings to the tedge.toml file, and if you're using Basic Auth, then the credentials can also be set
  in the credentials.toml file.

EXAMPLE

    $0 --help
    # Display the bootstrapping options

    $0 --c8y-url example.cumulocity.com --device-user "t12345/tedge01" --device-password "ex4ampl3["
    # Bootstrap device using Cumulocity Basic Auth credentials

    $0 --c8y-url example.cumulocity.com --ca c8y --one-time-password "ex4ampl3["
    # Bootstrap device using Cumulocity Certificate Authority (in PUBLIC_PREVIEW)

    $0 --c8y-url example.cumulocity.com --ca self-signed
    # Bootstrap device using a self signed certificate. This will required you to enter your Cumulocity
    # User's credentials and the Tenant Manager Role
EOT
}

REST_ARGS=""

while [ $# -gt 0 ]; do
    case "$1" in
        --device-id)
            DEVICE_ID="$2"
            shift
            ;;
        --c8y-url)
            C8Y_URL="$2"
            shift
            ;;
        --ca)
            CA="$2"
            shift
            ;;
        --device-user)
            DEVICE_USER="$2"
            shift
            ;;
        --device-password)
            DEVICE_PASSWORD="$2"
            shift
            ;;
        --one-time-password)
            DEVICE_ONE_TIME_PASSWORD="$2"
            shift
            ;;
        --offline)
            OFFLINE_MODE=1
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
            REST_ARGS="$REST_ARGS $1"
            ;;
    esac
    shift
done

# shellcheck disable=SC2086
set -- $REST_ARGS

if [ -f "$CONFIG_DIR/env" ]; then
    # shellcheck disable=SC1091
    . "$CONFIG_DIR/env"
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

    # Note: proactively enable mosquitto otherwise the tedge connect can require
    # a few attempts before it can connect, and sometimes it will fail even after 3 attempts
    echo "Enabling mosquitto by default" >&2
    tedgectl enable mosquitto

elif [ -d /etc/init.d ]; then
    #
    # Setup SysVInit services
    #
    echo "Using /etc/init.d service definitions" >&2
    cp "$CONFIG_DIR/services-init.d"/S[0-9][0-9]* /etc/init.d/
    rm -f "$CONFIG_DIR/bin/tedgectl"
    ln -s "$CONFIG_DIR/services-init.d/tedgectl" "$CONFIG_DIR/bin/tedgectl"

    # Note: proactively enable mosquitto otherwise the tedge connect can require
    # a few attempts before it can connect, and sometimes it will fail even after 3 attempts
    echo "Enabling mosquitto by default" >&2
    tedgectl enable mosquitto
else
    echo "WARNING: Could not start services as 'runsvdir' is not installed. You will need to start the services yourself" >&2
fi


C8Y_AUTH_METHOD=certificate
C8Y_CREDENTIALS_PATH=$(tedge config get c8y.credentials_path 2>/dev/null ||:)

if [ -n "$DEVICE_USER" ] && [ -n "$DEVICE_PASSWORD" ]; then
    # infer device id from basic auth credentials
    C8Y_AUTH_METHOD=basic
    DEVICE_ID=$(echo "$DEVICE_USER" | cut -d/ -f2- | sed 's|^device_||')

    echo "Writing device's basic auth credentials to file: $C8Y_CREDENTIALS_PATH" >&2
    cat <<EOT > "$C8Y_CREDENTIALS_PATH"
[c8y]
username = "$DEVICE_USER"
password = "$DEVICE_PASSWORD"
EOT
elif [ -f "$C8Y_CREDENTIALS_PATH" ]; then
    # infer device id from basic auth credentials
    C8Y_AUTH_METHOD=basic
    DEVICE_ID=$(grep username "$C8Y_CREDENTIALS_PATH" | sed 's/username *= *"\(.*\)"/\1/' | cut -d/ -f2- | sed 's|^device_||')
else
    C8Y_AUTH_METHOD=certificate
fi

tedge config set c8y.auth_method "$C8Y_AUTH_METHOD"

if [ -z "$DEVICE_ID" ]; then
    echo "Using tedge-identity to detect the device.id"
    DEVICE_ID=$("$CONFIG_DIR/bin/tedge-identity" 2>/dev/null)
fi

if [ -n "$DEVICE_ID" ]; then
    tedge config set device.id "$DEVICE_ID"
fi

configure_c8y_url() {
    if [ -z "$(tedge config get c8y.url 2>/dev/null)" ]; then
        if [ -z "$C8Y_URL" ]; then
            printf "Enter c8y.url: "
            read -r C8Y_URL
        fi

        C8Y_URL=$(echo "$C8Y_URL" | sed -E 's|^https?://||g')
        echo "Setting c8y.url to $C8Y_URL"
        tedge config set c8y.url "$C8Y_URL"
    fi
}

configure_self_signed_certificate() {
    # Check if a certificate already exists
    DEVICE_CERT_PATH=$(tedge config get device.cert_path 2>/dev/null ||:)

    if [ ! -f "$DEVICE_CERT_PATH" ]; then
        tedge cert create --device-id "$DEVICE_ID"
        # Note: If the user is blank, tedge will prompt for the required information
        tedge cert upload c8y --user "$C8Y_USER"
    else
        # Show device certificate
        tedge cert show
    fi
}

configure_c8y_ca_certificate() {
    DEVICE_CERT_PATH=$(tedge config get device.cert_path 2>/dev/null ||:)

    if [ -f "$DEVICE_CERT_PATH" ]; then
        echo "Device certificate already exists" >&2
        return 0
    fi

    GENERATE_ONE_TIME_PASSWORD=1
    if [ "$GENERATE_ONE_TIME_PASSWORD" = 1 ] && [ -z "$DEVICE_ONE_TIME_PASSWORD" ] && [ -n "$DEVICE_ID" ]; then
        DEVICE_ONE_TIME_PASSWORD=$(printf "%s" "$DEVICE_ID" | md5sum | awk '{print $1}')
    fi

    C8Y_HOST=$(tedge config get c8y.url 2>/dev/null ||:)
    if [ -n "$C8Y_HOST" ]; then
        echo "Cumulocity Registration URL"
        echo
        echo "  Cumulocity:  https://$C8Y_HOST/apps/devicemanagement/index.html#/deviceregistration?externalId=$DEVICE_ID&one-time-password=$DEVICE_ONE_TIME_PASSWORD"
        echo
    fi

    tedge cert download c8y --device-id "$DEVICE_ID" --one-time-password "$DEVICE_ONE_TIME_PASSWORD" --retry-every 5s --max-timeout 300s
}

connect_c8y() {
    if [ -n "$(tedge config get c8y.url 2>/dev/null)" ]; then
        CONNECT_ARGS=
        case "$OFFLINE_MODE" in
            1|yes|true)
                CONNECT_ARGS="--offline"
                ;;
        esac

        tedge reconnect c8y $CONNECT_ARGS
    fi
}

post_bootstrap() {
    MESSAGE=$(printf '{"text": "tedge started up 🚀 version=%s"}' "$(tedge --version | cut -d' ' -f2)")
    tedge mqtt pub --qos 1 "te/device/main///e/startup" "$MESSAGE"
}

#
# Configure
#
configure_c8y_url

case "$C8Y_AUTH_METHOD" in
    certificate)
        case "$CA" in
            self-signed)
                configure_self_signed_certificate
                ;;
            c8y)
                configure_c8y_ca_certificate
                ;;
            *)
                echo "ERROR: Unknown certificate authority option. value=$CA. Available options: [self-signed, ca]" >&2
                exit 1
                ;;
        esac
        ;;
esac

connect_c8y

sleep 5
post_bootstrap

# Show info to user about important connection settings
DEVICE_ID="$(tedge config get device.id 2>/dev/null ||:)"
C8Y_URL="$(tedge config get c8y.url 2>/dev/null ||:)"
echo
echo "--------------------------- Summary ---------------------------"
echo "thin-edge.io"
echo "  device.id:      ${DEVICE_ID:-not configured}"
echo "  c8y.url:        ${C8Y_URL:-not configured}"
if [ -n "$DEVICE_ID" ] && [ -n "$C8Y_URL" ]; then
    echo "  Cumulocity IoT: https://${C8Y_URL}/apps/devicemanagement/index.html#/assetsearch?filter=*${DEVICE_ID}*"
fi
echo "---------------------------------------------------------------"
echo
