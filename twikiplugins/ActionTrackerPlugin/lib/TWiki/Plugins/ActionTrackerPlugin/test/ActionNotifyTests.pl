# Tests for module ActionNotify.pm
use lib ('fakewiki');
use lib ('../../../..');
use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::ActionSet;
use TWiki::Plugins::ActionTrackerPlugin::ActionNotify;
use TWiki::Plugins::ActionTrackerPlugin::Attrs;
use lib ('.');
use Assert;
use TWiki::TestMaker;
use TWiki::Func;

Action::forceTime(Time::ParseDate::parsedate("2 Jan 2002"));
#Assert::showProgress();
TWiki::TestMaker::init();

TWiki::TestMaker::writeTopic("Test", "Topic1", "
%ACTION{who=Main.Sam,due=\"1 Jan 02\",open}% A0: Sam_open_late");
TWiki::TestMaker::writeTopic("Test", "Topic2", "
%ACTION{who=Fred,due=\"1 Jan 02\",open}% A1: Fred_open_ontime");
TWiki::TestMaker::writeTopic("Test", "WebNotify", "
   * Main.Fred - fred\@sesame.street.com
");
TWiki::TestMaker::writeTopic("Test", "Topic2", "
%ACTION{who=Fred,due=\"1 Jan 02\",open}% A1: Fred_open_ontime");

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

$notify = {};
ActionNotify::_gatherNotablesFromWeb("Main", $notify );
Assert::assert(__FILE__,__LINE__, $notify->{"Sam"} eq "sam\@sesame.street.com");

$notify = {};
ActionNotify::_gatherNotablesFromWeb("Test", $notify );
Assert::assert(__FILE__,__LINE__, $notify->{"Fred"} eq "fred\@sesame.street.com");

$notify = {};
ActionNotify::_gatherNotables($notify);
Assert::assert(__FILE__,__LINE__, $notify->{"Sam"} eq "sam\@sesame.street.com");
Assert::assert(__FILE__,__LINE__, $notify->{"Fred"} eq "fred\@sesame.street.com");

$address = ActionNotify::_getMailAddress("Fred", $notify);
Assert::assert(__FILE__,__LINE__, $address eq "fred\@sesame.street.com");
$address = ActionNotify::_getMailAddress("Sam", $notify);
Assert::assert(__FILE__,__LINE__, $address eq "sam\@sesame.street.com");
$address = ActionNotify::_getMailAddress("Joe", $notify);
Assert::assert(__FILE__,__LINE__, $address eq "joe\@sesame.street.com");
$address = ActionNotify::_getMailAddress("TheWholeBunch", $notify);
Assert::assert(__FILE__,__LINE__, $address eq 
"joe\@sesame.street.com,fred\@sesame.street.com,sam\@sesame.street.com,gunga-din\@war_lords-home.ind");

# Do the whole shebang; the output generation is rather dependent on the
# correct format of the template, however...
ActionNotify::actionNotify( "state=late" );
Assert::assert(__FILE__,__LINE__, scalar(@TWiki::Net::sent) == 3);
$html = shift(@TWiki::Net::sent);
Assert::sContains(__FILE__,__LINE__, $html, "From: PREFS(WIKIWEBMASTER)");
Assert::sContains(__FILE__,__LINE__, $html, "To: joe\@sesame.street.com,fred\@sesame.street.com,sam\@sesame.street.com,gunga-din\@war_lords-home.ind");
Assert::sContains(__FILE__,__LINE__, $html, "Subject: Outstanding actions on PREFS(WIKITOOLNAME)");
Assert::htmlContains(__FILE__,__LINE__, $html, "<table border=$Action::border>
<tr bgcolor=$Action::hdrcol><th>Assignee</th><th>Due date</th><th>Description</th><th>State</th><th>&nbsp;</th></tr>
<tr valign=\"top\"><td> Main.TheWholeBunch </td><td bgcolor=$Action::latecol> Mon, 29 Jan 2001 </td><td> [[Main.Topic2#AcTion2][ A4: Joe_open_ontime ]] </td><td> open </td><td><A href=\"PREFS(SCRIPTURLPATH)/editactionPREFS(SCRIPTSUFFIX)/Main/Topic2?action=2\">edit</a></td></tr></table>");
$html = shift(@TWiki::Net::sent);
Assert::sContains(__FILE__,__LINE__, $html, "From: PREFS(WIKIWEBMASTER)");
Assert::sContains(__FILE__,__LINE__, $html, "To: sam\@sesame.street.com");
Assert::sContains(__FILE__,__LINE__, $html, "Subject: Outstanding actions on PREFS(WIKITOOLNAME)");
Assert::htmlContains(__FILE__,__LINE__, $html, "<table border=$Action::border>
<tr bgcolor=$Action::hdrcol><th>Assignee</th><th>Due date</th><th>Description</th><th>State</th><th>&nbsp;</th></tr>
<tr valign=\"top\"><td> Main.Sam </td><td bgcolor=$Action::latecol> Tue, 1 Jan 2002 </td><td> [[Test.Topic1#AcTion0][ A0: Sam_open_late ]] </td><td> open </td><td><A href=\"PREFS(SCRIPTURLPATH)/editactionPREFS(SCRIPTSUFFIX)/Test/Topic1?action=0\">edit</a></td></tr>
</table>");
$html = shift(@TWiki::Net::sent);
Assert::sContains(__FILE__,__LINE__, $html, "From: PREFS(WIKIWEBMASTER)");
Assert::sContains(__FILE__,__LINE__, $html, "To: fred\@sesame.street.com");
Assert::sContains(__FILE__,__LINE__, $html, "Subject: Outstanding actions on PREFS(WIKITOOLNAME)");
Assert::htmlContains(__FILE__,__LINE__, $html, "<table border=$Action::border>
<tr bgcolor=$Action::hdrcol><th>Assignee</th><th>Due date</th><th>Description</th><th>State</th><th>&nbsp;</th></tr>
<tr valign=\"top\"><td> Main.Fred </td><td bgcolor=$Action::latecol> Tue, 1 Jan 2002 </td><td> [[Test.Topic2#AcTion0][ A1: Fred_open_ontime ]] </td><td> open </td><td><A href=\"PREFS(SCRIPTURLPATH)/editactionPREFS(SCRIPTSUFFIX)/Test/Topic2?action=0\">edit</a></td></tr>
</table>");

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
ActionNotify::actionNotify( "changedsince=\"1 dec 2001\"" );
$html = shift(@TWiki::Net::sent);
Assert::sContains(__FILE__,__LINE__, $html, "From: PREFS(WIKIWEBMASTER)");
Assert::sContains(__FILE__,__LINE__, $html, "To: Mowgli\@there.com");
Assert::sContains(__FILE__,__LINE__, $html, "Subject: Changed actions on PREFS(WIKITOOLNAME)");
Assert::sContains(__FILE__,__LINE__, $html, "Actions that have changed since Sat Dec  1 00:00:00 2001");
Assert::htmlContains(__FILE__,__LINE__, $html, "<table><td> Main.RikkiTikkiTavi </td><td bgcolor=yellow> Sun, 22 Jul 2001 </td><td> [[Test.ActionChanged#AcTion2][  Text change from original ]]  </td><td> open </td><td><A href=\"PREFS(SCRIPTURLPATH)/editactionPREFS(SCRIPTSUFFIX)/Test/ActionChanged?action=2\">edit</a></td></table>Text appended ... from original");
$html = shift(@TWiki::Net::sent);
Assert::sContains(__FILE__,__LINE__, $html, "From: PREFS(WIKIWEBMASTER)");
Assert::sContains(__FILE__,__LINE__, $html, "To: RikkiTikkiTavi\@here.com");
Assert::sContains(__FILE__,__LINE__, $html, "Subject: Changed actions on PREFS(WIKITOOLNAME)");
Assert::sContains(__FILE__,__LINE__, $html, "Actions that have changed since Sat Dec  1 00:00:00 2001");
Assert::htmlContains(__FILE__,__LINE__, $html, "<table><td> Main.Mowgli </td><td> Sat, 22 Jun 2002 </td><td> [[Test.ActionChanged#AcTion0][  Date change ]]  </td><td> open </td><td><A href=\"PREFS(SCRIPTURLPATH)/editactionPREFS(SCRIPTSUFFIX)/Test/ActionChanged?action=0\">edit</a></td></table>	*Due date changed from *Fri, 22 Jun 2001* to *Sat, 22 Jun 2002*");

1;

