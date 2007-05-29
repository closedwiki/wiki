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
use Test::Unit::Debug qw(debug_pkgs);
use Test::Unit::TestRunner;
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

#make sure our environment is sufficiently clean to run tests
#DON"T RUN THIS :)
my $dangerousRemover = 'rm -r /tmp/junk* ; rm  '.$TWiki::cfg{TempfileDir}.'/[cde]* ; rm '.$TWiki::cfg{TempfileDir}.'/* ; rm -r '.$TWiki::cfg{DataDir}.'/Temp*';
`$dangerousRemover`;
testForFiles('/tmp/junk*'); #this is hardcoded into some tests :(
testForFiles($TWiki::cfg{TempfileDir}.'/*');
testForFiles($TWiki::cfg{DataDir}.'/Temp*');


# Uncomment and edit to debug individual packages.
#debug_pkgs(qw/Test::Unit::TestCase/);

my $testrunner = Test::Unit::TestRunner->new();
print "\n---------------\nRunning: ".join(',', @ARGV)."\n";
$testrunner->start(@ARGV);

sub testForFiles {
    my $test = shift;
    
    my $list = `ls $test 2> /dev/null`;
    die "please remove $test to run tests\n" unless ($list eq '');
}

1;
