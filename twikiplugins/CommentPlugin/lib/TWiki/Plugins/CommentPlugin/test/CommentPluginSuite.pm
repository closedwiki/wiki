package CommentPluginSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'CommentPlugin' };

sub include_tests { qw(CommentTest) };

1;
