ezscan-gowit.sh
---------

wrapper for output of ezscan and into gowitness for http screenshots

There is a comment in ezscan that you can uncomment and autorun this after getting hosts

just run it; downloads oct, 2023 gowitness binary ( was having issues with go download latest) and feeds it http hosts from ezscan

./ezscan-gowit.sh

![image](https://github.com/0x42eau/scripts/assets/49952735/6d980ffd-379e-438b-b384-b54c66f4e0e4)



ezscan.sh
---------

wrapper and parser from masscan, most common internal ports (heavily opnionated)

masscan is the only dependency for this to work

parses things like HTTP, FTP, WINRM, etc hosts into individual files. HTTP (80,443,8000,8080) will be in separate files AND into a file for gowitness

./ezscan.sh ip-list scan-rate
./ezscan.sh ips.txt 5000


![image](https://github.com/0x42eau/scripts/assets/49952735/fbe553ce-2a62-4f05-a984-89c4ba13c653)




spraygun.sh
-----------

(spraygun.py is a work in progress, but will be the same thing more or less)

Spraygun is a wrapper for netexec 
install here : https://www.netexec.wiki/getting-started/installation/installation-on-unix

--

sudo apt install pipx git

pipx ensurepath

pipx install git+https://github.com/Pennyw0rth/NetExec

--

netexec is the only dependency for this to work.

./spraygun.sh dc-ip users-file pass-file time-between-sprays passwords-per-spray
./spraygun.sh 10.10.10.10 users.txt passwords.txt 20 2

![image](https://github.com/0x42eau/scripts/assets/49952735/ce002d74-896c-4770-9f34-39dbcafe76a7)

external_scan.sh
-----------
Incorporates many o' tool for automated scanning. Built to be module to add functions and turn on/off features in the script.
Uses : dig, crtsh, nslookup, sublist3r, harvester, amass, goofuzz, masscan, unicornscan, naabu, nmap -F(ast), nmap -sV, gowitness, cloud_enum, nikto, and parsing for notes.
-d domain
-t targets file

