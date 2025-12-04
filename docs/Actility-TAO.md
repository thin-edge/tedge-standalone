# Actility-TAO 

This is the thin-edge installation instructions for Actility TAO device -- kerlink. 

## Kerlink

1. Run the install script with install-path option

    ```sh
    wget -q -O - https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/install.sh | sh -s -- --install-path /user
    ```

2. Add the folowing lines into the `/etc/profile` file:

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


5. Bootstrap
   
    ```sh
    /user/tedge/bootstrap.sh --ca c8y --c8y-url '<domain-name>.eu-latest.cumulocity.com' --device-id <unique-device-id>
    ```

    Example:
    ```sh
    /user/tedge/bootstrap.sh --ca c8y --c8y-url 'test.eu-latest.cumulocity.com' --device-id kerlink-12345
    ```

    During the bootstrap, you will need to finish the device registration on the platform. The link to the device registration page will be printed in the shell. More information please check thin-edge [documentation](https://thin-edge.github.io/thin-edge.io/operate/c8y/connect/#cumulocity-certificate-authority). 

6. Add [tedge-reconnect](./tedge-reconnect) script into /etc/init.d folder, make the script executable. Then enable it with: 

    ```sh
    update-rc.d tedge-reconnect defaults
    ```
    > **Note**: This is a temporary workaround to address the premature startup of Mosquitto. It will be removed once the root cause and a permanent solution are identified.

7. Reboot the device, thin-edge will connect to the platform after 120 seconds. 

