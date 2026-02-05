TARGET_DIR=$(pwd)
CONFIG_FILE="$TARGET_DIR/scripts/config.txt"
[[ -f "$CONFIG_FILE" ]] || { echo "Missing $CONFIG_FILE"; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG_FILE"

apply_patches() {
  IFS=',' read -ra PATCH_IDS <<< "$2"

  cd $1
  for id in "${PATCH_IDS[@]}"; do
        echo "Applying patch: $id"
        #b4 am -o ./patch.mbox "$id"
        #git am ./patch.mbox
        #rm ./patch.mbox
        b4 am -o- "$id" | git am
  done
  cd -
}

build_kernel() {
  echo "building kernel..."
  cd $TARGET_DIR/$KERNEL_REPO_NAME
  if [[ ! -d "$INSTALL_MOD_PATH" ]]; then
    echo "Module directory does not exist, creating it..."
    mkdir -p "$INSTALL_MOD_PATH"
  fi
  if [[ ! -d "$INSTALL_HDR_PATH" ]]; then
    echo "Header directory does not exist, creating it..."
    mkdir -p "$INSTALL_HDR_PATH"
  fi
  if [[ ! -f "$TARGET_DIR/$KERNEL_REPO_NAME/.config" ]]; then
    echo "Directory does not exist, creating it..."
    cp $KCONFIG $TARGET_DIR/$KERNEL_REPO_NAME/.config
  fi
  make -j$(nproc)
  #make M=tools/testing/nvdimm
  #sudo make M=tools/testing/nvdimm modules_install INSTALL_MOD_PATH=$INSTALL_MOD_PATH
  #make M=tools/testing/cxl
  #sudo make M=tools/testing/cxl modules_install INSTALL_MOD_PATH=$INSTALL_MOD_PATH
  sudo make modules_install INSTALL_MOD_PATH=$INSTALL_MOD_PATH
  make headers_install INSTALL_HDR_PATH=$INSTALL_HDR_PATH
  cd -
}

build_qemu() {
  echo "building qemu..."
  cd $TARGET_DIR/$QEMU_REPO_NAME
  if [[ ! -d "build" ]]; then
    echo "Creating build directory"
    mkdir -p "build"
  fi
  cd -
  cd $TARGET_DIR/$QEMU_REPO_NAME/build
  CFLAGS='-Wno-error=deprecated-declarations' ../configure --target-list=x86_64-softmmu --enable-debug --disable-strip
  make -j$(nproc)
  cd -
}

git_clone() {
  echo "cloning repo..."
  URL=$1
  TARGET=$4
  NAME=$5
  QUICK=
  if [[ $2 != "" ]]; then
    BRANCH="--branch $2"
  else
    BRANCH=""
  fi
  if [[ $3 == true ]]; then
    QUICK="--depth 1"
  else 
    QUICK=""
  fi
  git clone $BRANCH $QUICK $URL $TARGET/$NAME
}

print_help() {
  echo "help placeholder"
}

TARGET_DIR=$(pwd)
CONFIG_FILE="$TARGET_DIR/scripts/config.txt"
[[ -f "$CONFIG_FILE" ]] || { echo "Missing $CONFIG_FILE"; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG_FILE"

PRINT_HELP=false

GIT_DOWNLOAD=false
KERNEL_BUILD=false
QEMU_BUILD=false
APPLY_QEMU_PATCHES=false
APPLY_KERNEL_PATCHES=false

GIT_URL=
GIT_BRANCH=""
GIT_REPO_NAME=
GIT_QUICK=false

if [[ $# -eq 0 ]]; then
  PRINT_HELP=true
fi
while [[ $# -gt 0 ]]; do
    case "$1" in
	-h|--help)
	    PRINT_HELP=true
	    break
	    ;;
        -d)
	    if [[ -z "$2" || ( "$2" != "kernel" && "$2" != "qemu" ) ]]; then
		echo "Error: Option requires 'kernel' or 'qemu'" 
	    fi
            shift 1
	    if [[ "$1" == "kernel" ]]; then
		GIT_DOWNLOAD=true
		GIT_URL=$KERNEL_GIT
		GIT_BRANCH=$KERNEL_BRANCH
		GIT_REPO_NAME=$KERNEL_REPO_NAME
	    elif [[ "$1" == "qemu" ]]; then
		GIT_DOWNLOAD=true
		GIT_URL=$QEMU_GIT
		GIT_BRANCH=$QEMU_BRANCH
		GIT_REPO_NAME=$QEMU_REPO_NAME
	    else
		echo "Error: unrecognised option... use -h" 
	    fi
            shift 1
            ;;
        -q)
	    GIT_QUICK=true
            shift 1
            ;;
	-b)
	    if [[ -z "$2" || ( "$2" != "kernel" && "$2" != "qemu" ) ]]; then
		echo "Error: Option requires 'kernel' or 'qemu'" 
	    fi
            shift 1
	    if [[ "$1" == "kernel" ]]; then
		KERNEL_BUILD=true
	    elif [[ "$1" == "qemu" ]]; then
		QEMU_BUILD=true
	    else
		echo "Error: unrecognised option... use -h" 
	    fi
            shift 1
            ;;
	-p)
	    if [[ -z "$2" || ( "$2" != "kernel" && "$2" != "qemu" ) ]]; then
		echo "Error: Option requires 'kernel' or 'qemu'" 
	    fi
            shift 1
	    if [[ "$1" == "kernel" ]]; then
		GIT_REPO_NAME=$KERNEL_REPO_NAME
		APPLY_KERNEL_PATCHES=true
	    elif [[ "$1" == "qemu" ]]; then
		GIT_REPO_NAME=$QEMU_REPO_NAME
		APPLY_QEMU_PATCHES=true
	    else
		echo "Error: unrecognised option... use -h" 
	    fi
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

$PRINT_HELP && print_help
$GIT_DOWNLOAD && git_clone $GIT_URL "$GIT_BRANCH" $GIT_QUICK $TARGET_DIR $GIT_REPO_NAME
$APPLY_QEMU_PATCHES && apply_patches $TARGET_DIR/$GIT_REPO_NAME $QEMU_PATCHES
$APPLY_KERNEL_PATCHES && apply_patches $TARGET_DIR/$GIT_REPO_NAME $KERNEL_PATCHES
$KERNEL_BUILD && build_kernel
$QEMU_BUILD && build_qemu
