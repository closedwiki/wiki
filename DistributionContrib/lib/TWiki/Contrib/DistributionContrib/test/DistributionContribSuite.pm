package DistributionContribTester;
use base qw(Test::Unit::TestCase);

sub test_ok {
    1;
}

sub test {
 use Test::Unit::TestRunner;

 my $testrunner = Test::Unit::TestRunner->new();
 $testrunner->start('TWikiReleaseNamesTester');
}

1;
