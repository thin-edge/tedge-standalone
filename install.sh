#!/bin/sh
set -e

INSTALL_PATH="${INSTALL_PATH:-/data}"
VERSION="${VERSION:-0.1.0}"

usage() {
    cat << EOT
Install thin-edge.io standalone package for running on resource constrained devices
without any accessible init system.

USAGE
    $0 [--install-path <path>] [--version <version>]

ARGUMENTS
  --install-path <path>         Install path. Defaults to $INSTALL_PATH
  --version <version>           Version to install. Defaults to $VERSION

EXAMPLE

    $0
    # Install with default settings

    $0 --install-path /custom
    # Install under a custom location

EOT
}

while [ $# -gt 0 ]; do
    case "$1" in
        --install-path)
            INSTALL_PATH="$2"
            shift
            ;;
        --version)
            VERSION="$2"
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        --*|-*)
            echo "Unknown flags. $1" >&2
            exit 1
            ;;
        *)
            echo "Unexpected positional arguments" >&2
            exit 1
            ;;
    esac
    shift
done

update_install_path() {
    src="$1"
    value="$2"
    find "$src" -type f -exec sed -i s%@CONFIG_DIR@%"${value}"% {} \;
}

main() {
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
    echo "Installing thin-edge.io to $INSTALL_PATH/tedge"
    tar xzf /tmp/tedge-standalone-*.tar.gz -C "$INSTALL_PATH"
    rm -f /tmp/tedge-standalone-*.tar.gz

    # Replace reference to installation path
    update_install_path "$INSTALL_PATH/tedge" "$INSTALL_PATH/tedge"

    echo
    echo "Configure and start thin-edge.io using the following command:"
    echo
    echo "    $INSTALL_PATH/tedge/bootstrap.sh"
    echo
}

main
