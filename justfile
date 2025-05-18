
PACKAGE := "tedge-standalone"

# Build static binaries and create the tarball package
build target target_name *args:
    ./scripts/build.sh --target {{target}} --target-name {{target_name}} --package {{PACKAGE}} {{args}}

# Build artifacts to be used in system tests
build-test:
    just build aarch64-linux-musl arm64-noupx --skip-upx
    just build aarch64-linux-musl arm64

# Install python virtual environment
venv:
  [ -d .venv ] || python3 -m venv .venv
  ./.venv/bin/pip3 install -r tests/requirements.txt

# Run tests
test *args='':
  ./.venv/bin/python3 -m robot.run --outputdir output {{args}} tests
