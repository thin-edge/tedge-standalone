# tedge-standalone

## TODO

* create wrapper script for tedge init manager interactions, though maybe it is not needed

## Install

**Using wget**

```sh
wget -q -O - https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/install.sh | sh -s
```

**Using curl**

```sh
curl -fsSL https://raw.githubusercontent.com/thin-edge/tedge-standalone/main/install.sh | sh -s
```

## Bootstrapping

Run the start.sh script to run the bootstrap process to create a certificate and connect thin-edge.io

```sh
/data/tedge/start.sh
```
