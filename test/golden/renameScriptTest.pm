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

package renameScriptTest;

require 'ScriptTestFixture.pm';

# base on the fixture so we get compare functionality
use base qw(ScriptTestFixture);

my $web = "Sandbox";
my $topic = "AutoCreatedTopic$$";

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

sub set_up {
  my $this = shift;
  $this->SUPER::set_up();
  my $text = "Pugh,Pugh,Barney%20McGrew,Cuthbert,Dibble,Grubb";
  # Save in both old and new
  $this->compareOldAndNew("save", $web, $topic, "text=$text&unlock=on");
}

sub tear_down {
  my $this = shift;
  $this->SUPER::tear_down();
  # clean up fixture
  $this->deleteTopic($web, $topic);
  $this->deleteTopic("Trash", $topic);
}

sub test_simple {
  my $this = shift;

  # This shouldn't do anything yet
  $this->compareOldAndNew("rename", $web, $topic, undef);

  # This should rename it to Trash web
  $this->getNew("rename", $web, $topic, "breaklock=on&newweb=Trash&newtopic=$topic");
  $this->assert($this->newExists("Trash", $topic), $topic);
  $this->assert(!$this->newExists($web, $topic), $topic);
}

# Should test other parameters

1;
