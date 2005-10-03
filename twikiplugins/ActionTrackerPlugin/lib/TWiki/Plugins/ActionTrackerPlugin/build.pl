#!/usr/bin/perl -w
#
# Build file for Action Tracker Plugin
#
package ActionTrackerPluginBuild;

BEGIN {
  foreach my $pc (split(/:/, $ENV{TWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use TWiki::Contrib::Build;

@ActionTrackerPluginBuild::ISA = ( "TWiki::Contrib::Build" );

sub new {
    my $class = shift;
    return bless( $class->SUPER::new( "ActionTrackerPlugin" ), $class );
}

$build = new ActionTrackerPluginBuild();
$build->build($build->{target});
