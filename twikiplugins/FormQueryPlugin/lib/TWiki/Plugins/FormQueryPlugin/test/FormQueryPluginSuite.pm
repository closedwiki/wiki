package FormQueryPluginSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'FormQueryPlugin' };

sub include_tests {
  qw(ArithmeticTest ArrayTest MapTest ArchiveTest FileTimeTest ColourMapTest SearchTest RelationTest TableDefTest TableFormatTest WebDBTest) };

1;
