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

{ package FileActionSetTests;

  my $textonlyfmt = new ActionTrackerPlugin::Format("Text", "\$text", "cols", "\$text", "", "");

  sub setUp {
    TWiki::TestMaker::init("ActionTrackerPlugin");
    ActionTrackerPlugin::Action::forceTime("2 Jan 2002");

    # All actions in a web
    TWiki::TestMaker::writeTopic("Test", "Topic1", "
%ACTION{who=Main.C,due=\"3 Jan 02\",open}% C_open_ontime");
    TWiki::TestMaker::writeTopic("Test", "Topic2", "
%ACTION{who=A,due=\"1 Jun 2001\",open}% <<EOF
A_open_late
EOF
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
    my $attrs = new ActionTrackerPlugin::Attrs("topic=\".*\"");
    my $actions = ActionTrackerPlugin::ActionSet::allActionsInWeb("Test", $attrs);
    my $fmt = $textonlyfmt;
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
    my $attrs = new ActionTrackerPlugin::Attrs();
    my $actions = ActionTrackerPlugin::ActionSet::allActionsInWeb("Main", $attrs);
    my $fmt = $textonlyfmt;
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
    my $attrs = new ActionTrackerPlugin::Attrs("open");
    my $actions = ActionTrackerPlugin::ActionSet::allActionsInWeb("Test", $attrs );
    my $fmt = $textonlyfmt;
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
    my $attrs = new ActionTrackerPlugin::Attrs("late");
    my $actions = ActionTrackerPlugin::ActionSet::allActionsInWeb("Test", $attrs );
    my $fmt = $textonlyfmt;
    my $chosen = $actions->formatAsString($fmt);

    Assert::assert($chosen !~ /C_open_ontime/o);
    Assert::assert($chosen =~ /A_open_late/o);
    Assert::assert($chosen =~ /TestRunner_open_late/o);
    Assert::assert($chosen !~ /A_closed_ontime/o);
    Assert::assert($chosen !~ /B_open_ontime/o);
  }

  sub testMyActions {
    my $attrs = new ActionTrackerPlugin::Attrs("who=me");
    my $actions = ActionTrackerPlugin::ActionSet::allActionsInWeb("Test", $attrs);
    my $fmt = $textonlyfmt;
    my $chosen = $actions->formatAsString($fmt);
    Assert::assert($chosen !~ /C_open_ontime/o);
    Assert::assert($chosen !~ /A_open_late/o);
    Assert::assert($chosen !~ /A_closed_ontime/o);
    Assert::assert($chosen !~ /B_open_ontime/o);
    Assert::assert($chosen =~ /TestRunner_open_late/o);
  }
}

1;
