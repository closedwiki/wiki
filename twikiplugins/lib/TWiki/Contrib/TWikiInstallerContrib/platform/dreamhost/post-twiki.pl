#! /home/wikihosting/packages/perl5.8.4/bin/perl -w
# post-twiki.sh
use strict;
use Data::Dumper qw( Dumper );
use File::Basename qw( basename );

# TODO notes:
# * tighten up templates directory permissions (chmod -R o-w twiki/templates)
# * use WWW::Mechanize::TWiki;

sub mychomp { chomp $_[0]; $_[0] }

my $opts = {
    startupTopic => "",
    scriptSuffix => '.cgi',
};

BEGIN {
    use Config;
    use FindBin;
#    my $localLibBase = "$FindBin::Bin/cgi-bin/lib/CPAN/lib/site_perl/" . $Config{version};
    my $localLibBase = "$FindBin::Bin/cgi-bin/lib/CPAN/lib";
    unshift @INC, ( $localLibBase, "$localLibBase/$Config{archname}" );
    # TODO: use setlib.cfg (along with TWiki:Codev.SetMultipleDirsInSetlibDotCfg)
};

#use WWW::Mechanize::TWiki;

system( "mv cgi-bin/tmp/install/LocalSite.cfg cgi-bin/lib/" );
system( "mkdir htdocs/" );
system( "mv cgi-bin/tmp/twiki/pub htdocs/twiki/" );
system( "mv cgi-bin/tmp/twiki/templates twiki/" );
system( "chmod -R o-w cgi-bin/twiki/ cgi-bin/lib/ cgi-bin/lib/CPAN/" );

print `find cgi-bin/twiki/ -print | xargs chmod go-w`;
print `find cgi-bin/lib/ -print | xargs chmod go-w`;

#system( "rm -rf cgi-bin/tmp" );

################################################################################

open( INDEX_PHP, ">htdocs/index.php" ) or die $!;
print INDEX_PHP <<'EOF';
<?php 
Header( "Location: http://" . $_SERVER[HTTP_HOST] . "/cgi-bin/twiki/view$opts->{scriptSuffix}/" );
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

my $agent = "TWikiInstaller: " . basename( $0 );
my $mech = WWW::Mechanize::TWiki->new( agent => "$agent", autocheck => 1 ) or die $!;
$mech->cgibin( "http://$hostname/cgi-bin/twiki", { scriptSuffix => $opts->{scriptSuffix} } );

# open up the system (could be locked down at the end)
$mech->edit( "Main.TWikiAdminGroup" );
my $text = $mech->value( "text", 1 );
$text =~ s/(\* Set GROUP = )PeterThoeny/$1TWikiGuest/;
$mech->field( text => $text );
$mech->click_button( value => 'Save' );

################################################################################

#rm -rf cgi-bin/install_twiki$opts->{scriptSuffix} cgi-bin/tmp/

# $account = /Users/(twiki)/Sites
# echo `curl http://localhost/~twiki/cgi-bin/twiki/manage?action=relockrcs | grep code | wc -l` topic(s) unlocked

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

my $START = "http://$hostname/cgi-bin/twiki/view$opts->{scriptSuffix}/$opts->{startupTopic}";
print "$START\n";
system( links => $START ) == 0 or print "start using your wiki at $START\n";

################################################################################
################################################################################

package WWW::Mechanize::TWiki;

use strict;
use warnings FATAL => 'all';
our $VERSION = '0.02';

use base qw( WWW::Mechanize );

sub new {
    my $class = shift;
    my %args = @_;
    my $self = $class->SUPER::new( %args );
    return $self;
}

sub cgibin {
    my $self = shift;
    my $cgibin = shift;
    my $args = shift;

    $self->{cgibin} = $cgibin;
    $self->{scriptSuffix} = $args->{scriptSuffix};

    print STDERR $self->{scriptSuffix}, "\n";

    return $self;
}

# pub (that's all the directories, right?)
# config (query on page text or bin script for cgibin and pub (and anything else))
# page list?
# web exists?

# maps function calls into twiki urls
sub AUTOLOAD {
    our ($AUTOLOAD);
    no strict 'refs';
    (my $action = $AUTOLOAD) =~ s/.*:://;
    *$AUTOLOAD = sub {
        my ($self, $topic, $args) = @_;
        (my $url = URI->new( "$self->{cgibin}/$action$self->{scriptSuffix}/$topic" ))->query_form( $args );
        return $self->get( $url );
    };
    goto &$AUTOLOAD;
}

################################################################################
