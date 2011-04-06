#!/usr/bin/perl -w
#
# Build file for TWiki Draw Plugin
#
# This builds the packages using the existing source.zip.
# (Use build-from-java-source.pl to build from Java source)

# Standard preamble
BEGIN {
  foreach my $pc (split(/:/, $ENV{TWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use TWiki::Contrib::Build;

# Declare our build package
package TWikiDrawPluginBuild;

@TWikiDrawPluginBuild::ISA = ( "TWiki::Contrib::Build" );

sub new {
    my $class = shift;
    return bless( $class->SUPER::new( "TWikiDrawPlugin" ), $class );
}

# Create the build object
$build = new TWikiDrawPluginBuild();

# Build the target on the command line, or the default target
$build->build($build->{target});
