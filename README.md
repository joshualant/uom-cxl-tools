# UoM Tool for CXL/QEMU Development and Debugging:

-------------------------
## 0. Note (Important)

All commands should be run from the ./< project dir >, unless you configure 
otherwise (untested and very much at your own risk...):

These scripts were made mainly made to allow UoM colleagues on similar machines
to replicate my own dev envorinment, and so they may well have bugs.
Apologies if they don't work 100% for you right away.

DEPENDENCIES:

There may be MANY packages that you need to install in order to get a nicely
working version of QEMU. You will need to look at the config output when
running "./scripts/build_tools.sh -b qemu" to determine which deps are 
not present, and if they are required. (I would like a concrete list of deps,
but don't have it at this time...)

Some clear dependencies are:
qemu-img, debootstrap, slirp, b4


-------------------------
## 1. Quickstart

Reading example_full_install.sh should give you a general idea of the workflow.
From there, reading the individual scripts will give you a good idea of what is
happening in each step...

To run, you can simply use:

```
./scripts/example_full_install.sh
ssh root@localhost -p < base ssh port (look in ./scripts/config.txt) >
/root/cli_tool_installer.sh -a
```

From this point you should have a setup which can use all cxl related tools for 
dev/debug. 

Each of the scripts should individually have a help section and several options.
The default using full_install.sh will use -q (quick) when getting kernel/qemu. This
option will shallow clone the repos with no git history. For proper dev you'll want
to run without -q option.

-------------------------
## 2. Config

There are many config options, most of which are not necessary to modify.
The config.txt has a load of information about what the options are and
if they are necessary to change.

-------------------------
## 3. CXL Topologies

Launching QEMU is done using the qemu_command.sh script. In there is currently
where you should add new topologies you want to run. The QEMU command is 
broken up into two portions. The first is a static machine_base, which I have
tailored for my own needs. You may want a different set up...
The second is the CXL/device topology which you can modify/add new ones if 
you like. 

In order to launch a new CXL topology you simply run
```
./scripts/qemu_command.sh -l < my topology name >
```

You can chain these together if you want to launch multiple machines. i.e.
```
./scripts/qemu_command.sh -l host_1 host_2
```

But you will have needed to create multiple base filesystem images to
do this. I.e.
```
./scripts/create_image.sh -n 2
```

(or created multiple copies of one image, with appropriately named .img files).

If you launch multiple images, they will have incremented ports for ssh/gdb etc.
The increment is currently 1000 per machine.

Alternatively you could launch them separately and specify the base port. e.g:

```
./scrips/qemu_command.sh -l host_1 -p 40000
./scrips/qemu_command.sh -l host_2 -p 50000
```

-------------------------
## 4. CLI Tool Installer

To install the CLI tools simply run this from the guest:

```
/root/cli_installer.sh -a
```

The main cli tools for the qemu instance I have been interested in are:

ndctl, mctp, libcxlmi, acpica (needed because newer cxl acpi table stuff 
isn't in packaged versions.)

The installer script for these is placed in /root/ of your image when you
create it with create_image.sh. I will at some point get round to installing
these from the host before you launch the qemu instance, but not done yet.

If you need anything different it should not be too much trouble to extend
the installer script as you need and modify config.txt accordingly.

-------------------------
## 5. Shared directories

The default setup creates a folder which is shared between host and 
all project guests which may be useful to you. This is found:

on host: \<project dir\>/host-share

on guest: /host-share

Note- Due to the shared filesystem using virtio-9p
you may find that building/copying from this directory on the guest is quite slow.
I mainly use it for small bespoke scripts which are not suitable for this base
repo.

The kernel headers and modules are also mounted in the guest from the host's 
filesystem. This way you can easily do kernel development and simply reboot 
to apply a new kernel or update a module.

-------------------------
## 5. Extending beyond a basic install...

Once you are up and running from the exmaple_full_install.sh the world is your
oyster... It is difficult to give more information since what you want to do 
may be very different from what I want to do. However, something useful
that you might want is to issue FMAPI commmands to configure CXL devices etc.

To do this I might use a topology adding a CXL DCD with MCTP over USB like so:

Adding to qemu_command.sh (below exmaple() function):

```
working_dcd_single_instance() {
TOPOLOGY="-device usb-ehci,id=ehci \
-object memory-backend-file,id=cxl-mem1,share=on,mem-path=/tmp/t3_cxl_single_dcd.raw,size=4G \
-object memory-backend-file,id=cxl-lsa1,share=on,mem-path=/tmp/t3_lsa_single_dcd.raw,size=1M \
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
```

and then running with 

```
./scripts/qemu_command.sh -l working_dcd_single_instance
```

Once logged in I will need to set up MCTP to work (the default install uses 
dbus for controlling mctp from libcxlmi, which is used to issue basic commands).
So I create a script like so in /host-share/... and run it (once i have installed
the CLI tools of course):

```
mctp_link=$(mctp link | grep mctpusb | awk '{print $2}')
echo $mctp_link
if [ "$mctp_link" == "" ];then
    echo "MCTP link not found"
    exit 1
fi

mctp link set mctpusb0 up;
mctp addr add 8 dev mctpusb0;
mctp link set mctpusb0 net 1;

mctp link set mctpusb1 up;
mctp addr add 9 dev mctpusb1;
mctp link set mctpusb1 net 1;

systemctl restart mctpd.service
busctl call au.com.codeconstruct.MCTP1 /au/com/codeconstruct/mctp1/interfaces/mctpusb0 au.com.codeconstruct.MCTP.BusOwner1 SetupEndpoint ay 0
busctl call au.com.codeconstruct.MCTP1 /au/com/codeconstruct/mctp1/interfaces/mctpusb1 au.com.codeconstruct.MCTP.BusOwner1 SetupEndpoint ay 0
```

Now I should be able to issue MCTP commands to the DCD to add and release extents etc.
(But first I need to create a region in the host which can be mapped to this extent).

```
cxl create-region -m mem0 -d decoder0.0 -s 2G -t dynamic_ram_a --debug
/root/libcxlmi/build/examples/fmapi-mctp 1 11
```

(This example was taken from [1]. For more information, visit that page...)

[1] https://lore.kernel.org/linux-cxl/20250714174509.1984430-1-Jonathan.Cameron@huawei.com/

In the VM, you can use libcxlmi to test.

```sh
cd libcxlmi
python3 tests/run_tests.py --endpoint mctp 1 11 -s FMAPI --verify-rsp
```
-------------------------
## 6. Help

Please if something doesn't set up correctly on your system, email me, even if 
the fix is quick/obvious. Then I can make the scripts better or add to the
package deps etc...

joshualant@gmail.com
