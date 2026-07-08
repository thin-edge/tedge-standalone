# Minimal SSH server that acts as the remote-access *target*.
# The device's c8y-remote-access-plugin bridges the Cumulocity websocket to
# ssh-server:22, so this only needs to accept TCP and speak the SSH banner.
# Credentials (tedge/tedge, root/tedge) are provided for manual verification.
FROM alpine:3.20

RUN set -eux; \
    apk add --no-cache openssh-server; \
    ssh-keygen -A; \
    adduser -D -s /bin/sh tedge; \
    echo 'tedge:tedge' | chpasswd; \
    echo 'root:tedge'  | chpasswd; \
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config; \
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D", "-e"]
