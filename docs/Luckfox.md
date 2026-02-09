# Luckfox

## Luckfox Pico

The default busybox based Luckfox images don't include any tools to download files using TLS (e.g. for downloading files using HTTPS), and even it it does, it would need a root certificate trust store (e.g. ca-certificates.crt) before it could even trust those services. Because of this, it is recommended to download the standalone file and then transfer it to the device where it can be installed locally.

Install thin-edge.io standalone on a Luckfox Pico device using the following steps:

1. Download the latest standalone file from the releases page onto your current machine. Download the `armhf` version without the `-upx` in the file name.

2. Copy the standalone file and the install script to the device

    **Using ADB**

    ```sh
    adm push "./install.sh" /tmp/install.sh
    adm push ./tedge-standalone-armhf-*.tar.gz /tmp/tedge-standalone-armhf.tar.gz
    ```

    **Using SSH**

    Replace the IP address (`192.168.68.71`) with the relevant IP address for your device.

    ```sh
    scp -o PreferredAuthentications=password -o PubkeyAuthentication=no "./install.sh" root@192.168.68.71:/tmp/install.sh
    scp -o PreferredAuthentications=password -o PubkeyAuthentication=no ./tedge-standalone-armhf*.tar.gz root@192.168.68.71:/tmp/
    ```

1. SSH into the device

    ```sh
    ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no root@192.168.68.71
    ```

3. Run the installer script on the device

    ```sh
    sh /tmp/install.sh --file /tmp/tedge-standalone-armhf*.tar.gz --install-path /opt
    ```

    Afterwards you can delete both the installer and tar.gz file.

    ```sh
    rm /tmp/install.sh
    rm /tmp/tedge-standalone-armhf*.tar.gz
    ```

4. Bootstrap the device

    ```sh
    /opt/tedge/bootstrap.sh
    ```

5. Set some device specific settings

    ```sh
    mkdir -p /tedge/tmp
    tedge config set tmp.path /tedge/tmp
    tedge config set data.path /tedge
    ```

    Avoid using the `/tmp` directory as it is only a virtual filesystem mounted in memory, so downloading files will use more memory and can lead to OOM level events which kill the thin-edge.io components.

6. Add the following shell profile snippet to enable loading of the tedge configuration by default in newly opened shells. You will need to reload your shell afterwards for it to take effect

    ```sh
    vi /etc/profile.d/tedge.sh
    ```

    ```sh
    load_tedge_env() {
        . /opt/tedge/env;
    }
    load_tedge_env
    ```
