#!/usr/bin/perl -w
# pre-twiki.pl
use strict;

sub mychomp { chomp $_[0]; $_[0] }

print "TWiki Installation (Step 1/4)\n";

my $whoami = mychomp(`whoami`);
my $INSTALL = "http://" . mychomp(`hostname`) . "/~$whoami/config/install.html";

#if ( -e "twiki/" )
if ( 0 )
{
    print "pre-twiki.pl already run; continue installatin at $INSTALL (you shouldn't have a ./twiki directory)\n";
    exit 0;
}

print `mkdir -p cgi-bin/` unless -d "cgi-bin";
print `cp install_twiki.cgi cgi-bin/ ; chmod +x cgi-bin/install_twiki.cgi` unless -e "cgi-bin/install_twiki.cgi";

print `mkdir -p cgi-bin/tmp/ cgi-bin/tmp/twiki/pub/ cgi-bin/tmp/twiki/templates/ cgi-bin/tmp/install/`;
print `cp -R downloads cgi-bin/tmp/install/`;
print `cp -R cpan cgi-bin/tmp/install/`;
print `cp -R webs cgi-bin/tmp/install/`;
print `chmod -R 777 cgi-bin/tmp/`;

print `mkdir -p cgi-bin/twiki/ ; chmod 777 cgi-bin/twiki/`;
print `mkdir -p cgi-bin/lib/ ; chmod -R 777 cgi-bin/lib/`;
print `mkdir -p twiki/ ; chmod -R 777 twiki/`;

print `mkdir -p cgi-bin/lib/CPAN/ ; chmod -R 777 cgi-bin/lib/CPAN/`;
if ( -e ( my $mirrorOrigLoc = "cgi-bin/tmp/install/cpan/MIRROR/" ) ) { print `mv $mirrorOrigLoc/ cgi-bin/lib/CPAN/` }
unless ( -e ( my $cpanConfig = "/Users/$whoami/.cpan/CPAN/MyConfig.pm" ) ) { print `mkdir -p /Users/$whoami/.cpan/CPAN; mv MyConfig.pm $cpanConfig` }
print `perl cpan/install-cpan.pl XML::Parser XML::Simple Text::Diff Algorithm::Diff HTML::Diff`;
#print `perl cpan/install-cpan.pl'`;

print `find cgi-bin/twiki -print | xargs chmod go-w`;
print `find cgi-bin/lib -print | xargs chmod go-w`;

print `chmod -R 777 cgi-bin/tmp/`;

system( open => $INSTALL ) == 0 or print "continue installation at $INSTALL\n";
