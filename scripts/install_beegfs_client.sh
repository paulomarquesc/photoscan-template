#!/bin/bash

set -xeuo pipefail

if [[ $(id -u) -ne 0 ]] ; then
    echo "Must be run as root"
    exit 1
fi

if [ $# -lt 2 ]; then
    echo "Usage: $0 <ManagementHost> <Mount> <homeNfsExportPath> <sharedNfsStorageHpcUserHomeFolder> <hpcuser> <hpcgroup>"
    exit 1
fi

SCRIPT_NAME=$0
MGMT_HOSTNAME=$1

# Share
SHARE_SCRATCH="/beegfs"
if [[ ! -z "${2:-}" ]]; then
	SHARE_SCRATCH=$2
fi

NFS_HOME_EXPORT="/mnt/beegfshome"
if [[ ! -z "${3:-}" ]]; then
	NFS_HOME_EXPORT="$3"
fi

SHARE_HOME="/mnt/beegfshome"
if [[ ! -z "${4:-}" ]]; then
	SHARE_HOME="$4"
fi

# User
HPC_USER="hpcuser"
if [[ ! -z "${5:-}" ]]; then
	HPC_USER="$5"
fi

HPC_GROUP="hpcgroup"
if [[ ! -z "${6:-}" ]]; then
	HPC_GROUP="${6}"
fi

BEEGFS_NODE_TYPE="client"

is_client()
{
	if [ "$BEEGFS_NODE_TYPE" == "client" ] || is_management ; then 
		return 0
	fi
	return 1
}

# Installs all required packages.
install_kernel_pkgs()
{
	HOST="buildlogs.centos.org"
	CENTOS_MAJOR_VERSION=$(cat /etc/centos-release | awk '{print $4}' | awk -F"." '{print $1}')
	CENTOS_MINOR_VERSION=$(cat /etc/centos-release | awk '{print $4}' | awk -F"." '{print $3}')
	KERNEL_LEVEL_URL="https://$HOST/c$CENTOS_MAJOR_VERSION.$CENTOS_MINOR_VERSION.u.x86_64/kernel"

	cd ~/
	wget -r -l 1 $KERNEL_LEVEL_URL
	
	RESULT=$(find . -name "*.html" -print | xargs grep `uname -r`)

	RELEASE_DATE=$(echo $RESULT | awk -F"/" '{print $5}')

	KERNEL_ROOT_URL="$KERNEL_LEVEL_URL/$RELEASE_DATE/`uname -r`"

	KERNEL_PACKAGES=()
	#KERNEL_PACKAGES+=("$KERNEL_ROOT_URL/kernel-`uname -r | sed 's/.x86_64*//'`.src.rpm")
	KERNEL_PACKAGES+=("$KERNEL_ROOT_URL/kernel-devel-`uname -r`.rpm")
	KERNEL_PACKAGES+=("$KERNEL_ROOT_URL/kernel-headers-`uname -r`.rpm")
	KERNEL_PACKAGES+=("$KERNEL_ROOT_URL/kernel-tools-libs-devel-`uname -r`.rpm")
	
	sudo yum install -y ${KERNEL_PACKAGES[@]}
}

install_pkgs()
{
    sudo yum -y install epel-release
	sudo yum -y install kernel-devel kernel-headers kernel-tools-libs-devel gcc gcc-c++
    sudo yum -y install zlib zlib-devel bzip2 bzip2-devel bzip2-libs openssl openssl-devel openssl-libs nfs-utils rpcbind mdadm wget python-pip openmpi openmpi-devel automake autoconf
	
	if [ ! -e "/usr/src/kernels/`uname -r`" ]; then
		echo "Kernel packages matching kernel version `uname -r` not installed. Executing alternate package install..."
		install_kernel_pkgs
	fi
}

install_beegfs_repo()
{
	sudo wget -O /etc/yum.repos.d/beegfs-rhel7.repo https://www.beegfs.io/release/beegfs_7_1/dists/beegfs_rhel7.repo
	sudo rpm --import https://www.beegfs.io/release/latest-stable/gpg/RPM-GPG-KEY-beegfs
}

install_beegfs()
{
	if is_client; then
	    if [ ! -e "$SHARE_SCRATCH" ]; then
            mkdir -p $SHARE_SCRATCH
        fi

		yum install -y beegfs-client beegfs-helperd beegfs-utils
		# setup client
		sed -i 's/^sysMgmtdHost.*/sysMgmtdHost = '$MGMT_HOSTNAME'/g' /etc/beegfs/beegfs-client.conf
		echo "$SHARE_SCRATCH /etc/beegfs/beegfs-client.conf" > /etc/beegfs/beegfs-mounts.conf
	
		systemctl daemon-reload
		systemctl enable beegfs-helperd.service
		systemctl enable beegfs-client.service
	fi
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

setup_user()
{
    if [ ! -e "$SHARE_HOME" ]; then
        sudo mkdir -p $SHARE_HOME
    fi

	echo "$MGMT_HOSTNAME:$NFS_HOME_EXPORT $SHARE_HOME    nfs4 defaults 0 0" >> /etc/fstab
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

SETUP_MARKER=/var/local/install_beegfs_client.marker
if [ -e "$SETUP_MARKER" ]; then
    echo "We're already configured, exiting..."
    exit 0
fi

systemctl stop firewalld
systemctl disable firewalld

# Disable SELinux
sed -i 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
setenforce 0 || true

# Disable tty requirement for sudo
sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

install_pkgs
tune_tcp
install_beegfs_repo
install_beegfs
download_lis
install_lis_in_cron
setup_user

# Create marker file so we know we're configured
sudo touch $SETUP_MARKER

shutdown -r +1 &

exit 0
