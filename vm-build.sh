#!/bin/bash

BASE_PATH="${HOME}"
SCRIPT_PATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

SSH_PUB_KEY=${BASE_PATH}/.ssh/id_rsa.pub
RPMS_DIR=${BASE_PATH}/rpmbuild/RPMS/x86_64
VM_IMAGE_DIR=${BASE_PATH}/works/virt/images

FIRSTBOOT_SCRIPT=${SCRIPT_PATH}/vm-firstboot.sh
FIRSTBOOT_BASE_SCRIPT=${SCRIPT_PATH}/vm-firstboot-base.sh
TOOLS_HOST_DIR=${SCRIPT_PATH}/vm-tools

RPMS_HOST_DIR=${SCRIPT_PATH}/rpms
RPMS_GUEST_DIR=/rpms
TOOLS_GUEST_DIR=/

FV="34"

RED='\033[0;31m'
NC='\033[0m' # No Color

function usage
{
    echo -e "usage: $0 [OPTION...]"
    echo -e ""
    echo -e "Build a VM image."
    echo -e "  Base image will contain OS and base packages. "
    echo -e "  The final image (backed on the base image) will contain the RPMs"
    echo -e "  installed."
    echo -e ""
    echo -e " -a, --all           alias for -c -i -r -s -t"
    echo -e ""
    echo -e " -c, --clean         remove final image previously generated"
    echo -e " -C, --clean-base    remove base image"
    echo -e " -i, --install       install VM using virt-install"
    echo -e " -f, --fedora        Fedora version to use [def: ${FV}]"
    echo -e " -r, --rpms          install RPMs in the VM"
    echo -e "     --rpms-dir      directory that contains the RPMs [def: $RPMS_DIR]"
    echo -e "     --rpms-remove   remove RPMs from the host directory"
    echo -e " -s, --start         start the VM at the end"
    echo -e " -t, --tools         install vm-tools in the VM"
    echo -e " --vmdk              generate also VMDK image"
    echo -e " -h, --help          print this help"
}

CLEAN_BASE=0
CLEAN=0
CUSTOMIZE=""
INSTALL=0
RPMS=0
RPMS_REMOVE=0
START=0
TOOLS=0
VMDK=0

while [ "$1" != "" ]; do
    case $1 in
        -a | --all )
            CLEAN=1
            INSTALL=1
            RPMS=1
            START=1
            TOOLS=1
            ;;
        -c | --clean )
            CLEAN=1
            ;;
        -C | --clean-base )
            CLEAN_BASE=1
            ;;
        -i | --install )
            INSTALL=1
            ;;
        -f | --fedora )
            shift
            FV=$1
            ;;
        -r | --rpms )
            RPMS=1
            ;;
        --rpms-dir )
            shift
            RPMS_DIR=$1
            ;;
        --rpms-remove )
            shift
            RPMS_REMOVE=$1
            ;;
        -s | --start )
            START=1
            ;;
        -t | --tools )
            TOOLS=1
            ;;
        --vmdk )
            VMDK=1
            ;;
        -h | --help )
            usage
            exit
            ;;
        * )
            echo -e "\n${RED}Parameter not found:${NC} $1\n"
            usage
            exit 1
    esac
    shift
done

if [ "$RPMS" == "1" ]; then
    if [ ! -d "$RPMS_HOST_DIR" ]; then
        mkdir "$RPMS_HOST_DIR"
    fi

    rm "$RPMS_HOST_DIR"/*
    if [ "$RPMS_REMOVE" == "1" ]; then
        mv "${RPMS_DIR}"/*rpm "$RPMS_HOST_DIR"/
    else
        cp "${RPMS_DIR}"/*rpm "$RPMS_HOST_DIR"/
    fi

    CUSTOMIZE+=" --mkdir ${RPMS_GUEST_DIR} \
                 --copy-in ${RPMS_HOST_DIR}:${RPMS_GUEST_DIR}"
fi

if [ "$TOOLS" == "1" ]; then
    CUSTOMIZE+=" --mkdir ${TOOLS_GUEST_DIR} \
                 --copy-in ${TOOLS_HOST_DIR}:${TOOLS_GUEST_DIR}"
fi

if [ ! -d "$VM_IMAGE_DIR" ]; then
    mkdir -p "$VM_IMAGE_DIR"
fi

VM=f${FV}-vm-build
VM_IMAGE_REL=${VM}.qcow2
VM_IMAGE_BASE_REL=${VM_IMAGE_REL}.base
VM_IMAGE=${VM_IMAGE_DIR}/${VM_IMAGE_REL}
VM_IMAGE_BASE=${VM_IMAGE}.base
OS_NAME=fedora-${FV}
OS_VARIANT=fedora${FV}

set -x

virsh --connect qemu:///system destroy $VM
virsh --connect qemu:///system undefine $VM

if [ "$CLEAN_BASE" == "1" ]; then
    rm "${VM_IMAGE_BASE}"
fi

if [ ! -f "${VM_IMAGE_BASE}" ]; then
    virt-builder --ssh-inject=root:file:${SSH_PUB_KEY} \
        --selinux-relabel --root-password=password:redhat \
        --output=${VM_IMAGE_BASE} \
        --format=qcow2 \
        --firstboot ${FIRSTBOOT_BASE_SCRIPT} \
        --size 10G $OS_NAME || exit

    virt-install --connect qemu:///system --name $VM --import \
        --noautoconsole --wait \
        --ram 2048 --vcpus 2 --cpu host \
        --disk bus=virtio,path=${VM_IMAGE_BASE} \
        --network network=default,model=virtio --os-variant $OS_VARIANT

    virsh --connect qemu:///system undefine $VM
fi

if [ "$CLEAN" == "1" ]; then
    rm "${VM_IMAGE}"
fi

if  [ "${VM_IMAGE_BASE}" != "${VM_IMAGE}" ] && [ ! -f "${VM_IMAGE}" ]; then
    pushd ${VM_IMAGE_DIR}
    qemu-img create -f qcow2 -F qcow2 -b ${VM_IMAGE_BASE_REL} ${VM_IMAGE_REL}
    popd
fi

if [ -n "${CUSTOMIZE}" ]; then
    virt-customize -a ${VM_IMAGE} --selinux-relabel \
        --firstboot ${FIRSTBOOT_SCRIPT} \
        --hostname ${VM} \
        ${CUSTOMIZE}
fi

if [ "$INSTALL" == "1" ]; then
    virt-install --connect qemu:///system --name $VM --import \
        --noautoconsole --wait \
        --ram 2048 --vcpus 2 --cpu host \
        --disk bus=virtio,path=${VM_IMAGE} \
        --network network=default,model=virtio --os-variant $OS_VARIANT

#    --vsock cid.auto=yes \
#    virt-install --name $VM --import --ram 2048 --vcpus 4,cpuset=0,2,4,6 \
#        --cpu host-passthrough,cache.mode=passthrough \
#        --cputune vcpupin0.vcpu=0,vcpupin0.cpuset=0,vcpupin1.vcpu=1,vcpupin1.cpuset=2,vcpupin2.vcpu=2,vcpupin2.cpuset=4,vcpupin3.vcpu=3,vcpupin3.cpuset=6 \
#        --numatune 0 \
#	--iothreads 4 \
#        --disk bus=virtio,path=${VM_IMAGE} \
#        --network network=default,model=virtio --os-variant $OS_VARIANT
        #--qemu-commandline="-drive file=/dev/nvme0n1,format=raw,if=none,id=hd1,cache=none,aio=io_uring -device virtio-blk-pci,scsi=off,drive=hd1,num-queues=4" \
fi

if [ "$VMDK" == "1" ]; then
    qemu-img convert -f qcow2 -O vmdk ${VM_IMAGE} ${VMDK_IMAGE}
fi

if [ "$START" == "1" ]; then
    virsh --connect qemu:///system start ${VM}
    echo "You can attach your domain by running:"
    echo "  virsh --connect qemu:///system console ${VM}"
fi
