#!/bin/bash

cd ~
mkdir moses2
cd moses2
git clone https://github.com/snukky/mosesdecoder.git
cd mosesdecoder
git fetch origin gleu
git checkout gleu
cd ..
mv mosesdecoder mosesdecoder-gleu
mv mosesdecoder-gleu ../.
cd ~
rm -rf moses2
wget https://downloads.sourceforge.net/project/cmph/cmph/cmph-2.0.tar.gz
tar -zxvf cmph-2.0.tar.gz
cd cmph-2.0
./configure
make
sudo make install
cd ../mosesdecoder-gleu
./bjam -j16 --max-kenlm-order=9 --with-cmph=~/cmph-2.0
cp -r /mine/tools ~/mosesdecoder-gleu/.
cd ~
sudo apt-get update
sudo apt-get --assume-yes install pigz parallel htop
cpan Parallel::ForkManager
cpan YAML::XS
cpan Algorithm::Diff::XS
wget https://bootstrap.pypa.io/get-pip.py
sudo python get-pip.py
rm get-pip.py
rm -r cmph-2.0
sudo pip install joblib
cp -r /mine/lazy ~/.
cp -r /mine/srilm ~/.
sudo pip install -U nltk
sudo python -m nltk.downloader -d /usr/local/share/nltk_data all