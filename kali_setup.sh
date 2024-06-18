#!/bin/bash


# option "N" for new install, make root login
git clone https://github.com/Dewalt-arch/pimpmykali.git /opt
/opt/pimpmykali/pimpmykali.sh

git clone https://github.com/0x42eau/scripts.git /opt

chmod +x /opt/scripts/*

/opt/scripts/command_logging.sh
/opt/add-pihole-nameserver.sh
/opt/install_brave.sh
