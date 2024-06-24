#!/bin/bash
#
# install brave from:
# https://brave.com/linux/
sudo apt install curl -y 
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list
sudo apt update
sudo apt install brave-browser -y

########################################################################

#make "brave" open vs brave-browser
echo "adding 'brave' to path"
me=$(whoami)
echo "" >> /home/$me/.bashrc
echo "export PATH=$PATH:/opt" >> /home/$me/.bashrc
sudo /bin/bash -c 'echo "#!/bin/bash" > /opt/brave '
sudo /bin/bach -c  'echo "brave-browser --no-sandbox &>/dev/null &" >> /opt/brave'
sudo chmod +x /opt/brave
#start brave
#brave
