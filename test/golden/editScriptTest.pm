#
# Test script for testing TWiki refactorings, based on the concept
# that a refactoring should not change the rendered output from the
# various scripts.
#
# Note that THESE TESTS ARE AMAZINGLY CRUDE and should be backed up
# by unit tests in the refactored code. This is really just a sanity
# check, rather than a production quality test.
#
# Uses two installations, one using the old (golden) code, the other
# using the new test code.
#
# A subset of parameters is also tested; many are not, either because
# no-one can work out what they were for, or because nobody has been
# bothered yet. Contributors willing to write tests are always welcome!
#
# The basic strategy is to avoid dependencies on actual content wherever
# possible, and only use comparison between old and new to detect differences.
#
use strict;

package editScriptTest;

require 'ScriptTestFixture.pm';

# base on the fixture so we get compare functionality
use base qw(ScriptTestFixture);

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

# no specific setup required
#sub set_up {
#  my $this = shift;
#  $this->SUPER::set_up();
#}

# no specific tear-down required (creates no topics)
#sub tear_down {
#  my $this = shift;
#  $this->SUPER::tear_down();
#}

my $web = "TWiki";
my $topic = "TextFormattingRules";

sub test_simple {
  my $this = shift;
  # breaklock is on in case we are using a common data area
  $this->compareOldAndNew("edit", $web, $topic,
                          "breaklock=on");
  # delete the lock we created
  $this->unlock($web, $topic);
}

sub test_locks {
  my $this = shift;
  # assumes old worked correctly! ;-)
  $this->getNew("edit", $web, $topic, undef);
  $this->assert($this->newLocked($web, $topic));
  $this->getNew("view", $web, $topic, "unlock=on");
  $this->assert(!$this->newLocked($web, $topic));
}

# Should test other parameters

1;
