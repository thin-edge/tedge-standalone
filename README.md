# tedge-standalone

This repository shows how thin-edge.io can be packaged and installed on a device which has the following constraints:

* device has less than 5 MB disk space on the read-write partition
* device uses a read-only root filesystem (rootfs) which results in the following restrictions:
    * Can't add or modify services in the init system -> need custom init system
    * Can't add linux users or groups -> need to run services as **root**
    * Can't install any dependencies in the system files -> need static MQTT broker installed at a custom location
    * Can't install files in the default locations (e.g. `/etc/tedge`) -> need to install all components under a custom path (which is read-writable)

## Pre-requisites

The following pre-requisites are required for the standalone thin-edge.io version to work.

* busy-box (with the following binaries)
    * wget
    * runsvdir

## Install

The following command can be used to install the standalone/portable thin-edge.io version.

**Using wget**

```sh
wget -q -O - https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/install.sh | sh -s
```

**Using curl**

```sh
curl -fsSL https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/install.sh | sh -s
```

## Bootstrapping

Run the `bootstrap.sh` script to run the bootstrap process to create a certificate and connect thin-edge.io.

```sh
/data/tedge/bootstrap.sh
```

Alternatively, you can do the bootstrapping yourself but running the following commands:

```sh
. /data/tedge/env
tedge-cli cert create --device-id "mydeviceid"
tedge-cli config set c8y.url "<myurl>"
tedge-cli cert upload c8y --user "<myuser>"
```

Where `tedge-cli` is a custom wrapper around `tedge` which sets the custom configuration directory for you from the `CONFIG_DIR` environment variable, via `--config-dir "$CONFIG_DIR"`. The `tedge-cli` wrapper can be removed once the following ticket this ticket is implemented, https://github.com/thin-edge/thin-edge.io/issues/1794.


## Automatically starting services

**Note:** For Telit devices, checkout these [instructions](./docs/TELIT.md).

Assuming you have already bootstrapped the device (e.g. configured the Cumulocity IoT instance, and uploaded the device certificate), then you need to add the following lines to your startup routine:

```sh
. /data/tedge/env
mkdir -p "$SVDIR"
tedgectl enable mosquitto
tedgectl enable tedge-agent
tedgectl enable tedge-mapper-c8y
runsvdir -P "$SVDIR/" &

sleep 5
MESSAGE=$(printf '{"text": "tedge started up 🚀 version=%s"}' "$(tedge-cli --version | cut -d' ' -f2)")
tedge-cli mqtt pub --qos 1 "te/device/main///e/startup" "$MESSAGE"
```

Then reboot device to check if the services are started correctly.

**Note** The above snippet uses **runit** to launch the thin-edge.io services from a custom configured services directory (as defined in the `/data/tedge/env` dotenv file). **runit** is used as it is included in busy-box and provides service supervision (e.g. it will automatically relaunch the service if it crashes for any reason).

## Service management

Assuming you have already launched the custom `runsvdir` instance, the following commands can be used to manage the thin-edge.io related services. The commands use a wrapper (`tedgectl`) around the **runit** commands for convenience (and `tedgectl` is used in the init system integration defined in the `system.toml` file).

### Start services

```sh
. /data/tedge/env
tedgectl start tedge-agent
tedgectl start tedge-mapper-c8y
tedgectl start mosquitto
```

### Stop services

```sh
. /data/tedge/env
tedgectl stop tedge-agent
tedgectl stop tedge-mapper-c8y
tedgectl stop mosquitto
```

### Enable services

Enable services so they automatically run on startup.

```sh
. /data/tedge/env
tedgectl enable mosquitto
tedgectl enable tedge-agent
tedgectl enable tedge-mapper-c8y
```


### Disable services

Disable services so they don't automatically run on startup.

```sh
. /data/tedge/env
tedgectl disable mosquitto
tedgectl disable tedge-agent
tedgectl disable tedge-mapper-c8y
```
