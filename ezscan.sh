#!/bin/bash

# ./ezscan.sh scope.file scan-rate
# ./ezscan.sh scope.txt 4000

masscan -p21,22,23,25,53,80,110,111,135-139,143,443,445,502,993,995,1433,1434,1723,3306,3389,5900,8000,8080 -iL $1 --rate $2 -oB masscan.mass

masscan --open --readscan masscan.mass > masscan.grep

cat masscan.grep | awk -F " " '{print $6}' | sort -uV > online-hosts.txt

cat masscan.grep | grep -i '21/tcp' | awk -F " " '{print $6}' > ftp.hosts
cat masscan.grep | grep -i '22/tcp' | awk -F " " '{print $6}' > ssh.hosts
cat masscan.grep | grep -i '23/tcp' | awk -F " " '{print $6}' > telnet.hosts
cat masscan.grep | grep -i '25/tcp' | awk -F " " '{print $6}' > smtp.hosts
cat masscan.grep | grep -i '80/tcp' | awk -F " " '{print $6}' > http.hosts
cat masscan.grep | grep -i '443/tcp' | awk -F " " '{print $6}' > https.hosts
cat masscan.grep | grep -i '8000/tcp' | awk -F " " '{print $6}' > http-8000.hosts
cat masscan.grep | grep -i '8080/tcp' | awk -F " " '{print $6}' > http-8080.hosts
cat masscan.grep | grep -i '53/tcp' | awk -F " " '{print $6}' > dns.hosts
cat masscan.grep | grep -i '445/tcp' | awk -F " " '{print $6}' > smb.hosts
cat masscan.grep | grep -i '1433/tcp' | awk -F " " '{print $6}' > mssql.hosts
cat masscan.grep | grep -i '3306/tcp' | awk -F " " '{print $6}' > sql.hosts
cat masscan.grep | grep -i '3389/tcp' | awk -F " " '{print $6}' > rdp.hosts
cat masscan.grep | grep -i '5900/tcp' | awk -F " " '{print $6}' > vnc.hosts
cat masscan.grep | grep -i '502/tcp' | awk -F " " '{print $6}' > modbus.hosts
