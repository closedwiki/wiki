#!/bin/sh
# pre-twiki.sh
cp TWiki20040901.tar.gz install_twiki.cgi cgi-bin/
chmod +x cgi-bin/install_twiki.cgi 

mkdir -p cgi-bin/tmp cgi-bin/tmp/twiki/pub cgi-bin/tmp/twiki/templates
cp -R install cgi-bin/tmp/
chmod -R 777 cgi-bin/tmp

mkdir -p cgi-bin/twiki ; chmod 777 cgi-bin/twiki
mkdir -p cgi-bin/lib ; chmod 777 cgi-bin/lib
mkdir -p twiki ; chmod -R 777 twiki

