#!/usr/bin/env bash
set -ex
TARGET="$1"

ZIG=zig
if ! command -V "$ZIG" >/dev/null 2>&1; then
    python3 -m venv .venv ||:
    # shellcheck disable=SC1091
    . .venv/bin/activate
    pip install ziglang
    ZIG="python -m ziglang"
fi

git submodule update --init --recursive

cd binaries/zig-mosquitto
ln -sf ../mosquitto mosquitto

$ZIG build -Doptimize=ReleaseSmall -Dtarget="$TARGET"
mv zig-out/bin/mosquitto "zig-out/bin/mosquitto-$TARGET"

if command -V upx; then
    upx --lzma --best "zig-out/bin/mosquitto-$TARGET"
fi

# Download tedge
cd ../../

TEDGE_VERSION="1.1.2-rc139+g4e94ab6"
case "$TARGET" in
    aarch64-linux-musl)
        TEDGE_URL="https://dl.cloudsmith.io/public/thinedge/tedge-main/raw/names/tedge-arm64/versions/$TEDGE_VERSION/tedge.tar.gz"
        ;;
    arm-linux-musleabihf)
        TEDGE_URL="https://dl.cloudsmith.io/public/thinedge/tedge-main/raw/names/tedge-armv7/versions/$TEDGE_VERSION/tedge.tar.gz"
        ;;
    arm-linux-musleabi)
        TEDGE_URL="https://dl.cloudsmith.io/public/thinedge/tedge-main/raw/names/tedge-armv5/versions/$TEDGE_VERSION/tedge.tar.gz"
        ;;
esac

echo "Download the tedge binary: $TEDGE_URL" >&2
wget -O "tedge-$TARGET.tar.gz" "$TEDGE_URL"
tar xzvf "tedge-$TARGET.tar.gz"
mv tedge "tedge-$TARGET"
if command -V upx; then
    upx --lzma --best "tedge-$TARGET"
fi
