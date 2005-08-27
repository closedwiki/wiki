package MacrosPluginSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'MacrosPlugin' };

sub include_tests { qw(MacrosTest) };

1;
