#!/bin/bash
set -x

ENFORCE=$(getenforce)

# rpm fails if it runs from init
# (error: failed to exec scriptlet interpreter /bin/sh: Permission denied)
setenforce Permissive

# Waiting network is up
sleep 10

dnf -y --best update

dnf -y install @virtualization libguestfs-tools libvirt libvirt-nss nfs-utils \
    lksctp-tools tuned grubby rsync gperftools fio perf gdb liburing driverctl \
    nmap git meson python3-docutils rust cargo rustfmt clippy diffutils

setenforce $ENFORCE

poweroff
