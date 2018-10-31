#!/bin/bash

set -xeuo pipefail

if [[ $(id -u) -ne 0 ]] ; then
    echo "Must be run as root"
    exit 1
fi

if [ $# -lt 2 ]; then
    echo "Usage: $0 <ActivationCode> <DownloadPath> <Dispatch> <RootPath> <GpuMask> <InstallPath> <absolute paths (0,1)> <hpcUser> <hpcGroup> "
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

# User
HPC_USER="hpcuser"
if [[ ! -z "${8:-}" ]]; then
	HPC_USER="$8"
fi

HPC_GROUP="hpcgroup"
if [[ ! -z "${9:-}" ]]; then
	HPC_GROUP="${9}"
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
echo "HPC_USER..: $HPC_USER"
echo "HPC_GROUP..: $HPC_GROUP"

if [ $INSTALL_PATH = "/" ]; then
	PHOTOSCAN_FOLDER="/photoscan-pro"
else
	PHOTOSCAN_FOLDER="$INSTALL_PATH/photoscan-pro"
fi

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

	chmod 775 -R $PHOTOSCAN_FOLDER
	chown -R $HPC_USER:$HPC_GROUP $PHOTOSCAN_FOLDER
}

activate_photoscan()
{
	sudo -H -u $HPC_USER bash -c "$PHOTOSCAN_FOLDER/photoscan.sh --activate $ACTIVATION_CODE"
}

install_photoscan_node_script_in_cron()
{
	echo "install_photoscan_node_script_in_cron"
	! crontab -l > photoscan_cron
	echo "@reboot sudo -H -u $HPC_USER bash -c 'xvfb-run $PHOTOSCAN_FOLDER/photoscan.sh --node --dispatch $DISPATCH --root $ROOT_PATH --gpu_mask $GPU_MASK --timestamp --absolute_paths $ABSOLUTE_PATHS'" >> photoscan_cron
	crontab photoscan_cron
	rm photoscan_cron
}

start_photoscan()
{
	sudo -H -u $HPC_USER bash -c "xvfb-run $PHOTOSCAN_FOLDER/photoscan.sh --node --dispatch $DISPATCH --root $ROOT_PATH --gpu_mask $GPU_MASK --timestamp --absolute_paths $ABSOLUTE_PATHS" &
}

SETUP_MARKER=/var/local/install_photoscan_node.marker
if [ -e "$SETUP_MARKER" ]; then
    echo "We're already configured, exiting..."
    exit 0
fi

# Disable SELinux
sed -i 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
! setenforce 0

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
