# Telit

## Run thin-edge.io at startup

Using the Telit startup hooks, run the following code to configure the `oem_poststart.sh` script. If the `/data/oem_poststart.sh` file already exists, then you will have to manually edit it to add the code from the [example script](https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/docs/oem_poststart.sh).

```sh
[ ! -f /data/oem_poststart.sh ] && wget -O /data/oem_poststart.sh https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/docs/oem_poststart.sh
chmod +x /data/oem_poststart.sh
```

### Enable SSH

```sh
mkdir -p /data/ssh
echo 1 > /data/ssh/enable_sshd
cp /etc/ssh/sshd_config_readonly /data/ssh/sshd_config_readonly
```

If the `ssh` process does not start, then you can manually start the service by adding the following to the `/data/oem_poststart.sh` file.

```sh
# enable ssh
/etc/init.d/sshd start
```
