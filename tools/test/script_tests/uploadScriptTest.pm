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

package uploadScriptTest;

require 'ScriptTestFixture.pm';

# base on the fixture so we get compare functionality
use base qw(ScriptTestFixture);

my $web = "Sandbox";
my $topic = "AutoCreatedTopic$$";

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

sub createOldFixture {
  my $this = shift;
  $this->createTempForUpload();
  my $text = "Pugh,Pugh,Barney%20McGrew,Cuthbert,Dibble,Grubb";
  $this->getOld("save", $web, $topic, "text=$text&unlock=on");
}

sub createNewFixture {
  my $this = shift;
  $this->createTempForUpload();
  my $text = "Pugh,Pugh,Barney%20McGrew,Cuthbert,Dibble,Grubb";
  $this->getNew("save", $web, $topic, "text=$text&unlock=on");
}

sub deleteFixture {
  my $this = shift;
  $this->SUPER::tear_down();
  # clean up fixture
  $this->deleteTopic($web, $topic);
}

sub test_simple {
  my $this = shift;

  $this->createOldFixture();
  my $old = $this->getOld("upload", $web, $topic, "filepath=/tmp/robot.gif&filecomment=Arrrrgh&createlink=on&noredirect=on");
  $this->deleteFixture();

  $this->createNewFixture();
  my $new = $this->getNew("upload", $web, $topic, "filepath=/tmp/robot.gif&filecomment=Arrrrgh&createlink=on&noredirect=on");
  $this->deleteFixture();

  $this->diff($old, $new);
}

sub test_badweb {
  my $this = shift;

  $this->createOldFixture();
  my $old = $this->getOld("upload", "Spogarog", $topic, "filepath=/tmp/robot.gif&filecomment=Arrrrgh&createlink=on&noredirect=on");
  $this->deleteFixture();

  $this->createNewFixture();
  my $new = $this->getNew("upload", "Spogarog", $topic, "filepath=/tmp/robot.gif&filecomment=Arrrrgh&createlink=on&noredirect=on");
  $this->deleteFixture();

  $this->diff($old, $new);
}

sub test_badtopic {
  my $this = shift;

  $this->createOldFixture();
  my $old = $this->getOld("upload", $web, "Spogarog", "filepath=/tmp/robot.gif&filecomment=Arrrrgh&createlink=on&noredirect=on");
  $this->deleteFixture();

  $this->createNewFixture();
  my $new = $this->getNew("upload", $web, "Spogarog", "filepath=/tmp/robot.gif&filecomment=Arrrrgh&createlink=on&noredirect=on");
  $this->deleteFixture();

  $this->diff($old, $new);
}

sub test_missing_upload {
  my $this = shift;

  $this->createOldFixture();
  my $old = $this->getOld("upload", $web, $topic, "filepath=/dev/scream.gif&filecomment=Arrrrgh&createlink=on&noredirect=on");
  $this->deleteFixture();

  $this->createNewFixture();
  my $new = $this->getNew("upload", $web, $topic, "filepath=/dev/scream.gif&filecomment=Arrrrgh&createlink=on&noredirect=on");
  $this->deleteFixture();

  $this->diff($old, $new);
}

#sub test_size_limit {
#  my $this = shift;
#}

# Should test other parameters

1;
