package SharedCodeSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'SharedCode' };

sub include_tests { qw(AttrsTests) };

1;
