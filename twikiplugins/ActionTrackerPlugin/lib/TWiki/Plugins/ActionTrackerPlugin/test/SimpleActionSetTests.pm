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
					      "", "",
					      "horizontal");
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

  sub testAVTable {
    my $fmt = new ActionTrackerPlugin::Format("|Web|Topic|Edit|",
					      "|\$web|\$topic|\$edit|",
					      "", "",
					      "vertical");
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
    my $chosen = $actions->search("state=open");
    my $fmt = new ActionTrackerPlugin::Format("", "", "\$text");
    my $text = $chosen->formatAsString($fmt);
    Assert::assert($text =~ /Blah_B_open/);
    Assert::assert($text =~ /A_open/);
    Assert::assert($text !~ /closed/);
  }

  sub testSearchClosed {
    my $chosen = $actions->search("closed");
    my $fmt = new ActionTrackerPlugin::Format("", "", "\$text");
    my $text = $chosen->formatAsString($fmt);
    Assert::assert($text !~ /open/o);
  }

  sub testSearchWho {
    my $chosen = $actions->search("who=A");
    my $fmt = new ActionTrackerPlugin::Format("", "", "\$text");
    my $text = $chosen->formatAsString($fmt);
    Assert::assert($text !~ /B_open_ontime/o);
  }

  sub testSearchLate {
    my $chosen = $actions->search("late");
    my $fmt = new ActionTrackerPlugin::Format("", "", "\$text");
    my $text = $chosen->formatAsString($fmt);
    Assert::assert($text !~ /ontime/o);
  }

  sub testSearchAll {
    my $chosen = $actions->search("");
    my $fmt = new ActionTrackerPlugin::Format("", "", "\$text");
    my $text = $chosen->formatAsString($fmt);
    Assert::assert($text =~ /Main_A_open_late/o);
    Assert::assert($text =~ /Main_A_closed_ontime/o);
    Assert::assert($text =~ /Blah_B_open_ontime/o);
  }

  # add more actions to the fixture
  sub addMoreActions {
    my $moreactions = new ActionTrackerPlugin::ActionSet();
    my $fmt = new ActionTrackerPlugin::Format("", "", "\$text");
    my $action = new ActionTrackerPlugin::Action( "Test", "Topic", 0,
			      "who=C,due=\"1 Jan 02\",open",
			      "C_open_late");
    $moreactions->add($action);
    $actions->concat( $moreactions );
  }

  # x1 so it gets executed second last
  sub testx1Search {
    addMoreActions();
    my $chosen = $actions->search("late");
    my $fmt = new ActionTrackerPlugin::Format("", "", "\$text");
    my $text = $chosen->formatAsString($fmt);
    Assert::assert($text =~ /A_open_late/);
    Assert::assert($text =~ /C_open_late/o);
    Assert::assert($text !~ /ontime/o);
  }

  # x2 so it gets executed last
  sub testx2Actionees {
    my $chosen = $actions->search("late");
    my %peeps;
    $chosen->getActionees(\%peeps);
    Assert::assert($peeps{"Main.A"});
    Assert::assert($peeps{"Main.C"});
    Assert::assert(!$peeps{"Blah.B"});
  }

}

1;
