package MailerContribSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'MailerContrib' };

sub include_tests {
  qw(MailerContribTests)
};

1;
