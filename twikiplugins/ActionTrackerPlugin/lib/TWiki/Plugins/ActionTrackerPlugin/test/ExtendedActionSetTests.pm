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

# tests of actionset when action fields have been extended
{ package ExtendedActionSetTests;

  my $actions;

  # Build the fixture
  sub setUp {
    TWiki::TestMaker::init("ActionTrackerPlugin");
    ActionTrackerPlugin::Action::forceTime("2 Jan 2002");
    ActionTrackerPlugin::Action::extendTypes("|ap,text,12|");
    $actions = new ActionTrackerPlugin::ActionSet();
    $action = new ActionTrackerPlugin::Action("Test", "Topic", 0,
			  "who=A,due=1-Jan-02,open",
			  "Test_Main_A_open_late");
    $actions->add($action);
    $action = new ActionTrackerPlugin::Action("Test", "Topic", 1,
			  "ap=1 who=Main.A,due=1-Jan-02,closed=1-dec-01",
			  "Test_Main_A_closed_ontime");
    $actions->add($action);
    $action = new ActionTrackerPlugin::Action("Test", "Topic", 2,
			  "ap=2 who=Blah.B,due=\"29 Jan 2010\",open",
			  "Test_Blah_B_open_ontime");
    $actions->add($action);
  }

  sub tearDown {
    ActionTrackerPlugin::Action::unextendTypes();
  }

  sub testSort {
    $actions->sort("\$ap,\$due");
    my $fmt = new ActionTrackerPlugin::Format("|AP|","|\$ap|","\$ap");
    my $s = $actions->formatAsString($fmt);
    Assert::sEquals($s,"1\n2\n\n");
  }
}

1;
