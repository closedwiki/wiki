#!/usr/bin/perl -w
#
# Build file for Action Tracker Plugin
#
# Standard preamble
BEGIN {
  foreach my $pc (split(/:/, $ENV{TWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use TWiki::Contrib::Build;

# Declare our build package
{ package ActionTrackerPluginBuild;

  @ActionTrackerPluginBuild::ISA = ( "TWiki::Contrib::Build" );

  sub new {
    my $class = shift;
    return bless( $class->SUPER::new( "ActionTrackerPlugin" ), $class );
  }
}

# Create the build object
$build = new ActionTrackerPluginBuild();

# Build the target on the command line, or the default target
$build->build($build->{target});

