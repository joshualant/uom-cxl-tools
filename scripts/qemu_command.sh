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
ADD_CPU_NOSTART_FLAG_FOR_GDB=


launch_instance() {
    # Expand the variables inside MACHINE_BASE and TOPOLOGY
    fn="${MACHINE_BASE}${1}"
    #declare -F "$func" &
    eval "$fn" &
    sleep $SLEEP_BETWEEN_BOOTS
}

machine_base() {
  MACHINE_BASE="$QEMU_DIR/build/qemu-system-x86_64 $ADD_CPU_NOSTART_FLAG_FOR_GDB -gdb tcp::$(($BASE_PORT_SSH+3)) -kernel $KERNEL_SRC_DIR/arch/x86_64/boot/bzImage \
    -append 'root=/dev/sda rw console=ttyS0,115200 loglevel=8 ignore_loglevel nokaslr cxl_acpi.dyndbg=+fplm cxl_pci.dyndbg=+fplm cxl_core.dyndbg=+fplm cxl_mem.dyndbg=+fplm cxl_pmem.dyndbg=+fplm cxl_port.dyndbg=+fplm cxl_region.dyndbg=+fplm cxl_test.dyndbg=+fplm cxl_mock.dyndbg=+fplm cxl_mock_mem.dyndbg=+fplm dax.dyndbg=+fplm dax_cxl.dyndbg=+fplm device_dax.dyndbg=+fplm pci=earlydump pci=trace ' \
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

working_dcd_single_instance() {
TOPOLOGY="-device usb-ehci,id=ehci \
-object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/josh-t3_cxl_single_dcd.raw,size=4G \
-object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/josh-t3_lsa_single_dcd.raw,size=1M \
-device pxb-cxl,bus_nr=11,bus=pcie.0,id=cxl.1,hdm_for_passthrough=true \
-device cxl-rp,port=0,bus=cxl.1,id=cxl_rp_port0,chassis=0,slot=2 \
-device cxl-upstream,port=0,sn=1234,bus=cxl_rp_port0,id=us0,addr=0.0,multifunction=on, \
-device cxl-switch-mailbox-cci,bus=cxl_rp_port0,addr=0.3,target=us0 \
-device cxl-downstream,port=0,bus=us0,id=swport0,slot=4 \
-device cxl-type3,bus=swport0,volatile-dc-memdev=cxl-mem1,id=cxl-dcd0,lsa=cxl-lsa1,num-dc-regions=2,sn=99,multifunction=on \
-device usb-cxl-mctp,bus=ehci.0,id=usb0,target=us0 \
-device usb-cxl-mctp,bus=ehci.0,id=usb1,target=cxl-dcd0 \
-machine cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.size=4G,cxl-fmw.0.interleave-granularity=1k "
}

dcd_two_dsp() {
TOPOLOGY="-device usb-ehci,id=ehci \
-object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/josh-t3_cxl_single_dcd.raw,size=4G \
-object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/josh-t3_lsa_single_dcd.raw,size=1M \
-object memory-backend-file,id=cxl-mem2,share=on,mem-path=/tmp/josh-t3_cxl_single_dcd2.raw,size=4G \
-object memory-backend-file,id=cxl-lsa2,share=on,mem-path=/tmp/josh-t3_lsa_single_dcd2.raw,size=1M \
-device pxb-cxl,bus_nr=11,bus=pcie.0,id=cxl.1,hdm_for_passthrough=true \
-device cxl-rp,port=0,bus=cxl.1,id=cxl_rp_port0,chassis=0,slot=2 \
-device cxl-upstream,port=0,sn=1234,bus=cxl_rp_port0,id=us0,addr=0.0,multifunction=on, \
-device cxl-switch-mailbox-cci,bus=cxl_rp_port0,addr=0.3,target=us0 \
-device cxl-downstream,port=0,bus=us0,id=swport0,slot=4 \
-device cxl-downstream,port=1,bus=us0,id=swport1,slot=5 \
-device cxl-type3,bus=swport0,volatile-dc-memdev=cxl-mem1,id=cxl-dcd0,lsa=cxl-lsa1,num-dc-regions=2,sn=99,multifunction=on \
-device cxl-type3,bus=swport1,volatile-dc-memdev=cxl-mem2,id=cxl-dcd1,lsa=cxl-lsa2,num-dc-regions=2,sn=99,multifunction=on \
-device usb-cxl-mctp,bus=ehci.0,id=usb0,target=us0 \
-device usb-cxl-mctp,bus=ehci.0,id=usb1,target=cxl-dcd0 \
-device usb-cxl-mctp,bus=ehci.0,id=usb2,target=cxl-dcd1 \
-machine cxl-fmw.0.targets.0=cxl.1,cxl-fmw.0.size=8G,cxl-fmw.0.interleave-granularity=1k "
}

two_rp() {
TOPOLOGY="-device usb-ehci,id=ehci \
 -object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/t3_cxl1.raw,size=8G \
-object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/t3_lsa1.raw,size=1M \
-object memory-backend-file,id=cxl-mem2,share=on,mem-path=/tmp/t3_cxl2.raw,size=8G \
-object memory-backend-file,id=cxl-lsa2,share=on,mem-path=/tmp/t3_lsa2.raw,size=1M \
-device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.0,hdm_for_passthrough=true \
-device pxb-cxl,bus_nr=48,bus=pcie.0,id=cxl.1,hdm_for_passthrough=true \
-device cxl-rp,port=0,bus=cxl.0,id=root_port1,chassis=0,slot=1 \
-device cxl-rp,port=1,bus=cxl.1,id=root_port2,chassis=1,slot=1 \
-device cxl-type3,bus=root_port1,volatile-dc-memdev=cxl-mem1,id=cxl-dcd0,lsa=cxl-lsa1,num-dc-regions=8,sn=99 \
-device cxl-type3,bus=root_port2,volatile-dc-memdev=cxl-mem2,id=cxl-dcd1,lsa=cxl-lsa2,num-dc-regions=8,sn=100 \
-machine cxl-fmw.0.targets.0=cxl.0,cxl-fmw.0.size=8G,cxl-fmw.1.targets.0=cxl.1,cxl-fmw.1.size=8G"
}

two_rp_with_switch() {
TOPOLOGY="-device usb-ehci,id=ehci \
 -object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/t3_cxl1.raw,size=8G \
-object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/t3_lsa1.raw,size=1M \
-object memory-backend-file,id=cxl-mem2,share=on,mem-path=/tmp/t3_cxl2.raw,size=8G \
-object memory-backend-file,id=cxl-lsa2,share=on,mem-path=/tmp/t3_lsa2.raw,size=1M \
-device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.0,hdm_for_passthrough=true \
-device pxb-cxl,bus_nr=48,bus=pcie.0,id=cxl.1,hdm_for_passthrough=true \
-device cxl-rp,port=0,bus=cxl.0,id=root_port1,chassis=0,slot=1 \
-device cxl-rp,port=1,bus=cxl.1,id=root_port2,chassis=1,slot=1 \
-device cxl-upstream,port=0,sn=1234,bus=root_port1,id=us0,addr=0.0,multifunction=on, \
-device cxl-upstream,port=0,sn=5678,bus=root_port2,id=us1,addr=0.1,multifunction=on, \
-device cxl-switch-mailbox-cci,bus=root_port1,addr=0.3,target=us0 \
-device cxl-downstream,port=0,bus=us0,id=swport0,slot=3 \
-device cxl-downstream,port=0,bus=us1,id=swport1,slot=4 \
-device cxl-type3,bus=swport0,volatile-dc-memdev=cxl-mem1,id=cxl-dcd0,lsa=cxl-lsa1,num-dc-regions=8,sn=99 \
-device cxl-type3,bus=swport1,volatile-dc-memdev=cxl-mem2,id=cxl-dcd1,lsa=cxl-lsa2,num-dc-regions=8,sn=100 \
-machine cxl-fmw.0.targets.0=cxl.0,cxl-fmw.0.size=8G,cxl-fmw.1.targets.0=cxl.1,cxl-fmw.1.size=8G"
}
#-device usb-ehci,id=ehci \
#-object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/t3_cxl1.raw,size=4G \
#-object memory-backend-file,id=cxl-mem2,share=on,mem-path=/tmp/t3_cxl2.raw,size=4G \
#-object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/t3_lsa1.raw,size=1M \
#-object memory-backend-file,id=cxl-lsa2,share=on,mem-path=/tmp/t3_lsa2.raw,size=1M \
#-device pxb-cxl,bus_nr=11,bus=pcie.0,id=cxl.1,hdm_for_passthrough=true \
#-device pxb-cxl,bus_nr=12,bus=pcie.0,id=cxl.2,hdm_for_passthrough=true \
#-device cxl-rp,port=0,bus=cxl.1,id=cxl_rp_port0,chassis=0,slot=2 \
#-device cxl-rp,port=1,bus=cxl.2,id=cxl_rp_port1,chassis=1,slot=2 \
#-device cxl-upstream,port=0,sn=1234,bus=cxl_rp_port0,id=us0,addr=0.0,multifunction=on, \
#-device cxl-upstream,port=0,sn=5678,bus=cxl_rp_port1,id=us1,addr=0.1,multifunction=on, \
#-device cxl-switch-mailbox-cci,bus=cxl_rp_port0,addr=0.3,target=us0 \
#-device cxl-switch-mailbox-cci,bus=cxl_rp_port1,addr=0.3,target=us1 \
#-device cxl-downstream,port=0,bus=us0,id=swport0,slot=4 \
#-device cxl-downstream,port=0,bus=us1,id=swport1,slot=5 \
#-device cxl-type3,bus=swport0,volatile-dc-memdev=cxl-mem1,id=cxl-dcd0,lsa=cxl-lsa1,num-dc-regions=2,sn=99 \
#-device cxl-type3,bus=swport1,volatile-dc-memdev=cxl-mem2,id=cxl-dcd1,lsa=cxl-lsa2,num-dc-regions=2,sn=100 \
#-device usb-cxl-mctp,bus=ehci.0,id=usb0,target=us0 \
#-device usb-cxl-mctp,bus=ehci.0,id=usb1,target=us1 \
#-device usb-cxl-mctp,bus=ehci.0,id=usb2,target=cxl-dcd0 \
#-device usb-cxl-mctp,bus=ehci.0,id=usb3,target=cxl-dcd1 \
#-machine cxl-fmw.0.targets.0=cxl.2,cxl-fmw.1.targets.0=cxl.1,cxl-fmw.0.size=2G,cxl-fmw.1.size=2G,cxl-fmw.0.interleave-granularity=1k,cxl-fmw.1.interleave-granularity=1k

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
        -i)
            if [[ ! -f "$TARGET_DIR/$2" ]]; then
                echo "Error: -i provided image name does not exist..." >&2
                shift 2
                break
            fi
            ROOTFS_IMAGE_NAME=$2
            shift 2
            ;;
        -S)
            ADD_CPU_NOSTART_FLAG_FOR_GDB="-S"
            shift 1
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


