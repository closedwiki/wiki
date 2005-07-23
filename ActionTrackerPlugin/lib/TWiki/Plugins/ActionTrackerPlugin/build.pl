#!/usr/bin/perl -w
#
# Build file for Action Tracker Plugin
#
package ActionTrackerPluginBuild;

BEGIN {
    unshift(@INC, '../../../../bin');
    do 'setlib.cfg';
}
use TWiki::Contrib::Build;


  @ActionTrackerPluginBuild::ISA = ( "TWiki::Contrib::Build" );

sub new {
    my $class = shift;
    return bless( $class->SUPER::new( "ActionTrackerPlugin" ), $class );
}

$build = new ActionTrackerPluginBuild();
$build->build($build->{target});
