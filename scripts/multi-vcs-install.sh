TARGET_DIR=$(pwd)
CONFIG_FILE="$TARGET_DIR/scripts/config.txt"
[[ -f "$CONFIG_FILE" ]] || { echo "Missing $CONFIG_FILE"; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG_FILE"

# Download tools with shallow clone option (remove -q for full dl)
./scripts/build_tools.sh  -q -d kernel
./scripts/build_tools.sh  -q -d qemu
# Apply patches to the projects
./scripts/build_tools.sh -p kernel
./scripts/build_tools.sh -p qemu
# Build the tools
./scripts/build_tools.sh -b kernel
./scripts/build_tools.sh -b qemu
# Create a filesystem image with relevant packages installed etc.
./scripts/create_image.sh -n 3
# Launch a single qemu instance with "exmaple" CXL topology 
#./scripts/qemu_command.sh -l example

./scripts/qemu_command.sh -i rootfs.img -p 33000 -l vcs_seccom_test_fm
./scripts/qemu_command.sh -i rootfs2.img -p 34000 -l vcs_seccom_test_node1
./scripts/qemu_command.sh -i rootfs3.img -p 35000 -l vcs_seccom_test_node2

expect -c 'set timeout -1; spawn ssh -o StrictHostKeyChecking=no root@localhost -p 33000 "bash -lc /root/cli_tool_installer.sh -n -l -m"; expect "password:"; send "root\r"; expect eof'

expect -c 'set timeout -1; spawn ssh -o StrictHostKeyChecking=no root@localhost -p 34000 "bash -lc /root/cli_tool_installer.sh -n -l -m"; expect "password:"; send "root\r"; expect eof'

expect -c 'set timeout -1; spawn ssh -o StrictHostKeyChecking=no root@localhost -p 35000 "bash -lc /root/cli_tool_installer.sh -n -l -m"; expect "password:"; send "root\r"; expect eof'

cp -r ./scripts/shared_testing_scripts/* ./$GUEST_DATA_SHARE_PATH
