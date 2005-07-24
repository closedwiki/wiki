#!/usr/bin/perl -w

require 5.006;

BEGIN {
    use Cwd 'abs_path';

    # root the tree
    my $here = Cwd::abs_path(Cwd::getcwd());

    # scoot up the tree looking for a bin dir that has setlib.cfg
    my $root = $here;
    while( !-e "$root/bin/setlib.cfg" ) {
        $root =~ s#/[^/]*$##;
    }
    unshift @INC, "$root/test/unit";
    unshift @INC, "$root/bin";
    require 'setlib.cfg';
};

use strict;

use Test::Unit::Debug qw(debug_pkgs);
use Test::Unit::TestRunner;
use Cwd;

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

