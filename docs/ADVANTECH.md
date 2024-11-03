# Advantech

## Run thin-edge.io at startup

1. Remount the root filesystem as read/write (as it is normally mounted as read-only)

    ```sh
    mount -o rw,remount /
    ```

2. Edit the `/etc/init.d/background.sh` script and add the following line (before the call to `exit`)

    ```sh
    {{install_path}}/tedge/bootstrap.sh
    ```

    Where `{{install_path}}` should be replace with the path where thin-edge.io was installed. The full path to the bootstrap.sh script is printed out to the console when you installed thin-edge.io.

    Note: If the `/etc/init.d/background.sh` file does not exist, then you may need to create your own SysvInit file which launches the thin-edge.io bootstrap.sh script.

3. Reboot the device and check that all of the services have started

Using the Telit startup hooks, run the following code to configure the `oem_poststart.sh` script. If the `/data/oem_poststart.sh` file already exists, then you will have to manually edit it to add the code from the [example script](https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/docs/oem_poststart.sh).

```sh
[ ! -f /data/oem_poststart.sh ] && wget -O /data/oem_poststart.sh https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/docs/oem_poststart.sh
chmod +x /data/oem_poststart.sh
```
