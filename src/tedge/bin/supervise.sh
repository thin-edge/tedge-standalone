#!/bin/sh
name="$1"
shift

# Trap common errors, as the supervisor should be resilient
trap 'echo "ignoring signal"' EXIT INT HUP

DATA_DIR=${DATA_DIR:-/data/tedge}

echo "Note: Stop the service by executing: 'echo 0 > /data/tedge/enable_$name'"

while :; do
    activate_file="$DATA_DIR/enable_$name"
    if [ -f "$activate_file" ]; then
        SHOULD_RUN=$(head -n1 "$activate_file" ||:)
        if [ "$SHOULD_RUN" = 0 ]; then
            echo "Supervision of $name has been disabled (set to 0) via file: $activate_file"
            exit 0
        fi
    fi

    echo "Starting $name"
    if ! "$@"; then
        exit_code="$?"
        echo "Process stopped with a non-zero exit code. name=$name, code=$exit_code"
    fi
    echo "Waiting 5 seconds before restarting. name=$name"
    sleep 5
done
