# Actility-TAO

This is the thin-edge installation instructions for Actility TAO device -- kerlink.

## Kerlink

1. Run the install script with install-path option

    ```sh
    wget -q -O - https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/install.sh | sh -s -- --install-path /user --vendor actility-tao-kerlink
    ```

    The script will also apply some vendor specific settings like:

    * Add monit rules to monit thin-edge.io components
    * Set custom MQTT ports so they don't conflict with the existing mosquitto broker

2. Reload your shell

    ```sh
    . /user/tedge/env
    ```

3. Run the bootstrap to initialize and connect the device to Cumulocity using the Cumulocity Certificate Authority

    ```sh
    /user/tedge/bootstrap.sh --ca c8y --c8y-url '<cumulocity-url>'
    ```

    **Example**

    ```sh
    /user/tedge/bootstrap.sh --ca c8y --c8y-url 'example.eu-latest.cumulocity.com'
    ```

    By default, the `tedge-identity` script will attempt to be auto detected from the `/user/actility/FDB_lora/lUUID/` folder, but you can manually provide a user-defined device id.

    ```sh
    /user/tedge/bootstrap.sh --ca c8y --c8y-url "example.eu-latest.cumulocity.com" --device-id "kerlink-abcdef"
    ```

    During the bootstrap, you will need to finish the device registration on the platform. The link to the device registration page will be printed in the shell. More information please check thin-edge [documentation](https://thin-edge.github.io/thin-edge.io/operate/c8y/connect/#cumulocity-certificate-authority).

    **Troubleshooting**

    * If you don't see the registration URL on your console then try closing the terminal, and opening a new window as sometimes the terminal's output can get corrupted and hide messages that were printed to it.

4. Reboot the device to verify that thin-edge.io automatically connects to Cumulocity

### Uninstalling

You can uninstall thin-edge.io by running the following script, though this will stop and remove all components, so please do not run on a production system!

```sh
wget -q -O - https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/uninstall.sh | sh -s -- --install-path /user --force
```
