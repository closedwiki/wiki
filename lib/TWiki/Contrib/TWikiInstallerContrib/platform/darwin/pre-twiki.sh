#!/bin/sh
# pre-twiki.sh
echo "TWiki Installation (Step 1/4)"

mkdir -p cgi-bin/ ; cp install_twiki.cgi ./cgi-bin/ ; chmod +x cgi-bin/install_twiki.cgi

mkdir -p cgi-bin/tmp/ cgi-bin/tmp/twiki/pub/ cgi-bin/tmp/twiki/templates/ cgi-bin/tmp/install/
cp -R downloads cgi-bin/tmp/install/
cp -R cpan cgi-bin/tmp/install/
cp -R webs cgi-bin/tmp/install/
chmod -R 777 cgi-bin/tmp/

mkdir -p cgi-bin/twiki/ ; chmod 777 cgi-bin/twiki/
mkdir -p cgi-bin/lib/ ; chmod -R 777 cgi-bin/lib/
mkdir -p twiki/ ; chmod -R 777 twiki/

mkdir -p cgi-bin/lib/CPAN/ ; chmod -R 777 cgi-bin/lib/CPAN/
[ -e cgi-bin/tmp/install/cpan/MIRROR ] && mv cgi-bin/tmp/install/cpan/MIRROR/ cgi-bin/lib/CPAN/
perl cpan/install-cpan.pl XML::Parser XML::Simple Text::Diff Algorithm::Diff HTML::Diff
#perl cpan/install-cpan.pl
chmod -R 777 cgi-bin/lib/CPAN/

find cgi-bin -print | xargs chmod go-w

#open "http://`hostname`/~`whoami`/cgi-bin/install_twiki.cgi"
open "http://`hostname`/~`whoami`/config/install.html"
