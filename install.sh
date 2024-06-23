#!/bin/sh
set -e

INSTALL_PATH=/data
VERSION=0.0.1-rc.3

ARCH=$(uname -m)
TARGET_ARCH=
case "$ARCH" in
    arm64|aarch64)
        TARGET_ARCH=arm64
        ;;
    armv7*)
        TARGET_ARCH=armhf
        ;;
    armel)
        TARGET_ARCH=armel
        ;;
    x86_64|amd64)
        TARGET_ARCH=amd64
        ;;
    i386|x86)
        TARGET_ARCH=i386
        ;;
    *)
        echo "Unsupported architecture. arch=$ARCH" >&2
        exit 1
        ;;
esac

cd /tmp
wget -q "https://github.com/thin-edge/tedge-standalone/releases/download/$VERSION/tedge-standalone-${TARGET_ARCH}.tar.gz"

mkdir -p "$INSTALL_PATH"
echo "Installing thin-edge.io to $INSTALL_PATH"
tar xzf /tmp/tedge-standalone-*.tar.gz -C "$INSTALL_PATH"
rm -f /tmp/tedge-standalone-*.tar.gz

echo
echo "Configure and start thin-edge.io using the following command:"
echo
echo "    $INSTALL_PATH/start.sh"
echo