package FormQueryPluginSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'FormQueryPlugin' };

sub include_tests {
  qw(ArithmeticTest ColourMapTest RelationTest TableDefTest TableFormatTest WebDBTest)
};

1;
