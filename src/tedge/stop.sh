#!/bin/sh
set -e

stop_service(){
    name="$1"
    pattern="$1"
    if [ $# -gt 1 ]; then
        pattern="$2"
    fi
    PROC=$(pgrep -f "$pattern")
    if [ -n "$PROC" ]; then
        echo "Stopping $name (pid=$PROC)" >&2
        kill -15 "$PROC"
    else
        echo "Service is not running. name=$name" >&2
    fi
}

stop_service mosquitto
stop_service tedge-agent
stop_service "tedge-mapper-c8y" "tedge-mapper.* c8y"