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

{ package FileActionSetTests;

  sub setUp {
    TWiki::TestMaker::init("ActionTrackerPlugin");
    ActionTrackerPlugin::Action::forceTime("2 Jan 2002");

    # All actions in a web
    TWiki::TestMaker::writeTopic("Test", "Topic1", "
%ACTION{who=Main.C,due=\"3 Jan 02\",open}% C_open_ontime");
    TWiki::TestMaker::writeTopic("Test", "Topic2", "
%ACTION{who=A,due=\"1 Jun 2001\",open}% A_open_late
%ACTION{who=TestRunner,due=\"1 Jun 2001\",open}% TestRunner_open_late");
    
    TWiki::TestMaker::writeTopic("Main", "WebNotify", "
   * MowGli - mowgli\@jungle.book
");
    TWiki::TestMaker::writeTopic("Main", "Topic2", "
%ACTION{who=Main.A,due=\"1 Jan 02\",closed}% A_closed_ontime
%ACTION{who=Blah.B,due=\"29 Jan 2010\",open}% B_open_ontime");
  }

  sub tearDown {
    TWiki::TestMaker::purge();
  }

  sub testAllActionsInWebTest {
    my $attrs = ActionTrackerPlugin::Attrs->new("topic=\".*\"");
    my $actions = ActionTrackerPlugin::ActionSet::allActionsInWeb("Test", $attrs);
    my $fmt = new ActionTrackerPlugin::Format("", "", "\$text");
    my $chosen = $actions->formatAsString($fmt);

    Assert::assert($chosen =~ /C_open_ontime/o);
    Assert::assert($chosen =~ /A_open_late/o);
    Assert::assert($chosen =~ /TestRunner_open_late/o);
    Assert::assert($chosen !~ /A_closed_ontime/o);
    Assert::assert($chosen !~ /B_open_ontime/o);

    my %actionees;
    $actions->getActionees(\%actionees);
    Assert::assert(defined($actionees{"Main.C"}));
    Assert::assert(defined($actionees{"Main.A"}));
    Assert::assert(defined($actionees{"Main.TestRunner"}));
    Assert::assert(!defined($actionees{"Blah.B"}));
  }

  sub testAllActionsInWebMain {
    my $attrs = ActionTrackerPlugin::Attrs->new();
    my $actions = ActionTrackerPlugin::ActionSet::allActionsInWeb("Main", $attrs);
    my $fmt = new ActionTrackerPlugin::Format("", "", "\$text");
    my $chosen = $actions->formatAsString( $fmt );

    Assert::assert($chosen !~ /C_open_ontime/o);
    Assert::assert($chosen !~ /A_open_late/o);
    Assert::assert($chosen !~ /TestRunner_open_late/o);
    Assert::assert($chosen =~ /A_closed_ontime/o);
    Assert::assert($chosen =~ /B_open_ontime/o);

    my %actionees;
    $actions->getActionees(\%actionees);
    Assert::assert(!defined($actionees{"Main.C"}));
    Assert::assert(defined($actionees{"Main.A"}));
    Assert::assert(!defined($actionees{"Main.TestRunner"}));
    Assert::assert(defined($actionees{"Blah.B"}));
  }

  sub testOpenActions {
    my $attrs = ActionTrackerPlugin::Attrs->new();
    my $actions = ActionTrackerPlugin::ActionSet::allActionsInWeb("Test", $attrs );
    $actions = $actions->search( "open" );
    my $fmt = new ActionTrackerPlugin::Format("", "", "\$text");
    my $chosen = $actions->formatAsString($fmt);
    Assert::assert($chosen =~ /C_open_ontime/o);
    Assert::assert($chosen =~ /A_open_late/o);
    Assert::assert($chosen =~ /TestRunner_open_late/o);
    Assert::assert($chosen !~ /A_closed_ontime/o);
    Assert::assert($chosen !~ /B_open_ontime/o);
  }

#%ACTION{who=C,     due=\"3 Jan 02\",open}%    C_open_ontime
#%ACTION{who=A,     due=\"1 Jun 2001\",open}%  A_open_late
#%ACTION{who=TestRunner,     due=\"1 Jun 2001\",open}%  TestRunner_open_late
#%ACTION{who=A,     due=\"1 Jan 02\",closed}%  A_closed_ontime
#%ACTION{who=Blah.B,due=\"29 Jan 2010\",open}% B_open_ontime");
  sub testLateActions {
    my $attrs = ActionTrackerPlugin::Attrs->new();
    my $actions = ActionTrackerPlugin::ActionSet::allActionsInWeb("Test", $attrs );
    $actions = $actions->search("late");
    my $fmt = new ActionTrackerPlugin::Format("", "", "\$text");
    my $chosen = $actions->formatAsString($fmt);

    Assert::assert($chosen !~ /C_open_ontime/o);
    Assert::assert($chosen =~ /A_open_late/o);
    Assert::assert($chosen =~ /TestRunner_open_late/o);
    Assert::assert($chosen !~ /A_closed_ontime/o);
    Assert::assert($chosen !~ /B_open_ontime/o);
  }

  sub testMyActions {
    my $attrs = ActionTrackerPlugin::Attrs->new();
    my $actions = ActionTrackerPlugin::ActionSet::allActionsInWeb("Test", $attrs);
    $actions = $actions->search( "who=me" );
    my $fmt = new ActionTrackerPlugin::Format("", "", "\$text");
    my $chosen = $actions->formatAsString($fmt);
    Assert::assert($chosen !~ /C_open_ontime/o);
    Assert::assert($chosen !~ /A_open_late/o);
    Assert::assert($chosen !~ /A_closed_ontime/o);
    Assert::assert($chosen !~ /B_open_ontime/o);
    Assert::assert($chosen =~ /TestRunner_open_late/o);
  }
}

1;
