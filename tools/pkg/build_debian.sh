#!/bin/sh

cd /tmp
chmod -R 777 /tmp/twiki-20040902
rm -r /tmp/twiki-20040902

cp ~sven/build/twiki_20040902.orig.tar.gz .
tar zxvf twiki_20040902.orig.tar.gz > /tmp/tar.log

mv twiki twiki-20040902
cd /tmp/twiki-20040902

svn export http://ntwiki.ethermage.net:8181/svn/twiki/trunk/tools/pkg/debian > /tmp/svn_export.log

fakeroot debian/rules patch
fakeroot debian/rules checkpo

debuild
