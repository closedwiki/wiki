#!/usr/bin/perl -w
#
# Build file for AuthPagePlugin
#
# Standard preamble
BEGIN {
  foreach my $pc (split(/:/, $ENV{TWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use TWiki::Contrib::Build;

# Declare our build package
{ package AuthPagePluginBuild;

  @AuthPagePluginBuild::ISA = ( "TWiki::Contrib::Build" );

  sub new {
    my $class = shift;
    return bless( $class->SUPER::new( "AuthPagePlugin" ), $class );
  }
}

# Create the build object
$build = new AuthPagePluginBuild();

# Build the target on the command line, or the default target
$build->build($build->{target});

