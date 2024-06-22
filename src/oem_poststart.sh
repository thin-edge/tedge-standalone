#!/bin/sh

#
# Delay before trying to enable the modem otherwise it can fail
# Note: /dev/smd8 only works on LE910C1 chips, see the Telit LE91* manual for more details
# TODO: Replace sleep with a more reliable method
#
sleep 30
echo "Activating modem" > /dev/kmsg
cat /dev/smd8 > /dev/kmsg &
MON_PID="$!"
(printf 'at#sgact=1,1\r' | socat - /dev/smd8) ||:
sleep 2
if [ -n "$MON_PID" ]; then
    kill -9 "$MON_PID" ||:
fi

sleep 1
/data/tedge/start.sh > /dev/kmsg
