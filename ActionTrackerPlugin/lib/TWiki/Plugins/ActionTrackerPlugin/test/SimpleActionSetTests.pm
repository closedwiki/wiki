# Tests for module Action.pm
use strict;

package SimpleActionSetTests;

use base qw(BaseFixture);

use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::ActionSet;
use TWiki::Plugins::ActionTrackerPlugin::Format;
use TWiki::Contrib::Attrs;
use Time::ParseDate;
use CGI;

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

my $actions;

sub set_up {
  my $this = shift;
  $this->SUPER::set_up();

  TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("2 Jan 2002");
  $actions = new TWiki::Plugins::ActionTrackerPlugin::ActionSet();
  my $action = new TWiki::Plugins::ActionTrackerPlugin::Action("Test", "Topic", 0,
											"who=A,due=1-Jan-02,open",
											"Test_Main_A_open_late");
  $actions->add($action);
  $action = new TWiki::Plugins::ActionTrackerPlugin::Action("Test", "Topic", 1,
											"who=Main.A,due=1-Jan-02,closed",
											"Test_Main_A_closed_ontime");
  $actions->add($action);
  $action = new TWiki::Plugins::ActionTrackerPlugin::Action("Test", "Topic", 2,
											"who=Blah.B,due=\"29 Jan 2010\",open",
											"Test_Blah_B_open_ontime");
  $actions->add($action);
}

sub tear_down {
  my $this = shift;
  $this->SUPER::tear_down();
  $actions = undef;
}

sub testAHTable {
  my $this = shift;
  my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format("|Web|Topic|Edit|",
											"|\$web|\$topic|\$edit|",
											"rows",
											"", "");
  my $s;
  $s = $actions->formatAsHTML( $fmt, "href", 0 );
  $s =~ s/\n//go;
  $s =~ /(&t=\d+)/;
  my $t = $1;
  $this->assert_html_matches_all("<table border=\"1\"><tr><th bgcolor=\"orange\">Web</th><td>Test</td><td>Test</td><td>Test</td></tr><tr><th bgcolor=\"orange\">Topic</th><td>Topic</td><td>Topic</td><td>Topic</td></tr><tr><th bgcolor=\"orange\">Edit</th><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion0$t\">edit</a></td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion1$t\">edit</a></td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion2$t\">edit</a></td></tr></table>", $s);
  $s = $actions->formatAsHTML( $fmt, "name", 0 );
  $s =~ s/\n//go;
  $s =~ /(&t=\d+)/;
  $t = $1;
  $this->assert_html_matches_all("<table border=\"1\"><a name=\"AcTion0\"></a><a name=\"AcTion1\"></a><a name=\"AcTion2\"></a><tr><th bgcolor=\"orange\">Web</th><td>Test</td><td>Test</td><td>Test</td></tr><tr><th bgcolor=\"orange\">Topic</th><td>Topic</td><td>Topic</td><td>Topic</td></tr><tr><th bgcolor=\"orange\">Edit</th><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion0$t\">edit</a></td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion1$t\">edit</a></td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion2$t\">edit</a></td></tr></table>", $s);
  $s = $actions->formatAsHTML( $fmt, "name", 1 );
  $s =~ s/\n//go;
  $s =~ /(&t=\d+)/;
  $t = $1;
  $this->assert_html_matches_all("<table border=\"1\"><a name=\"AcTion0\"></a><a name=\"AcTion1\"></a><a name=\"AcTion2\"></a><tr><th bgcolor=\"orange\">Web</th><td>Test</td><td>Test</td><td>Test</td></tr><tr><th bgcolor=\"orange\">Topic</th><td>Topic</td><td>Topic</td><td>Topic</td></tr><tr><th bgcolor=\"orange\">Edit</th><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion0$t\" onClick=\"return editWindow('%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion0$t')\">edit</a></td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion1$t\" onClick=\"return editWindow('%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion1$t')\">edit</a></td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion2$t\" onClick=\"return editWindow('%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion2$t')\">edit</a></td></tr></table>", $s);
}

sub testAVTable {
  my $this = shift;
  my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format("|Web|Topic|Edit|",
											"|\$web|\$topic|\$edit|",
											"cols",
											"", "",);
  my $s;
  $s = $actions->formatAsHTML( $fmt, "href", 0 );
  $s =~ s/\n//go;
  $s =~ /(&t=\d+)/;
  my $t = $1;
  $this->assert_html_matches_all("<table border=\"1\"><tr bgcolor=\"orange\"><th>Web</th><th>Topic</th><th>Edit</th></tr><tr valign=\"top\"><td>Test</td><td>Topic</td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion0$t\">edit</a></td></tr><tr valign=\"top\"><td>Test</td><td>Topic</td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion1$t\">edit</a></td></tr><tr valign=\"top\"><td>Test</td><td>Topic</td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion2$t\">edit</a></td></tr></table>", $s);
  $s = $actions->formatAsHTML( $fmt, "name", 0 );
  $s =~ s/\n//go;
  $s =~ /(&t=\d+)/;
  $t = $1;
  $this->assert_html_matches_all("<table border=\"1\"><tr bgcolor=\"orange\"><th>Web</th><th>Topic</th><th>Edit</th></tr><tr valign=\"top\"><a name=\"AcTion0\"></a><td>Test</td><td>Topic</td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion0$t\">edit</a></td></tr><tr valign=\"top\"><a name=\"AcTion1\"></a><td>Test</td><td>Topic</td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion1$t\">edit</a></td></tr><tr valign=\"top\"><a name=\"AcTion2\"></a><td>Test</td><td>Topic</td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion2$t\">edit</a></td></tr></table>", $s);
  $s = $actions->formatAsHTML( $fmt, "name", 1 );
  $s =~ s/\n//go;
  $s =~ /(&t=\d+)/;
  $t = $1;
  $this->assert_html_matches_all("<table border=\"1\"><tr bgcolor=\"orange\"><th>Web</th><th>Topic</th><th>Edit</th></tr><tr valign=\"top\"><a name=\"AcTion0\"></a><td>Test</td><td>Topic</td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion0$t\" onClick=\"return editWindow('%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion0$t')\">edit</a></td></tr><tr valign=\"top\"><a name=\"AcTion1\"></a><td>Test</td><td>Topic</td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion1$t\" onClick=\"return editWindow('%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion1$t')\">edit</a></td></tr><tr valign=\"top\"><a name=\"AcTion2\"></a><td>Test</td><td>Topic</td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion2$t\" onClick=\"return editWindow('%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion2$t')\">edit</a></td></tr></table>", $s);
}

sub testSearchOpen {
  my $this = shift;
  my $attrs = new TWiki::Contrib::Attrs("state=open");
  my $chosen = $actions->search($attrs);
  my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format("", "", "", "\$text");
  my $text = $chosen->formatAsString($fmt);
  $this->assert_matches(qr/Blah_B_open/, $text);
  $this->assert_matches(qr/A_open/, $text);
  $this->assert_does_not_match(qr/closed/, $text);
}

sub testSearchClosed {
  my $this = shift;
  my $attrs = new TWiki::Contrib::Attrs("closed");
  my $chosen = $actions->search($attrs);
  my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format("", "", "", "\$text");
  my $text = $chosen->formatAsString($fmt);
  $this->assert_does_not_match(qr/open/o, $text);
}

sub testSearchWho {
  my $this = shift;
  my $attrs = new TWiki::Contrib::Attrs("who=A");
  my $chosen = $actions->search($attrs);
  my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format("", "", "", "\$text");
  my $text = $chosen->formatAsString($fmt);
  $this->assert_does_not_match(qr/B_open_ontime/o, $text);
}

sub testSearchLate {
  my $this = shift;
  my $attrs = new TWiki::Contrib::Attrs("late");
  my $chosen = $actions->search($attrs);
  my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format("", "", "", "\$text");
  my $text = $chosen->formatAsString($fmt);
  $this->assert_matches(qr/Test_Main_A_open_late/, $text);
  $this->assert_does_not_match(qr/ontime/o, $text);
}

sub testSearchLate2 {
  my $this = shift;
  my $attrs = new TWiki::Contrib::Attrs("state=\"late\"");
  my $chosen = $actions->search($attrs);
  my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format("", "", "", "\$text");
  my $text = $chosen->formatAsString($fmt);
  $this->assert_matches(qr/Test_Main_A_open_late/, $text);
  $this->assert_does_not_match(qr/ontime/o, $text);
}

sub testSearchAll {
  my $this = shift;
  my $attrs = new TWiki::Contrib::Attrs("");
  my $chosen = $actions->search($attrs);
  my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format("", "", "", "\$text");
  my $text = $chosen->formatAsString($fmt);
  $this->assert_matches(qr/Main_A_open_late/o, $text);
  $this->assert_matches(qr/Main_A_closed_ontime/o, $text);
  $this->assert_matches(qr/Blah_B_open_ontime/o, $text);
}

# add more actions to the fixture
sub addMoreActions {
  my $moreactions = new TWiki::Plugins::ActionTrackerPlugin::ActionSet();
  my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format("", "", "", "\$text");
  my $action = new TWiki::Plugins::ActionTrackerPlugin::Action( "Test", "Topic", 0,
												"who=C,due=\"1 Jan 02\",open",
												"C_open_late");
  $moreactions->add($action);
  $actions->concat( $moreactions );
}

# x1 so it gets executed second last
sub testx1Search {
  my $this = shift;
  addMoreActions();
  my $attrs = new TWiki::Contrib::Attrs("late");
  my $chosen = $actions->search($attrs);
  my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format("", "", "", "\$text");
  my $text = $chosen->formatAsString($fmt);
  $this->assert_matches(qr/A_open_late/, $text);
  $this->assert_matches(qr/C_open_late/o, $text);
  $this->assert_does_not_match(qr/ontime/o, $text);
}

# x2 so it gets executed last
sub testx2Actionees {
  my $this = shift;
  addMoreActions();
  my $attrs = new TWiki::Contrib::Attrs("late");
  my $chosen = $actions->search($attrs);
  my %peeps;
  $chosen->getActionees(\%peeps);
  $this->assert_not_null($peeps{"Main.A"});
  $this->assert_not_null($peeps{"Main.C"});
  $this->assert_null($peeps{"Blah.B"});
}

1;
