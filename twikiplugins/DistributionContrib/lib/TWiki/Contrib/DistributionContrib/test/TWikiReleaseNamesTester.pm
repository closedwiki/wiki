

package TWikiReleaseNamesTester;
use base qw(Test::Unit::TestCase);

sub new {
 my $self = shift()->SUPER::new(@_);

 # your state for fixture here
 return $self;
}

sub set_up {

 # provide fixture
}

sub tear_down {

 # clean up after test
}

sub test_works {
 my $self = shift;
 $self->assert_equals(
  "TWiki20040730beta",
  TWikiReleaseNames::releaseTopicToDistributionName(
   "TWikiBetaRelease2004x07x30")
 );
}

sub test_works2 {
 my $self = shift;
 $self->assert_equals( "TWiki20030201",
  TWikiReleaseNames::releaseTopicToDistributionName("TWikiRelease20030201") );
}

sub test_wikiVersionToDistributionName {
 my $self = shift;
 $self->assert_equals( "TWiki20030201",
  TWikiReleaseNames::wikiVersionToDistributionName("01 Feb 2003") );
}

sub test_thisFaultsTestUnit {
 my $self = shift;
 $self->assert_equals( "1", "2" );
}

# Test::Unit segfaults on failure for me, but this at least keeps the interface working
sub assert_equals {
 my ( $self, $compare, $with ) = @_;
 if ( $compare eq $with ) {
  print "ok ($compare == $with)\n";
  return 1;
 }
 else {
  print "failed ($compare == $with) \n";
  return -1;
 }
}
