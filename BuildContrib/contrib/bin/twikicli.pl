#!/usr/bin/perl -w

use strict;
use diagnostics;

# This line is useful for pasting into PDB:
# foreach my $pc (split(/:/, $ENV{TWIKI_LIBS})) {unshift @INC, $pc;}
BEGIN {
  foreach my $pc (split(/:/, $ENV{TWIKI_LIBS})) {
    unshift @INC, $pc;
  }
}

use TWiki::Contrib::BuildContrib::TWikiCLI;

=pod

twikicli extension install DistributionContrib

=cut 

print TWiki::Contrib::BuildContrib::TWikiCLI::dispatch(@ARGV);
