sub test {
 use Test::Unit::TestRunner;

 my $testrunner = Test::Unit::TestRunner->new();
 $testrunner->start('TWikiReleaseNamesTester');
}

test();