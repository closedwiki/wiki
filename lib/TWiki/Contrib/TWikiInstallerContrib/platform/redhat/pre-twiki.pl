#!/usr/bin/perl -w
# pre-twiki.pl
use strict;

sub mychomp { chomp $_[0]; $_[0] }

print "TWiki Installation (Step 1/4)\n";

my $whoami = mychomp(`whoami`);
#my $INSTALL = "http://" . mychomp(`hostname`) . "/~$whoami/config/install.html";
my $INSTALL = "http://" . mychomp(`hostname`) . "/~$whoami/cgi-bin/install_twiki.cgi";

#if ( -e "twiki/" )
if ( 0 )
{
    print "pre-twiki.pl already run; continue installatin at $INSTALL (you shouldn't have a ./twiki directory)\n";
    exit 0;
}

print `mkdir -p cgi-bin/` unless -d "cgi-bin";
print `cp install_twiki.cgi cgi-bin/ ; chmod +x cgi-bin/install_twiki.cgi` unless -e "cgi-bin/install_twiki.cgi";

print `mkdir -p cgi-bin/tmp/ cgi-bin/tmp/twiki/pub/ cgi-bin/tmp/twiki/templates/ cgi-bin/tmp/install/`;
print `cp -R downloads/ cgi-bin/tmp/install/downloads/`;
print `cp -R cpan/ cgi-bin/tmp/install/cpan/`;
print `cp -R webs/ cgi-bin/tmp/install/webs/`;
print `chmod -R 777 cgi-bin/tmp/`;

print `mkdir -p cgi-bin/twiki/ ; chmod 777 cgi-bin/twiki/`;
print `mkdir -p cgi-bin/lib/ ; chmod -R 777 cgi-bin/lib/`;
print `mkdir -p twiki/ ; chmod -R 777 twiki/`;

print `mkdir -p cgi-bin/lib/CPAN/ ; chmod -R 777 cgi-bin/lib/CPAN/`;
if ( -e ( my $mirrorOrigLoc = "cgi-bin/tmp/install/cpan/MIRROR/" ) ) 
{ 
    print `mv $mirrorOrigLoc/ cgi-bin/lib/CPAN/`;
}
unless ( -e ( my $cpanConfig = "/home/$whoami/.cpan/CPAN/MyConfig.pm" ) ) 
{ 
    print `mkdir -p /home/$whoami/.cpan/CPAN; mv MyConfig.pm $cpanConfig`;
}
print `perl cpan/install-cpan.pl XML::Simple Error Text::Diff Algorithm::Diff HTML::Diff XML::Parser URI HTML::Parser HTML::Form WWW::Mechanize WWW::Mechanize::TWiki`;
#print `perl cpan/install-cpan.pl'`;

print `chmod -R 777 cgi-bin/tmp/`;
#print `chmod -R 777 cgi-bin/lib/CPAN/`;

#print `find cgi-bin -print | xargs chmod go-w`;

system( htmlview => $INSTALL ) == 0 or print "continue installation at $INSTALL\n";
