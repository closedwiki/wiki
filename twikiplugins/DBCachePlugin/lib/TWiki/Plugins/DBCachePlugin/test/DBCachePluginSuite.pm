package DBCachePluginSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'DBCachePlugin' };

sub include_tests {
  qw(ArrayTest MapTest ArchiveTest FileTimeTest SearchTest)
};

1;
