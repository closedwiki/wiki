package ColourMapTest;

use TWiki::Plugins::FormQueryPlugin::ColourMap;

use base qw(Test::Unit::TestCase);

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

sub test_cmap {
  my $this=shift;
  my $cm = TWiki::Plugins::FormQueryPlugin::ColourMap->new("
\t* /pass/ = green:\$1:green
\t* /(fail.*)/ = #FF0000:\$1:#FF0000
\t* /([Nn]ot [Ss]tarted)/ = yellow:\$1:yellow
");

  $this->assert_str_equals("#FF0000:fail:#FF0000", $cm->map("fail"));
  $this->assert_str_equals("yellow:Not started:yellow", $cm->map("Not started"));
  $this->assert_str_equals("yellow:not Started:yellow", $cm->map("not Started"));
  $this->assert_str_equals("yellow:Not Started:yellow", $cm->map("Not Started"));
  $this->assert_str_equals("#FF0000:fail disaster:#FF0000", $cm->map("fail disaster"));
  $this->assert_str_equals("#FF0000:fail_review:#FF0000", $cm->map("fail_review"));
  $this->assert_str_equals("no_fail", $cm->map("no_fail"));
}

1;
