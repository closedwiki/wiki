package GetAWebAddOnSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'GetAWebAddOnSuite' };

sub include_tests { qw(GetAWebAddOnTests) };

1;
