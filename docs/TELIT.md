# Telit

## Run thin-edge.io at startup

Using the Telit startup hooks, run the following code to configure the `oem_poststart.sh` script. If the `/data/oem_poststart.sh` file already exists, then you will have to manually edit it to add the code from the [example script](https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/docs/oem_poststart.sh).

```sh
[ ! -f /data/oem_poststart.sh ] && wget -O /data/oem_poststart.sh https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/docs/oem_poststart.sh
chmod +x /data/oem_poststart.sh
```
