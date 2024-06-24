#!/bin/bash

apt update && apt upgrade -y

# install vmware tools 
sudo apt-get install open-vm-tools git -y

# add vmware shared folders 
# MY ENV/PREFS ONLY
# Define the mount point
# checking for kali repos in /etc/apt/sources.list and adding if snot
echo '###################'
echo '[*] Adding sharefolder to /mnt/hgfs'
echo '###################'

MOUNT_POINT="/mnt/hgfs"

# Check if the mount point already exists
if mountpoint -q "$MOUNT_POINT"; then
    echo "$MOUNT_POINT is already mounted."
    exit 0
fi

# Try the first command
if /usr/bin/vmhgfs-fuse .host:/ $MOUNT_POINT -o subtype=vmhgfs-fuse,allow_other; then
    echo "Mounted using /usr/bin/vmhgfs-fuse .host:/ $MOUNT_POINT -o subtype=vmhgfs-fuse,allow_other"
    exit 0
fi

# Try the second command
if mount -t vmhgfs .host:F:/VMShared /mnt/vmshared; then
    echo "Mounted using mount -t vmhgfs .host:F:/VMShared /mnt/vmshared"
    exit 0
fi

# Try the third command
if /usr/bin/vmhgfs-fuse .host:F:/VMShared /mnt/vmshared -o subtype=vmhgfs-fuse,allow_other; then
    echo "Mounted using /usr/bin/vmhgfs-fuse .host:F:/VMShared /mnt/vmshared -o subtype=vmhgfs-fuse,allow_other"
    exit 0
fi

# Try the fourth command
if mount -t fuse.vmhgfs-fuse .host:/ $MOUNT_POINT -o allow_other; then
    echo "Mounted using mount -t fuse.vmhgfs-fuse .host:/ $MOUNT_POINT -o allow_other"
    exit 0
fi

# option "N" for new install, no make root login
echo '###################'
echo '[*] Downloading and running pimpmykali, for'
echo '###################'
git clone https://github.com/Dewalt-arch/pimpmykali.git /opt/pimpmykali
echo "N" | /opt/pimpmykali/pimpmykali.sh

echo '###################'
echo '[*] grabbing my scripts and putting into /opt'
echo '###################'
git clone https://github.com/0x42eau/scripts.git /opt/scripts

chmod +x /opt/scripts/*

echo '###################'
echo '[*] turning on logging'
echo '###################'
/opt/scripts/command_logging.sh

echo '###################'
echo '[*] mapping pi-hole for dns'
echo '###################'
/opt/scripts/add-pihole-nameserver.sh

echo '###################'
echo '[*] installing brave'
echo '###################'
/opt/scripts/install_brave.sh


echo '###################'
echo '[*] Running pimpmykali again to set up root account'
echo '###################'
sleep 5s
/opt/pimpmykali/pimpmykali.sh
