#!/usr/bin/perl -w

use strict;
use diagnostics;

# This line is useful for pasting into PDB:
# foreach my $pc (split(/:/, $ENV{TWIKI_LIBS})) {unshift @INC, $pc;}
BEGIN {

#use Cwd;
#print cwd(); 


 my $twikiLibs = $ENV{TWIKI_LIBS} || "" ;
 if ( $twikiLibs eq "") {
  warn
"Warning: twikicli expects TWIKI_LIBS to be a colon separated set of lib directories (one from each dev-plugin) to be put into \@INC\n";
 } else {
  foreach my $pc ( split( /:/, $twikiLibs ) ) {
   unshift @INC, $pc;
  }
 }
}

#use TWiki::Contrib::BuildContrib::TWikiCLI;
use TWiki::Contrib::BuildContrib::TWikiShell;
=pod

twikicli extension install DistributionContrib

=cut 

#print TWiki::Contrib::BuildContrib::TWikiCLI::dispatch($ENV{ARGV});
my $shell = new TWiki::Contrib::BuildContrib::TWikiShell;
$shell->cmdloop();

1;
