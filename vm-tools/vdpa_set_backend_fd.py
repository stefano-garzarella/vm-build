#!/usr/bin/python3
import argparse, os

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('device', help='vDPA block device name')
    parser.add_argument('-b', '--backend', help='raw file or device to set as backend')
    parser.add_argument('-c', '--clean', action='store_true', help='clean backend file')
    parser.add_argument('-v', '--verbose', action='store_true')
    args = parser.parse_args()

    if args.verbose:
        print(args)

    str_to_write = None
    backend_fd = None

    if args.backend:
        backend_fd = os.open(args.backend, os.O_RDWR|os.O_DIRECT)
        str_to_write = str(backend_fd)

    if args.clean:
        str_to_write = "-1"

    dev_path = "/sys/bus/vdpa/devices/" + args.device + "/backend_fd"

    if args.verbose:
        print("path: " + dev_path + " - str: " + str_to_write)

    dev_backend = open(dev_path, "w")

    if str_to_write != None:
        dev_backend.write(str_to_write)

    dev_backend.close()

    if backend_fd != None:
        os.close(backend_fd)

if __name__ == "__main__":
    main()
