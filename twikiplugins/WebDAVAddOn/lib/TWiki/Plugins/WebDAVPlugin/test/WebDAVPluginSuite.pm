package WebDAVPluginSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'WebDAVPlugin' };

sub include_tests { qw(WriteReadTest CReadTest) };

1;
