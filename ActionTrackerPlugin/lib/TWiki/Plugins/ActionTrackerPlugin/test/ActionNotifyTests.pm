# Tests for module ActionNotify.pm
use lib ('fakewiki');
use lib ('../../../..');
use lib ('../../../../TWiki/Plugins');
use ActionTrackerPlugin::Action;
use ActionTrackerPlugin::ActionSet;
use ActionTrackerPlugin::ActionNotify;
use ActionTrackerPlugin::Attrs;
use ActionTrackerPlugin::Format;
use lib ('.');
use Assert;
use TWiki::TestMaker;
use TWiki::Func;

{ package ActionNotifyTests;

  sub setUp {
    ActionTrackerPlugin::Action::forceTime("2 Jan 2002");
    TWiki::TestMaker::init("ActionTrackerPlugin");

    TWiki::TestMaker::writeTopic("Test", "Topic1", "
%ACTION{who=Main.Sam,due=\"1 Jan 02\",open}% A0: Sam_open_late");
    TWiki::TestMaker::writeTopic("Test", "Topic2", "
%ACTION{who=Fred,due=\"1 Jan 02\",open}% A1: Fred_open_ontime");
    TWiki::TestMaker::writeTopic("Test", "WebNotify", "
   * Main.Fred - fred\@sesame.street.com
");

    TWiki::TestMaker::writeTopic("Main", "Topic2", "
%ACTION{who=Main.Fred,due=\"1 Jan 02\",closed}% A2: Fred_closed_ontime
%ACTION{who=Joe,due=\"29 Jan 2010\",open}% A3: Joe_open_ontime
%ACTION{who=TheWholeBunch,due=\"29 Jan 2001\",open}% A4: Joe_open_ontime");

    TWiki::TestMaker::writeTopic("Main", "WebNotify", "
   * Main.Sam - sam\@sesame.street.com
");
    TWiki::TestMaker::writeTopic("Main", "Joe", "
   * Email: joe\@sesame.street.com
");
    TWiki::TestMaker::writeTopic("Main", "TheWholeBunch", "
   * Email: joe\@sesame.street.com
   * Email: fred\@sesame.street.com
   * E-mail: sam\@sesame.street.com
   * Main.GungaDin - gunga-din\@war_lords-home.ind
");
    # Action changes are hard to fake because the RCS files are not there.
    TWiki::TestMaker::writeRcsTopic("Test", "ActionChanged", "head	1.2;
access;
symbols;
locks
	apache:1.2; strict;
comment	\@# \@;


1.2
date	2001.12.24.17.54.53;	author guest;	state Exp;
branches;
next	1.1;

1.1
date	2001.09.23.19.28.56;	author guest;	state Exp;
branches;
next	;


desc
\@none
\@


1.2
log
\@none
\@
text
\@%META:TOPICINFO{author=\"guest\" date=\"1032890093\" format=\"1.0\" version=\"1.2\"}%
%ACTION{who=Mowgli,due=\"22-jun-2002\",notify=RikkiTikkiTavi\@\@here.com}% Date change
%ACTION{who=Mowgli,due=\"22-jun-2002\",notify=RikkiTikkiTavi\@\@here.com}% Stuck in
%ACTION{who=RikkiTikkiTavi,due=\"22-jul-2001\",notify=Mowgli\@\@there.com}% Text change from original
\@


1.1
log
\@none
\@
text
\@d1 3
a3 3
%META:TOPICINFO{author=\"guest\" date=\"1032811587\" format=\"1.0\" version=\"1.1\"}%
%ACTION{who=Mowgli,due=\"22-jun-2001\",notify=RikkiTikkiTavi\@\@here.com}% Date change
%ACTION{who=RikkiTikkiTavi,due=\"22-jul-2001\",notify=Mowgli\@\@there.com}% Text change
\@
");
  }

  sub testNotablesInMain {
    my $notify = {};
    ActionTrackerPlugin::ActionNotify::_gatherNotablesFromWeb("Main", $notify );
    Assert::sEquals($notify->{"Sam"}, "sam\@sesame.street.com");
  }

  sub testNotablesInTest {
    my $notify = {};
    ActionTrackerPlugin::ActionNotify::_gatherNotablesFromWeb("Test", $notify );
    Assert::sEquals($notify->{"Fred"}, "fred\@sesame.street.com");
  }

  sub testAllNotables {
    my $notify = {};
    ActionTrackerPlugin::ActionNotify::_gatherNotables($notify);
    Assert::sEquals($notify->{"Sam"}, "sam\@sesame.street.com");
    Assert::sEquals($notify->{"Fred"}, "fred\@sesame.street.com");

    my $address = ActionTrackerPlugin::ActionNotify::_getMailAddress("Fred", $notify);
    Assert::sEquals($address, "fred\@sesame.street.com");
    $address = ActionTrackerPlugin::ActionNotify::_getMailAddress("Sam", $notify);
    Assert::sEquals($address, "sam\@sesame.street.com");
    $address = ActionTrackerPlugin::ActionNotify::_getMailAddress("Joe", $notify);
    Assert::sEquals($address, "joe\@sesame.street.com");
    $address = ActionTrackerPlugin::ActionNotify::_getMailAddress("TheWholeBunch", $notify);
    Assert::sEquals($address, 
		    "joe\@sesame.street.com,fred\@sesame.street.com,sam\@sesame.street.com,gunga-din\@war_lords-home.ind");
  }

  sub testWholeShebang {
    # Do the whole shebang; the output generation is rather dependent on the
    # correct format of the template, however...
    ActionTrackerPlugin::ActionNotify::actionNotify( "late" );
    Assert::equals(scalar(@TWiki::Net::sent), 3);
    my $html = shift(@TWiki::Net::sent);

    Assert::sContains($html, "From: mailsender");
    Assert::sContains($html, "To: joe\@sesame.street.com,fred\@sesame.street.com,sam\@sesame.street.com,gunga-din\@war_lords-home.ind");
    Assert::sContains($html, "Subject: Outstanding actions on mailsender");
    Assert::htmlContains($html, "<table border=\"$ActionTrackerPlugin::Format::border\"><tr bgcolor=\"$ActionTrackerPlugin::Format::hdrcol\"><th> Assigned to </th><th> Due date </th><th> Description </th><th> State </th><th>&nbsp;</th></tr><tr valign=\"top\"><td> Main.TheWholeBunch </td><td bgcolor=\"$ActionTrackerPlugin::Format::latecol\"> Mon, 29 Jan 2001 (LATE) </td><td> [[Main.Topic2#AcTion2][ A4: Joe_open_ontime ]] </td><td> open </td><td> <a href=\"scripturl/edit.cgi/Main/Topic2?skin=action&action=AcTion2\">edit</a> </td></tr></table>");
    Assert::sContains($html, "Action for Main.TheWholeBunch, due Mon, 29 Jan 2001 (LATE), open");
    $html = shift(@TWiki::Net::sent);
    Assert::sContains($html, "From: mailsender");
    Assert::sContains($html, "To: sam\@sesame.street.com");
    Assert::sContains($html, "Subject: Outstanding actions on mailsender");
    Assert::htmlContains($html, "<table border=\"$ActionTrackerPlugin::Format::border\"><tr bgcolor=\"$ActionTrackerPlugin::Format::hdrcol\"><th> Assigned to </th><th> Due date </th><th> Description </th><th> State </th><th>&nbsp;</th></tr><tr valign=\"top\"><td> Main.Sam </td><td bgcolor=\"$ActionTrackerPlugin::Format::latecol\"> Tue, 1 Jan 2002 (LATE) </td><td> [[Test.Topic1#AcTion0][ A0: Sam_open_late ]] </td><td> open </td><td> <a href=\"scripturl/edit.cgi/Test/Topic1?skin=action&action=AcTion0\">edit</a> </td></tr>
</table>");
    $html = shift(@TWiki::Net::sent);
    Assert::sContains($html, "From: mailsender");
    Assert::sContains($html, "To: fred\@sesame.street.com");
    Assert::sContains($html, "Subject: Outstanding actions on mailsender");
    Assert::htmlContains($html, "<table border=\"$ActionTrackerPlugin::Format::border\"><tr bgcolor=\"$ActionTrackerPlugin::Format::hdrcol\"><th> Assigned to </th><th> Due date </th><th> Description </th><th> State </th><th>&nbsp;</th></tr><tr valign=\"top\"><td> Main.Fred </td><td bgcolor=\"$ActionTrackerPlugin::Format::latecol\"> Tue, 1 Jan 2002 (LATE) </td><td> [[Test.Topic2#AcTion0][ A1: Fred_open_ontime ]] </td><td> open </td><td> <a href=\"scripturl/edit.cgi/Test/Topic2?skin=action&action=AcTion0\">edit</a> </td></tr>
</table>");
    Assert::sContains($html, "Action for Main.Fred, due Tue, 1 Jan 2002 (LATE), open");
  }

  sub testChangedSince {
    ActionTrackerPlugin::ActionNotify::actionNotify( "changedsince=\"1 dec 2001\"" );
    my $html = shift(@TWiki::Net::sent);
    Assert::sContains($html, "From: mailsender");
    Assert::sContains($html, "To: Mowgli\@there.com");
    Assert::sContains($html, "Subject: Changes to actions on mailsender");
    Assert::sContains($html, "Changes to actions since Sat Dec  1 00:00:00 2001");
    Assert::htmlContains($html, "<tr><td>text</td><td> Text change</td><td> Text change from original</td></tr>");
    Assert::sContains($html, "Action for Main.RikkiTikkiTavi, due Sun, 22 Jul 2001 (LATE), open\n");
    Assert::sContains($html, "Attribute \"text\" changed, was \"Text change\", now \"Text change from original\"");

    $html = shift(@TWiki::Net::sent);
    Assert::sContains($html, "From: mailsender");
    Assert::sContains($html, "To: RikkiTikkiTavi\@here.com");
    Assert::sContains($html, "Subject: Changes to actions on mailsender");
    Assert::sContains($html, "Changes to actions since Sat Dec  1 00:00:00 2001");
    Assert::htmlContains($html, "<td> Main.Mowgli </td>");
    Assert::htmlContains($html, "<tr><td>due</td><td>Fri, 22 Jun 2001 (LATE)</td><td>Sat, 22 Jun 2002</td></tr>");
    Assert::equals(scalar(@TWiki::Net::sent), 0);
  }
}

1;
