#use strict;
#use diagnostics;
package FaultyTestCaseOnDreamhost;

use base qw(Test::Unit::TestCase);

sub test_thisFaultsTestUnit {
    my $self = shift;
    $self->assert_equals( "1", "2" );
}


sub new {
  my $self = shift()->SUPER::new(@_);
    # your state for fixture here
    return $self;
}

1;
