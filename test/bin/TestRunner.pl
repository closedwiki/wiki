#!/usr/bin/perl -w

require 5.006;

use strict;

use Test::Unit::Debug qw(debug_pkgs);
use Test::Unit::TestRunner;

unless (defined $ENV{TWIKI_ASSERTS}) {
  print "exporting TWIKI_ASSERTS=1 for extra checking; disable by exporting TWIKI_ASSERTS=0\n";
  $ENV{TWIKI_ASSERTS} = 1;
}

if ($ENV{TWIKI_ASSERTS} == 1) {
  print "Assert checking on\n";
} else {
  print "Assert checking off\n";
}

# Uncomment and edit to debug individual packages.
#debug_pkgs(qw/Test::Unit::TestCase/);

my $testrunner = Test::Unit::TestRunner->new();
$testrunner->start(@ARGV);

