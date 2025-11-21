TARGET_DIR=$(pwd)
CONFIG_FILE="$TARGET_DIR/scripts/config.txt"
CLI_TOOL_INSTALLER="$TARGET_DIR/scripts/cli_tool_installer.sh"
[[ -f "$CONFIG_FILE" ]] || { echo "Missing $CONFIG_FILE"; exit 1; }
source "$CONFIG_FILE"
set -e

generate_base_image() {
  qemu-img create -f raw $IMAGE_NAME 10G
  sudo losetup -fP $IMAGE_NAME
  LOOPBACK_DEVICE=$(losetup -a | grep $IMAGE_NAME | awk -F: '{print $1}')
  sudo mkfs.ext4 $LOOPBACK_DEVICE
  sudo mount $LOOPBACK_DEVICE $MOUNT_POINT
  # Minimal install to SSH in... Doesnt install user packages for ndctl tests...
  #sudo debootstrap --arch=amd64 --include=openssh-server,ifupdown,net-tools,iproute2,bash bookworm $MOUNT_POINT
  # Maximal setup, ndctl tests should run with no missing deps.
  sudo debootstrap --arch=amd64 --include=openssh-server,ifupdown,net-tools,iproute2,bash,git,meson,build-essential,pkg-config,cmake,libkmod-dev,libudev-dev,uuid-dev,libjson-c-dev,libtraceevent-dev,libtracefs-dev,asciidoctor,libkeyutils-dev,libiniparser-dev,keyutils,bash-completion,jq,bsdmainutils,xxd,parted,uuid-runtime,vim,pciutils,man-db,libdbus-1-dev,pkg-config,python3-pytest,libsystemd-dev,dbus,numactl,libnuma-dev,m4,bison,flex bookworm $MOUNT_POINT
  # Setup networking at boot on the fs.
  sudo sh -c "echo 'auto enp0s2' >> \"$MOUNT_POINT/etc/network/interfaces\""
  sudo sh -c "echo 'iface enp0s2 inet dhcp' >> \"$MOUNT_POINT/etc/network/interfaces\""
  sudo cp $CLI_TOOL_INSTALLER $MOUNT_POINT/$CLI_TOOLS_TARGET_DIR
  sudo cp $CONFIG_FILE $MOUNT_POINT/$CLI_TOOLS_TARGET_DIR
  #Please change upon first login!
  PASSWORD='root'
  HASH=$(openssl passwd -6 "$PASSWORD")
  # apply the password to the root user on the guest
  sudo chroot "$MOUNT_POINT" /bin/bash -c "usermod -p '$HASH' root"
  # Make modifications to allow root to SSH in, in case QEMU config gives no terminal (i.e. output to log file).
  sudo sh -c "echo 'PermitRootLogin yes' >> \"$MOUNT_POINT/etc/ssh/sshd_config\""
  # Mount module sharing and data share dirs from boot
  sudo sh -c "echo 'modshare /lib/modules 9p trans=virtio,version=9p2000.L,msize=262144 0 0' >> \"$MOUNT_POINT/etc/fstab\""
  sudo sh -c "echo 'headershare /usr/local/include 9p trans=virtio,version=9p2000.L,msize=262144 0 0' >> \"$MOUNT_POINT/etc/fstab\""
  sudo sh -c "mkdir -p \"$MOUNT_POINT/$GUEST_DATA_SHARE_PATH\""
  sudo sh -c "echo 'datashare /$GUEST_DATA_SHARE_PATH 9p trans=virtio,version=9p2000.L,msize=262144 0 0' >> \"$MOUNT_POINT/etc/fstab\""
  # cleanup before qemu can boot
  sudo umount $MOUNT_POINT
  sudo losetup -d $LOOPBACK_DEVICE
}

replicate_base_image() {
    for ((i = 2; i <= $1; i++)); do
        target="${IMAGE_NAME%.*}$i.${IMAGE_NAME##*.}"
        echo "Copying $IMAGE_NAME to $target"
        cp "$IMAGE_NAME" "$target" || {
            echo "Failed to copy to $target" >&2
        }
    done
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n)
            if [[ -z "$2" || ! "$2" =~ ^[1-9]+$ ]]; then
                echo "Error: -n requires a numeric argument" >&2
            fi
            count="$2"
            shift 2
            ;;
        -*)
            echo "Error: Unknown option $1" >&2
            ;;
        *)
            echo "Error: Unexpected argument $1" >&2
            ;;
    esac
done

# Run the function N times if -n was given
if [[ -n "$count" ]]; then
    generate_base_image
    replicate_base_image $count
else
    echo "Error: -n option is required" >&2
fi

set +e
