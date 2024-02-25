#!/bin/bash

# ./ezscan.sh ip/cidr scan-rate
# ./ezscan.sh 10.10.10.0/24 4000

masscan -p21,22,23,25,53,80,110,111,135-139,143,443,445,502,993,995,1433,1434,1723,3306,3389,5900,8000,8080 $1 --rate $@ -oB masscan.mass

masscan --open --readscan masscan.mass > masscan.grep

cat masscan.grep | cut -d " " -f 6 | sort -uV > online-hosts.txt

cat masscan.grep | grep -i '21/tcp' > ftp.hosts
cat masscan.grep | grep -i '22/tcp' > ssh.hosts
cat masscan.grep | grep -i '23/tcp' > telnet.hosts
cat masscan.grep | grep -i '25/tcp' > smtp.hosts
cat masscan.grep | grep -i '80/tcp' > http.hosts
cat masscan.grep | grep -i '443/tcp' > https.hosts
cat masscan.grep | grep -i '8000/tcp' > http-8000.hosts
cat masscan.grep | grep -i '8080/tcp' > http-8080.hosts
cat masscan.grep | grep -i '53/tcp' > dns.hosts
cat masscan.grep | grep -i '445/tcp' > smb.hosts
cat masscan.grep | grep -i '1433/tcp' > mssql.hosts
cat masscan.grep | grep -i '3306/tcp' > sql.hosts
cat masscan.grep | grep -i '3389/tcp' > rdp.hosts
cat masscan.grep | grep -i '5900/tcp' > vnc.hosts
cat masscan.grep | grep -i '502/tcp' > modbus.hosts
