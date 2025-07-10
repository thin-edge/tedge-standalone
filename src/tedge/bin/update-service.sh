#!/bin/sh
set -e
##################################################################
# Update (including optional registration) a service's status with
# the local MQTT broker so that the service status can be sent to
# any connected cloud
#
# Note: This is a convenience script which uses the tedge cli to do all of the main interactions
#
# Example on how to use the script within a runit system definition
#
# file: services/app1/run
#
#   $CONFIG_DIR/bin/update-service.sh --register --name app1 --status up
#   exec /usr/bin/app1
#
# file: services/app1/finish
#
#   $CONFIG_DIR/bin/update-service.sh --name app1 --status down
#   sleep 2
#
##################################################################

register_service() {
    parent_topic_id="$1"
    topic_id="$2"
    name="$3"
    payload=$(
        cat << EOT
    {
        "@parent": "$parent_topic_id",
        "@topic-id": "$topic_id",
        "@type": "service",
        "name": "$name"
    }
EOT
    )

    # register entity (will be a no-op if it is already registered)
    tedge http post /te/v1/entities "$payload" 2>/dev/null ||:
}

update_service_status() {
    # try publishing health status
    topic_id="$1"
    status="$2"
    topic_root=$(tedge config get mqtt.topic_root)
    tedge mqtt pub --retain "$topic_root/$topic_id/status/health" "{\"status\":\"$status\"}" ||:
}


#
# Argument parsing
#
REGISTER=0
NAME=
STATUS=
SERVICE_TOPIC_ID=
PARENT_TOPIC_ID=$(tedge config get mqtt.device_topic_id)

while [ $# -gt 0 ]; do
    case "$1" in
        --register)
            REGISTER=1
            ;;
        --name)
            NAME="$2"
            SERVICE_TOPIC_ID="device/main/service/$NAME"
            shift
            ;;
        --status)
            STATUS="$2"
            shift
            ;;
    esac
    shift
done

if [ "$REGISTER" = 1 ]; then
    register_service "$PARENT_TOPIC_ID" "$SERVICE_TOPIC_ID" "$NAME"
fi

update_service_status "$SERVICE_TOPIC_ID" "$STATUS"
