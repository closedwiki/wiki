#!/bin/sh
# post-twiki.sh
mkdir -p htdocs/twiki
mv cgi-bin/tmp/twiki/pub/* htdocs/twiki/
mkdir twiki/templates
cp cgi-bin/tmp/twiki/templates/* twiki/templates/

# $account = /Users/(twiki)/Sites
#echo `wget -O - http://localhost/~twiki/cgi-bin/twiki/manage?action=relockrcs | grep code | wc -l` topic(s) unlocked
