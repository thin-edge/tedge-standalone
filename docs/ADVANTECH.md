# Advantech

## Device: ECU150

1. Install thin-edge.io standalone

    ```sh
    wget -q -O - https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/install.sh | sh -s -- --install-path /home/etc
    ```

2. Run the thin-edge.io bootstrap script

    ```sh
    /home/etc/tedge/bootstrap.sh
    ```

3. Remount the root filesystem as read/write (as it is normally mounted as read-only)

    ```sh
    mount -o rw,remount /
    ```

4. Edit the `/etc/init.d/background.sh` script and add the following line (before the call to `exit`)

    ```sh
    sed -i '/exit 0/i \
    /home/etc/tedge/bootstrap.sh' 2&> /dev/null \
    /etc/init.d/background.sh
    ```

    **Note**
    
    If the `/etc/init.d/background.sh` file does not exist, then you may need to create your own SysVInit file which launches the thin-edge.io bootstrap.sh script.

5. Edit the default shell profile (whilst still in read/write mode) and add the following snippet

    ```sh
    vi /etc/profile
    ```

    *Contents*

    ```sh
    if [ -d /home/etc/tedge/bin ]; then
        export PATH=$PATH:/home/etc/tedge/bin
    fi
    ```

6. Reboot the device and check that all of the services have started

    ```sh
    reboot
    ```
