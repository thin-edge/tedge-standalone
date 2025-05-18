#!/bin/sh
set -e

if [ -f @CONFIG_DIR@/env ]; then
    # shellcheck disable=SC1091
    . @CONFIG_DIR@/env
fi

tedgectl stop tedge-mapper-c8y
tedgectl stop tedge-agent
tedgectl stop mosquitto
