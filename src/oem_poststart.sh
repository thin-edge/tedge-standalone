#!/bin/sh

# Wait before trying to activate the modem other it won't work
# TODO: Find a more reliable way to confirm that the activation worked
sleep 30
echo "Activating modem" > /dev/kmsg
# Read from the modem interface to get feedback when connecting
cat /dev/smd8 &
MON_PID="$!"
# Note /dev/smd8 only works on LE910C1 chips
# See the Telit LE91* manual for more details
(printf 'at#sgact=1,1\r' | socat - /dev/smd8) ||:
sleep 2
kill -9 "$MON_PID" ||:

sleep 1
/data/tedge/start.sh > /dev/kmsg
