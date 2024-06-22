# tedge-standalone


## Bootstrapping

Run the start.sh script to run the bootstrap process to create a certificate and connect thin-edge.io

```sh
/data/tedge/start.sh
```

## Auto starting thin-edge.io

### Example: telit

Using the Telit startup hooks, the following code can be added to the `oem_poststart.sh` file to automatically start mosquitto and the thin-edge.io components on device startup.

**file: /data/oem_poststart.sh**

```sh
#!/bin/sh

#
# Activate Modem
#
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

#
# Start thin-edge.io components
#
sleep 1
/data/tedge/start.sh > /dev/kmsg
```

## SSH

Generate SSH server keys to a custom location.

```sh
ssh-keygen -q -N "" -t dsa -f /data/ssh/ssh_host_dsa_key
ssh-keygen -q -N "" -t rsa -b 4096 -f /data/ssh/ssh_host_rsa_key
ssh-keygen -q -N "" -t ecdsa -f /data/ssh/ssh_host_ecdsa_key
ssh-keygen -q -N "" -t ed25519 -f /data/ssh/ssh_host_ed25519_key
```
