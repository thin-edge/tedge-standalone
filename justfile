
PACKAGE := "tedge-standalone"

# Build static binaries and create the tarball package
build target target_name *args:
    ./scripts/build.sh --target {{target}} --target-name {{target_name}} --package {{PACKAGE}} {{args}}
