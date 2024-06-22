# Telit

## Run thin-edge.io at startup

Using the Telit startup hooks, the following code can be added to the `oem_poststart.sh` file to automatically start mosquitto and the thin-edge.io components on device startup.

```sh
echo "/data/tedge/start.sh > /dev/kmsg" >> /data/oem_poststart.sh
```

### Activate modem on start-up

```sh
if [ ! -f /data/oem_poststart.sh ]; then
cat << EOT > /data/oem_poststart.sh
#!/bin/sh

# Activate Modem
# Wait before trying to activate the modem other it won't work
# TODO: Find a more reliable way to confirm that the activation worked
sleep 30
echo "Activating modem" > /dev/kmsg
# Read from the modem interface to get feedback when connecting
cat /dev/smd8 &
MON_PID="\$!"
# Note /dev/smd8 only works on LE910C1 chips
# See the Telit LE91* manual for more details
(printf 'at#sgact=1,1\r' | socat - /dev/smd8) ||:
sleep 2
kill -9 "\$MON_PID" ||:
EOT
fi
```

### Enable SSH

```sh
mkdir -p /data/ssh
echo 1 > /data/ssh/enable_sshd
cp /etc/ssh/sshd_config_readonly /data/ssh/sshd_config_readonly
```
