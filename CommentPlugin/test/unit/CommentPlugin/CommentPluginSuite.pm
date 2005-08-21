package CommentPluginSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'CommentPluginSuite' };

sub include_tests { qw(CommentPluginTests) };

1;
