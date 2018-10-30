#!/bin/bash

set -xeuo pipefail

if [[ $(id -u) -ne 0 ]] ; then
    echo "Must be run as root"
    exit 1
fi

if [ $# -lt 2 ]; then
    echo "Usage: $0 <HpcUser> <HpcUID> <HpcGroup> <HpcGID> <customDomain>"
    exit 1
fi

# User
HPC_USER=hpcuser
if [[ ! -z "${1:-}" ]]; then
	HPC_USER="$1"
fi

HPC_UID=7007
if [[ ! -z "${2:-}" ]]; then
	HPC_UID=$2
fi

HPC_GROUP="hpcgroup"
if [[ ! -z "${3:-}" ]]; then
	HPC_GROUP="${3}"
fi

HPC_GID=7007
if [[ ! -z "${4:-}" ]]; then
	HPC_GID=${4}
fi

CUSTOMDOMAIN=""
if [[ ! -z "${5:-}" ]]; then
	CUSTOMDOMAIN="${5}"
fi


install_pkgs()
{
    sudo yum -y install epel-release
    sudo yum -y install nfs-utils
}

setup_user()
{
    groupadd -g $HPC_GID $HPC_GROUP

    # Don't require password for HPC user sudo
    echo "$HPC_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    
    # Disable tty requirement for sudo
    sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

	useradd -c "HPC User" -g $HPC_GROUP -s /bin/bash -u $HPC_UID $HPC_USER	    
	
	# Allow HPC_USER to reboot
    echo "%$HPC_GROUP ALL=NOPASSWD: /sbin/shutdown" | (EDITOR="tee -a" visudo)
    echo $HPC_USER | tee -a /etc/shutdown.allow

}

setup_domain()
{
    if [[ -n "$CUSTOMDOMAIN" ]]; then

		# surround domain names separated by comma with " after removing extra spaces
		QUOTEDDOMAIN=$(echo $CUSTOMDOMAIN | sed -e 's/ //g' -e 's/"//g' -e 's/^\|$/"/g' -e 's/,/","/g')
		echo $QUOTEDDOMAIN

		echo "supersede domain-search $QUOTEDDOMAIN;" >> /etc/dhcp/dhclient.conf
	fi
}

SETUP_MARKER=/var/local/setup_linux_common_user.marker
if [ -e "$SETUP_MARKER" ]; then
    echo "We're already configured, exiting..."
    exit 0
fi

systemctl stop firewalld
systemctl disable firewalld

# Disable SELinux
sed -i 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
setenforce 0

# Disable tty requirement for sudo
sed -i 's/^Defaults[ ]*requiretty/# Defaults requiretty/g' /etc/sudoers

install_pkgs
setup_user
setup_domain

# Create marker file so we know we're configured
sudo touch $SETUP_MARKER

exit 0
