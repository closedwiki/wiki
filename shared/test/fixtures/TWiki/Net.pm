package TWiki::Net;

use vars qw( @sent );

@sent = ();

sub sendEmail {
  my $text = shift;

  # We should really assert that it contains the correct fields for the
  # twiki mail tool, but we'll leave that up to the tests themselves
  # because it's easy enough to check.
  push @sent, $text;

  return undef;
}

1;
