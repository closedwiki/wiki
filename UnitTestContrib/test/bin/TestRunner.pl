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
    unshift @INC, "$root/lib";
    unshift @INC, "$root/lib/CPAN/lib";
    require 'setlib.cfg';
};

use strict;
use TWiki;   # If you take this out then TestRunner.pl will fail on IndigoPerl
use Unit::TestRunner;
use Cwd;

unless (defined $ENV{TWIKI_ASSERTS}) {
    print "exporting TWIKI_ASSERTS=1 for extra checking; disable by exporting TWIKI_ASSERTS=0\n";
    $ENV{TWIKI_ASSERTS} = 1;
}

if ($ENV{TWIKI_ASSERTS}) {
    print "Assert checking on $ENV{TWIKI_ASSERTS}\n";
} else {
    print "Assert checking off $ENV{TWIKI_ASSERTS}\n";
}

if ($ARGV[0] eq '-clean') {
    shift @ARGV;
    require File::Path;
    my @x = glob "$TWiki::cfg{DataDir}/Temp*";
    File::Path::rmtree([@x]) if scalar(@x);
    @x = glob "$TWiki::cfg{PubDir}/Temp*";
    File::Path::rmtree([@x]) if scalar(@x);
}

testForFiles($TWiki::cfg{DataDir}.'/Temp*');
testForFiles($TWiki::cfg{PubDir}.'/Temp*');

my $testrunner = Unit::TestRunner->new();
exit $testrunner->start(@ARGV);

sub testForFiles {
    my $test = shift;
    my @list = glob $test;
    die "Please remove $test (or run with the -clean option) to run tests\n" if (scalar(@list));
}

1;
