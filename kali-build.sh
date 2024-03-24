#!/bin/bash

#set up script to fix kali with pimpmykali, auto put in root passwords and all the other stuff I like because I'm lazy and don't want to stare at this while it builds.
# going to add ghidra in a bit

#####
# NEEDS TO REFERENCE -- 'EXEPCT-PIMP.EXP' -- TO AUTO PIMPMYKALI ROOT ENABLE AND PASSWORD
# PASSWORD DEFAULTS TO TOOR, CHANGE THOSE LINES IF YOU WANT ANOTHER PASSWORD
#####

# Disable all suspend, hibernate, and sleep
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# enable auto-start for ssh service on boot
systemctl enable ssh.socket
systemctl start ssh.socket

#check internets
wget -q --spider http://google.com
if [ $? -eq 0 ]; then
    echo "Detected Internet connection."

	#add spraygun and masscan scripts
	git clone https://github.com/0x42eau/scripts.git /opt/scripts
	chmod +x /opt/scripts/*
	

	# used autoexpect to create script, long af, so use pimp to install/update everything.
	# after install, running expect script to just change root password and allow auto login. 
	# <hashtag> efficiency 
	git clone https://github.com/Dewalt-arch/pimpmykali.git /opt/pimpmykali
	cd /opt/pimpmykali
	yes n | /opt/pimpmykali/pimpmykali.sh
	
	cp /opt/scripts/expect-pimp.exp /opt/pimpmykali/expect-pimp.exp
	/opt/pimpmykali/expect-pimp.exp


	#installs from old script
	apt  install -y autossh ssh x11vnc html2text shutter libreoffice pdftk bettercap terminator

	
	#add pcredz for sniffs
	git clone https://github.com/lgandx/PCredz.git /opt/PCredz
	apt-get install libpcap-dev -y && pip3 install Cython && pip3 install python-libpcap
	

	
	#add manspider for share enum
	pipx install git+https://github.com/blacklanternsecurity/MANSPIDER

	
else
    echo "No Internet connection, skipping downloads."
	echo "FEED ME INTERNETS"
fi
