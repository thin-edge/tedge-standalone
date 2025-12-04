# tedge-standalone

This repository shows how thin-edge.io can be packaged and installed on a device which has the following constraints:

* device has very little disk space on the read-write partition
    * Requires 5MB  - when using compressed (upx'd) binaries
    * Requires 14MB - when using uncompressed (non-upx'd) binaries
* device uses a read-only root filesystem (root-fs) which results in the following restrictions:
    * Can't add or modify services in the init system -> need custom init system
    * Can't add linux users or groups -> need to run services as **root**
    * Can't install any dependencies in the system files -> need static MQTT broker installed at a custom location
    * Can't install files in the default locations (e.g. `/etc/tedge`) -> need to install all components under a custom path (which is read-writable)

**Important Notes and Limitations**

* A statically compiled [mosquitto](https://github.com/eclipse-mosquitto/mosquitto) is provided, but it is not currently compiled with SSL enable, so it is not recommended to expose the MQTT broker to other devices in the network. This limitation will most likely be lifted in the future once the build issues can be sorted with mosquitto. Note, 

* Since statically compiled mosquitto version does not yet support SSL, the tedge-mapper is configured to use the built-in (Rust) bridge to connect securely to the cloud using TLS. The built-in bridge was added in thin-edge.io ~1.2.0 but is not yet enabled by default in the standard installation, but there should be no notable difference.

* [upx](https://github.com/upx/upx) is used to compress the **tedge** and **mosquitto** binaries to meet the 5MB installation size. Using UPX has the slight performance cost on the startup of the service. Please read the [UPX README](https://github.com/upx/upx) on their page for more details about how it works and some of the tradeoffs.

## Pre-requisites

The following pre-requisites are required for the standalone thin-edge.io version to work.

* busy-box (with the following binaries)
    * runsvdir or SysVInit (though runsvdir is preferred as it includes a service supervisor)

## Install

### Install using wget/curl

The following command can be used to install the standalone/portable thin-edge.io version if you have `wget` or `curl` which support TLS/SSL. If you have trouble installing it due to some TLS or your device does not have an up to date CA store, then please read the [alternative installation instructions](./README.md#install-without-wgetcurl).

**Using wget**

```sh
wget -q -O - https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/install.sh | sh -s -- --install-path /data
```

**Using curl**

```sh
curl -fsSL https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/install.sh | sh -s -- --install-path /data
```

Then, follow the instructions printed out on the console to bootstrap (configure) and then start the services.

### Install without wget/curl

On devices where `wget` and/or `curl` don't support TLS/SSL, you will have to manually download the required artifacts and then copy the files over to the device yourself. The steps for a manual installation are as follows:

1. Download the binaries from the [Releases](https://github.com/thin-edge/tedge-standalone/releases) page to your device (make sure you choose the appropriate CPU architecture for your device)
2. Download the [install.sh](https://github.com/thin-edge/tedge-standalone/blob/main/install.sh) installation script
3. Copy both the `install.sh` and the `tar.gz` file to your device using either `scp` or `adb push`
4. Run the install.sh script and provide both the path to the tar.gz file that you copied earlier and the path where the package should be installed

    ```sh
    sh ./install.sh --file ./tedge-standalone*.tar.gz --install-path /opt
    ```

### Using Cumulocity basic authentication

Before running the `bootstrap.sh` script, you will need to set the device's credentials (username/password).

For example, if you installed thin-edge.io under `/data` then you can set the credentials using the following snippet:

```sh
./bootstrap.sh --device-user "{tenant}/device_{external_id}" --device-password "{password}" --c8y-url {CumulocityURL}

# example
./bootstrap.sh --device-user "t12345/device_tedge-abcdef" --device-password 'ex4amp!3' --c8y-url example.cumulocity.com
```

Alternative, you can set the `credentials.toml` under the installed directory, e.g. `/data/tedge/credentials.toml` (if you're using the default installation directory):

```sh
[c8y]
username = "{tenant}/device_{external_id}"
password = "{password}"
```

For [go-c8y-cli](https://goc8ycli.netlify.app/) users, you can register a device and generate randomized credentials using the following command. The device's username (including tenant) and password will be printed out on the console, and then you can provide the values to the `bootstrap.sh` script. 

```sh
c8y deviceregistration register-basic --id tedge-abcdef
```

## Automatically starting services

### Device specific instructions

If your device is listed below, then you can follow the device specific instructions on how to configure thin-edge.io to start automatically at boot-up.

* [PSsystec](./docs/PSsystec.md)
* [Advantech](./docs/ADVANTECH.md)
* [Luckfox Pico](./docs/Luckfox.md)
* [Actility-TAO](./docs/Actility-TAO.md)


### General instructions

Assuming you have already bootstrapped the device (e.g. configured the Cumulocity IoT instance, and uploaded the device certificate), then you need to add the following lines to your startup routine:

```sh
/data/tedge/bootstrap.sh
```

Then reboot device to check if the services are started correctly.

**Note** The above snippet uses **runit** to launch the thin-edge.io services from a custom configured services directory (as defined in the `/data/tedge/env` dotenv file). **runit** is used as it is included in busy-box and provides service supervision (e.g. it will automatically relaunch the service if it crashes for any reason).

## Additional Guides

Additional guides are provided to help users to perform common tasks are listed below.

* [Moving a device to a new Cumulocity Tenant](./docs/guides/c8y-tenant-migration.md)

Please feel free to raise a PR to contribute any additional guides.

## Service management

Assuming you have already launched the custom `runsvdir` instance, the following commands can be used to manage the thin-edge.io related services. The commands use a wrapper (`tedgectl`) around the **runit** commands for convenience (and `tedgectl` is used in the init system integration defined in the `system.toml` file).

Before running any of the command you need to load the environment variables using the following one-liner:

```sh
. /data/tedge/env
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
