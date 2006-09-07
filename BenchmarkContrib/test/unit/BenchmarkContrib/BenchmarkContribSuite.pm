package BenchmarkContribSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'BenchmarkContribSuite' };

sub include_tests { qw(BenchmarkContribTests) };

1;
