#!/usr/bin/env bash
# Build a tedge-standalone package tarball from the repo's LOCAL src/tedge tree
# (i.e. your in-progress packaging changes) with a chosen tedge binary swapped in.
# This reproduces exactly what `install.sh --file <pkg>` would install on a device,
# so it validates the real packaging a customer would download — without needing
# zig/upx to rebuild mosquitto (the committed src/tedge/bin/mosquitto is reused).
#
# Usage: build-local-package.sh [OUT] [CHANNEL] [VERSION] [ARCH]
#   OUT      output tarball path (default variants/local-runall/package.tar.gz)
#   CHANNEL  cloudsmith channel for the tedge binary: main|release (default main)
#   VERSION  tedge version, or 'latest' (default latest)
#   ARCH     arm64|amd64|armhf|... (default arm64)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$HERE/lib.sh"

OUT="${1:-$EXP_DIR/variants/local-runall/package.tar.gz}"
CHANNEL="${2:-main}"
VERSION="${3:-latest}"
ARCH="${4:-arm64}"

SRC="$REPO_ROOT/src/tedge"
[ -d "$SRC" ] || { echo "no $SRC" >&2; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

log "Copying local src/tedge packaging"
cp -a "$SRC" "$work/tedge"

log "Fetching tedge binary: channel=$CHANNEL version=$VERSION arch=$ARCH"
url="https://dl.cloudsmith.io/public/thinedge/tedge-${CHANNEL}/raw/names/tedge-${ARCH}/versions/${VERSION}/tedge.tar.gz"
curl -fsSL "$url" -o "$work/tedge.tar.gz"
# Extract into a separate dir so the bare 'tedge' binary doesn't collide with the
# package directory ($work/tedge), then swap it into the package's bin/.
mkdir -p "$work/bin-extract"
tar xzf "$work/tedge.tar.gz" -C "$work/bin-extract"
install -m 0755 "$work/bin-extract/tedge" "$work/tedge/bin/tedge"

mkdir -p "$(dirname "$OUT")"
log "Packaging -> $OUT"
tar czf "$OUT" --owner=0 --group=0 -C "$work" ./tedge
log "Done: $OUT ($(wc -c < "$OUT") bytes), tedge = $(echo "$VERSION" )/$CHANNEL"
