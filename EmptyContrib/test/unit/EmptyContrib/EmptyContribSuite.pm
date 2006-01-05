package EmptyContribSuite;

use base qw(Test::Unit::TestSuite);

sub name { 'EmptyContribSuite' };

sub include_tests { qw(EmptyContribTests) };

1;
