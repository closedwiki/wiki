#!/bin/sh
# post-twiki.sh
mkdir -p htdocs/twiki
mv cgi-bin/tmp/twiki/pub/* htdocs/twiki/
mkdir twiki/templates
cp cgi-bin/tmp/twiki/templates/* twiki/templates/
