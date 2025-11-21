TARGET_DIR=$(pwd)
CONFIG_FILE="$TARGET_DIR/scripts/config.txt"
[[ -f "$CONFIG_FILE" ]] || { echo "Missing $CONFIG_FILE"; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG_FILE"

if [[ ! -d "$TARGET_DIR/$GUEST_DATA_SHARE_PATH" ]]; then
  echo "Shared directory between host/guest does not exist, creating it..."
  mkdir -p "$TARGET_DIR/$GUEST_DATA_SHARE_PATH"
fi

KERNEL_SRC_DIR=$TARGET_DIR/$KERNEL_REPO_NAME
ROOTFS_DIR=$TARGET_DIR
ROOTFS_IMAGE_NAME=$IMAGE_NAME
GUEST_MODDIR=$INSTALL_MOD_PATH/lib/modules
SHARED_DATA_DIR=$TARGET_DIR/$GUEST_DATA_SHARE_PATH
BASE_PORT_SSH=$BASE_SSH_PORT
QEMU_DIR=$TARGET_DIR/$QEMU_REPO_NAME
GUEST_KERNEL_HEADERS=$INSTALL_HDR_PATH/include
LOG_DIR=$TARGET_DIR
PORT_INCREMENT=$PORT_INCREMENT_PER_HOST
#BIOS_FILE=

SLEEP_BETWEEN_BOOTS=0
MACHINE_BASE=
TOPOLOGY=



launch_instance() {
    # Expand the variables inside MACHINE_BASE and TOPOLOGY
    fn="${MACHINE_BASE}${1}"
    #declare -F "$func" &
    eval "$fn" &
    sleep $SLEEP_BETWEEN_BOOTS
}

machine_base() {
  MACHINE_BASE="$QEMU_DIR/build/qemu-system-x86_64 -gdb tcp::$(($BASE_PORT_SSH+3)) -kernel $KERNEL_SRC_DIR/arch/x86_64/boot/bzImage \
    -append 'root=/dev/sda rw console=ttyS0,115200 loglevel=8 ignore_loglevel nokaslr cxl_acpi.dyndbg=+fplm cxl_pci.dyndbg=+fplm cxl_core.dyndbg=+fplm cxl_mem.dyndbg=+fplm cxl_pmem.dyndbg=+fplm cxl_port.dyndbg=+fplm cxl_region.dyndbg=+fplm cxl_test.dyndbg=+fplm cxl_mock.dyndbg=+fplm cxl_mock_mem.dyndbg=+fplm dax.dyndbg=+fplm dax_cxl.dyndbg=+fplm device_dax.dyndbg=+fplm pci=earlydump pci=trace pcie_aspm=off' \
  -smp 1 -accel kvm -serial file:/$LOG_DIR/$ROOTFS_IMAGE_NAME.log -nographic -qmp tcp:localhost:$(($BASE_PORT_SSH+1)),server,wait=off \
  -netdev user,id=network0,hostfwd=tcp::$BASE_PORT_SSH-:22 -device e1000,netdev=network0 \
  -monitor telnet:127.0.0.1:$(($BASE_PORT_SSH+2)),server,nowait \
  -drive file=$ROOTFS_DIR/$ROOTFS_IMAGE_NAME,index=0,media=disk,format=raw \
  -machine q35,cxl=on -m 8G,maxmem=32G,slots=8 \
  -virtfs local,path=$GUEST_MODDIR,mount_tag=modshare,security_model=none \
  -virtfs local,path=$GUEST_KERNEL_HEADERS,mount_tag=headershare,security_model=none \
  -virtfs local,path=$SHARED_DATA_DIR,mount_tag=datashare,security_model=mapped \
  "
}

example() {
    TOPOLOGY=" -device usb-ehci,id=ehci \
    "
}

LAUNCH=false

generate_new_base_port() {
    BASE_PORT_SSH=$(($BASE_PORT_SSH + $PORT_INCREMENT))
}

generate_new_image_name() {
    local base ext num
    base="${ROOTFS_IMAGE_NAME%.*}"   # e.g. "rootfs" or "rootfs2"
    ext="${ROOTFS_IMAGE_NAME##*.}"   # e.g. "img"

    # Extract trailing number if present, else start from 1
    if [[ $base =~ ^([a-zA-Z0-9_-]+?)([0-9]+)$ ]]; then
        base="${BASH_REMATCH[1]}"
        num=$(( BASH_REMATCH[2] + 1 ))
    else
        num=2
    fi

    ROOTFS_IMAGE_NAME="${base}${num}.${ext}"
}


while [[ $# -gt 0 ]]; do
    case "$1" in
        -n)
            if [[ -z "$2" || ! "$2" =~ ^[1-9]+$ ]]; then
                echo "Error: -n requires a numeric argument" >&2
            else
              for ((i=1;i<$2;i++)); do
                generate_new_image_name
              done
            fi
            shift 2
            ;;
        -l)
	    shift 1
            while [[ -n "$1" ]]; do
                machine_base
                func="$1"
                if declare -F "$func" >/dev/null; then
                    "$func"
		    launch_instance "$TOPOLOGY" $BASE_PORT_SSH
                    generate_new_base_port
                    generate_new_image_name
		    shift 1
                else
                    echo "Error: function '$func' not defined"
		    shift 1
                fi
	    done
            ;;
        -s)
            if [[ -z "$2" || ! "$2" =~ ^[1-9]+$ ]]; then
                echo "Error: -s requires a numeric argument" >&2
            fi
            SLEEP_BETWEEN_BOOTS=$2
            shift 2
            ;;
        -p)
            if [[ -z "$2" || ! "$2" =~ ^[0-9]+$ ]]; then
                echo "Error: -p port needs a numeric argument" >&2
            fi
            BASE_PORT_SSH=$2
            shift 2
            ;;
        -*)
            echo "Error: Unknown option $1" 
            shift 1
            ;;
        *)
            echo "Error: Unexpected argument $1" 
            shift 1
            ;;
    esac
done


