#!/usr/bin/perl -w
# post-twiki.sh
use strict;
use Data::Dumper qw( Dumper );
use Cwd qw( cwd );
use File::Basename qw( basename );

BEGIN {
    use Config;
    my $localLibBase = cwd() . "/cgi-bin/lib/CPAN/lib/site_perl/" . $Config{version};
    unshift @INC, ( $localLibBase, "$localLibBase/$Config{archname}" );
    # TODO: use setlib.cfg (along with TWiki:Codev.SetMultipleDirsInSetlibDotCfg)
};

system( "mkdir htdocs/" );
system( "mv cgi-bin/tmp/twiki/pub htdocs/twiki/" );
system( "mv cgi-bin/tmp/twiki/templates twiki/" );
system( "chmod o-w cgi-bin/twiki/" );

my $agent = "TWikiInstaller: " . basename( $0 );
my $mech = WWW::Mechanize::TWiki->new( agent => "$agent", autocheck => 1 ) or die $!;
$mech->cgibin( "http://localhost/~twiki/cgi-bin/twiki" );

# open up the system (could be locked down at the end)
$mech->edit( "Main.TWikiAdminGroup" );
my $text = $mech->value( "text", 1 );
$text =~ s/(\* Set GROUP = )PeterThoeny/$1TWikiGuest/;
$mech->field( text => $text );
$mech->click_button( value => 'Save' );

################################################################################

#rm -rf cgi-bin/install_twiki.cgi cgi-bin/tmp/

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
					filepath => cwd() . "/$topic.html",
					filecomment => `date`,
					hidefile => undef,
			    },
	) ) { #unlink "${topic}.html" 
	}
}

################################################################################

open( INDEX_PHP, ">htdocs/index.php" ) or die $!;
print INDEX_PHP <<'EOF';
<?php 
Header( "Location: http://" . $_SERVER[HTTP_HOST] . "/cgi-bin/twiki/view/" );
?>
EOF
close( INDEX_PHP );

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
    my $args = @_;

    $self->{cgibin} = $cgibin;

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
        (my $url = URI->new( "$self->{cgibin}/$action/$topic" ))->query_form( $args );
        return $self->get( $url );
    };
    goto &$AUTOLOAD;
}

################################################################################
