UoM Tool for CXL/QEMU Development and Debugging:

-------------------------
0. Note (Important)

All commands should be run from the ./< project dir >, unless you configure 
otherwise (untested and very much at your own risk...):

These scripts were made mainly made for my own use and may have bugs.
Apologies if they don't work 100% for you right away.

DEPENDENCIES:

There may be MANY packages that you need to install in order to get a nicely
working version of QEMU. You will need to look at the config output when
running "./scripts/build_tools.sh -b qemu" to determine which deps are 
not present, and if they are required. (I would like a concrete list of deps,
but don't have it at this time...)

Some clear dependencies are:
qemu-img, debootstrap, slirp


-------------------------
1. Quickstart

To run, you can simply use:

./scripts/example_full_install.sh
ssh root@localhost -p < base ssh port (look in ./scripts/config.txt) >
/root/cli_tool_installer.sh -a

You should then have a setup which can use all cxl related tools for dev/debug.
Reading the script will give you a clearer idea of the individual steps
involved in set up for when you want to customise your environment...

Each of the scripts should individually have a help section and several options.
The default using full_install.sh will use -q (quick) when getting kernel/qemu. This
option will shallow clone the repos with no git history. For proper dev you'll want
to run without -q option.

-------------------------
2. Config

There are many config options, most of which are not necessary to modify.
The config.txt has a load of information about what the options are and
if they are necessary to change.

-------------------------
3. CXL Topologies

Launching QEMU is done using the qemu_command.sh script. In there is currently
where you should add new topologies you want to run. The QEMU command is 
broken up into two portions. The first is a static machine_base, which I have
tailored for my own needs. You may want a different set up...
The second is the CXL/device topology which you can modify/add new ones if 
you like. 

In order to launch a new CXL topology you simply run
./scripts/qemu_command.sh -l < my topology name >

You can chain these together if you want to launch multiple machines. i.e.
./scripts/qemu_command.sh -l host_1 host_2

But you will have needed to create multiple base filesystem images to
do this. I.e.
./scripts/create_image.sh -n 2

(or created multiple copies of one image, with appropriately named .img files).

If you launch multiple images, they will have incremented ports for ssh/gdb etc.
The increment is currently 1000 per machine.

Alternatively you could launch them separately and specify the base port. e.g:

./scrips/qemu_command.sh -l host_1 -p 40000
./scrips/qemu_command.sh -l host_2 -p 50000

-------------------------
4. CLI Tool Installer

The main cli tools for the qemu instance I have been interested in are:

ndctl
mctp
libcxlmi
acpica (needed because newer cxl acpi table stuff isnt in packaged versions.)

The installer script for these is placed in /root/ of your image when you
create it with create_image.sh. I will at some point get round to installing
these from the host before you launch the qemu instance, but not done yet.

If you need anything different it should not be too much trouble to extend
the installer script as you need and modify config.txt accordingly.

-------------------------
5. Help

Please if something doesn't set up correctly on your system, email me, even if 
the fix is quick/obvious. Then I can make the scripts better or add to the
package deps etc...

joshualant@gmail.com
