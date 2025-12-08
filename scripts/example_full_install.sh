TARGET_DIR=$(pwd)
CONFIG_FILE="$TARGET_DIR/scripts/config.txt"
[[ -f "$CONFIG_FILE" ]] || { echo "Missing $CONFIG_FILE"; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG_FILE"

# Download tools with shallow clone option (remove -q for full dl)
./scripts/build_tools.sh  -d kernel
./scripts/build_tools.sh  -d qemu
# Apply patches to the projects
./scripts/build_tools.sh -p kernel
./scripts/build_tools.sh -p qemu
# Build the tools
./scripts/build_tools.sh -b kernel
./scripts/build_tools.sh -b qemu
# Create a filesystem image with relevant packages installed etc.
./scripts/create_image.sh -n 1
# Launch a single qemu instance with "exmaple" CXL topology 
#./scripts/qemu_command.sh -l example
