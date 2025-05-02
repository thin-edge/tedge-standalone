#!/bin/sh
set -e

INSTALL_PATH="${INSTALL_PATH:-/data}"
VERSION="${VERSION:-0.6.0}"
INSTALL_FILE="${INSTALL_FILE:-}"
OVERWRITE_CONFIG=0
VERSION_SUFFIX="${VERSION_SUFFIX:-""}"

usage() {
    cat << EOT
Install thin-edge.io standalone package for running on resource constrained devices
without any accessible init system.

USAGE
    $0 [--install-path <path>] [--version <version>] [--no-upx]

ARGUMENTS
  --install-path <path>         Install path. Defaults to $INSTALL_PATH
  --version <version>           Version to install. Defaults to $VERSION
  --file <path>                 Install from a file instead of downloading it
  --overwrite                   Overwrite any existing configuration
  --upx                         Use upx'd versions of the binaries (Default).
                                Useful for devices with very limited disk space (< 10MB) and have memory more than 64MB
  --no-upx                      Don't download the upx'd version (e.g. recommended for low-memory devices)

EXAMPLE

    $0
    # Install with default settings

    $0 --install-path /data
    # Install under a custom location

    $0 --install-path /data --no-upx
    # Install under a custom location but install the non-upx'd versions

    $0 --install-path /home/etc --overwrite
    # Install under a custom location and overrite any existing configuration files

    $0 --file ./tedge-standalone-arm64.tar.gz --install-path /home/root
    # Install from a manually downloaded file and install under a custom path
EOT
}

while [ $# -gt 0 ]; do
    case "$1" in
        --install-path)
            INSTALL_PATH="$2"
            shift
            ;;
        --upx)
            VERSION_SUFFIX="-upx"
            ;;
        --no-upx)
            VERSION_SUFFIX=""
            ;;
        --file)
            INSTALL_FILE="$2"
            shift
            ;;
        --version)
            VERSION="$2"
            shift
            ;;
        --overwrite)
            OVERWRITE_CONFIG=1
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
    # exclude binaries as this can cause additional memory usage which is a problem on smaller devices < 34MB RAM
    # like the Luckfox Pico
    find "$src" -type f ! -name tedge ! -name mosquitto -exec sed -i s%@CONFIG_DIR@%"${value}"%g {} \;
}

decompress_archive() {
    input_file="$1"
    output_dir="$2"

    # Note: busybox tar may not support expanding compressed
    # archives, so it may need to be manually decompressed before passing
    # the file to tar
    if command -V gunzip >/dev/null 2>&1 && gunzip -t "$input_file" >/dev/null 2>&1 ; then
        gunzip -c "$input_file" | tar xf - -C "$output_dir"
    else
        tar xzf "$input_file" -C "$output_dir"
    fi
}

install_from_file() {
    install_file="$1"
    mkdir -p "$INSTALL_PATH"
    echo "Installing thin-edge.io to $INSTALL_PATH/tedge"
    decompress_archive "$install_file" "$INSTALL_PATH"
}

install_from_web() {
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
    wget -q "https://github.com/thin-edge/tedge-standalone/releases/download/$VERSION/tedge-standalone-${TARGET_ARCH}${VERSION_SUFFIX}.tar.gz"
    mkdir -p "$INSTALL_PATH"
    echo "Installing thin-edge.io to $INSTALL_PATH/tedge"

    # Resolve the binary before calling the function
    install_file=$(find /tmp -name "tedge-standalone-*.tar.gz" | head -n1)
    decompress_archive "$install_file" "$INSTALL_PATH"
    rm -f "$install_file"
}

move_if_target_file_missing() {
    SRC="$INSTALL_PATH/tedge/$1"
    DST="$INSTALL_PATH/tedge/$2"
    if [ ! -f "$DST" ]; then
        mv "$SRC" "$DST"
    fi
}

main() {
    if [ -f "$INSTALL_FILE" ]; then
        echo "Installing from file: $INSTALL_FILE" >&2
        install_from_file "$INSTALL_FILE"
    else
        echo "Installing from url" >&2
        install_from_web
    fi

    # Replace reference to installation path
    update_install_path "$INSTALL_PATH/tedge" "$INSTALL_PATH/tedge"

    # Update the file if it does not already exist (this will only occur once)
    # after that, the user must move it themselves
    if [ "$OVERWRITE_CONFIG" = 1 ]; then
        echo "Overwriting any existing configuration" >&2
        mv "$INSTALL_PATH/tedge/env.default" "$INSTALL_PATH/tedge/env"
        mv "$INSTALL_PATH/tedge/tedge.default.toml" "$INSTALL_PATH/tedge/tedge.toml"
        mv "$INSTALL_PATH/tedge/system.default.toml" "$INSTALL_PATH/tedge/system.toml"
    else
        move_if_target_file_missing "env.default" "env"
        move_if_target_file_missing "tedge.default.toml" "tedge.toml"
        move_if_target_file_missing "system.default.toml" "system.toml"
    fi

    echo
    echo "Configure and start thin-edge.io using the following command:"
    echo
    echo "    $INSTALL_PATH/tedge/bootstrap.sh"
    echo
    echo Import the shell environment using:
    echo
    echo "    set -a; . '$INSTALL_PATH/tedge/env'; set +a"
    echo
}

main
