#!/bin/bash
#
# install brave from:
# https://brave.com/linux/
sudo apt install curl
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list
sudo apt update
sudo apt install brave-browser

########################################################################

#make "brave" open vs brave-browser
export PATH=$PATH:/opt
echo '#!/bin/bash' >> /opt/brave
echo 'brave-browser --no-sandbox &>/dev/null &' >> /opt/brave
chmod +x /opt/brave
#start brave
brave
