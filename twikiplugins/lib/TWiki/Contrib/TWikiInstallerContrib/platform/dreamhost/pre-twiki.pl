#! /home/wikihosting/packages/perl5.8.4/bin/perl -w
# pre-twiki.pl
use strict;
use File::Path qw( mkpath );

sub mychomp { chomp $_[0]; $_[0] }

print "TWiki Installation (Step 1/4)\n";

my $whoami = mychomp(`whoami`);
#my $INSTALL = "http://" . mychomp(`hostname`) . "/~$whoami/config/install.html";
#my $INSTALL = "http://wbniv.wikihosting.com/config/install.html";
my $INSTALL = "http://wbniv.wikihosting.com/cgi-bin/install_twiki.cgi";

if ( -e "cgi-bin/install_twiki.cgi" )
{
    print "pre-twiki.pl has already been run\n";
    print "   (i checked for the existence of cgi-bin/install_twiki.cgi)\n";
    print "   you can delete cgi-bin/install_twiki.cgi and rerun pre-twiki.pl to force ...\n";
    print "\ncontinue installation at $INSTALL\n";
    exit 0;
}

-d "cgi-bin" || mkpath "cgi-bin";
print `cp install_twiki.cgi cgi-bin/ ; chmod +x cgi-bin/install_twiki.cgi` unless -e "cgi-bin/install_twiki.cgi";

mkpath( [ qw( cgi-bin/tmp/ cgi-bin/tmp/twiki/pub/ cgi-bin/tmp/twiki/templates/ cgi-bin/tmp/install/ ) ] );
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
# TEMP: FIXME: !!! overwrites file FOR TESTING/DEVELOPMENT ONLY!!!
my $cpanConfig = "/home/$whoami/.cpan/CPAN/MyConfig.pm";
#unless ( -e ( my $cpanConfig = "/home/$whoami/.cpan/CPAN/MyConfig.pm" ) ) 
{ 
    print `mkdir -p /home/$whoami/.cpan/CPAN; cp MyConfig.pm $cpanConfig`;
}
print `~/bin/perl cpan/install-cpan.pl YAML Compress::Zlib IO::Zlib IO::String Archive::Tar ExtUtils::CBuilder ExtUtils::ParserXS Tree::DAG_Node </dev/null`;
# Module::Build
print `~/bin/perl cpan/install-cpan.pl Error URI HTML::Tagset HTML::Parser LWP XML::Parser XML::Simple Algorithm::Diff Text::Diff HTML::Diff </dev/null`;
##print `~/bin/perl cpan/install-cpan.pl 
print `~/bin/perl cpan/install-cpan.pl WWW::Mechanize HTML::TableExtract WWW::Mechanize::TWiki </dev/null`;
# Net::SSLeay IO::Socket::SSL
##print `~/bin/perl cpan/install-cpan.pl'`;

print `chmod -R 777 cgi-bin/tmp/`;

system( links => $INSTALL ) == 0 or print "continue installation at $INSTALL\n";
