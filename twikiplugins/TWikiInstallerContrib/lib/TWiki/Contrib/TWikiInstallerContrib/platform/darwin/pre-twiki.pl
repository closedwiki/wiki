#!/usr/bin/perl -w
# pre-twiki.pl
use strict;
use File::Path qw( mkpath );
use File::Copy qw( cp mv );

sub mychomp { chomp $_[0]; $_[0] }

print "TWiki Installation (Step 1/4)\n";

my $opts = {
    browser => 'open',
    whoami => mychomp( `whoami` ),
    cgibin => 'cgi-bin',
    installcgi => 'install_twiki.cgi',
    hostname => mychomp( `hostname --long` ),
};

my $INSTALL = "http://$opts->{hostname}/~$opts->{whoami}/config/install.html";

if ( -e "$opts->{cgibin}/install_twiki.cgi" )
{
    print <<__MSG__;
pre-twiki.pl has already been run
	(i checked for the existence of $opts->{cgibin}/install_twiki.cgi)
	you can delete $opts->{cgibin}/install_twiki.cgi and rerun pre-twiki.pl to force ...

continue installation at $INSTALL
__MSG__
    exit 0;
}

################################################################################
# create (copy) install_twiki.cgi into cgi-bin/ for second stage
################################################################################
-d $opts->{cgibin} || mkpath( $opts->{cgibin} );
chmod 0755, $opts->{cgibin};
#unless ( -e "$opts->{cgibin}/$opts->{installcgi}" )
#{
    cp( $opts->{installcgi}, "$opts->{cgibin}/$opts->{installcgi}" ) or die $!;
    chmod 0755, "$opts->{cgibin}/$opts->{installcgi}" or die $!;
#}

################################################################################
# install CPAN modules
################################################################################
my $cpanConfigDir = "/Users/$opts->{whoami}/.cpan/CPAN";
my $cpanConfig = "$cpanConfigDir/MyConfig.pm";
# TEMP: FIXME: !!! overwrites file FOR TESTING/DEVELOPMENT ONLY!!!
#unless ( -e $cpanConfig )
{ 
    mkpath( $cpanConfigDir );
    cp( "MyConfig.pm" => $cpanConfig );
}

foreach my $module (
		    qw( YAML Compress::Zlib IO::Zlib IO::String Archive::Tar Archive::TarGzip ExtUtils::CBuilder ExtUtils::ParserXS Tree::DAG_Node ),
		    # Module::Build
		    qw( Error URI HTML::Tagset HTML::Parser LWP XML::Parser XML::Simple Algorithm::Diff Text::Diff HTML::Diff ),
		    qw( WWW::Mechanize HTML::TableExtract WWW::Mechanize::TWiki ),
		    # Net::SSLeay IO::Socket::SSL
		    qw( Number::Compare Text::Glob File::Find::Rule File::Slurp File::Slurp::Tree ),
		    )
{
    next;	# for testing when i already know they're all already installed
    print `~/bin/perl cpan/install-cpan.pl $module`;
}

#print `~/bin/perl cpan/install-cpan.pl YAML Compress::Zlib IO::Zlib IO::String Archive::Tar Archive::TarGzip ExtUtils::CBuilder ExtUtils::ParserXS Tree::DAG_Node </dev/null`;
## Module::Build
#print `~/bin/perl cpan/install-cpan.pl Error URI HTML::Tagset HTML::Parser LWP XML::Parser XML::Simple Algorithm::Diff Text::Diff HTML::Diff </dev/null`;
#print `~/bin/perl cpan/install-cpan.pl WWW::Mechanize HTML::TableExtract WWW::Mechanize::TWiki </dev/null`;
## Net::SSLeay IO::Socket::SSL
#print `~/bin/perl cpan/install-cpan.pl Number::Compare Text::Glob File::Find::Rule File::Slurp File::Slurp::Tree </dev/null`;

################################################################################
# setup permissions for rest of install
################################################################################
print `mkdir $opts->{cgibin}/tmp ; chmod -R 777 $opts->{cgibin}/tmp/`;
chmod 0777, ".";
chmod 0777, "cgi-bin";
chmod 0777, "cgi-bin/lib";

################################################################################
system( $opts->{browser} => $INSTALL ) == 0 or print "continue installation at $INSTALL\n";
