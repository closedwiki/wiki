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

package oopsScriptTest;

require 'ScriptTestFixture.pm';

# base on the fixture so we get compare functionality
use base qw(ScriptTestFixture);

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

#sub set_up {
#  my $this = shift;
#  $this->SUPER::set_up();
#}

#sub tear_down {
#  my $this = shift;
#  $this->SUPER::tear_down();
#}
my $web = "Sandbox";
my $topic = "AutoCreatedTopic$$";

sub test_oopsaccesschange {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsaccesschange&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsaccessgroup {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsaccessgroup&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsaccessmanage {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsaccessmanage&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsaccessrename {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsaccessrename&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsaccessview {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsaccessview&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsattachnotopic {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsattachnotopic&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsauth {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsauth&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsbadcharset {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsbadcharset&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsbadpwformat {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsbadpwformat&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopschangepasswd {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopschangepasswd&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopscreatenewtopic {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopscreatenewtopic&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsempty {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsempty&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopslocked {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopslocked.pattern&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopslockedrename {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopslockedrename&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsmanage {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsmanage&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsmissing {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsmissing&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsmngcreateweb {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsmngcreateweb&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsmoveerr {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsmoveerr&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsnoformdef {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsnoformdef&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsnotwikiuser {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsnotwikiuser&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsnoweb {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsnoweb&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopspreview {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopspreview&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsregemail {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsregemail&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsregerr {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsregerr&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsregexist {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsregexist&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsregpasswd {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsregpasswd&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsregrequ {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsregrequ&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsregthanks {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsregthanks&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsregwiki {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsregwiki&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsremoveuserdone {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsremoveuserdone&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsrenameerr {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsrenameerr&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsrenamenotwikiword {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsrenamenotwikiword&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsresetpasswd {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsresetpasswd&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsrev {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsrev&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopssaveerr {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopssaveerr&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopssave {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopssave&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopssendmailerr {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopssendmailerr&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopstopicexists {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopstopicexists&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsuploadlimit {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsuploadlimit&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopsupload {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopsupload&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}

sub test_oopswrongpassword {
  my $this = shift;

  $this->compareOldAndNew("oops", $web, $topic,
                          "template=oopswrongpassword&param1=EINE&param2=ZWEI&param3=DREI&param1=VIER", 1);
}


1;
