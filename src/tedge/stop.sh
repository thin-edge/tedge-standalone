#!/bin/sh
set -e

if [ -f @CONFIG_DIR@/env ]; then
    set -a
    # shellcheck disable=SC1091
    . @CONFIG_DIR@/env
    set +a
fi

tedgectl stop tedge-mapper-c8y
tedgectl stop tedge-agent
tedgectl stop mosquitto
