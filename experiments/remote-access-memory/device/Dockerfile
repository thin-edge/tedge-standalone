# Busybox/musl based "device" image, faithful to a real constrained target:
#   * Alpine == busybox + musl (the tedge binaries are *-linux-musl static builds)
#   * runit provides runsvdir/sv/chpst (the standalone package uses runit supervision)
#   * openssh-client gives us an SSH client for manual verification of the tunnel
#
# The tedge-standalone package + published installer are downloaded for the exact
# VERSION under test, so this image reproduces a real install (upx or non-upx).
ARG ALPINE_VERSION=3.20
FROM alpine:${ALPINE_VERSION}

ARG VERSION=2.0.1-3
ARG ARCH=arm64
# "" -> upx-compressed binaries (default), "-noupx" -> uncompressed
ARG VARIANT=
ARG REPO=thin-edge/tedge-standalone
ARG INSTALL_PATH=/data

RUN apk add --no-cache runit openssh-client ca-certificates

# Install the released standalone package via the published installer
RUN set -eux; \
    wget -O /tmp/install.sh "https://raw.githubusercontent.com/${REPO}/main/install.sh"; \
    wget -O /tmp/tedge-standalone.tar.gz \
        "https://github.com/${REPO}/releases/download/${VERSION}/tedge-standalone-${ARCH}${VARIANT}.tar.gz"; \
    sh /tmp/install.sh --file /tmp/tedge-standalone.tar.gz --install-path "${INSTALL_PATH}"; \
    rm -f /tmp/install.sh /tmp/tedge-standalone.tar.gz

# Pin the runit service dir so the entrypoint and bootstrap.sh agree on one location
RUN echo 'export SVDIR=/run/services' >> "${INSTALL_PATH}/tedge/env"

# Record which package this image contains (handy for the measurement report).
# NB: must NOT start with TEDGE_ or tedge treats it as a config override.
ENV STANDALONE_PKG_VERSION=${VERSION}${VARIANT}

COPY device/entrypoint.sh /opt/entrypoint.sh
COPY device/measure.sh /opt/measure.sh
RUN chmod +x /opt/entrypoint.sh /opt/measure.sh

ENTRYPOINT ["/opt/entrypoint.sh"]
