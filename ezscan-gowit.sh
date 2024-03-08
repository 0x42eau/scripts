#!/bin/bash

# needs go and chromium
#parsing ezscan HTTP hosts into a file for gowit

apt update
apt install -y golang-go
apt install -y chromium

wget https://github.com/sensepost/gowitness/releases/download/2.5.1/gowitness-2.5.1-linux-amd64


echo "using file: gowit.hosts from ezscan"
echo ""
sleep 2
date
echo ""
./gowitness-2.5.1-linux-amd64 file -f gowit.hosts 

echo "done"
echo ""
echo "starting server"
echo ""
sleep 5
./gowitness-2.5.1-linux-amd64 server
