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
wget -q -O - https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/install.sh | sh -s -- --install-path /data
```

**Using curl**

```sh
curl -fsSL https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/install.sh | sh -s -- --install-path /data
```

Then, follow the instructions printed out on the console to bootstrap (configure) and then start the services. However if you are planning on using Cumulocity's basic authentication, then you need to run the following section before running the `bootstrap.sh` script.

### Using Cumulocity basic authentication

Before running the `boostrap.sh` script, you will need to set the device's credentials (username/password).

For example, if you installed thin-edge.io under `/data` then you can set the credentials using the following snippet:

```sh
cat <<EOT > /data/tedge/credentials
[c8y]
username = "{tenant}/device_{external_id}"
password = "{password}"
EOT
```

## Automatically starting services

### Device specific instructions

If your device is listed below, then you can follow the device specific instructions on how to configure thin-edge.io to start automatically at boot-up.

* [Telit](./docs/TELIT.md)
* [Advantech](./docs/ADVANTECH.md)


### General instructions

Assuming you have already bootstrapped the device (e.g. configured the Cumulocity IoT instance, and uploaded the device certificate), then you need to add the following lines to your startup routine:

```sh
/data/tedge/bootstrap.sh
```

Then reboot device to check if the services are started correctly.

**Note** The above snippet uses **runit** to launch the thin-edge.io services from a custom configured services directory (as defined in the `/data/tedge/env` dotenv file). **runit** is used as it is included in busy-box and provides service supervision (e.g. it will automatically relaunch the service if it crashes for any reason).

## Service management

Assuming you have already launched the custom `runsvdir` instance, the following commands can be used to manage the thin-edge.io related services. The commands use a wrapper (`tedgectl`) around the **runit** commands for convenience (and `tedgectl` is used in the init system integration defined in the `system.toml` file).

Before running any of the command you need to load the environment variables using the following one-liner:

```sh
set -a; . /data/tedge/env; set +a
```

### Start services

```sh
tedgectl start tedge-agent
tedgectl start tedge-mapper-c8y
tedgectl start mosquitto
```

### Stop services

```sh
tedgectl stop tedge-agent
tedgectl stop tedge-mapper-c8y
tedgectl stop mosquitto
```

### Enable services

Enable services so they automatically run on startup.

```sh
tedgectl enable mosquitto
tedgectl enable tedge-agent
tedgectl enable tedge-mapper-c8y
```


### Disable services

Disable services so they don't automatically run on startup.

```sh
tedgectl disable mosquitto
tedgectl disable tedge-agent
tedgectl disable tedge-mapper-c8y
```

## Upgrading

https://cloudsmith.io/~thinedge/repos/tedge-main/packages/?q=format%3Araw


For example, the [tedge-armv7](https://cloudsmith.io/~thinedge/repos/tedge-main/packages/detail/raw/tedge-armv7/1.1.2-rc135+gf35f1f1/) package.

```sh
c8y software get --id tedge || c8y software create --name tedge --data softwareType=executable

# Add a new version for installation
c8y software versions create --software tedge --version "1.1.2-rc135+gf35f1f1" --url "https://dl.cloudsmith.io/public/thinedge/tedge-main/raw/names/tedge-armv7/versions/1.1.2-rc135+gf35f1f1/tedge.tar.gz"
```

## ca-certificates

The standalone installation includes an existing **ca-certificates.crt** file which is installed under `/data/tedge/ca-certificates.crt`. Depending on which Cumulocity IoT instance, and external services you wish to use with thin-edge.io, you may need to add addition CA certificates to the file.
