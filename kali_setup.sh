#!/bin/bash

apt update && apt upgrade -y

# install vmware tools 
sudo apt-get install open-vm-tools -y


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
