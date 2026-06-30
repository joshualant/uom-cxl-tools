TARGET_DIR=$(pwd)
CONFIG_FILE="$TARGET_DIR/config.txt"
[[ -f "$CONFIG_FILE" ]] || { echo "Missing $CONFIG_FILE"; exit 1; }
# shellcheck disable=SC1090
source "$CONFIG_FILE"

git_clone() {
  echo "cloning repo..."
  URL=$1
  TARGET=$3
  NAME=$4
  QUICK=
  if [[ $2 != "" ]]; then
    BRANCH="--branch $2"
  else
    BRANCH=""
  fi
  git clone $BRANCH $URL $TARGET/$NAME
}

#install ndctl
ndctl_installer() {
  GIT_URL=$NDCTL_GIT
  GIT_BRANCH=$NDCTL_BRANCH
  GIT_REPO_NAME=$NDCTL_REPO_NAME
  git_clone $GIT_URL "$GIT_BRANCH" $CLI_TOOLS_TARGET_DIR $GIT_REPO_NAME
  cd $CLI_TOOLS_TARGET_DIR/$NDCTL_REPO_NAME
  meson setup build
  meson compile -C build
  meson install -C build
  cd -
}

#install libcxlmi
libcxlmi_installer() {
  GIT_URL=$LIBCXLMI_GIT
  GIT_BRANCH=$LIBCXLMI_BRANCH
  GIT_REPO_NAME=$LIBCXLMI_REPO_NAME
  git_clone $GIT_URL "$GIT_BRANCH" $CLI_TOOLS_TARGET_DIR $GIT_REPO_NAME
  cd $CLI_TOOLS_TARGET_DIR/$LIBCXLMI_REPO_NAME
  meson setup -Dlibdbus=enabled -Dmctpd=codeconstruct --buildtype=debug build
  meson compile -C build
  meson install -C build
  cd -
}

#install mctp
mctp_installer() {
  GIT_URL=$MCTP_GIT
  GIT_BRANCH=$MCTP_BRANCH
  GIT_REPO_NAME=$MCTP_REPO_NAME
  git_clone $GIT_URL "$GIT_BRANCH" $CLI_TOOLS_TARGET_DIR $GIT_REPO_NAME
  cd $CLI_TOOLS_TARGET_DIR/$MCTP_REPO_NAME
  meson setup obj
  ninja -C obj
  meson install -C obj
  cp conf/mctpd-dbus.conf /etc/dbus-1/system.d/mctpd-dbus.conf
  cp conf/mctpd.conf /etc/mctpd.conf
  cp conf/mctp-local.target /etc/systemd/system/mctp-local.target
  cp conf/mctp.target /etc/systemd/system/mctp.target
  cp conf/mctpd.service /etc/systemd/system/mctpd.service
  ln -s /usr/local/bin/mctp /usr/bin/mctp
  ln -s /usr/local/bin/mctp-client /usr/bin/mctp-client
  ln -s /usr/local/sbin/mctpd /usr/sbin/mctpd
  systemctl daemon-reload
  systemctl enable mctpd.service
  systemctl start mctpd.service
  cd -
}

acpica_installer() {
  GIT_URL=$ACPICA_GIT
  GIT_BRANCH=$ACPICA_BRANCH
  GIT_REPO_NAME=$ACPICA_REPO_NAME
  git_clone $GIT_URL "$GIT_BRANCH" $CLI_TOOLS_TARGET_DIR $GIT_REPO_NAME
  cd $CLI_TOOLS_TARGET_DIR/$ACPICA_REPO_NAME
  make -j$(nproc)
  make install
  cd -
}

NDCTL_DOWNLOAD=false
LIBCXLMI_DOWNLOAD=false
MCTP_DOWNLOAD=false
ACPICA_DOWNLOAD=false

if [[ $# -eq 0 ]]; then
  PRINT_HELP=true
fi
while [[ $# -gt 0 ]]; do
    case "$1" in
	-h|--help)
	    PRINT_HELP=true
	    break
	    ;;
        -a)
            NDCTL_DOWNLOAD=true
            LIBCXLMI_DOWNLOAD=true
            MCTP_DOWNLOAD=true
            ACPICA_DOWNLOAD=true
            shift 1
	    ;;
        -n)
            NDCTL_DOWNLOAD=true
            shift 1
	    ;;
        -l)
            LIBCXLMI_DOWNLOAD=true
            shift 1
	    ;;
        -m)
            MCTP_DOWNLOAD=true
            shift 1
	    ;;
        -t)
            ACPICA_DOWNLOAD=true
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

$NDCTL_DOWNLOAD && ndctl_installer
$LIBCXLMI_DOWNLOAD && libcxlmi_installer
$MCTP_DOWNLOAD && mctp_installer
$ACPICA_DOWNLOAD && acpica_installer
