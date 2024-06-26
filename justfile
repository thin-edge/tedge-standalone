
PACKAGE := "tedge-standalone"

# Build static binaries and create the tarball package
build target target_name *args:
    ./scripts/build.sh {{target}} {{args}}
    cp "binaries/zig-mosquitto/zig-out/bin/mosquitto-{{target}}" src/tedge/bin/mosquitto
    cp "tedge-{{target}}" src/tedge/bin/tedge
    tar czvf "{{PACKAGE}}-{{target_name}}.tar.gz" --owner=0 --group=0 --no-same-owner --no-same-permissions -C src ./tedge
