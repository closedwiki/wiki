# Tests for module ActionSet.pm
use lib ('fakewiki');
use lib ('../../../..');
use lib ('../../../../TWiki/Plugins');
use ActionTrackerPlugin::Action;
use ActionTrackerPlugin::ActionSet;
use ActionTrackerPlugin::Attrs;
use ActionTrackerPlugin::Format;
use Assert;
use TWiki::TestMaker;
use TWiki::Func;

{ package LiveActionSetTests;

  sub setUp {
    TWiki::TestMaker::init("ActionTrackerPlugin");
    ActionTrackerPlugin::Action::forceTime("2 Jan 2002");
    #Assert::showProgress();

TWiki::TestMaker::writeTopic("Test", "Topic1", "
%ACTION{who=Main.C,due=\"16 Dec 02\",open}% Test_Topic1_C_open_ontime");

TWiki::TestMaker::writeTopic("Test", "Topic2", "
%ACTION{who=A,due=\"1 Jan 02\",open}% Test_Topic2_A_open_late");

TWiki::TestMaker::writeTopic("Test", "WebNotify", "
   * Main.A - fred\@sesame.street.com
");

TWiki::TestMaker::writeTopic("Main", "Topic2", "
%ACTION{who=Main.A,due=\"1 Jan 02\",closed}% Main_Topic2_A_closed_ontime
%ACTION{who=B,due=\"29 Jan 2010\",open}% Main_Topic2_B_open_ontime
%ACTION{who=E,due=\"29 Jan 2001\",open}% Main_Topic2_E_open_ontime");

TWiki::TestMaker::writeTopic("Main", "WebNotify", "
   * Main.C - sam\@sesame.street.com
");
TWiki::TestMaker::writeTopic("Main", "B", "
   * Email: joe\@sesame.street.com
");
TWiki::TestMaker::writeTopic("Main", "E", "
   * Email: joe\@sesame.street.com
   * Email: fred\@sesame.street.com
   * Email: sam\@sesame.street.com
   * Main.GungaDin - gunga-din\@war_lords-home.ind
");
  }

  sub tearDown() {
    TWiki::TestMaker::purge();
  }

  sub testGetAllInMain {
    my $attrs = ActionTrackerPlugin::Attrs->new();
    my $actions = ActionTrackerPlugin::ActionSet::allActionsInWeb("Main", $attrs);
    my $fmt = new ActionTrackerPlugin::Format("", "", "\$text");
    my $chosen = $actions->formatAsString($fmt);
    Assert::assert($chosen !~ /Test_Topic1_C_open_ontime/o);
    Assert::assert($chosen !~ /Test_Topic2_A_open_late/o);
    Assert::assert($chosen =~ /Main_Topic2_A_closed_ontime/o);
    Assert::assert($chosen =~ /Main_Topic2_B_open_ontime/o);
    Assert::assert($chosen =~ /Main_Topic2_E_open_ontime/o);
  }

  sub testGetAllInTest {
    my $attrs = ActionTrackerPlugin::Attrs->new();
    my $actions = ActionTrackerPlugin::ActionSet::allActionsInWeb("Test", $attrs);
    my $fmt = new ActionTrackerPlugin::Format("", "", "\$text");
    my $chosen = $actions->formatAsString($fmt);
    Assert::assert($chosen =~ /Test_Topic1_C_open_ontime/o);
    Assert::assert($chosen =~ /Test_Topic2_A_open_late/o);
    Assert::assert($chosen !~ /Main_Topic2_A_closed_ontime/o);
    Assert::assert($chosen !~ /Main_Topic2_B_open_ontime/o);
    Assert::assert($chosen !~ /Main_Topic2_E_open_ontime/o);
  }

  sub testGetAllInAllWebs {
    my $attrs = ActionTrackerPlugin::Attrs->new("web=\".*\"");
    my $actions = ActionTrackerPlugin::ActionSet::allActionsInWebs("Main", $attrs);
    $actions->sort();
    my $fmt = new ActionTrackerPlugin::Format("", "", "\$text");
    my $chosen = $actions->formatAsString($fmt);

    Assert::assert($chosen =~ /Test_Topic1_C_open_ontime/o);
    Assert::assert($chosen =~ /Test_Topic2_A_open_late/o);
    Assert::assert($chosen =~ /Main_Topic2_A_closed_ontime/o);
    Assert::assert($chosen =~ /Main_Topic2_B_open_ontime/o);
    Assert::assert($chosen =~ /Main_Topic2_E_open_ontime/o);

    # Make sure they are sorted correctly
#%ACTION{who=E,due=\"29 Jan 2001\",open}% Main_Topic2_E_open_ontime");
#%ACTION{who=A,due=\"1 Jan 02\",open}% Test_Topic2_A_open_late");
#%ACTION{who=Main.A,due=\"1 Jan 02\",closed}% Main_Topic2_A_closed_ontime
#%ACTION{who=Main.C,due=\"16 Dec 02\",open}% Test_Topic1_C_open_ontime
#%ACTION{who=B,due=\"29 Jan 2010\",open}% Main_Topic2_B_open_ontime

    Assert::assert($chosen =~ /Main_Topic2_E_open_ontime.*Test_Topic2_A_open_late.*Main_Topic2_A_closed_ontime.*Test_Topic1_C_open_ontime.*Main_Topic2_B_open_ontime/so);
  }

  sub testSortAllWebs {
    my $attrs = ActionTrackerPlugin::Attrs->new("web=\".*\"");
    my $actions = ActionTrackerPlugin::ActionSet::allActionsInWebs("Main", $attrs);
    $actions->sort("who,state");
    my $fmt = new ActionTrackerPlugin::Format("", "", "\$text");
    my $chosen = $actions->formatAsString($fmt);
    Assert::assert($chosen =~ /Main_Topic2_A_closed_ontime.*Test_Topic2_A_open_late.*Main_Topic2_B_open_ontime.*Test_Topic1_C_open_ontime.*Main_Topic2_E_open_ontime/so);
  }

  sub testAllInTestWebRE {
    my $attrs = ActionTrackerPlugin::Attrs->new("web=\"T.*\"");
    my $actions = ActionTrackerPlugin::ActionSet::allActionsInWebs("Main", $attrs);
    my $fmt = new ActionTrackerPlugin::Format("", "", "\$text");
    my $chosen = $actions->formatAsString($fmt);

    Assert::assert($chosen =~ /Test_Topic1_C_open_ontime/o);
    Assert::assert($chosen =~ /Test_Topic2_A_open_late/o);
    Assert::assert($chosen !~ /Main_Topic2_A_closed_ontime/o);
    Assert::assert($chosen !~ /Main_Topic2_B_open_ontime/o);
    Assert::assert($chosen !~ /Main_Topic2_E_open_ontime/o);
  }

  sub testAllInMainWebRE {
    my $attrs = ActionTrackerPlugin::Attrs->new("web=\".*ain\"");
    my $actions = ActionTrackerPlugin::ActionSet::allActionsInWebs("Main", $attrs);
    my $fmt = new ActionTrackerPlugin::Format("", "", "\$text");
    my $chosen = $actions->formatAsString($fmt);

    Assert::assert($chosen !~ /Test_Topic1_C_open_ontime/o);
    Assert::assert($chosen !~ /Test_Topic2_A_open_late/o);
    Assert::assert($chosen =~ /Main_Topic2_A_closed_ontime/o);
    Assert::assert($chosen =~ /Main_Topic2_B_open_ontime/o);
    Assert::assert($chosen =~ /Main_Topic2_E_open_ontime/o);
  }

  sub testAllTopicRE {
    my $attrs = ActionTrackerPlugin::Attrs->new("web=Test topic=\".*2\"");
    my $actions = ActionTrackerPlugin::ActionSet::allActionsInWebs("Test", $attrs);
    my $fmt = new ActionTrackerPlugin::Format("", "", "\$text");
    my $chosen = $actions->formatAsString($fmt);
    Assert::assert($chosen !~ /Test_Topic1_C_open_ontime/o);
    Assert::assert($chosen =~ /Test_Topic2_A_open_late/o);
    Assert::assert($chosen !~ /Main_Topic2_A_closed_ontime/o);
    Assert::assert($chosen !~ /Main_Topic2_B_open_ontime/o);
    Assert::assert($chosen !~ /Main_Topic2_E_open_ontime/o);
  }

  sub testAllWebsTopicRE {
    my $attrs = ActionTrackerPlugin::Attrs->new("web=\".*\",topic=\".*2\"");
    my $actions = ActionTrackerPlugin::ActionSet::allActionsInWebs("Main", $attrs);
    my $fmt = new ActionTrackerPlugin::Format("", "", "\$text");
    my $chosen = $actions->formatAsString($fmt);
    Assert::assert($chosen !~ /Test_Topic1_C_open_ontime/o);
    Assert::assert($chosen =~ /Test_Topic2_A_open_late/o);
    Assert::assert($chosen =~ /Main_Topic2_A_closed_ontime/o);
    Assert::assert($chosen =~ /Main_Topic2_B_open_ontime/o);
    Assert::assert($chosen =~ /Main_Topic2_E_open_ontime/o);
  }
}

1;
