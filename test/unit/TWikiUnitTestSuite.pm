package TWikiUnitTestsSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'TWikiUnitTests' };

sub include_tests {
  qw(RobustnessTests PrefsTests MetaTests RcsTests StoreTests TestRegister MailerTests)
};

1;
