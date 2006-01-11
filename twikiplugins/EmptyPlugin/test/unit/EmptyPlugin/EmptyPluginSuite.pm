package EmptyPluginSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'EmptyPluginSuite' };

sub include_tests { qw(EmptyPluginTests) };

1;
