# Tests for module ActionSet.pm
use lib ('fakewiki');
use lib ('../../../..');
use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::ActionSet;
use TWiki::Plugins::ActionTrackerPlugin::Attrs;
use TWiki::Plugins::ActionTrackerPlugin::Format;
use Assert;
use TWiki::TestMaker;
use TWiki::Func;

{ package SimpleActionSetTests;

  my $actions;

  # Build the fixture
  sub setUp {
    TWiki::TestMaker::init("ActionTrackerPlugin");
    ActionTrackerPlugin::Action::forceTime("2 Jan 2002");
    $actions = new ActionTrackerPlugin::ActionSet();
    $action = new ActionTrackerPlugin::Action("Test", "Topic", 0,
			  "who=A,due=1-Jan-02,open",
			  "Test_Main_A_open_late");
    $actions->add($action);
    $action = new ActionTrackerPlugin::Action("Test", "Topic", 1,
			  "who=Main.A,due=1-Jan-02,closed",
			  "Test_Main_A_closed_ontime");
    $actions->add($action);
    $action = new ActionTrackerPlugin::Action("Test", "Topic", 2,
			  "who=Blah.B,due=\"29 Jan 2010\",open",
			  "Test_Blah_B_open_ontime");
    $actions->add($action);
    my $junk = $actions->toString();
  }

  sub testAHTable {
    my $fmt = new ActionTrackerPlugin::Format("|Web|Topic|Edit|",
					      "|\$web|\$topic|\$edit|",
					      "rows",
					      "", "");
    my $s;
    $s = $actions->formatAsHTML( $fmt, "href", 0 );
    $s =~ s/\n//go;
    Assert::sEquals($s, "<table border=\"1\"><tr><th bgcolor=\"orange\">Web</th><td>Test</td><td>Test</td><td>Test</td></tr><tr><th bgcolor=\"orange\">Topic</th><td>Topic</td><td>Topic</td><td>Topic</td></tr><tr><th bgcolor=\"orange\">Edit</th><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion0\">edit</a></td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion1\">edit</a></td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion2\">edit</a></td></tr></table>");
    $s = $actions->formatAsHTML( $fmt, "name", 0 );
    $s =~ s/\n//go;
    Assert::sEquals($s, "<table border=\"1\"><a name=\"AcTion0\"></a><a name=\"AcTion1\"></a><a name=\"AcTion2\"></a><tr><th bgcolor=\"orange\">Web</th><td>Test</td><td>Test</td><td>Test</td></tr><tr><th bgcolor=\"orange\">Topic</th><td>Topic</td><td>Topic</td><td>Topic</td></tr><tr><th bgcolor=\"orange\">Edit</th><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion0\">edit</a></td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion1\">edit</a></td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion2\">edit</a></td></tr></table>");
    $s = $actions->formatAsHTML( $fmt, "name", 1 );
    $s =~ s/\n//go;
    Assert::sEquals($s, "<table border=\"1\"><a name=\"AcTion0\"></a><a name=\"AcTion1\"></a><a name=\"AcTion2\"></a><tr><th bgcolor=\"orange\">Web</th><td>Test</td><td>Test</td><td>Test</td></tr><tr><th bgcolor=\"orange\">Topic</th><td>Topic</td><td>Topic</td><td>Topic</td></tr><tr><th bgcolor=\"orange\">Edit</th><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion0\" onClick=\"return editWindow('%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion0')\">edit</a></td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion1\" onClick=\"return editWindow('%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion1')\">edit</a></td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion2\" onClick=\"return editWindow('%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion2')\">edit</a></td></tr></table>");
  }

  sub testAVTable {
    my $fmt = new ActionTrackerPlugin::Format("|Web|Topic|Edit|",
					      "|\$web|\$topic|\$edit|",
					      "cols",
					      "", "",);
    my $s;
    $s = $actions->formatAsHTML( $fmt, "href", 0 );
    $s =~ s/\n//go;
    Assert::sEquals($s, "<table border=\"1\"><tr bgcolor=\"orange\"><th>Web</th><th>Topic</th><th>Edit</th></tr><tr valign=\"top\"><td>Test</td><td>Topic</td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion0\">edit</a></td></tr><tr valign=\"top\"><td>Test</td><td>Topic</td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion1\">edit</a></td></tr><tr valign=\"top\"><td>Test</td><td>Topic</td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion2\">edit</a></td></tr></table>");
    $s = $actions->formatAsHTML( $fmt, "name", 0 );
    $s =~ s/\n//go;
    Assert::sEquals($s, "<table border=\"1\"><tr bgcolor=\"orange\"><th>Web</th><th>Topic</th><th>Edit</th></tr><tr valign=\"top\"><a name=\"AcTion0\"></a><td>Test</td><td>Topic</td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion0\">edit</a></td></tr><tr valign=\"top\"><a name=\"AcTion1\"></a><td>Test</td><td>Topic</td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion1\">edit</a></td></tr><tr valign=\"top\"><a name=\"AcTion2\"></a><td>Test</td><td>Topic</td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion2\">edit</a></td></tr></table>");
    $s = $actions->formatAsHTML( $fmt, "name", 1 );
    $s =~ s/\n//go;
    Assert::sEquals($s, "<table border=\"1\"><tr bgcolor=\"orange\"><th>Web</th><th>Topic</th><th>Edit</th></tr><tr valign=\"top\"><a name=\"AcTion0\"></a><td>Test</td><td>Topic</td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion0\" onClick=\"return editWindow('%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion0')\">edit</a></td></tr><tr valign=\"top\"><a name=\"AcTion1\"></a><td>Test</td><td>Topic</td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion1\" onClick=\"return editWindow('%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion1')\">edit</a></td></tr><tr valign=\"top\"><a name=\"AcTion2\"></a><td>Test</td><td>Topic</td><td><a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion2\" onClick=\"return editWindow('%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/Test/Topic?skin=action&action=AcTion2')\">edit</a></td></tr></table>");
  }

  sub testSearchOpen {
    my $attrs = new ActionTrackerPlugin::Attrs("state=open");
    my $chosen = $actions->search($attrs);
    my $fmt = new ActionTrackerPlugin::Format("", "", "", "\$text");
    my $text = $chosen->formatAsString($fmt);
    Assert::assert($text =~ /Blah_B_open/);
    Assert::assert($text =~ /A_open/);
    Assert::assert($text !~ /closed/);
  }

  sub testSearchClosed {
    my $attrs = new ActionTrackerPlugin::Attrs("closed");
    my $chosen = $actions->search($attrs);
    my $fmt = new ActionTrackerPlugin::Format("", "", "", "\$text");
    my $text = $chosen->formatAsString($fmt);
    Assert::assert($text !~ /open/o);
  }

  sub testSearchWho {
    my $attrs = new ActionTrackerPlugin::Attrs("who=A");
    my $chosen = $actions->search($attrs);
    my $fmt = new ActionTrackerPlugin::Format("", "", "", "\$text");
    my $text = $chosen->formatAsString($fmt);
    Assert::assert($text !~ /B_open_ontime/o);
  }

  sub testSearchLate {
    my $attrs = new ActionTrackerPlugin::Attrs("late");
    my $chosen = $actions->search($attrs);
    my $fmt = new ActionTrackerPlugin::Format("", "", "", "\$text");
    my $text = $chosen->formatAsString($fmt);
    Assert::assert($text !~ /ontime/o);
  }

  sub testSearchAll {
    my $attrs = new ActionTrackerPlugin::Attrs("");
    my $chosen = $actions->search($attrs);
    my $fmt = new ActionTrackerPlugin::Format("", "", "", "\$text");
    my $text = $chosen->formatAsString($fmt);
    Assert::assert($text =~ /Main_A_open_late/o);
    Assert::assert($text =~ /Main_A_closed_ontime/o);
    Assert::assert($text =~ /Blah_B_open_ontime/o);
  }

  # add more actions to the fixture
  sub addMoreActions {
    my $moreactions = new ActionTrackerPlugin::ActionSet();
    my $fmt = new ActionTrackerPlugin::Format("", "", "", "\$text");
    my $action = new ActionTrackerPlugin::Action( "Test", "Topic", 0,
			      "who=C,due=\"1 Jan 02\",open",
			      "C_open_late");
    $moreactions->add($action);
    $actions->concat( $moreactions );
  }

  # x1 so it gets executed second last
  sub testx1Search {
    addMoreActions();
    my $attrs = new ActionTrackerPlugin::Attrs("late");
    my $chosen = $actions->search($attrs);
    my $fmt = new ActionTrackerPlugin::Format("", "", "", "\$text");
    my $text = $chosen->formatAsString($fmt);
    Assert::assert($text =~ /A_open_late/);
    Assert::assert($text =~ /C_open_late/o);
    Assert::assert($text !~ /ontime/o);
  }

  # x2 so it gets executed last
  sub testx2Actionees {
    my $attrs = new ActionTrackerPlugin::Attrs("late");
    my $chosen = $actions->search($attrs);
    my %peeps;
    $chosen->getActionees(\%peeps);
    Assert::assert($peeps{"Main.A"});
    Assert::assert($peeps{"Main.C"});
    Assert::assert(!$peeps{"Blah.B"});
  }

}

1;
