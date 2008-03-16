#!/usr/bin/perl -w
#
# Build for EmbedFlashPlugin
#
BEGIN {
  foreach my $pc (split(/:/, $ENV{TWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use TWiki::Plugins::Build;

# Create the build object
$build = new TWiki::Plugins::Build( 'EmbedFlashPlugin' );

# Build the target on the command line, or the default target
$build->build($build->{target});

