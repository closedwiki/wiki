use lib ('fakewiki');
use lib ('../../../..');
use TWiki::Plugins::ActionTrackerPlugin;
use Assert;
use TWiki::TestMaker;
use TWiki::Func;

# Tests for all ActionTracker submodules

$result = `perl ActionTests.pl`;
die $result if $result;
$result = `perl ActionSetTests.pl`;
die $result if $result;
$result= `perl ActionNotifyTests.pl`;
die $result if $result;

print "Starting ActionTrackerPluginTests\n";

TWiki::TestMaker::init();
#Assert::showProgress();

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

Action::forceTime(Time::ParseDate::parsedate("3 Jun 2002"));

$chosen = TWiki::Plugins::ActionTrackerPlugin::handleActionSearch("Main", "web=\".*\"");
Assert::assert(__FILE__,__LINE__, $chosen =~ /Test0:/);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Test1:/);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Main0:/);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Main1:/);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Main2:/);

$chosen = "
Before
%ACTION{who=Zero,due=\"11 jun 1993\"}% Finagle0: Zeroth action
%ACTIONSEARCH{web=\".*\"}%
%ACTION{who=One,due=\"11 jun 1993\"}% Finagle1: Oneth action
After
";

TWiki::Plugins::ActionTrackerPlugin::commonTagsHandler($chosen, "Finagle", "Main");

Assert::assert(__FILE__,__LINE__, $chosen =~ /Test0:/);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Test1:/);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Main0:/);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Main1:/);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Main2:/);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Finagle0:/);
Assert::assert(__FILE__,__LINE__, $chosen =~ /Finagle1:/);

$text = "%ACTION{who=ActorOne, due=11/01/02}% __Unknown__ =status= www.twiki.org
   %ACTION{who=Main.ActorTwo,due=\"Mon, 11 Mar 2002\",closed}% Open <table><td>status<td>status2</table>
text %ACTION{who=Main.ActorThree,due=\"Sun, 11 Mar 2001\",closed}%The *world* is flat
%ACTION{who=Main.ActorFour,due=\"Sun, 11 Mar 2001\",open}% _Late_ the late great *date*
%ACTION{who=Main.ActorFiveVeryLongNameBecauseItsATest,due=\"Wed, 13 Feb 2002\",open}% This is an action with a lot of associated text to test <br>   * the VingPazingPoodleFactor, <br>   * when large actions get edited by the edit button.<br>   * George Bush is a brick.<br>   * Who should really be built<br>   * Into a very high wall.
%ACTION{who=ActorSix, due=11 2 03,open}% Bad date
break the table here %ACTION{who=ActorSeven,due=01/01/02,open}% Create the mailer, %USERNAME%

   * A list
   * should generate %ACTION{who=ActorEight,due=01/01/02}% Create the mailer
   * endofthelist

   * A list
   * should generate %ACTION{who=ActorNine,due=01/01/02,closed}% Create the mailer";

TWiki::Plugins::ActionTrackerPlugin::commonTagsHandler($text, "TheTopic", "TheWeb");

Assert::htmlEquals(__FILE__,__LINE__, $text, "<table border=$Action::border>
<tr bgcolor=\"$Action::hdrcol\"><th>Assignee</th><th>Due date</th><th>Description</th><th>State</th><th>&nbsp;</th></tr>
<tr valign=\"top\"><td> Main.ActorOne </td><td> Fri, 1 Nov 2002 </td><td> <A name=\"AcTion0\"></A>  __Unknown__ =status= www.twiki.org </td><td> open </td><td><A href=\"%SCRIPTURLPATH%/editaction%SCRIPTSUFFIX%/TheWeb/TheTopic?action=0\">edit</a></td></tr>
<tr valign=\"top\"><td> Main.ActorTwo </td><td> Mon, 11 Mar 2002 </td><td> <A name=\"AcTion1\"></A>  Open <table><td>status<td>status2</table> </td><td> closed </td><td><A href=\"%SCRIPTURLPATH%/editaction%SCRIPTSUFFIX%/TheWeb/TheTopic?action=1\">edit</a></td></tr>
</table>

text <table border=$Action::border>
<tr bgcolor=\"$Action::hdrcol\"><th>Assignee</th><th>Due date</th><th>Description</th><th>State</th><th>&nbsp;</th></tr>
<tr valign=\"top\"><td> Main.ActorThree </td><td> Sun, 11 Mar 2001 </td><td> <A name=\"AcTion2\"></A> The *world* is flat </td><td> closed </td><td><A href=\"%SCRIPTURLPATH%/editaction%SCRIPTSUFFIX%/TheWeb/TheTopic?action=2\">edit</a></td></tr>
<tr valign=\"top\"><td> Main.ActorFour </td><td bgcolor=\"$Action::latecol\"> Sun, 11 Mar 2001 </td><td> <A name=\"AcTion3\"></A>  _Late_ the late great *date* </td><td> open </td><td><A href=\"%SCRIPTURLPATH%/editaction%SCRIPTSUFFIX%/TheWeb/TheTopic?action=3\">edit</a></td></tr>
<tr valign=\"top\"><td> Main.ActorFiveVeryLongNameBecauseItsATest </td><td bgcolor=\"$Action::latecol\"> Wed, 13 Feb 2002 </td><td> <A name=\"AcTion4\"></A>  This is an action with a lot of associated text to test \n   * the VingPazingPoodleFactor, \n   * when large actions get edited by the edit button.\n   * George Bush is a brick.\n   * Who should really be built\n   * Into a very high wall. </td><td> open </td><td><A href=\"%SCRIPTURLPATH%/editaction%SCRIPTSUFFIX%/TheWeb/TheTopic?action=4\">edit</a></td></tr>
<tr valign=\"top\"><td> Main.ActorSix </td><td bgcolor=\"$Action::badcol\"> BAD DATE FORMAT see Plugins.ActionTrackerPlugin#DateFormats </td><td> <A name=\"AcTion5\"></A>  Bad date </td><td> open </td><td><A href=\"%SCRIPTURLPATH%/editaction%SCRIPTSUFFIX%/TheWeb/TheTopic?action=5\">edit</a></td></tr>
</table>

break the table here <table border=$Action::border>
<tr bgcolor=\"$Action::hdrcol\"><th>Assignee</th><th>Due date</th><th>Description</th><th>State</th><th>&nbsp;</th></tr><tr valign=\"top\"><td> Main.ActorSeven </td><td bgcolor=\"$Action::latecol\"> Tue, 1 Jan 2002 </td><td> <A name=\"AcTion6\"></A>  Create the mailer, %USERNAME% </td><td> open </td><td><A href=\"%SCRIPTURLPATH%/editaction%SCRIPTSUFFIX%/TheWeb/TheTopic?action=6\">edit</a></td></tr>
</table>

   * A list
   * should generate <table border=$Action::border><tr bgcolor=\"$Action::hdrcol\"><th>Assignee</th><th>Due date</th><th>Description</th><th>State</th><th>&nbsp;</th></tr><tr valign=\"top\"><td> Main.ActorEight </td><td bgcolor=\"$Action::latecol\"> Tue, 1 Jan 2002 </td><td> <A name=\"AcTion7\"></A>  Create the mailer </td><td> open </td><td><A href=\"%SCRIPTURLPATH%/editaction%SCRIPTSUFFIX%/TheWeb/TheTopic?action=7\">edit</a></td></tr></table>
   * endofthelist

   * A list
   * should generate <table border=$Action::border><tr bgcolor=\"$Action::hdrcol\"><th>Assignee</th><th>Due date</th><th>Description</th><th>State</th><th>&nbsp;</th></tr><tr valign=\"top\"><td> Main.ActorNine </td><td> Tue, 1 Jan 2002 </td><td> <A name=\"AcTion8\"></A>  Create the mailer </td><td> closed </td><td><A href=\"%SCRIPTURLPATH%/editaction%SCRIPTSUFFIX%/TheWeb/TheTopic?action=8\">edit</a></td></tr></table>");

1;
