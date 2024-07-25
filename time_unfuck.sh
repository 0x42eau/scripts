#!/bin/bash

#used to force Parrot for HyperV and ARM to update properly
# could be more issues with other versions but have only noticed it there

sudo date -s "$(wget -qSO- --max-redirect=0 google.com 2>&1 | grep Date: | cut -d' ' -f5-8)Z"
