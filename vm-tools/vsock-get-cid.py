#!/usr/bin/env python3
import socket
import struct
import fcntl

with open("/dev/vsock", "rb") as fd:
    r = fcntl.ioctl(fd, socket.IOCTL_VM_SOCKETS_GET_LOCAL_CID, "    ")
    cid = struct.unpack("I", r)[0]

    print("Local CID: {}".format(cid))
