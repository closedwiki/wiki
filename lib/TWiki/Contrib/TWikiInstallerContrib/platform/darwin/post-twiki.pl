#!/usr/bin/perl -w
# post-twiki.sh
use strict;
use Data::Dumper qw( Dumper );
use Cwd qw( getcwd );

system( "mkdir -p htdocs/twiki/" );
system( "mv cgi-bin/tmp/twiki/pub/* htdocs/twiki/" );
system( "mkdir twiki/templates" );
system( "cp cgi-bin/tmp/twiki/templates/* twiki/templates/" );

#rm -rf cgi-bin/install_twiki.cgi cgi-bin/tmp/

# $account = /Users/(twiki)/Sites
#echo `wget -O - http://localhost/~twiki/cgi-bin/twiki/manage?action=relockrcs | grep code | wc -l` topic(s) unlocked

################################################################################

use WWW::Mechanize;

my $tt = TWiki::Topic->new() or die $!;

my $mech = WWW::Mechanize::TWiki->new( agent => 'TWikiInstaller', autocheck => 1 ) or die $!;

my $baseUrl = "http://localhost/~twiki/cgi-bin/twiki/view";
my $baseWebUrl = "$baseUrl/TWiki";

################################################################################
# attach TWikiInstallationReport

my $topic = 'TWikiInstallationReport';
$mech->go( url => "$baseWebUrl/$topic" );
$mech->get( "$baseWebUrl/$topic" );
$mech->follow_link( text => 'Create' );

$mech->field( text => q[%INCLUDE{"%ATTACHURL%/TWikiInstallationReport.html"}%] );
$mech->click_button( value => 'Save' );

$mech->follow_link( text => 'Attach' );
$mech->submit_form(
		   form_name => 'main',
		   fields    => { 
		       filepath => getcwd() . "/TWikiInstallationReport.html",
		       filecomment => q[`date`],
		       hidefile => undef,
		   },
		   );

unlink "TWikiInstallationReport.html";

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
our $VERSION = '0.01';

use base qw( WWW::Mechanize );

sub new {
    my $class = shift;
    my %args = @_;
    my $self = $class->SUPER::new( %args );
    return $self;
}

use Data::Dumper qw( Dumper );
sub go {
    my $self = shift;
    my %args = @_;
    return $args{url};
}

################################################################################

package TWiki::Topic;

use strict;
use warnings FATAL => 'all';
our $VERSION = '0.01';

#use base qw();

sub new {
    my $class = shift;
    my $self  = { @_,
#  defaults here...
	      };
    return bless ($self, $class);
}



