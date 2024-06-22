
PACKAGE := "tedge-standalone"

# Build static binaries
build target *args:
    ./scripts/build.sh {{target}} {{args}}
    cp "binaries/zig-mosquitto/zig-out/bin/mosquitto-{{target}}" src/tedge/bin/mosquitto
    tar czvf "{{PACKAGE}}-{{target}}.tar.gz" --owner=0 --group=0 --no-same-owner --no-same-permissions -C src ./tedge
