# Tests for module Action.pm
use lib ('fakewiki');
use lib ('.');
use lib ('..');
use lib ('../../../..');
use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::Attrs;
use Assert;
use Time::ParseDate;

$action = Action->new( "Test", "Topic", 0, "who=Fred,due=\"2 Jun 02\",state=open", "A new action");
# check lateness
Action::forceTime(Time::ParseDate::parsedate("31 May 2002"));
Assert::assert(__FILE__,__LINE__, !$action->isLate());
Action::forceTime(Time::ParseDate::parsedate("1 Jun 2002 24:59:59"));
Assert::assert(__FILE__,__LINE__, !$action->isLate());
Action::forceTime(Time::ParseDate::parsedate("2 Jun 2002 00:00:01"));
Assert::assert(__FILE__,__LINE__, $action->isLate());
# make it late
Action::forceTime(Time::ParseDate::parsedate("3 Jun 2002"));
Assert::assert(__FILE__,__LINE__, $action->isLate());
Assert::assert(__FILE__,__LINE__, $action->matches(ActionTrackerPlugin::Attrs->new("late")));
Assert::assert(__FILE__,__LINE__, $action->daysToGo() == -1);
Assert::sEquals(__FILE__,__LINE__, $action->formatAsString(),
"Test.Topic/0: Open action for Main.Fred, due Sun, 2 Jun 2002 (LATE): A new action ");
Assert::htmlContains(__FILE__,__LINE__, $action->formatAsTableData( "href" ),
"<td> Main.Fred </td><td bgcolor=$Action::latecol> Sun, 2 Jun 2002 </td><td> [[Test.Topic#AcTion0][ A new action ]] </td><td> open </td>");
Assert::htmlContains(__FILE__,__LINE__, $action->formatAsTableData( "name" ),
"<td> Main.Fred </td><td bgcolor=$Action::latecol> Sun, 2 Jun 2002 </td><td> <A name=\"AcTion0\"></A> A new action </td><td> open </td>");

# Check late actions for Fred
$attrs = ActionTrackerPlugin::Attrs->new("who=Fred");
Assert::assert(__FILE__,__LINE__, $action->matches($attrs));
$attrs = ActionTrackerPlugin::Attrs->new("who=Main.Fred");
Assert::assert(__FILE__,__LINE__, $action->matches($attrs));
$attrs = ActionTrackerPlugin::Attrs->new("who=Joe");
Assert::assert(__FILE__,__LINE__, !$action->matches($attrs));
$attrs = ActionTrackerPlugin::Attrs->new("who=Main.Joe");
Assert::assert(__FILE__,__LINE__, !$action->matches($attrs));

# make it on-time
Action::forceTime(Time::ParseDate::parsedate("1 Jun 2002"));
Assert::assert(__FILE__,__LINE__, !$action->isLate());
$attrs = ActionTrackerPlugin::Attrs->new("late");
Assert::assert(__FILE__,__LINE__, !$action->matches($attrs));
Assert::assert(__FILE__,__LINE__, $action->daysToGo() == 1);
Assert::sEquals(__FILE__,__LINE__, $action->formatAsString(),
"Test.Topic/0: Open action for Main.Fred, due Sun, 2 Jun 2002: A new action ");

# Make it within 3 days
Action::forceTime(Time::ParseDate::parsedate("30 May 2002"));
Assert::assert(__FILE__,__LINE__, $action->daysToGo() == 3);
Assert::assert(__FILE__,__LINE__, $action->matches(ActionTrackerPlugin::Attrs->new("within=3")));
Assert::assert(__FILE__,__LINE__, !$action->matches(ActionTrackerPlugin::Attrs->new("within=2")));

$text = "
%ACTION{who=One,due=\"30 May 2002\"}% AOne
%ACTION{who=Two,due=\"30 May 2002\"}% ATwo\r
%ACTION{who=Three,due=\"30 May 2002\"}% AThree
\r%ACTION{who=Four,due=\"30 May 2002\"}% AFour";

($action,$pre,$post) = Action::findNthAction("Test", "Topic", $text, 0);
Assert::sEquals(__FILE__,__LINE__, $action->text(), "AOne");
($action,$pre,$post) = Action::findNthAction("Test", "Topic", $text, 1);
Assert::sEquals(__FILE__,__LINE__, $action->text(), "ATwo");
($action,$pre,$post) = Action::findNthAction("Test", "Topic", $text, 2);
Assert::sEquals(__FILE__,__LINE__, $action->text(), "AThree");
($action,$pre,$post) = Action::findNthAction("Test", "Topic", $text, 3);
Assert::sEquals(__FILE__,__LINE__, $action->text(), "AFour");

1;
