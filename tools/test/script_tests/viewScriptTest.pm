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

package viewScriptTest;

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

sub test_simple1 {
  my $this = shift;
  $this->compareOldAndNew("view", "TWiki", "WhatIsWikiWiki", undef, 1);
}

sub test_simple2 {
  my $this = shift;
  $this->compareOldAndNew("view", "TWiki", "TextFormattingRules", undef, 1);
}

sub test_simple3 {
  my $this = shift;
  $this->compareOldAndNew("view", "TWiki", "TWikiDocGraphics", undef, 1);
}

sub notest_raw {
  my $this = shift;
  $this->compareOldAndNew("view", "TWiki", "TextFormattingFAQ", "raw=on", 0);
}

sub test_print_skinned {
  my $this = shift;
  $this->compareOldAndNew("view", "TWiki", "TextFormattingRules", "skin=print", 1);
}

sub test_dragon_skinned {
  my $this = shift;
  $this->compareOldAndNew("view", "TWiki", "TextFormattingRules", "skin=dragon", 1);
}

sub test_rss_skinned {
  my $this = shift;
  $this->compareOldAndNew("view", "TWiki", "TextFormattingRules", "skin=rss", 1);
}

# Should test other view parameters

1;
