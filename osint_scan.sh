#!/bin/bash

########################
#USAGE
# -d | -- domain
# -t | -- IP targets-file FULL PATH

########################

# Initialize variables with default values
domain=""
ips_file=""


# Parse command line arguments
#
if [ $# -eq 0 ]; then
		echo "###########"
        echo "usage: "
        echo "-d | --domain"
        echo "-t | --targets-file"
		echo "FULL PATH FOR TARGETS FILE, e.g. /opt/osint_scan/ips.txt"

fi

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -d|--domain) domain="$2"; shift ;;
        -t|--targets-ips-file) ips_file="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Check if the IPs file is provided
if [ -z "$ips_file" ]; then
    echo "Please provide a file containing the list of IPs."
    exit 1
fi

# Use the provided arguments
echo "Domain: $domain"
echo "IPs file: $ips_file"
echo "Dumping all stuffs into /opt/osint_scan/"

sleep 3s

########################
#make dirs
########################
mkdir /opt/osint_scan/
cd /opt/osint_scan/
mkdir scans dns-stuff logs_and_data formatted_notes formatted_notes/goofuzz-docs
cd /opt/osint_scan/scans/
mkdir masscan nmap unicorn naabu gowitness cloud_enum nikto goofuzz goofuzz/docs
cd /opt/osint_scan/dns-stuff
mkdir amass harvester crtsh sublist3r dig nslookup
cd /opt/osint_scan/
sleep 2s

########################
#update and install
########################
apt update && apt upgrade -y

apt install -y theharvester amass libpcap-dev naabu unicornscan sublist3r chromium golang-go

#gowit depends
wget https://github.com/sensepost/gowitness/releases/download/2.5.1/gowitness-2.5.1-linux-amd64 -O /opt/osint_scan/scans/gowitness/gowitness-2.5.1-linux-amd64 
sleep 5s #sleeping because chmod too farsht
chmod +x /opt/osint_scan/scans/gowitness/gowitness-2.5.1-linux-amd64

# goofuzz
git clone https://github.com/m3n0sd0n4ld/GooFuzz.git /opt/osint_scan/scans/goofuzz
chmod +x /opt/osint_scan/scans/goofuzz/GooFuzz

#naabu
apt install -y libpcap-dev
#go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest
apt install naabu

#cloud_enum
git clone https://github.com/initstring/cloud_enum.git /opt/osint_scan/scans/cloud_enum
pip3 install -r /opt/osint_scan/scans/cloud_enum/requirements.txt


#trufflehog
curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b /usr/local/bin

echo ""
echo ""
echo '*********************************'
echo ""
echo ""
echo "Done installing everything"
echo "Let's get this bread"
echo ""
echo ""
echo '*********************************'
echo ""
echo ""
sleep 2s

########################
#logger
# making a all.log file to keep date/time and commands
########################
logger()
{
echo ""
echo ""
echo '*********************************'
echo ""
echo ""
echo "STARTING $1" | tee -a /opt/osint_scan/logs_and_data/all.log
date | tee -a /opt/osint_scan/logs_and_data/all.log
echo ""
echo ""
echo '*********************************'
echo ""
echo ""
# add spacing to log file for readability
echo "" >> /opt/osint_scan/logs_and_data/all.log
echo "===========================" >> /opt/osint_scan/logs_and_data/all.log
echo "" >> /opt/osint_scan/logs_and_data/all.log

sleep 5s
"$1"

}

########################
#masscan
# --ttl  | time to live
# -p  | ports / U:udp
# --rate  | how fast in bytes
# -iL  | import file
# -oB  | output file in masscan binary
########################
masscan_scan()
{
echo 'masscan --ttl 62 -p1-65535,U:1-65535 --rate 2000 -iL $ips_file -oB /opt/osint_scan/scans/masscan/masscan.mass' | tee -a /opt/osint_scan/logs_and_data/all.log
masscan --ttl 62 -p1-65535,U:1-65535 --rate 2000 -iL $ips_file -oB /opt/osint_scan/scans/masscan/masscan.mass
masscan --readscan /opt/osint_scan/scans/masscan/masscan.mass > /opt/osint_scan/scans/masscan/masscan.grep

cat /opt/osint_scan/scans/masscan/masscan.grep | awk -F " " '{print $6}' | sort -uV > /opt/osint_scan/scans/masscan/online-hosts.txt

cat /opt/osint_scan/scans/masscan/masscan.grep | grep -i '21/tcp' | awk -F " " '{print $6}' > /opt/osint_scan/scans/masscan/ftp.hosts
cat /opt/osint_scan/scans/masscan/masscan.grep | grep -i '22/tcp' | awk -F " " '{print $6}' > /opt/osint_scan/scans/masscan/ssh.hosts
cat /opt/osint_scan/scans/masscan/masscan.grep | grep -i '23/tcp' | awk -F " " '{print $6}' > /opt/osint_scan/scans/masscan/telnet.hosts
cat /opt/osint_scan/scans/masscan/masscan.grep | grep -i '25/tcp' | awk -F " " '{print $6}' > /opt/osint_scan/scans/masscan/smtp.hosts
cat /opt/osint_scan/scans/masscan/masscan.grep | grep -i '80/tcp' | awk -F " " '{print $6}' > /opt/osint_scan/scans/masscan/http.hosts
cat /opt/osint_scan/scans/masscan/masscan.grep | grep -i '88/tcp' | awk -F " " '{print $6}' > /opt/osint_scan/scans/masscan/kerberos.hosts
cat /opt/osint_scan/scans/masscan/masscan.grep | grep -i '443/tcp' | awk -F " " '{print $6}' > /opt/osint_scan/scans/masscan/https.hosts
cat /opt/osint_scan/scans/masscan/masscan.grep | grep -iE '389/tcp|636/tcp' | awk -F " " '{print $6}' > /opt/osint_scan/scans/masscan/ldap.hosts
cat /opt/osint_scan/scans/masscan/masscan.grep | grep -i '8000/tcp' | awk -F " " '{print $6}' > /opt/osint_scan/scans/masscan/http-8000.hosts
cat /opt/osint_scan/scans/masscan/masscan.grep | grep -i '8080/tcp' | awk -F " " '{print $6}' > /opt/osint_scan/scans/masscan/http-8080.hosts
cat /opt/osint_scan/scans/masscan/masscan.grep | grep -i '8443/tcp' | awk -F " " '{print $6}' > /opt/osint_scan/scans/masscan/http-8443.hosts
cat /opt/osint_scan/scans/masscan/masscan.grep | grep -i '53/tcp' | awk -F " " '{print $6}' > /opt/osint_scan/scans/masscan/dns.hosts
cat /opt/osint_scan/scans/masscan/masscan.grep | grep -i '445/tcp' | awk -F " " '{print $6}' > /opt/osint_scan/scans/masscan/smb.hosts
cat /opt/osint_scan/scans/masscan/masscan.grep | grep -i '1433/tcp' | awk -F " " '{print $6}' > /opt/osint_scan/scans/masscan/mssql.hosts
cat /opt/osint_scan/scans/masscan/masscan.grep | grep -i '3306/tcp' | awk -F " " '{print $6}' > /opt/osint_scan/scans/masscan/sql.hosts
cat /opt/osint_scan/scans/masscan/masscan.grep | grep -i '3389/tcp' | awk -F " " '{print $6}' > /opt/osint_scan/scans/masscan/rdp.hosts
cat /opt/osint_scan/scans/masscan/masscan.grep | grep -i '5900/tcp' | awk -F " " '{print $6}' > /opt/osint_scan/scans/masscan/vnc.hosts
cat /opt/osint_scan/scans/masscan/masscan.grep | grep -iE '5985/tcp|5986/tcp' | awk -F " " '{print $6}' > /opt/osint_scan/scans/masscan/winrm.hosts
cat /opt/osint_scan/scans/masscan/masscan.grep | grep -i '502/tcp' | awk -F " " '{print $6}' > /opt/osint_scan/scans/masscan/modbus.hosts

#add UDP hosts

# for nmaps
cat /opt/osint_scan/scans/masscan/masscan.grep | awk -F " " '{print $4}' | awk -F "/" '{print $1}' | sort -u > /opt/osint_scan/scans/masscan/masscan.ports

#for gowitness script
cat /opt/osint_scan/scans/masscan/http.hosts > /opt/osint_scan/scans/gowitness/gowit.hosts
cat /opt/osint_scan/scans/masscan/https.hosts >> /opt/osint_scan/scans/gowitness/gowit.hosts
cat /opt/osint_scan/scans/masscan/http-8000.hosts | sed 's/$/:8000/g' >> /opt/osint_scan/scans/gowitness/gowit.hosts
cat /opt/osint_scan/scans/masscan/http-8080.hosts | sed 's/$/:8080/g' >> /opt/osint_scan/scans/gowitness/gowit.hosts
}


########################
#unicorn scan
# -r  | packets per second
# -m  | T tcp scan
# -v  | verbose
# -I  | immediate mode, displays results as found. Doesn't work with logging??
# ip:a  | all ports, can also use range 1-65535
# -l  | out log file
########################
unicorn_scan()
{
echo 'for i in $(cat $ips_file); do echo "scanning $i" && unicornscan -mT -v -Ir 1000 $i:a -l /opt/osint_scan/scans/unicorn/portscan-$i; done' | tee -a /opt/osint_scan/logs_and_data/all.log
for i in $(cat $ips_file); do echo "scanning $i" && unicornscan -mT -v -Ir 1000 $i:a -l /opt/osint_scan/scans/unicorn/portscan-$i; done
cat /opt/osint_scan/scans/unicorn/portscan* | grep -i open | awk -F " " '{print $3}' | awk -F ":" '{print $2}' | sed -e '/^$/d' | sort -u > /opt/osint_scan/scans/unicorn/unicorn.ports
}

########################
#naabu
#https://github.com/projectdiscovery/naabu
# -p  | - all ports, takes it like nmap for range
# -l  | ip file list
# -v  | -v verbose
# -o  | output file
########################
naabu_scan()
{
echo 'naabu -p - -l $ips_file -v -o /opt/osint_scan/scans/naabu/naabu.ips.scan' | tee -a /opt/osint_scan/logs_and_data/all.log
naabu -p - -l $ips_file -v -o /opt/osint_scan/scans/naabu/naabu.ips.scan
cat /opt/osint_scan/scans/naabu/naabu.ips.scan | awk -F ":" '{print $2}' | sort -u > /opt/osint_scan/scans/naabu/naabu.ports
#cat /opt/osint_scan/scans/naabu/naabu.domain.scan | awk -F ":" '{print $2}' | sort -u >> /opt/osint_scan/scans/naabu/naabu.ports
}


########################
#nmap-fast
# -F  | fast mode, top 1k ports
# -sV  | versions-scans
# -Pn  | disable ping scan, assume host is update
# -n  | don't resolve ips to hosts
# -T  | 1-5 speed, 2 is kinda slow but we not doing much
# -f  | fragment packets
# --data-length  | add data to potentially bypass
# --randomize-hosts  | does what is says
# --ttl  | tries some bypass
# -iL  | input file
# -oA  | output files
########################
nmap_fast()
{
echo 'nmap -F -sV -Pn -n -T2 -f --data-length 12 --randomize-hosts --ttl 57 --stats-every 60s -iL $ips_file -oA /opt/osint_scan/scans/nmap/fast-nmap' | tee -a /opt/osint_scan/logs_and_data/all.log
nmap -F -sV -Pn -n -T2 -f --data-length 12 --randomize-hosts --ttl 57 --stats-every 60s -iL $ips_file -oA /opt/osint_scan/scans/nmap/fast-nmap
#cat /opt/osint_scan/scans/nmap/fast-nmap.gnmap 
}

########################
#nmap-version
#ports.txt needs to be comma separated
# -p  | ports  -- current command cats out ports in line
# -sC  | default scripts
# -sV  | versions-scans
# -vv  | verbose verbose
# -iL  | input file
# -oA  | output files
# puts ports into tmp file, then replaces \r\n with , for nmaps
########################
nmap_version_scan()
{
echo 'nmap -p$(cat /opt/osint_scan/scans/nmap/ports_for_version_scan.txt) -sV -sC -vv --stats-every 60s -iL $ips_file -oA /opt/osint_scan/scans/nmap/nmap-versions-scans --source-port 53' | tee -a /opt/osint_scan/logs_and_data/all.log
cat /opt/osint_scan/scans/nmap/fast-nmap.xml | grep -i portid | awk -F " " '{print $3}' | awk -F '"' '{print $2}' | sort -u >> /opt/osint_scan/scans/nmap/ports_for_version_scan.tmp
cat /opt/osint_scan/scans/masscan/masscan.ports >> /opt/osint_scan/scans/nmap/ports_for_version_scan.tmp
cat /opt/osint_scan/scans/unicorn/unicorn.ports  >> /opt/osint_scan/scans/nmap/ports_for_version_scan.tmp
cat /opt/osint_scan/scans/naabu/naabu.ports >> /opt/osint_scan/scans/nmap/ports_for_version_scan.tmp
sort -u /opt/osint_scan/scans/nmap/ports_for_version_scan.tmp | tr -d '\r' | tr '\n' ',' > /opt/osint_scan/scans/nmap/ports_for_version_scan.txt
nmap -p$(cat /opt/osint_scan/scans/nmap/ports_for_version_scan.txt) -sV -sC -vv --stats-every 60s -iL $ips_file -oA /opt/osint_scan/scans/nmap/nmap-versions-scans --source-port 53
}



########################
#gowit
# https://github.com/sensepost/gowitness
# file mode to input files
# -f  | input files
########################
gowit_scan()
{
echo '/opt/osint_scan/scans/gowitness/gowitness-2.5.1-linux-amd64 file -f /opt/osint_scan/scans/gowitness/gowit.hosts -P /opt/osint_scan/scans/gowitness/screenshots' | tee -a /opt/osint_scan/logs_and_data/all.log

/opt/osint_scan/scans/gowitness/gowitness-2.5.1-linux-amd64 file -f /opt/osint_scan/scans/gowitness/gowit.hosts -P /opt/osint_scan/scans/gowitness/screenshots

/opt/osint_scan/scans/gowitness/gowitness-2.5.1-linux-amd64 server & 
echo "gowitness server is on localhost:7171"
}

########################
#harvester
# -d  | domain
# -b  | all source scans
########################
harvester_scan()
{
echo 'theHarvester -d $domain -b all | tee -a /opt/osint_scan/dns-stuff/harvester/harvester.log' | tee -a /opt/osint_scan/logs_and_data/all.log
theHarvester -d $domain -b all | tee -a /opt/osint_scan/dns-stuff/harvester/harvester.log
cat /opt/osint_scan/dns-stuff/harvester/harvester.log | grep -iE ":[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" | sed -e 's/:/ : /g' > /opt/osint_scan/dns-stuff/harvester/harvester.parsed
# needs to be checked against $scope
}


########################
#amass
# enum module
# -r  | resolution hosts
# -d  | domain
# -v  | verbose
# -nocolor  | no color
# -o  | output file
# added timeout for 5mins because amass kept fucking hanging
# pushed amass to background and looped PID check to kill it after 5 mins
########################
amass_scan()
{
echo 'amass enum -d $domain -v -nocolor -norecursive -o /opt/osint_scan/dns-stuff/amass/amass.log  &' | tee -a /opt/osint_scan/logs_and_data/all.log
#amass command and pid for fixing hang
amass enum -d $domain -v -nocolor -norecursive -o /opt/osint_scan/dns-stuff/amass/amass.log  &
amass_pid=$!

# set timeout for amass execution (5 mins here)
timeout 300s tail --pid=$amass_pid -f /dev/null

#check if amass is still running
if ps -p $amass_pid > /dev/null; then
	kill $amass_pid
	echo "Amass timed out and was murdered"
fi
cat /opt/osint_scan/dns-stuff/amass/amass.log | grep -i ipaddress --color=never | grep -iv netblock --color=never | awk -F "-->" '{print $1,$3}' | sed -e 's/(FQDN)//g' | awk '{ print $1 " : " $5 }' > /opt/osint_scan/dns-stuff/amass/amass.parsed
}

########################
#sublist3r
# -n  | no color
# -d  | domain
########################
sublist3r_scan()
{
echo 'sublist3r -n -d $domain | tee -a /opt/osint_scan/dns-stuff/sublist3r/sublist3r.log' | tee -a /opt/osint_scan/logs_and_data/all.log
sublist3r -n -d $domain | tee -a /opt/osint_scan/dns-stuff/sublist3r/sublist3r.log
cat /opt/osint_scan/dns-stuff/sublist3r/sublist3r.log | sort -u > /opt/osint_scan/dns-stuff/sublist3r/sublist3r.parsed
}

########################
#crt.sh
#https://crt.sh/
# curl crtsh for specified domain, parses for subdomains
# curl -s https://crt.sh/\?q\=inlanefreight.com\&output\=json | jq -r '.[] | [.common_name] + (.name_value | split("\n")) | .[]' | sort -u
########################
crt_sh_scan()
{
echo 'curl https://crt.sh/?q="$domain" | tee /opt/osint_scan/dns-stuff/crtsh/crt-sh.log' | tee -a /opt/osint_scan/logs_and_data/all.log
curl https://crt.sh/?q="$domain" | tee /opt/osint_scan/dns-stuff/crtsh/crt-sh.log
grep -ai $domain /opt/osint_scan/dns-stuff/crtsh/crt-sh.log | sed 's/<TD>//g' | sed 's/<\/TD>//g' | sed 's/<BR>/\r\n/g' | grep -ivE 'href|search|title' | sed 's/^ *//g' | sort -u > /opt/osint_scan/dns-stuff/crtsh/crtsh.domains
grep -ai $domain /opt/osint_scan/dns-stuff/crtsh/crt-sh.log | sed 's/<TD>//g' | sed 's/<\/TD>//g' | sed 's/<BR>/\r\n/g' | grep -ivE 'href|search|title' | sed 's/^ *//g' | sed "s/.$domain//g" | sort -u > /opt/osint_scan/dns-stuff/crtsh/crtsh.subdomains
}

########################
#dig
########################

dig_scan()
{
echo 'dig $domain | tee -a dig.log' | tee -a /opt/osint_scan/logs_and_data/all.log
dig $domain | tee -a /opt/osint_scan/dns-stuff/dig/dig.log
cat /opt/osint_scan/dns-stuff/dig/dig.log | grep -i $domain | grep -iv ';' | awk -F " " '{print $1,$4,$5}' | sed 's/ A / : /g' > /opt/osint_scan/dns-stuff/dig/dig.parsed
}

########################
#nslookup
########################
nslookup_scan()
{
echo 'nslookup $domain > /opt/osint_scan/dns-stuff/nslookup/nslookup.log' | tee -a /opt/osint_scan/logs_and_data/all.log
nslookup $domain | tee -a /opt/osint_scan/dns-stuff/nslookup/nslookup.log
for i in $(cat /opt/osint_scan/dns-stuff/crtsh/crtsh.domains); do nslookup $i | tee -a /opt/osint_scan/dns-stuff/nslookup/nslookup-crtsh.domains; done
# maybe add amass and harvester? all have been encompassed via crtsh, double check
cat nslookup-crtsh.domains | grep -iE 'name|address' | grep -iv '#53'| sed ':a;N;$!ba;s/\nAddress: / : /g' | sed 's/Name:[[:space:]]*//' > /opt/osint_scan/dns-stuff/nslookup/nslookup.parsed
}

########################
#cloud_enum
#https://github.com/initstring/cloud_enum
# -k  | keywork, can be multiple (good for domain.com)
# -l  | log output file
########################
cloud_enum_scan()
{
echo 'python3 /opt/osint_scan/scans/cloud_enum/cloud_enum.py -k $domain -l /opt/osint_scan/scans/cloud_enum/cloud_enum.log' | tee -a /opt/osint_scan/logs_and_data/all.log
python3 /opt/osint_scan/scans/cloud_enum/cloud_enum.py -k $domain -l /opt/osint_scan/scans/cloud_enum/cloud_enum.log
}



########################
#goofuzz
# https://github.com/m3n0sd0n4ld/GooFuzz
# just goofuzzing for docs
# downloads docs and copies to log folder
#
########################
goofuzz_scan()
{
echo '/opt/osint_scan/scans/goofuzz/GooFuzz -t $domain -e pdf,doc,bak,txt,xls,ppt,config,bk,old,git -o /opt/osint_scan/scans/goofuzz/goofuzz.results' | tee -a /opt/osint_scan/logs_and_data/all.log
/opt/osint_scan/scans/goofuzz/GooFuzz -t $domain -e pdf,doc,bak,txt,xls,ppt,config,bk,old,git -o /opt/osint_scan/scans/goofuzz/goofuzz.results
for i in $(cat /opt/osint_scan/scans/goofuzz/goofuzz.results); do wget $i -O /opt/osint_scan/scans/goofuzz/docs/$i; done
}


########################
#nikto
########################
nikto_scan()
{
echo 'nikto -host $domain -followredirects -p 80 | tee -a /opt/osint_scan/scans/nikto/nikto-80.log' | tee -a /opt/osint_scan/logs_and_data/all.log
nikto -host $domain -followredirects -p 80 | tee -a /opt/osint_scan/scans/nikto/nikto-80.log
echo 'nikto -host $domain -followredirects -p 443 | tee -a /opt/osint_scan/scans/nikto/nikto-443.log' | tee -a /opt/osint_scan/logs_and_data/all.log
nikto -host $domain -followredirects -p 443 | tee -a /opt/osint_scan/scans/nikto/nikto-443.log
}

########################
# uses trufflehog to hunt for CI/CD creds
# https://github.com/trufflesecurity/trufflehog

########################
trufflehog_scan()
{
echo 'trufflehog github --org=$truffle_domain --only-verified' | tee -a /opt/osint_scan/logs_and_data/all.log
truffle_domain=`$domain | awk -F '.' '{print $1}'`
trufflehog github --org=$truffle_domain --only-verified
echo ""
sleep 4s
echo ""
echo "this ran with $truffle_domain, consider more OSINT to find org dev pipelines and rerun with -- trufflehog githup --org=orgname_in_github --only-verified"
}

########################
#parse me for like one of your french girls
# essentially pulls all the parse logs for one note
# also pulls ports/versions to copy and paste
########################
one_note()
{
#find /opt/osint_scan/ -type f -name "*.parsed" > /opt/osint_scan/formatted_notes/parsed.files  << testing for lazy format
cp /opt/osint_scan/dns-stuff/harvester/harvester.parsed /opt/osint_scan/formatted_notes/harvester.txt
cp /opt/osint_scan/dns-stuff/nslookup/nslookup.parsed /opt/osint_scan/formatted_notes/nslookup.txt
cp /opt/osint_scan/dns-stuff/dig/dig.parsed  /opt/osint_scan/formatted_notes/dig.txt
cp /opt/osint_scan/scans/nmap/nmap-versions-scans.nmap /opt/osint_scan/formatted_notes/nmap-version.txt
cp /opt/osint_scan/scans/goofuzz/docs/* /opt/osint_scan/formatted_notes/goofuzz-docs
}

########################
# actual running code
# logger is used to send all commands, with date for accountability to a log file.
# comment things out to "turn off" the function you don't want. e.g. turn off nikto = #logger nikto_scan
########################
logger dig_scan
logger crt_sh_scan
logger nslookup_scan
logger sublist3r_scan
sleep 10s # too fast
logger harvester_scan
sleep 10s # too fast
logger goofuzz_scan
logger masscan_scan
logger unicorn_scan
logger naabu_scan
logger nmap_fast
logger nmap_version_scan
logger gowit_scan
logger cloud_enum_scan
logger truffle_scan
#logger nikto_scan #kept hanging 
logger amass_scan # moved this dipshit down here so it doesn't break everything
logger one_note

echo "all donesies :)"
echo "gowitness server is on localhost:7171"



## add trufflehog
