#!/usr/bin/perl -w
#
# Build file for the Wtf plugin
#
# Standard preamble
BEGIN {
  foreach my $pc (split(/:/, $ENV{TWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use TWiki::Contrib::Build;

# Declare our build package
package WtfPluginBuild;

@WtfPluginBuild::ISA = ( "TWiki::Contrib::Build" );

sub new {
  my $class = shift;
  return bless( $class->SUPER::new( "WtfPlugin" ), $class );
}

# Create the build object
$build = new WtfPluginBuild();

# Build the target on the command line, or the default target
$build->build($build->{target});

