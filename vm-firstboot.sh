#!/bin/bash

RPM_DIR=/rpms/
VMLINUZ=
set -x

ENFORCE=$(getenforce)

# rpm fails if it runs from init
# (error: failed to exec scriptlet interpreter /bin/sh: Permission denied)
setenforce Permissive

for file in $RPM_DIR/*/*.rpm; do
    pkg=$(rpm -q --queryformat "%{NAME}-%{VERSION}\n" $file)
    rpm -e $pkg
done

rpm -U --oldpackage $RPM_DIR/*/*.rpm
for file in $RPM_DIR/*/*.rpm; do
    #rpm -i --oldpackage $file
    if [ "$VMLINUZ" == "" ]; then
        VMLINUZ=$(rpm -qpl $file | grep /boot/vmlinuz)
    fi
done

if [ "$VMLINUZ" != "" ]; then
    grubby --set-default $VMLINUZ
fi

grubby --update-kernel=ALL --args="nokaslr nosmap nohz intel_iommu=strict selinux=0"

setenforce $ENFORCE

poweroff
