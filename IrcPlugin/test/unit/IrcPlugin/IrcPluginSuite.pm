package IrcPluginSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'IrcPluginSuite' };

sub include_tests { qw(IrcPluginTests) };

1;
