# Busybox/musl based "device" image, faithful to a real constrained target:
#   * Alpine == busybox + musl (the tedge binaries are *-linux-musl static builds)
#   * runit provides runsvdir/sv/chpst (the standalone package uses runit supervision)
#   * openssh-client gives us an SSH client for manual verification of the tunnel
#
# The image is assembled in three layers so you can test non-release builds:
#   1. Install a tedge-standalone RELEASE package (gives mosquitto + all the config,
#      service and operation scaffolding + a baseline `tedge` binary).
#   2. Optionally REPLACE the `tedge` binary with a custom build (Cloudsmith `main`
#      channel, or a binary you drop into an overlay's bin/tedge).
#   3. Optionally apply an OVERLAY: files copied over /data/tedge to change service
#      definitions, operation exec lines, env vars, bootstrap.sh, etc.
ARG ALPINE_VERSION=3.20
FROM alpine:${ALPINE_VERSION}

# --- base release package (scaffolding + mosquitto) ---
# VARIANT: "" = upx, "-noupx" = uncompressed (applies to the base package)
ARG VERSION=2.0.1-3
ARG ARCH=arm64
ARG VARIANT=
ARG REPO=thin-edge/tedge-standalone
ARG INSTALL_PATH=/data

# --- optional custom tedge binary ---
# TEDGE_BINARY: none | cloudsmith
# TEDGE_CHANNEL: cloudsmith channel (main | release)
# TEDGE_BINARY_UPX: 1 = upx-compress the custom binary to mimic packaging
ARG TEDGE_BINARY=none
ARG TEDGE_CHANNEL=main
ARG TEDGE_BINARY_VERSION=latest
ARG TEDGE_BINARY_UPX=0

# --- optional overlay path under ./variants (e.g. tokio1/overlay) ---
ARG OVERLAY=

# --- optional locally-built package (path under ./variants, overrides the release download) ---
ARG LOCAL_PACKAGE=

# --- reporting label ---
ARG PKG_LABEL=

RUN apk add --no-cache runit openssh-client ca-certificates

# variant files (overlays + any locally-built package) are needed from step 1 onward
COPY variants/ /build/variants/

# 1. Install the package via the published installer. Either a locally-built package
#    (LOCAL_PACKAGE, e.g. from scripts/build-local-package.sh) or a published release.
RUN set -eux; \
    wget -O /tmp/install.sh "https://raw.githubusercontent.com/${REPO}/main/install.sh"; \
    if [ -n "$LOCAL_PACKAGE" ]; then \
        PKG="/build/${LOCAL_PACKAGE#variants/}"; \
        [ -f "$PKG" ] || PKG="/build/variants/${LOCAL_PACKAGE#variants/}"; \
        echo "Installing local package: $PKG"; \
    else \
        wget -O /tmp/tedge-standalone.tar.gz \
            "https://github.com/${REPO}/releases/download/${VERSION}/tedge-standalone-${ARCH}${VARIANT}.tar.gz"; \
        PKG=/tmp/tedge-standalone.tar.gz; \
    fi; \
    sh /tmp/install.sh --file "$PKG" --install-path "${INSTALL_PATH}"; \
    rm -f /tmp/install.sh /tmp/tedge-standalone.tar.gz

# 2. Optionally replace the tedge binary with a custom (non-release) build
RUN set -eux; \
    if [ "$TEDGE_BINARY" = "cloudsmith" ]; then \
        URL="https://dl.cloudsmith.io/public/thinedge/tedge-${TEDGE_CHANNEL}/raw/names/tedge-${ARCH}/versions/${TEDGE_BINARY_VERSION}/tedge.tar.gz"; \
        echo "Fetching custom tedge binary: $URL"; \
        wget -O /tmp/tedge.tar.gz "$URL"; \
        tar xzf /tmp/tedge.tar.gz -C /tmp; \
        if [ "$TEDGE_BINARY_UPX" = "1" ]; then \
            apk add --no-cache upx; \
            upx --lzma --best /tmp/tedge; \
        fi; \
        install -m 0755 /tmp/tedge "${INSTALL_PATH}/tedge/bin/tedge"; \
        rm -f /tmp/tedge /tmp/tedge.tar.gz; \
        "${INSTALL_PATH}/tedge/bin/tedge" --version || true; \
    fi

# 3. Optionally apply an overlay (service defs / operations / env / bootstrap.sh / bin/tedge)
RUN set -eux; \
    if [ -n "$OVERLAY" ] && [ -d "/build/variants/${OVERLAY}" ]; then \
        echo "Applying overlay: ${OVERLAY}"; \
        cp -a "/build/variants/${OVERLAY}/." "${INSTALL_PATH}/tedge/"; \
        # substitute the install path placeholder in the overlaid files (skip binaries)
        find "${INSTALL_PATH}/tedge" -type f ! -name tedge ! -name mosquitto \
            -exec sed -i "s%@CONFIG_DIR@%${INSTALL_PATH}/tedge%g" {} \; ; \
        # make sure scripts are executable
        find "${INSTALL_PATH}/tedge/services" -name run -exec chmod +x {} \; 2>/dev/null || true; \
        find "${INSTALL_PATH}/tedge/bin" -type f -exec chmod +x {} \; 2>/dev/null || true; \
        [ -f "${INSTALL_PATH}/tedge/bootstrap.sh" ] && chmod +x "${INSTALL_PATH}/tedge/bootstrap.sh" || true; \
    fi; \
    rm -rf /build

# Pin the runit service dir so the entrypoint and bootstrap.sh agree on one location
RUN echo 'export SVDIR=/run/services' >> "${INSTALL_PATH}/tedge/env"

# Label shown in the measurement report (defaults to <version><variant>).
# NB: must NOT start with TEDGE_ or tedge treats it as a config override.
ENV STANDALONE_PKG_VERSION=${PKG_LABEL:-${VERSION}${VARIANT}}

COPY device/entrypoint.sh /opt/entrypoint.sh
COPY device/measure.sh /opt/measure.sh
RUN chmod +x /opt/entrypoint.sh /opt/measure.sh

ENTRYPOINT ["/opt/entrypoint.sh"]
