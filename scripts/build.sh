#!/usr/bin/env bash
set -e
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
