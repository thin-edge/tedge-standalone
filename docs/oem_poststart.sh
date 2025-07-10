#!/bin/sh


# enable ssh
mkdir -p /data/ssh
echo 1 > /data/ssh/enable_sshd
if [ ! -f /data/ssh/sshd_config_readonly ]; then
    cp /etc/ssh/sshd_config_readonly /data/ssh/sshd_config_readonly
fi

/etc/init.d/sshd start ||:

# start thin-edge.io
@CONFIG_DIR@/bootstrap.sh --offline
