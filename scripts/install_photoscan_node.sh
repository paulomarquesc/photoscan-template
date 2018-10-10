#!/bin/bash

set -xeuo pipefail

if [[ $(id -u) -ne 0 ]] ; then
    echo "Must be run as root"
    exit 1
fi

if [ $# -lt 2 ]; then
    echo "Usage: $0 <ActivationCode> <DownloadPath> <Dispatch> <RootPath> <GpuMask> <InstallPath> <absolute paths (0,1)>"
    exit 1
fi

ACTIVATION_CODE="$1"

DOWNLOAD_PATH="http://download.agisoft.com/photoscan-pro_1_4_3_amd64.tar.gz"
if [[ ! -z "${2:-}" ]]; then
	DOWNLOAD_PATH="$2"
fi

DISPATCH="$3"
ROOT_PATH="$4"
GPU_MASK="$5"

INSTALL_PATH="/"
if [[ ! -z "${6:-}" ]]; then
	INSTALL_PATH="$6"
fi

ABSOLUTE_PATHS=0
if [[ ! -z "${7:-}" ]]; then
	ABSOLUTE_PATHS="$7"
fi

PHOTOSCAN_TAR_FILE_NAME=$(echo $DOWNLOAD_PATH | awk -F/ '{print $4}')

echo "Starting script with following values:"
echo "ACTIVATION_CODE..........: (removed due to sensitiviness)"
echo "DOWNLOAD_PATH............: $DOWNLOAD_PATH"
echo "DISPATCH.................: $DISPATCH"
echo "ROOT_PATH................: $ROOT_PATH"
echo "GPU_MASK.................: $GPU_MASK"
echo "INSTALL_PATH.............: $INSTALL_PATH"
echo "ABSOLUTE_PATHS...........: $ABSOLUTE_PATHS"
echo "PHOTOSCAN_TAR_FILE_NAME..: $PHOTOSCAN_TAR_FILE_NAME"


install_prereqs()
{
	sudo yum install -y mesa-libGL-devel mesa-libGLU-devel qt qt-creator xorg-x11-server-Xvfb
}

download_photoscan()
{
	if [ ! -e "$INSTALL_PATH" ]; then
		mkdir -p $INSTALL_PATH
	fi

	wget -O ./$PHOTOSCAN_TAR_FILE_NAME $DOWNLOAD_PATH
	tar -xvzf ./$PHOTOSCAN_TAR_FILE_NAME --directory $INSTALL_PATH
}

activate_photoscan()
{
	$INSTALL_PATH/photoscan-pro/photoscan.sh --activate $ACTIVATION_CODE
}

install_photoscan_node_script_in_cron()
{
	echo "install_photoscan_node_script_in_cron"
	! crontab -l > photoscan_cron
	echo "@reboot xvfb-run $INSTALL_PATH/photoscan-pro/photoscan.sh --node --dispatch $DISPATCH --root $ROOT_PATH --gpu_mask $GPU_MASK --timestamp --aboslute_paths $ABSOLUTE_PATHS >/var/log/photoscanlog.txt 2>&1" >> photoscan_cron
	crontab photoscan_cron
	rm photoscan_cron
}

start_photoscan()
{
	xvfb-run $INSTALL_PATH/photoscan-pro/photoscan.sh --node --dispatch $DISPATCH --root $ROOT_PATH --gpu_mask $GPU_MASK --timestamp --aboslute_paths $ABSOLUTE_PATHS >/var/log/photoscanlog.txt 2>&1 &
}

SETUP_MARKER=/var/local/install_photoscan_node.marker
if [ -e "$SETUP_MARKER" ]; then
    echo "We're already configured, exiting..."
    exit 0
fi

# Disable SELinux
sed -i 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
setenforce 0

# Disable tty requirement for sudo
sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

install_prereqs
download_photoscan
activate_photoscan
install_photoscan_node_script_in_cron
start_photoscan

# Create marker file so we know we're configured
sudo touch $SETUP_MARKER

exit 0
