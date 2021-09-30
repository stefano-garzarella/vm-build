#!/bin/bash
set -x

# Waiting network is up
sleep 10

dnf -y --best update

dnf -y install @virtualization libguestfs-tools libvirt libvirt-nss nfs-utils \
    lksctp-tools tuned grubby rsync gperftools fio perf gdb liburing

poweroff
