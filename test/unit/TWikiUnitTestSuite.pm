package TWikiUnitTestsSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'TWikiUnitTests' };

sub include_tests {
  qw(RobustnessTests MetaTests RcsTests StoreTests)
};

1;
