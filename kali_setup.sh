#!/bin/bash


# install vmware tools 
sudo apt-get update
sudo apt-get install open-vm-tools open-vm-tools-desktop -y


# checking for kali repos in /etc/apt/sources.list and adding if snot
echo '###################'
echo '[*] Adding Kali to non-kali machines'
echo '###################'

# Check if Kali repository is already in the sources.list
nokali=$(ls /etc/apt/sources.list.d/ | grep -i kali)

if [ -z "$nokali" ]; then
    echo "Adding Kali repositories..."
    
    # Download and add the Kali archive key
    wget -q https://archive.kali.org/archive-key.asc -O /etc/apt/trusted.gpg.d/archive-key.asc
    if [ $? -ne 0 ]; then
        echo "Failed to download Kali archive key"
        exit 1
    fi
    
    apt-key add /etc/apt/trusted.gpg.d/archive-key.asc
    if [ $? -ne 0 ]; then
        echo "Failed to add Kali archive key"
        exit 1
    fi

    # Add Kali repository to sources.list.d
    echo 'deb https://http.kali.org/kali kali-rolling main non-free contrib' | tee /etc/apt/sources.list.d/kali.list > /dev/null
    if [ $? -ne 0 ]; then
        echo "Failed to add Kali repository to sources.list.d"
        exit 1
    fi

    # Update package lists
    apt update
    if [ $? -ne 0 ]; then
        echo "Failed to update package lists"
        exit 1
    fi

    echo "Kali repositories added and package lists updated."
else
    echo "Kali repos already installed"
fi



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

# If all commands fail
echo "Failed to mount $MOUNT_POINT using any of the provided commands."
exit 1




# option "N" for new install, no make root login
echo '###################'
echo '[*] Downloading and running pimpmykali, for'
echo '###################'
git clone https://github.com/Dewalt-arch/pimpmykali.git /opt
echo "N" | /opt/pimpmykali/pimpmykali.sh

echo '###################'
echo '[*] grabbing my scripts and putting into /opt'
echo '###################'
git clone https://github.com/0x42eau/scripts.git /opt

chmod +x /opt/scripts/*

echo '###################'
echo '[*] turning on logging'
echo '###################'
/opt/scripts/command_logging.sh

echo '###################'
echo '[*] mapping pi-hole for dns'
echo '###################'
/opt/add-pihole-nameserver.sh

echo '###################'
echo '[*] installing brave'
echo '###################'
/opt/install_brave.sh


echo '###################'
echo '[*] Running pimpmykali again to set up root account'
echo '###################'
sleep 5s
/opt/pimpmykali/pimpmykali.sh
