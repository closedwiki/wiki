#use strict;
#use diagnostics;
package NeedPerl58ForTests;

if ($] < 5.8) {
   print "Your Perl version $] is too old to run the tests - please upgrade to 5.8\n";
}

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
