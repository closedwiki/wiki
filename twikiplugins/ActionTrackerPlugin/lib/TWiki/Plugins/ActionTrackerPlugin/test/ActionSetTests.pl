# Tests for module ActionSet.pm
use lib ('fakewiki');
use lib ('../../../..');
use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::ActionSet;
use TWiki::Plugins::ActionTrackerPlugin::Attrs;
use Assert;
use TWiki::TestMaker;
use TWiki::Func;

TWiki::TestMaker::init();
#Assert::showProgress();

Action::forceTime(Time::ParseDate::parsedate("2 Jan 2002"));
$actions = ActionSet->new();

$action = Action->new( "Test", "Topic", 0, "who=Fred,due=\"1 Jan 02\",open", "Test1: Fred_open_late");
$actions->add($action);

$action = Action->new("Test", "Topic", 1, "who=Fred,due=\"1 Jan 02\",closed", "Test2: Fred_closed_ontime");
$actions->add($action);

$action = Action->new("Test", "Topic", 2, "who=Blah.Joe,due=\"29 Jan 2010\",open", "Test3: Joe_open_ontime");
$actions->add($action);

$chosen = $actions->search("open");
$text = $chosen->formatAsString();
Assert::assert(__FILE__,__LINE__, $text !~ /closed/o);

$chosen = $actions->search("closed");
$text = $chosen->formatAsString();
Assert::assert(__FILE__,__LINE__, $text !~ /open/o);

$chosen = $actions->search("who=Fred");
$text = $chosen->formatAsString();
Assert::assert(__FILE__,__LINE__, $text !~ /Joe/o);

$chosen = $actions->search("late");
$text = $chosen->formatAsString();
Assert::assert(__FILE__,__LINE__.$text, $text !~ /ontime/o);

$chosen = $actions->search("");
$text = $chosen->formatAsString();
Assert::assert(__FILE__,__LINE__, $text =~ /Test1:/o, "all $text");
Assert::assert(__FILE__,__LINE__, $text =~ /Test2:/o, "all $text");
Assert::assert(__FILE__,__LINE__, $text =~ /Test3:/o, "all $text");

$moreactions = ActionSet->new();
$action = Action->new( "Test", "Topic", 0, "who=Sam,due=\"1 Jan 02\",open", "Test1: Sam_open_late");
$moreactions->add($action);

$actions->concat( $moreactions );
$chosen = $actions->search("late");
$text = $chosen->formatAsString();
Assert::assert(__FILE__,__LINE__, $text =~ /Fred_open_late/o);
Assert::assert(__FILE__,__LINE__, $text =~ /Sam_open_late/o);

$peeps = $chosen->getActionees();
Assert::assert(__FILE__,__LINE__, $peeps->{"Main.Fred"});
Assert::assert(__FILE__,__LINE__, $peeps->{"Main.Sam"});
Assert::assert(__FILE__,__LINE__, !$peeps->{"Blah.Joe"});

# All actions in a web
TWiki::TestMaker::writeTopic("Test", "Topic1", "
%ACTION{who=Main.Sam,due=\"3 Jan 02\",open}% Test0: Sam_open_ontime");
TWiki::TestMaker::writeTopic("Test", "Topic2", "
%ACTION{who=Fred,due=\"1 Jun 2001\",open}% Test1: Fred_open_late
%ACTION{who=TestRunner,due=\"1 Jun 2001\",open}% Test4: TestRunner_open_late");

TWiki::TestMaker::writeTopic("Main", "WebNotify", "
   * MowGli - mowgli\@jungle.book
");
TWiki::TestMaker::writeTopic("Main", "Topic2", "
%ACTION{who=Main.Fred,due=\"1 Jan 02\",closed}% Main0: Fred_closed_ontime
%ACTION{who=Blah.Joe,due=\"29 Jan 2010\",open}% Main1: Joe_open_ontime");

$actions = ActionSet::allActionsInWeb("Test", ActionTrackerPlugin::Attrs->new());
$chosen = $actions->formatAsString();

Assert::assert(__FILE__,__LINE__, $chosen =~ /Test0:/o);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Test1:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Main0:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Main1:/o);

$actionees = $actions->getActionees();
Assert::assert(__FILE__,__LINE__, defined($actionees->{"Main.Sam"}));
Assert::assert(__FILE__,__LINE__, defined($actionees->{"Main.Fred"}));
Assert::assert(__FILE__,__LINE__, !defined($actionees->{"Blah.Joe"}));

$actions = ActionSet::allActionsInWeb("Main", ActionTrackerPlugin::Attrs->new() );
$chosen = $actions->formatAsString();

Assert::assert(__FILE__,__LINE__, $chosen !~ /Test0:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Test1:/o);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Main0:/o);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Main1:/o);

$actionees = $actions->getActionees();
Assert::assert(__FILE__,__LINE__, !defined($actionees->{"Main.Sam"}));
Assert::assert(__FILE__,__LINE__, defined($actionees->{"Main.Fred"}));
Assert::assert(__FILE__,__LINE__, defined($actionees->{"Blah.Joe"}));

$actions = $actions->search( "open" );
$chosen = $actions->formatAsString();
Assert::assert(__FILE__,__LINE__, $chosen !~ /Test0:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Test1:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Main0:/o);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Main1:/o);

$actions = ActionSet::allActionsInWeb("Test", ActionTrackerPlugin::Attrs->new() );
$actions = $actions->search( "late" );
$chosen = $actions->formatAsString();

Assert::assert(__FILE__,__LINE__, $chosen !~ /Test0:/o);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Test1:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Main0:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Main1:/o);

$actions = ActionSet::allActionsInWeb("Test", ActionTrackerPlugin::Attrs->new() );
$actions = $actions->search( "who=me" );
$chosen = $actions->formatAsString();
Assert::assert(__FILE__,__LINE__, $chosen !~ /Test0:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Test1:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Main0:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Main1:/o);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Test4:/o);

# Test on a "live" web
Action::forceTime(Time::ParseDate::parsedate("2 Jan 2002"));
#Assert::showProgress();
TWiki::TestMaker::purge();

TWiki::TestMaker::writeTopic("Test", "Topic1", "
%ACTION{who=Main.Sam,due=\"1 Jan 02\",open}% Test0: Sam_open_late");

TWiki::TestMaker::writeTopic("Test", "Topic2", "
%ACTION{who=Fred,due=\"1 Jan 02\",open}% Test1: Fred_open_ontime");

TWiki::TestMaker::writeTopic("Test", "WebNotify", "
   * Main.Fred - fred\@sesame.street.com
");

TWiki::TestMaker::writeTopic("Main", "Topic2", "
%ACTION{who=Main.Fred,due=\"1 Jan 02\",closed}% Main0: Fred_closed_ontime
%ACTION{who=Joe,due=\"29 Jan 2010\",open}% Main1: Joe_open_ontime
%ACTION{who=TheWholeBunch,due=\"29 Jan 2001\",open}% Main2: Joe_open_ontime");

TWiki::TestMaker::writeTopic("Main", "WebNotify", "
   * Main.Sam - sam\@sesame.street.com
");
TWiki::TestMaker::writeTopic("Main", "Joe", "
   * Email: joe\@sesame.street.com
");
TWiki::TestMaker::writeTopic("Main", "TheWholeBunch", "
   * Email: joe\@sesame.street.com
   * Email: fred\@sesame.street.com
   * Email: sam\@sesame.street.com
   * Main.GungaDin - gunga-din\@war_lords-home.ind
");

$actions = ActionSet::allActionsInWeb("Main", ActionTrackerPlugin::Attrs->new() );
$chosen = $actions->formatAsString();
Assert::assert(__FILE__,__LINE__, $chosen !~ /Test0:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Test1:/o);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Main0:/o);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Main1:/o);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Main2:/o);

$actions = ActionSet::allActionsInWeb("Test", ActionTrackerPlugin::Attrs->new() );
$chosen = $actions->formatAsString();
Assert::assert(__FILE__,__LINE__, $chosen =~ /Test0:/o);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Test1:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Main0:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Main1:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Main2:/o);

$actions = ActionSet::allActionsInWebs("Main", ActionTrackerPlugin::Attrs->new("web=\".*\""));
$actions->sort();
$chosen = $actions->formatAsString();

Assert::assert(__FILE__,__LINE__, $chosen =~ /Test0:/o);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Test1:/o);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Main0:/o);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Main1:/o);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Main2:/o);

# Make sure they are sorted correctly
Assert::assert(__FILE__,__LINE__, $chosen =~ /Main2:.*Test0:.*Test1:.*Main0:.*Main1:/so);

$actions = ActionSet::allActionsInWebs("Main", ActionTrackerPlugin::Attrs->new("web=\"T.*\""));
$chosen = $actions->formatAsString();

Assert::assert(__FILE__,__LINE__, $chosen =~ /Test0:/o);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Test1:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Main0:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Main1:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Main2:/o);

$actions = ActionSet::allActionsInWebs("Main", ActionTrackerPlugin::Attrs->new("web=\".*ain\""));
$chosen = $actions->formatAsString();

Assert::assert(__FILE__,__LINE__, $chosen !~ /Test0:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Test1:/o);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Main0:/o);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Main1:/o);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Main2:/o);

$actions = ActionSet::allActionsInWebs("Test", ActionTrackerPlugin::Attrs->new("topic=\".*1\""));
$chosen = $actions->formatAsString();
Assert::assert(__FILE__,__LINE__, $chosen =~ /Test0:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Test1:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Main0:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Main1:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Main2:/o);

$actions = ActionSet::allActionsInWebs("Main", ActionTrackerPlugin::Attrs->new("web=\"T.*\",topic=\".*1\""));
$chosen = $actions->formatAsString();
Assert::assert(__FILE__,__LINE__, $chosen =~ /Test0:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Test1:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Main0:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Main1:/o);
Assert::assert(__FILE__,__LINE__, $chosen !~ /Main2:/o);

1;
