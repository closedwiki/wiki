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

package viewfileScriptTest;

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
  $this->getOld("save", $web, $topic, "text=$text&unlock=on");
  $this->createTempForUpload();
  $this->getOld("attach", $web, $topic, "filename=/tmp/robot.gif");

  $this->getNew("save", $web, $topic, "text=$text&unlock=on");
  $this->createTempForUpload();
  $this->getNew("attach", $web, $topic, "filename=/tmp/robot.gif");
}

sub tear_down {
  my $this = shift;
  $this->SUPER::tear_down();
  # clean up fixture
  $this->deleteTopic($web, $topic);
}

sub test_simple {
  my $this = shift;

  # FIXME: This fails, though not as a result of refactoring

  my $old = $this->getOld("viewfile", $web, $topic, "filename=robot.gif");
  my $new = $this->getNew("viewfile", $web, $topic, "filename=robot.gif");
  $this->diff($old, $new);
}

# Should test other parameters

1;
