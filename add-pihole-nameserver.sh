#!/bin/bash
#
#
cp /etc/resolv.conf /etc/resolv.conf.bak
sed -i '0,/nameserver/s//nameserver 192.168.1.100\n&/' /etc/resolv.conf
