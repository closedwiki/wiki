# Tests for module ActionNotify.pm
use lib ('fakewiki');
use lib ('../../../..');
use TWiki::Plugins::ActionTrackerPlugin;
use Assert;
use TWiki::TestMaker;

{ package ActionTrackerPluginTests;

  sub setUp {
    $TWiki::Plugins::VERSION=2;
    TWiki::TestMaker::init("ActionTrackerPlugin");
    ActionTrackerPlugin::Action::forceTime("3 Jun 2002");
    TWiki::Plugins::ActionTrackerPlugin::initPlugin("Topic","Web","User","Blah");

    TWiki::TestMaker::writeTopic("Test", "Topic1", "
%ACTION{who=Main.Sam,due=\"3 Jan 02\",open}% Test0: Sam_open_late");

    TWiki::TestMaker::writeTopic("Test", "Topic2", "
%ACTION{who=Fred,due=\"2 Jan 02\",open}% Test1: Fred_open_ontime");

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
  }

  sub testActionSearchFn {
    my $chosen = TWiki::Plugins::ActionTrackerPlugin::handleActionSearch("Main", "web=\".*\"");
    Assert::assert($chosen =~ /Test0:/);
    Assert::assert($chosen =~ /Test1:/);
    Assert::assert($chosen =~ /Main0:/);
    Assert::assert($chosen =~ /Main1:/);
    Assert::assert($chosen =~ /Main2:/);
    $chosen =~ s/^.*?\[ ((Main|Test)\d:)//so;
    Assert::sEquals($1, "Main2:");
    $chosen =~ s/^.*?\[ ((Main|Test)\d:)//so;
    Assert::sEquals($1, "Main0:");
    $chosen =~ s/^.*?\[ ((Main|Test)\d:)//so;
    Assert::sEquals($1, "Test1:");
    $chosen =~ s/^.*?\[ ((Main|Test)\d:)//so;
    Assert::sEquals($1, "Test0:");
    $chosen =~ s/^.*?\[ ((Main|Test)\d:)//so;
    Assert::sEquals($1, "Main1:");
  }

  sub testActionSearchFnSorted {
    my $chosen = TWiki::Plugins::ActionTrackerPlugin::handleActionSearch("Main", "web=\".*\" sort=\"state,who\"");
    Assert::assert($chosen =~ /Test0:/);
    Assert::assert($chosen =~ /Test1:/);
    Assert::assert($chosen =~ /Main0:/);
    Assert::assert($chosen =~ /Main1:/);
    Assert::assert($chosen =~ /Main2:/);
    Assert::assert($chosen =~ /Main0:.*Test1:.*Main1:.*Test0:.*Main2:/so);
  }

  sub testActionSearchFormat {
    my $chosen = TWiki::Plugins::ActionTrackerPlugin::handleActionSearch("Main", "web=\".*\" who=Sam header=\"|Who|Due|\" format=\"|\$who|\$due|\"");
    Assert::sEquals($chosen, "<table border=\"1\"><tr bgcolor=\"orange\"><th>Who</th><th>Due</th></tr><tr valign=\"top\"><td>Main.Sam</td><td bgcolor=\"yellow\">Thu, 3 Jan 2002</td></tr></table>");
  }

  sub testCommonTagsHandler1 {
    my $chosen = "
Before
%ACTION{who=Zero,due=\"11 jun 1993\"}% Finagle0: Zeroth action
%ACTIONSEARCH{web=\".*\"}%
%ACTION{who=One,due=\"11 jun 1993\"}% Finagle1: Oneth action
After
";
    $TWiki::Plugins::ActionTrackerPlugin::pluginInitialized = 1;
    TWiki::Plugins::ActionTrackerPlugin::commonTagsHandler($chosen, "Finagle", "Main");

    Assert::assert($chosen =~ /Test0:/);
    Assert::assert($chosen =~ /Test1:/);
    Assert::assert($chosen =~ /Main0:/);
    Assert::assert($chosen =~ /Main1:/);
    Assert::assert($chosen =~ /Main2:/);
    Assert::assert($chosen =~ /Finagle0:/);
    Assert::assert($chosen =~ /Finagle1:/);
  }

  sub testCommonTagsHandler2 {
    my $text = "%ACTION{uid=\"UidOnFirst\" who=ActorOne, due=11/01/02}% __Unknown__ =status= www.twiki.org
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

    my $tblhdr = "<table border=\"$ActionTrackerPlugin::Format::border\"><tr bgcolor=\"$ActionTrackerPlugin::Format::hdrcol\"><th> Assigned to </th><th> Due date </th><th> Description </th><th> State </th><th>&nbsp;</th></tr>";

    Assert::htmlEquals
      (
       $text, "$tblhdr".
       action("UidOnFirst","Main.ActorOne",undef,"Fri, 1 Nov 2002","__Unknown__ =status= www.twiki.org","open").
       action("AcTion1","Main.ActorTwo",undef,"Mon, 11 Mar 2002","Open <table><td>status<td>status2</table>","closed")."</table>
text $tblhdr".
       action("AcTion2","Main.ActorThree",undef,"Sun, 11 Mar 2001","The *world* is flat","closed").
       action("AcTion3","Main.ActorFour",$ActionTrackerPlugin::Format::latecol,"Sun, 11 Mar 2001","_Late_ the late great *date*","open").
       action("AcTion4","Main.ActorFiveVeryLongNameBecauseItsATest",$ActionTrackerPlugin::Format::latecol,"Wed, 13 Feb 2002","This is an action with a lot of associated text to test <br />   * the VingPazingPoodleFactor, <br />   * when large actions get edited by the edit button.<br />   * George Bush is a brick.<br />   * Who should really be built<br />   * Into a very high wall.","open").
       action("AcTion5","Main.ActorSix",$ActionTrackerPlugin::Format::badcol,"BAD DATE FORMAT see Plugins.ActionTrackerPlugin#DateFormats","Bad date","open")."</table>
break the table here $tblhdr".
       action("AcTion6","Main.ActorSeven",$ActionTrackerPlugin::Format::latecol,"Tue, 1 Jan 2002","Create the mailer, %USERNAME%","open")."</table>

   * A list
   * $tblhdr".
       action("AcTion7","Main.ActorEight","yellow","Tue, 1 Jan 2002","Create the mailer","open")."</table>
   * endofthelist

   * Another list
   * should generate $tblhdr".
       action("AcTion8","Main.ActorNine",undef,"Tue, 1 Jan 2002","Create the mailer","closed")."</table>");
  }

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

  sub testBeforeEditHandler {
    my $q = new CGI("");
    $q->param(action=>"AcTion0");
    TWiki::Func::setQuery($q);
    # TODO: WRITE THIS TEST
  }

  sub testAfterEditHandler {
    my $q = new CGI("");
    $q->param(closeactioneditor=>1);
    $q->param(pretext=>"Before");
    $q->param(posttext=>"After");
    $q->param(who=>"AlexanderPope");
    $q->param(due=>"3 may 2009");
    $q->param(state=>"closed");
    # populate with edit fields
    TWiki::Func::setQuery($q);
    my $text = "%ACTION{}%";
    TWiki::Plugins::ActionTrackerPlugin::afterEditHandler($text,"Topic","Web");
    Assert::sEquals($text,"Before%ACTION{ state=\"closed\" creator=\"Main.TestRunner\" closer=\"Main.TestRunner\" closed=\"3-Jun-2002\" due=\"3-May-2009\" created=\"3-Jun-2002\" who=\"Main.AlexanderPope\" uid=\"WebTopic102153000n0\" }% No description
After");
  }

  sub testBeforeSaveHandler {
    my $q = new CGI("");
    $q->param(closeactioneditor=>1);
    TWiki::Func::setQuery($q);
    my $text = "%ACTION{}%";
    TWiki::Plugins::ActionTrackerPlugin::beforeSaveHandler($text,"Topic","Web");
    $text =~ s/ state=\"open\"//o;
    $text =~ s/ creator=\"Main.TestRunner\"//o;
    $text =~ s/ created=\"3-Jun-2002\"//o;
    $text =~ s/ due=\"3-Jun-2002\"//o;
    $text =~ s/ who=\"Main.TestRunner\"//o;
    $text =~ s/ uid=\"WebTopic102153000n0\"//o;
    $text =~ s/ No description//o;
    Assert::sEquals($text, "%ACTION{ }%");
  }
}

1;
