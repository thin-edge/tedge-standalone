#!/bin/sh
set -e

if [ -f /data/tedge/env ]; then
    set -a
    # shellcheck disable=SC1091
    . /data/tedge/env
    set +a
fi

tedgectl stop tedge-mapper-c8y
tedgectl stop tedge-agent
tedgectl stop mosquitto
