package OpenIDPluginSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'OpenIDPluginSuite' };

sub include_tests { qw(OpenIDPluginTests) };

1;
