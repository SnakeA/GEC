#!/bin/bash

sudo mount -t cifs //angelosgec.file.core.windows.net/angelos /mine -o vers=3.0,username=angelosgec,password=s+frkUZhtZkzrkw3Lxl+8pkmMmGoOBWvel0bownklCMOT1dfjfOW/VzenI7h5XzZFW1QlKkwWn18EXdKYodHzw==,dir_mode=0777,file_mode=0777,sec=ntlmssp

sudo chown $USER /mnt
sudo chown $USER /mine

mkdir /mnt/working

cp -r /mine/commoncrawllm /mnt/.
cp -r /mine/lang8 /mnt/.
cp -r /mine/nucle /mnt/.
cp -r /mine/wikilm /mnt/.
cp -r /mine/wiked/ /mnt/.