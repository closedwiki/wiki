#! /usr/local/bin/perl -w

use strict;
use diagnostics;

BEGIN {
    unless (-d "test") {chdir ".."};
    chdir "../../../../bin" || die "You must be above the test dir and have a normal twiki hierarchy - $!";
}


use lib "../lib";

use TWiki;
use TWiki::Plugins;
use TWiki::Func;

unless (eval "use TWiki::Plugins::TWikiReleaseTrackerPlugin") {
    print "$@\n";
}
 


