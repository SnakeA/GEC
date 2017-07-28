#!/bin/bash

sudo apt-get install build-essential git-core pkg-config automake libtool wget zlib1g-dev python-dev libbz2-dev
sudo apt-get install libsoap-lite-perl
git clone https://github.com/moses-smt/mosesdecoder.git 

sudo apt-get update
sudo apt-get install  g++ git subversion automake libtool zlib1g-dev libboost-all-dev libbz2-dev liblzma-dev python-dev graphviz imagemagick make cmake libgoogle-perftools-dev


cd mosesdecoder
make -f contrib/Makefiles/install-dependencies.gmake
./compile.sh

sudo mkdir /mine
sudo mount -t cifs //angelosgec.file.core.windows.net/angelos /mine -o vers=3.0,username=angelosgec,password=s+frkUZhtZkzrkw3Lxl+8pkmMmGoOBWvel0bownklCMOT1dfjfOW/VzenI7h5XzZFW1QlKkwWn18EXdKYodHzw==,dir_mode=0777,file_mode=0777,sec=ntlmssp