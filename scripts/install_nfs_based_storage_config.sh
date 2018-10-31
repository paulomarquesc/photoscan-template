#!/bin/bash

set -xeuo pipefail

if [[ $(id -u) -ne 0 ]] ; then
    echo "Must be run as root"
    exit 1
fi

if [ $# -lt 2 ]; then
    echo "Usage: $0 <nfsHostName> <nfsScratchExportPath> <Mount> <homeNfsExportPath> <sharedNfsStorageHpcUserHomeFolder> <nfsScratchFolderNfsVersion> <nfsHomeFolderNfsVersion> <nfsScratchMountOptions> <HpcUser> <HpcGroup> <customDomain>"
    exit 1
fi

SCRIPT_NAME=$(echo $0 | sed 's/\.\///g')

# NFS Host A record
if [[ ! -z "${1:-}" ]]; then
	NFS_HOSTNAME=$1
else
	echo "You must supply NFS hostname"
	exit 1
fi

# Scratch export path
NFS_SCRATCH="/data"
if [[ ! -z "${2:-}" ]]; then
	NFS_SCRATCH=$2
fi

# Share
SHARE_SCRATCH="/mnt/vfxt-data"
if [[ ! -z "${3:-}" ]]; then
	SHARE_SCRATCH=$3
fi

NFS_HOME_EXPORT="/home"
if [[ ! -z "${4:-}" ]]; then
	NFS_HOME_EXPORT="$4"
fi

SHARE_HOME="/mnt/vfxt-home"
if [[ ! -z "${5:-}" ]]; then
	SHARE_HOME="$5"
fi

SCRATCH_NFS_VERSION="nfs"
if [[ ! -z "${6:-}" ]]; then
	SCRATCH_NFS_VERSION=$6
fi

HOME_NFS_VERSION="nfs"
if [[ ! -z "${7:-}" ]]; then
	HOME_NFS_VERSION=$7
fi

SCRATCH_MOUNT_OPTIONS="defaults"
if [[ ! -z "${8:-}" ]]; then
	SCRATCH_MOUNT_OPTIONS=$8
fi

# User
HPC_USER="hpcuser"
if [[ ! -z "${9:-}" ]]; then
	HPC_USER="$9"
fi

HPC_GROUP="hpcgroup"
if [[ ! -z "${10:-}" ]]; then
	HPC_GROUP="${10}"
fi

CUSTOMDOMAIN=""
if [[ ! -z "${11:-}" ]]; then
	CUSTOMDOMAIN="${11}"
fi

install_pkgs()
{
    sudo yum -y install epel-release
	sudo yum -y install kernel-devel kernel-headers kernel-tools-libs-devel gcc gcc-c++
    sudo yum -y install zlib zlib-devel bzip2 bzip2-devel bzip2-libs openssl openssl-devel openssl-libs nfs-utils rpcbind mdadm wget python-pip openmpi openmpi-devel automake autoconf
}

tune_tcp()
{
    echo "net.ipv4.neigh.default.gc_thresh1=1100" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv4.neigh.default.gc_thresh2=2200" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv4.neigh.default.gc_thresh3=4400" | sudo tee -a /etc/sysctl.conf
}

kill_hpcuser_process()
{
    ps -aux | grep "$HPC_USER" | grep -v "grep" | grep -v "$SCRIPT_NAME" | awk '{print $2}' | $(while read pid; do kill -9 $pid || true; done) || true
}

run_photoscan_process_from_cron()
{
	CMD=$(crontab -l | grep "photoscan" | grep -v '^#' | cut -f 6- -d ' ' | cut -c 9- | sed 's/\/\//\//g' | sed 's/\x27//g')
	sudo -H -u hpcuser bash -c "$CMD" &
}

setup_nfs_scracth_mount()
{

    if [ ! -e "$SHARE_SCRATCH" ]; then
        mkdir -p $SHARE_SCRATCH
    fi

	echo "$NFS_HOSTNAME:$NFS_SCRATCH     $SHARE_SCRATCH $SCRATCH_NFS_VERSION $SCRATCH_MOUNT_OPTIONS 0 0" >> /etc/fstab
	mount -a
	mount
   
  	chown $HPC_USER:$HPC_GROUP $SHARE_SCRATCH
}

setup_user()
{
    if [ ! -e "$SHARE_HOME" ]; then
        sudo mkdir -p $SHARE_HOME
    fi

	echo "$NFS_HOSTNAME:$NFS_HOME_EXPORT $SHARE_HOME    $HOME_NFS_VERSION defaults 0 0" >> /etc/fstab
	mount -a
	mount

	RND_SECONDS=$(( RANDOM % (120 - 30 + 1 ) + 30 ))
	echo "Sleeping $RND_SECONDS seconds before creating folders and ssh keys..."
	sleep $RND_SECONDS

    if [ ! -e "$SHARE_HOME/$HPC_USER" ]; then
		
		if [ ! -e "$SHARE_HOME/$HPC_USER/.ssh" ]; then
			sudo mkdir -p $SHARE_HOME/$HPC_USER/.ssh
		fi
		
		# Configure public key auth for the HPC user
		sudo ssh-keygen -t rsa -f $SHARE_HOME/$HPC_USER/.ssh/id_rsa -q -P ""
		cat $SHARE_HOME/$HPC_USER/.ssh/id_rsa.pub >> $SHARE_HOME/$HPC_USER/.ssh/authorized_keys

		echo "Host *" > $SHARE_HOME/$HPC_USER/.ssh/config
		echo "    StrictHostKeyChecking no" | sudo tee -a $SHARE_HOME/$HPC_USER/.ssh/config
		echo "    UserKnownHostsFile /dev/null" | sudo tee -a $SHARE_HOME/$HPC_USER/.ssh/config
		echo "    PasswordAuthentication no" | sudo tee -a $SHARE_HOME/$HPC_USER/.ssh/config

		# Fix .ssh folder ownership
		sudo chown -R $HPC_USER:$HPC_GROUP $SHARE_HOME/$HPC_USER

		# Fix permissions
		sudo chmod 700 $SHARE_HOME/$HPC_USER/.ssh
		sudo chmod 644 $SHARE_HOME/$HPC_USER/.ssh/config
		sudo chmod 644 $SHARE_HOME/$HPC_USER/.ssh/authorized_keys
		sudo chmod 600 $SHARE_HOME/$HPC_USER/.ssh/id_rsa
		sudo chmod 644 $SHARE_HOME/$HPC_USER/.ssh/id_rsa.pub
    fi

	echo "Killing any process that is executed by HPC User"
	kill_hpcuser_process

	echo "Change HPC User home folder to be from the shared storage"
	sudo usermod -d $SHARE_HOME/$HPC_USER $HPC_USER
	
	# Allow HPC_USER to reboot
    echo "%$HPC_GROUP ALL=NOPASSWD: /sbin/shutdown" | (EDITOR="tee -a" visudo)
    echo $HPC_USER | tee -a /etc/shutdown.allow
}


download_lis()
{
	wget -O /root/lis-rpms-4.2.6.tar.gz https://download.microsoft.com/download/6/8/F/68FE11B8-FAA4-4F8D-8C7D-74DA7F2CFC8C/lis-rpms-4.2.6.tar.gz
   	tar -xvzf /root/lis-rpms-4.2.6.tar.gz -C /root
}

install_lis_in_cron()
{
	cat >  /root/lis_install.sh << "EOF"
#!/bin/bash
SETUP_LIS=/root/lispackage.setup

if [ -e "$SETUP_LIS" ]; then
    #echo "We're already configured, exiting..."
    exit 0
fi
cd /root/LISISO
./install.sh
touch $SETUP_LIS
echo "End"
shutdown -r +1
EOF
	chmod 700 /root/lis_install.sh
	! crontab -l > LIScron
	echo "@reboot /root/lis_install.sh >>/root/log.txt" >> LIScron
	crontab LIScron
	rm LIScron
}

SETUP_MARKER=/var/local/install_nfs_based_storage.marker
if [ -e "$SETUP_MARKER" ]; then
    echo "We're already configured, exiting..."
    exit 0
fi

install_pkgs
tune_tcp
download_lis
install_lis_in_cron
setup_nfs_scracth_mount
setup_user

# Create marker file so we know we're configured
sudo touch $SETUP_MARKER

shutdown -r +1 &

exit 0
