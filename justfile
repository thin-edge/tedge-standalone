
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

# Release
release bump="minor":
  #!/bin/bash
  set -e
  CURRENT_VERSION=$(git tag -l | sort -rV | head -n1)
  MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1)
  MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f2)
  PATCH=$(echo "$CURRENT_VERSION" | cut -d. -f3)
  case "{{bump}}" in
    major) MAJOR=$((MAJOR + 1));;
    minor) MINOR=$((MINOR + 1));;
    patch) PATCH=$((PATCH + 1));;
  esac
  echo "Current version: $CURRENT_VERSION"
  RELEASE_VERSION="${MAJOR}.${MINOR}.${PATCH}"
  echo "Next version:    $RELEASE_VERSION"
  git tag -a "$RELEASE_VERSION" -m "$RELEASE_VERSION"
  git push origin "$RELEASE_VERSION"
