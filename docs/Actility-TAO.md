# Actility-TAO

This is the thin-edge installation instructions for Actility TAO device -- kerlink.

## Kerlink

1. Run the install script with install-path option

    ```sh
    wget -q -O - https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/install.sh | sh -s -- --install-path /user
    ```

2. Add the following lines into the `/etc/profile` file:

    ```sh
    if [ -f /user/tedge/env ]; then
        . /user/tedge/env
    fi
    ```

3. Reload your shell.

4. Change thin-edge's mqtt configuration

    ```sh
    tedge config set mqtt.bind.port 1884
    tedge config set mqtt.client.port 1884
    ```

    > **Note**:
    >
    > You can select other ports as needed.
    >
    > The following warning might come when the device doesn't allow adding new users. You can ignore this warning:
    >
    > 2025-12-04T09:58:33.27572112Z  WARN tedge_config::tedge_toml::tedge_config_location: failed to set file ownership for '/user/tedge/tedge.toml': User not found: "tedge".

5. Run the bootstrap to initialize and connect the device to Cumulocity using the Cumulocity Certificate Authority

    ```sh
    /user/tedge/bootstrap.sh --ca c8y --c8y-url '<cumulocity-url>'
    ```

    **Example**

    ```sh
    /user/tedge/bootstrap.sh --ca c8y --c8y-url 'example.eu-latest.cumulocity.com'
    ```

    By default, the device id attempt to be auto detected from the `/user/actility/FDB_lora/lUUID/` folder. But you can manually provide a user-defined device id

    ```sh
    /user/tedge/bootstrap.sh --ca c8y --c8y-url "example.eu-latest.cumulocity.com" --device-id "kerlink-12345"
    ```

    During the bootstrap, you will need to finish the device registration on the platform. The link to the device registration page will be printed in the shell. More information please check thin-edge [documentation](https://thin-edge.github.io/thin-edge.io/operate/c8y/connect/#cumulocity-certificate-authority).

    **Troubleshooting**

    * If you don't see the registration URL on your console then try closing the terminal, and opening a new window as sometimes the terminal's output can get corrupted and hide messages that were printed to it.

6. Enable the **tedge-reconnect** service which is to ensure the tedge connect automatically on the device startup

    ```sh
    update-rc.d tedge-reconnect defaults
    ```
    > **Note**: This is a temporary workaround to address the premature startup of Mosquitto. It will be removed once the root cause and a permanent solution are identified.

7. Reboot the device, thin-edge will connect to the platform after 120 seconds.
