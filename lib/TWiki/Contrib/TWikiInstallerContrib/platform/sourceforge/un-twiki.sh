#!/bin/sh
# un-twiki.sh
rm -fr cgi-bin/lib cgi-bin/tmp cgi-bin/twiki htdocs/twiki twiki cgi-bin/TWiki20040901.tar.gz cgi-bin/install_twiki.cgi

# cleanup stuff that shouldn't still be here
mkdir -p cgi-bin/tmp/del
mv twiki cgi-bin/tmp/del
mv htdocs/twiki cgi-bin/tmp/del