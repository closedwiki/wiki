=begin text

---+ Package TWiki::Net - test fixture
A test fixture module that provides an ultra-thin implementation of the
functions of the TWiki::Net module that are required by plugins and add-ons.

Only the methods encountered in testing to date are implemented.

For full details, read the code.

=cut
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
