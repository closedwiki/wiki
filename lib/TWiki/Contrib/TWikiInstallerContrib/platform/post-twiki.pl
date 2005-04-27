#! /home/wikihosting/packages/perl5.8.4/bin/perl -w
# post-twiki.sh
use strict;
use Data::Dumper qw( Dumper );
use File::Basename qw( basename );

# TODO notes:
# * tighten up templates directory permissions (chmod -R o-w twiki/templates)

sub mychomp { chomp $_[0]; $_[0] }

my $opts = {
    startupTopic => "",
    scriptSuffix => '.cgi',
};

BEGIN {
    use Config;
    use FindBin;

    my $localLibBase = "$FindBin::Bin/cgi-bin/lib/CPAN/lib";
    unshift @INC, ( $localLibBase, "$localLibBase/arch" );
};

use WWW::Mechanize::TWiki;

#system( "rm -rf cgi-bin/tmp" );

################################################################################

open( INDEX_PHP, ">index.php" ) or die $!;
print INDEX_PHP <<"EOF";
<?php 
Header( "Location: http://" . \$_SERVER[HTTP_HOST] . "/cgi-bin/twiki/view$opts->{scriptSuffix}/" );
?>
EOF
close( INDEX_PHP );

################################################################################
# WIKI SYSTEM USABLE AT THIS POINT
################################################################################
################################################################################
################################################################################

# format: /Users/(account)/Sites/cgi-bin/...
# format: /home/(drive)/(account)/account.wikihosting.com/...
my $account = [ split( '/', $FindBin::Bin ) ]->[-2];
print STDERR "account=[$account]\n";

$ENV{SERVER_NAME} = "$account.wikihosting.com";
chomp( my $hostname = $ENV{SERVER_NAME} || `hostname --long` || 'localhost' );
die "hostname?" unless $hostname;

my $BIN = "http://$hostname/cgi-bin/twiki";

my $agent = "TWikiInstaller: " . basename( $0 );
my $mech = WWW::Mechanize::TWiki->new( agent => "$agent", autocheck => 1 ) or die $!;
$mech->cgibin( $BIN, { scriptSuffix => $opts->{scriptSuffix} } );

# open up the system (could be locked down at the end)
$mech->edit( "Main.TWikiAdminGroup" );
my $text = $mech->value( "text", 1 );
$text =~ s/(\* Set GROUP = )PeterThoeny/$1TWikiGuest/;
$mech->field( text => $text );
$mech->click_button( value => 'Save' );

################################################################################

#rm -rf cgi-bin/install_twiki$opts->{scriptSuffix} cgi-bin/tmp/

################################################################################

if ( -e "TWikiInstallationReport.html" )
{
    ################################################################################
    # attach TWikiInstallationReport
    
    my $topic = 'TWikiInstallationReport';
    $mech->edit( "TWiki.$topic" );
    
    $mech->field( text => qq[%TOC%\n\n%INCLUDE{"%ATTACHURL%/$topic.html"}%\n] );
    $mech->click_button( value => 'Save' );
    
    $mech->follow_link( text => 'Attach' );
    if ( $mech->submit_form(
			    fields    => { 
					filepath => "$FindBin::Bin/$topic.html",
					filecomment => `date`,
					hidefile => undef,
			    },
	) ) { #unlink "${topic}.html" 
	}
    
    $opts->{startupTopic} = "TWiki.$topic";
}

################################################################################

my $START = "$BIN/view$opts->{scriptSuffix}/$opts->{startupTopic}";
system( links => $START ) == 0 or print "start using your wiki at $START\n";

################################################################################
################################################################################
