#!/usr/bin/perl -w
# pre-twiki.pl
use strict;

sub mychomp { chomp $_[0]; $_[0] }

print "TWiki Installation (Step 1/4)\n";

my $INSTALL = "http://" . mychomp(`hostname`) . "/~" . mychomp(`whoami`) . "/config/install.html";

if ( -e "twiki/" )
{
    print "pre-twiki.sh already run; continue installatin at $$INSTALL (you shouldn't have a ./twiki directory)\n";
    exit 0;
}

print `mkdir -p cgi-bin/ ; cp install_twiki.cgi ./cgi-bin/ ; chmod +x cgi-bin/install_twiki.cgi`;

print `mkdir -p cgi-bin/tmp/ cgi-bin/tmp/twiki/pub/ cgi-bin/tmp/twiki/templates/ cgi-bin/tmp/install/`;
print `cp -R downloads cgi-bin/tmp/install/`;
print `cp -R cpan cgi-bin/tmp/install/`;
print `cp -R webs cgi-bin/tmp/install/`;
print `chmod -R 777 cgi-bin/tmp/`;

print `mkdir -p cgi-bin/twiki/ ; chmod 777 cgi-bin/twiki/`;
print `mkdir -p cgi-bin/lib/ ; chmod -R 777 cgi-bin/lib/`;
print `mkdir -p twiki/ ; chmod -R 777 twiki/`;

print `mkdir -p cgi-bin/lib/CPAN/ ; chmod -R 777 cgi-bin/lib/CPAN/`;
#print `perl cpan/install-cpan.pl XML::Parser XML::Simple Text::Diff Algorithm::Diff HTML::Diff'`;
#print `perl cpan/install-cpan.pl'`;
print `chmod -R 777 cgi-bin/lib/CPAN/`;

print `find cgi-bin -print | xargs chmod go-w`;

system( open => $INSTALL ) or print "continue installation at $INSTALL\n";
