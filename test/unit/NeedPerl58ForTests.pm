#use strict;
#use diagnostics;
package NeedPerl58ForTests;

use base qw(Test::Unit::TestCase);

sub test_thisFaultsTestUnit {
    my $self = shift;
    $self->assert($] >= 5.008, "Your Perl version $] is too old to run the tests - please upgrade to 5.8");
}


sub new {
  my $self = shift()->SUPER::new(@_);
    # your state for fixture here
    return $self;
}

1;
