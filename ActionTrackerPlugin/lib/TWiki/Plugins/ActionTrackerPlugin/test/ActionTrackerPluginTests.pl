use lib ('fakewiki');
use lib ('../../../..');
use TWiki::Plugins::ActionTrackerPlugin;
use Assert;
use TWiki::TestMaker;
use TWiki::Func;

#Assert::showProgress();
# Tests for all ActionTracker submodules
$TWiki::Plugins::VERSION=2;
$result = `perl ActionTests.pl`;
die $result if $result;
$result = `perl ActionSetTests.pl`;
die $result if $result;
$result= `perl ActionNotifyTests.pl`;
die $result if $result;

TWiki::TestMaker::init("ActionTrackerPlugin");

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
TWiki::Plugins::ActionTrackerPlugin::initPlugin("Topic","Web","User","Blah");

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

$text = "%ACTION{uid=\"UidOnFirst\" who=ActorOne, due=11/01/02}% __Unknown__ =status= www.twiki.org
   %ACTION{who=Main.ActorTwo,due=\"Mon, 11 Mar 2002\",closed}% Open <table><td>status<td>status2</table>
text %ACTION{who=Main.ActorThree,due=\"Sun, 11 Mar 2001\",closed}%The *world* is flat
%ACTION{who=Main.ActorFour,due=\"Sun, 11 Mar 2001\",open}% _Late_ the late great *date*
%ACTION{who=Main.ActorFiveVeryLongNameBecauseItsATest,due=\"Wed, 13 Feb 2002\",open}% This is an action with a lot of associated text to test <br />   * the VingPazingPoodleFactor, <br />   * when large actions get edited by the edit button.<br />   * George Bush is a brick.<br />   * Who should really be built<br />   * Into a very high wall.
%ACTION{who=ActorSix, due=11 2 03,open}% Bad date
break the table here %ACTION{who=ActorSeven,due=01/01/02,open}% Create the mailer, %USERNAME%

   * A list
   * %ACTION{who=ActorEight,due=01/01/02}% Create the mailer
   * endofthelist

   * Another list
   * should generate %ACTION{who=ActorNine,due=01/01/02,closed}% Create the mailer";

TWiki::Plugins::ActionTrackerPlugin::commonTagsHandler($text, "TheTopic", "TheWeb");

$tblhdr = "<table border=$Action::border><tr bgcolor=\"$Action::hdrcol\"><th> Assigned to </th><th> Due date </th><th> Description </th><th> State </th><th>&nbsp;</th></tr>";

Assert::htmlEquals(__FILE__,__LINE__, $text, "$tblhdr".
action("UidOnFirst","Main.ActorOne",undef,"Fri, 1 Nov 2002","__Unknown__ =status= www.twiki.org","open").
action("AcTion1","Main.ActorTwo",undef,"Mon, 11 Mar 2002","Open <table><td>status<td>status2</table>","closed")."</table>
text $tblhdr".
action("AcTion2","Main.ActorThree",undef,"Sun, 11 Mar 2001","The *world* is flat","closed").
action("AcTion3","Main.ActorFour",$Action::latecol,"Sun, 11 Mar 2001 (LATE)","_Late_ the late great *date*","open").
action("AcTion4","Main.ActorFiveVeryLongNameBecauseItsATest",$Action::latecol,"Wed, 13 Feb 2002 (LATE)","This is an action with a lot of associated text to test <br />   * the VingPazingPoodleFactor, <br />   * when large actions get edited by the edit button.<br />   * George Bush is a brick.<br />   * Who should really be built<br />   * Into a very high wall.","open").
action("AcTion5","Main.ActorSix",$Action::badcol,"BAD DATE FORMAT see Plugins.ActionTrackerPlugin#DateFormats","Bad date","open")."</table>
break the table here $tblhdr".
action("AcTion6","Main.ActorSeven",$Action::latecol,"Tue, 1 Jan 2002 (LATE)","Create the mailer, %USERNAME%","open")."</table>

   * A list
   * $tblhdr".
action("AcTion7","Main.ActorEight",$Action::latecol,"Tue, 1 Jan 2002 (LATE)","Create the mailer","open")."</table>
   * endofthelist

   * Another list
   * should generate $tblhdr".
action("AcTion8","Main.ActorNine",undef,"Tue, 1 Jan 2002","Create the mailer","closed")."</table>");

sub anchor {
  my $tag = shift;
  return "<a name=\"$tag\"></a>";
}

sub edit {
  my $tag = shift;
  return "<a href=\"%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/TheWeb/TheTopic?skin=action&action=$tag\" onClick=\"return editWindow('%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/TheWeb/TheTopic?skin=action&action=$tag')\">edit</a>";
}

sub action {
  my ($anch, $actor, $col, $date, $txt, $state) = @_;

  my $text = "<tr valign=\"top\">".anchor($anch);
  $text .= "<td> $actor </td><td";
  $text .= " bgcolor=\"$col\"" if ($col);
  $text .= "> $date </td><td> $txt </td><td> $state </td><td> ".
    edit($anch)." </td></tr>";
  return $text;
}

1;
