#!/usr/bin/env bash
set -e

if [ -n "$CI" ]; then
    set -x
fi

TARGET="$1"
TARGET_NAME="$2"
PACKAGE="${PACKAGE:-}"
TEDGE_VERSION="${TEDGE_VERSION:-}"
TEDGE_CHANNEL="${TEDGE_CHANNEL:-}"
SKIP_UPX="${SKIP_UPX:-}"

while [ $# -gt 0 ]; do
    case "$1" in
        --target)
            TARGET="$2"
            shift
            ;;
        --target-name)
            TARGET_NAME="$2"
            shift
            ;;
        --package)
            PACKAGE="$2"
            shift
            ;;
        --tedge-version)
            TEDGE_VERSION="$2"
            shift
            ;;
        --tedge-channel)
            TEDGE_CHANNEL="$2"
            shift
            ;;
        --skip-upx)
            SKIP_UPX=1
            ;;
    esac
    shift
done

# Guess the channel from the syntax, defaulting to the release channel
if [ -z "${TEDGE_CHANNEL}" ]; then
    if [ -z "$TEDGE_VERSION" ] || [[ "$TEDGE_VERSION" =~ ^\d+\.\d+\.\d+$ ]]; then
        TEDGE_CHANNEL=release
    else
        TEDGE_CHANNEL=main
    fi
fi

if [ -z "$TEDGE_VERSION" ]; then
    # get the latest version (use any architecture as they should all be the same)
    TEDGE_VERSION=$(curl -s "https://dl.cloudsmith.io/public/thinedge/tedge-${TEDGE_CHANNEL}/raw/names/tedge-arm64/versions/latest/tedge.tar.gz" --write-out '%{redirect_url}' | rev | cut -d/ -f2 | rev)
fi

if [ -z "$SKIP_UPX" ]; then
    SKIP_UPX=0
fi

if [ "$TARGET" = "riscv64-linux" ]; then
    # risc64 does not support upx, so ensure it is disabled
    SKIP_UPX=1
fi

ZIG=zig
if ! command -V "$ZIG" >/dev/null 2>&1; then
    python3 -m venv .venv ||:
    # shellcheck disable=SC1091
    . .venv/bin/activate
    # Use fixed ziglang version due to breaking changes in 0.15.1
    pip install ziglang==0.14.1
    ZIG="python -m ziglang"
fi

git submodule update --init --recursive

cd binaries/zig-mosquitto
ln -sf ../mosquitto mosquitto

# patch zig-mosquitto to include mosquitto version
# FIXME: This should be done by zig-mosquitto itself
MOSQUITTO_VERSION=$(cd mosquitto && git tag --points-at HEAD | sed 's/^v//')
echo "Setting mosquitto version from src tag: $MOSQUITTO_VERSION" >&2
SED="sed"
if command -V gsed >/dev/null 2>&1; then
    SED="gsed"
fi
"$SED" -i 's|-DVERSION=\\\".*\\\"|-DVERSION=\\\"'"$MOSQUITTO_VERSION"'\\\"|g' build.zig

$ZIG build -Doptimize=ReleaseSmall -Dtarget="$TARGET"
mv zig-out/bin/mosquitto "zig-out/bin/mosquitto-$TARGET"

if [ "$SKIP_UPX" -ne 1 ]; then
    if command -V upx; then
        upx --lzma --best "zig-out/bin/mosquitto-$TARGET"
    fi
fi

# Download tedge
cd ../../

case "$TARGET" in
    aarch64-linux-musl)
        TEDGE_URL="https://dl.cloudsmith.io/public/thinedge/tedge-${TEDGE_CHANNEL}/raw/names/tedge-arm64/versions/$TEDGE_VERSION/tedge.tar.gz"
        ;;
    arm-linux-musleabihf)
        TEDGE_URL="https://dl.cloudsmith.io/public/thinedge/tedge-${TEDGE_CHANNEL}/raw/names/tedge-armv7/versions/$TEDGE_VERSION/tedge.tar.gz"
        ;;
    arm-linux-musleabi)
        TEDGE_URL="https://dl.cloudsmith.io/public/thinedge/tedge-${TEDGE_CHANNEL}-armv6/raw/names/tedge-armv6/versions/$TEDGE_VERSION/tedge.tar.gz"
        ;;
    x86_64-linux)
        TEDGE_URL="https://dl.cloudsmith.io/public/thinedge/tedge-${TEDGE_CHANNEL}/raw/names/tedge-amd64/versions/$TEDGE_VERSION/tedge.tar.gz"
        ;;
    x86-linux)
        TEDGE_URL="https://dl.cloudsmith.io/public/thinedge/tedge-${TEDGE_CHANNEL}/raw/names/tedge-i386/versions/$TEDGE_VERSION/tedge.tar.gz"
        ;;
    riscv64-linux)
        TEDGE_URL="https://dl.cloudsmith.io/public/thinedge/tedge-${TEDGE_CHANNEL}/raw/names/tedge-riscv64/versions/$TEDGE_VERSION/tedge.tar.gz"
        ;;
    *)
        echo "Unsupported target. No thin-edge.io binary is available for this target. $TARGET" >&2
        exit 1
        ;;
esac

echo "Download the tedge binary: $TEDGE_URL" >&2
wget -O "tedge-$TARGET.tar.gz" "$TEDGE_URL"
tar xzvf "tedge-$TARGET.tar.gz"
mv tedge "tedge-$TARGET"

if [ "$SKIP_UPX" -ne 1 ]; then
    if command -V upx ; then
        upx --lzma --best "tedge-$TARGET"
    fi
fi

cp "binaries/zig-mosquitto/zig-out/bin/mosquitto-${TARGET}" src/tedge/bin/mosquitto
cp "tedge-${TARGET}" src/tedge/bin/tedge

TAR="tar"
if command -V gtar >/dev/null 2>&1; then
    TAR="gtar"
fi

OUTPUT_FILE="${PACKAGE}-${TARGET_NAME}.tar.gz"

"$TAR" czvf "$OUTPUT_FILE" --owner=0 --group=0 --no-same-owner --no-same-permissions -C src ./tedge

echo
echo "Built package:"
echo
echo "  TEDGE_CHANNEL: $TEDGE_CHANNEL"
echo "  TEDGE_VERSION: $TEDGE_VERSION"
echo
echo "  FILE:          $OUTPUT_FILE"
echo