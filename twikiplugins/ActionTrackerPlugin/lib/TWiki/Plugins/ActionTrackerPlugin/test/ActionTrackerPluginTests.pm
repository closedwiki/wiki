use strict;

package ActionTrackerPluginTests;

use base qw(BaseFixture);

use TWiki::Plugins::ActionTrackerPlugin;
use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::ActionSet;
use TWiki::Plugins::ActionTrackerPlugin::Format;
use Time::ParseDate;

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

sub set_up {
  my $this = shift;
  $this->SUPER::set_up();

  BaseFixture::loadPreferencesFor("ActionTrackerPlugin");
  ActionTrackerPlugin::Action::forceTime("3 Jun 2002");

  BaseFixture::writeTopic("Test", "Topic1", "
%ACTION{who=Main.Sam,due=\"3 Jan 02\",open}% Test0: Sam_open_late");

  BaseFixture::writeTopic("Test", "Topic2", "
%ACTION{who=Fred,due=\"2 Jan 02\",open}% Test1: Fred_open_ontime");

  BaseFixture::writeTopic("Test", "WebNotify", "
   * Main.Fred - fred\@sesame.street.com
");

  BaseFixture::writeTopic("Test", "WebPreferences", "
   * Set ACTIONTRACKERPLUGIN_HEADERCOL = green
   * Set ACTIONTRACKERPLUGIN_EXTRAS = |plaintiffs,names,16|decision,text,16|sentencing,date|sentence,select,\"life\",\"5 years\",\"community service\"|
");

  BaseFixture::writeTopic("Main", "Topic2", "
%META:TOPICINFO{author=\"guest\" date=\"1053267450\" format=\"1.0\" version=\"1.35\"}%
%META:TOPICPARENT{name=\"WebHome\"}%
%ACTION{who=Main.Fred,due=\"1 Jan 02\",closed}% Main0: Fred_closed_ontime
%ACTION{who=Joe,due=\"29 Jan 2010\",open}% Main1: Joe_open_ontime
%ACTION{who=TheWholeBunch,due=\"29 Jan 2001\",open}% Main2: Joe_open_ontime
%META:FORM{name=\"ThisForm\"}%
%META:FIELD{name=\"Know.TopicClassification\" title=\"Know.TopicClassification\" value=\"Know.PublicSupported\"}%
%META:FIELD{name=\"Know.OperatingSystem\" title=\"Know.OperatingSystem\" value=\"Know.OsHPUX, Know.OsLinux\"}%
%META:FIELD{name=\"Know.OsVersion\" title=\"Know.OsVersion\" value=\"hhhhhh\"}%
");
  
  BaseFixture::writeTopic("Main", "WebNotify", "
   * Main.Sam - sam\@sesame.street.com
");
  BaseFixture::writeTopic("Main", "Joe", "
   * Email: joe\@sesame.street.com
");
  BaseFixture::writeTopic("Main", "TheWholeBunch", "
   * Email: joe\@sesame.street.com
   * Email: fred\@sesame.street.com
   * Email: sam\@sesame.street.com
   * Main.GungaDin - gunga-din\@war_lords-home.ind
");
  TWiki::Plugins::ActionTrackerPlugin::initPlugin("Topic","Test","User","Blah");
}

sub testActionSearchFn {
  my $this = shift;
  my $chosen = TWiki::Plugins::ActionTrackerPlugin::_handleActionSearch("Main", "web=\".*\"");
  $this->assert_matches(qr/Test0:/, $chosen);
  $this->assert_matches(qr/Test1:/, $chosen);
  $this->assert_matches(qr/Main0:/, $chosen);
  $this->assert_matches(qr/Main1:/, $chosen);
  $this->assert_matches(qr/Main2:/, $chosen);
  $chosen =~ s/<td> ((Main|Test)\d:)//so;
  $this->assert_str_equals( "Main2:", $1);
  $chosen =~ s/<td> ((Main|Test)\d:)//so;
  $this->assert_str_equals( "Main0:", $1);
  $chosen =~ s/<td> ((Main|Test)\d:)//so;
  $this->assert_str_equals( "Test1:", $1);
  $chosen =~ s/<td> ((Main|Test)\d:)//so;
  $this->assert_str_equals( "Test0:", $1);
  $chosen =~ s/<td> ((Main|Test)\d:)//so;
  $this->assert_str_equals( "Main1:", $1);
}

sub testActionSearchFnSorted {
  my $this = shift;
  my $chosen = TWiki::Plugins::ActionTrackerPlugin::_handleActionSearch("Main", "web=\".*\" sort=\"state,who\"");
  $this->assert_matches(qr/Test0:/, $chosen);
  $this->assert_matches(qr/Test1:/, $chosen);
  $this->assert_matches(qr/Main0:/, $chosen);
  $this->assert_matches(qr/Main1:/, $chosen);
  $this->assert_matches(qr/Main2:/, $chosen);
  $this->assert_matches(qr/Main0:.*Test1:.*Main1:.*Test0:.*Main2:/so, $chosen);
}

sub testActionSearchFormat {
  my $this = shift;
  my $chosen = TWiki::Plugins::ActionTrackerPlugin::_handleActionSearch("Main", "web=\".*\" who=Sam header=\"|Who|Due|\" format=\"|\$who|\$due|\" orient=rows");
  $chosen =~ s/\n//og;
  $this->assert_html_matches("<table border=\"1\"><tr><th bgcolor=\"$ActionTrackerPlugin::Format::hdrcol\">Who</th><td>Main.Sam</td></tr><tr><th bgcolor=\"$ActionTrackerPlugin::Format::hdrcol\">Due</th><td bgcolor=\"yellow\">Thu, 3 Jan 2002</td></tr></table>", $chosen);
}

sub test2CommonTagsHandler {
  my $this = shift;
  my $chosen = "
Before
%ACTION{who=Zero,due=\"11 jun 1993\"}% Finagle0: Zeroth action
%ACTIONSEARCH{web=\".*\"}%
%ACTION{who=One,due=\"11 jun 1993\"}% Finagle1: Oneth action
After
";
  $TWiki::Plugins::ActionTrackerPlugin::pluginInitialized = 1;
  TWiki::Plugins::ActionTrackerPlugin::commonTagsHandler($chosen, "Finagle", "Main");

  $this->assert_matches(qr/Test0:/, $chosen);
  $this->assert_matches(qr/Test1:/, $chosen);
  $this->assert_matches(qr/Main0:/, $chosen);
  $this->assert_matches(qr/Main1:/, $chosen);
  $this->assert_matches(qr/Main2:/, $chosen);
  $this->assert_matches(qr/Finagle0:/, $chosen);
  $this->assert_matches(qr/Finagle1:/, $chosen);
}

# Must be first test, because we check JavaScript handling here
sub test1CommonTagsHandler {
  my $this = shift;
  my $text = "
%ACTION{uid=\"UidOnFirst\" who=ActorOne, due=11/01/02}% __Unknown__ =status= www.twiki.org
   %ACTION{who=Main.ActorTwo,due=\"Mon, 11 Mar 2002\",closed}% Open <table><td>status<td>status2</table>
text %ACTION{who=Main.ActorThree,due=\"Sun, 11 Mar 2001\",closed}%The *world* is flat
%ACTION{who=Main.ActorFour,due=\"Sun, 11 Mar 2001\",open}% _Late_ the late great *date*
%ACTION{who=Main.ActorFiveVeryLongNameBecauseItsATest,due=\"Wed, 13 Feb 2002\",open}% <<EOF
This is an action with a lot of associated text to test
   * the VingPazingPoodleFactor,
   * Tony Blair is a brick.
   * Who should really be built
   * Into a very high wall.
EOF
%ACTION{who=ActorSix, due=\"11 2 03\",open}% Bad date
break the table here %ACTION{who=ActorSeven,due=01/01/02,open}% Create the mailer, %USERNAME%

   * A list
   * %ACTION{who=ActorEight,due=01/01/02}% Create the mailer
   * endofthelist

   * Another list
   * should generate %ACTION{who=ActorNine,due=01/01/02,closed}% Create the mailer";
  
  TWiki::Plugins::ActionTrackerPlugin::commonTagsHandler($text, "TheTopic", "TheWeb");
  
  # Check the script is the first thing
  my $re = qr/^\s*(<script.*\/script>)\n/s;
  $this->assert_matches($re, $text);
  $text =~ s/$re//s;
  my $script = $1;
  $script =~ s/\s+/ /go;
  $this->assert_str_equals( "<script language=\"JavaScript\"><!-- function editWindow(url) { win=open(url,\"none\",\"titlebar=0,width=800,height=400,resizable,scrollbars\"); if(win){win.focus();} return false; } // --> </script>", $script);
  
  my $tblhdr = "<table border=\"$ActionTrackerPlugin::Format::border\"><tr bgcolor=\"$ActionTrackerPlugin::Format::hdrcol\"><th> Assigned to </th><th> Due date </th><th> Description </th><th> State </th><th> Notify </th><th>&nbsp;</th></tr>";
  $text =~ s/&t=\d+//g;
  my $t = BaseFixture::unhtml($tblhdr);
  $this->assert($text =~ s/^\s*$t//);
  $t = BaseFixture::unhtml(action("UidOnFirst","Main.ActorOne",undef,"Fri, 1 Nov 2002","__Unknown__ =status= www.twiki.org","open"));
  $this->assert($text =~ s/^\s*$t//);

  $t = BaseFixture::unhtml(action("AcTion1","Main.ActorTwo",undef,"Mon, 11 Mar 2002","Open <table><td>status<td>status2</table>","closed"));
  $this->assert($text =~ s/^\s*$t//);
  $t = BaseFixture::unhtml("</table> text $tblhdr");
  $this->assert($text =~ s/^\s*$t//);
  $t = BaseFixture::unhtml(action("AcTion2","Main.ActorThree",undef,"Sun, 11 Mar 2001","The *world* is flat","closed"));
  $this->assert($text =~ s/^\s*$t//);
  $t = BaseFixture::unhtml(action("AcTion3","Main.ActorFour",$ActionTrackerPlugin::Format::latecol,"Sun, 11 Mar 2001","_Late_ the late great *date*","open"));
  $this->assert($text =~ s/^\s*$t//);
  $t = BaseFixture::unhtml(action("AcTion4","Main.ActorFiveVeryLongNameBecauseItsATest",$ActionTrackerPlugin::Format::latecol,"Wed, 13 Feb 2002","This is an action with a lot of associated text to test<br />   * the VingPazingPoodleFactor,<br />   * Tony Blair is a brick.<br />   * Who should really be built<br />   * Into a very high wall.","open"));
  $this->assert($text =~ s/^\s*$t//);
  $t = BaseFixture::unhtml(action("AcTion5","Main.ActorSix",$ActionTrackerPlugin::Format::badcol,"BAD DATE FORMAT see $TWiki::Plugins::ActionTrackerPlugin::installWeb.ActionTrackerPlugin#DateFormats","Bad date","open"));
  $this->assert($text =~ s/^\s*$t//, "$t NOT IN $text");
  $t = BaseFixture::unhtml("</table> break the table here $tblhdr");
  $this->assert($text =~ s/^\s*$t//);
  $t = BaseFixture::unhtml(action("AcTion6","Main.ActorSeven",$ActionTrackerPlugin::Format::latecol,"Tue, 1 Jan 2002","Create the mailer, %USERNAME%","open"));
  $this->assert($text =~ s/^\s*$t//);
  $t = BaseFixture::unhtml("</table>");
  $this->assert($text =~ s/^\s*$t//);
  $t = BaseFixture::unhtml("* A list *");
  $this->assert($text =~ s/^\s*$t//, "$t: $text");
  $t = BaseFixture::unhtml("$tblhdr");
  $this->assert($text =~ s/^\s*$t//, "$t: $text");
  $t = BaseFixture::unhtml(action("AcTion7","Main.ActorEight","yellow","Tue, 1 Jan 2002","Create the mailer","open"));
  $this->assert($text =~ s/^\s*$t//);
  $t = BaseFixture::unhtml("</table> * endofthelist * Another list * should generate $tblhdr");
  $this->assert($text =~ s/^\s*$t//);
  $t = BaseFixture::unhtml(action("AcTion8","Main.ActorNine",undef,"Tue, 1 Jan 2002","Create the mailer","closed"));
  $this->assert($text =~ s/^\s*$t//, "$t: $text");
  $t = BaseFixture::unhtml("</table>");
  $this->assert($text =~ s/^\s*$t\s*$//, "$t: $text");
  
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
  $text .= "> $date </td><td> $txt </td><td> $state </td><td> \&nbsp; </td><td> ".
	edit($anch)." </td></tr>";
  return $text;
}

sub testBeforeEditHandler {
  my $this = shift;
  my $q = new CGI("");
  $q->param(action=>"AcTion0");
  BaseFixture::setCGIQuery($q);
  my $text = "JUNK";
  BaseFixture::setSkin("action");
  TWiki::Plugins::ActionTrackerPlugin::beforeEditHandler($text,"Topic2","Main");
  $text = $this->assert_html_matches("<INPUT TYPE=\"text\" NAME=\"who\" VALUE=\"Main\.Fred\" SIZE=\"35\"\/>", $text);
  $text = $this->assert_html_matches("<INPUT TYPE=\"text\" NAME=\"due\" VALUE=\"Tue, 1 Jan 2002\" SIZE=\"16\"\/>", $text);
  $this->assert_html_matches("<SELECT NAME=\"state\" SIZE=\"1\">", $text);
  $this->assert_html_matches("<OPTION NAME=\"open\">open</OPTION>", $text);
  $this->assert_html_matches("<OPTION NAME=\"closed\" SELECTED>closed</OPTION></SELECT>", $text);
  $this->assert_html_matches("<INPUT TYPE=\"text\" NAME=\"notify\" VALUE=\"\" SIZE=\"35\"/>", $text);
  $this->assert_html_matches("<INPUT TYPE=\"hidden\" NAME=\"creator\" VALUE=\"\">", $text);
  $this->assert_html_matches("<INPUT TYPE=\"hidden\" NAME=\"closed\" VALUE=\"BAD DATE FORMAT see $TWiki::Plugins::ActionTrackerPlugin::installWeb\.ActionTrackerPlugin\#DateFormats\">", $text);
  $this->assert_html_matches("<INPUT TYPE=\"hidden\" NAME=\"closer\" VALUE=\"\">", $text);
  $this->assert_html_matches("<INPUT TYPE=\"hidden\" NAME=\"created\" VALUE=\"BAD DATE FORMAT see $TWiki::Plugins::ActionTrackerPlugin::installWeb\.ActionTrackerPlugin\#DateFormats\">", $text);
  $this->assert_html_matches("<INPUT TYPE=\"hidden\" NAME=\"uid\" VALUE=\"\">", $text);
  $this->assert_html_matches("<INPUT TYPE=\"hidden\" NAME=\"closeactioneditor\" VALUE=\"1\" />", $text);
  $this->assert_html_matches("<INPUT TYPE=\"hidden\" NAME=\"cmd\" VALUE=\"\" />", $text);
  $this->assert_html_matches("<INPUT TYPE=\"hidden\" NAME=\"Know\.TopicClassification\" VALUE=\"Know\.PublicSupported\" />", $text);
  $this->assert_html_matches("<INPUT TYPE=\"hidden\" NAME=\"Know\.OperatingSystem\" VALUE=\"Know\.OsHPUX, Know\.OsLinux\" />", $text);
  $this->assert_html_matches("<INPUT TYPE=\"hidden\" NAME=\"Know\.OsVersion\" VALUE=\"hhhhhh\" />", $text);
  $this->assert_html_matches("<INPUT TYPE=\"hidden\" NAME=\"pretext\" VALUE=\"&#10;\" />", $text);
  $this->assert_html_matches("<INPUT TYPE=\"hidden\" NAME=\"posttext\" VALUE=\"%ACTION{who=Joe,due=&quot;29 Jan 2010&quot;,open}% Main1: Joe_open_ontime&#10;%ACTION{who=TheWholeBunch,due=&quot;29 Jan 2001&quot;,open}% Main2: Joe_open_ontime&#10;\" />", $text);
  $this->assert_html_matches("<textarea NAME=\"text\" WRAP=\"virtual\" ROWS=\"\" COLS=\"\">Main0: Fred_closed_ontime</textarea>", $text);
}

sub testAfterEditHandler {
  my $this = shift;
  my $q = new CGI("");
  $q->param(closeactioneditor=>1);
  $q->param(pretext=>"%ACTION{}% Before\n");
  $q->param(posttext=>"After");
  $q->param(who=>"AlexanderPope");
  $q->param(due=>"3 may 2009");
  $q->param(state=>"closed");
  # populate with edit fields
  BaseFixture::setCGIQuery($q);
  my $text = "%ACTION{}%";
  TWiki::Plugins::ActionTrackerPlugin::afterEditHandler($text,"Topic","Web");
  $this->assert($text =~ m/(%ACTION.*)(%ACTION.*)$/so);
  my $first = $1;
  my $second = $2;
  my $re = qr/\s+state=\"open\"\s+/;
  $this->assert_matches($re, $first); $first =~ s/$re/ /;
  $re = qr/\s+creator=\"Main\.TestRunner\"\s+/o;
  $this->assert_matches($re, $first); $first =~ s/$re/ /;
  $re = qr/\s+due=\"3-Jun-2002\"\s+/;
  $this->assert_matches($re, $first); $first =~ s/$re/ /;
  $re = qr/\s+created=\"3-Jun-2002\"\s+/;
  $this->assert_matches($re, $first); $first =~ s/$re/ /;
  $re = qr/\s+who=\"Main.TestRunner\"\s+/;
  $this->assert_matches($re, $first); $first =~ s/$re/ /;
  $re = qr/\s+uid=\"000002\"\s+/;
  $this->assert_matches($re, $first); $first =~ s/$re/ /;
  $this->assert_matches(qr/%ACTION{\s*}% Before\n/, $first);
  $re = qr/\s+state=\"closed\"\s+/;
  $this->assert_matches($re, $second); $second =~ s/$re/ /;
  $re = qr/\s+creator=\"Main.TestRunner\"\s+/;
  $this->assert_matches($re, $second); $second =~ s/$re/ /;
  $re = qr/\s+closer=\"Main.TestRunner\"\s+/;
  $this->assert_matches($re, $second); $second =~ s/$re/ /;
  $re = qr/\s+closed=\"3-Jun-2002\"\s+/;
  $this->assert_matches($re, $second); $second =~ s/$re/ /;
  $re = qr/\s+due=\"3-May-2009\"\s+/;
  $this->assert_matches($re, $second); $second =~ s/$re/ /;
  $re = qr/\s+created=\"3-Jun-2002\"\s+/;
  $this->assert_matches($re, $second); $second =~ s/$re/ /;
  $re = qr/\s+who=\"Main.AlexanderPope\"\s+/;
  $this->assert_matches($re, $second); $second =~ s/$re/ /;
  $re = qr/\s+uid=\"000001\"\s+/;
  $this->assert_matches($re, $second); $second =~ s/$re/ /;
  $this->assert_matches(qr/%ACTION{\s*}% No description\nAfter\n/, $second);
}

sub testBeforeSaveHandler1 {
  my $this = shift;
  my $q = new CGI("");
  $q->param(closeactioneditor=>1);
  BaseFixture::setCGIQuery($q);
  my $text =
	"%META:TOPICINFO{author=\"guest\" date=\"1053267450\" format=\"1.0\" version=\"1.35\"}%
%META:TOPICPARENT{name=\"WebHome\"}%
%ACTION{}%
%META:FORM{name=\"ThisForm\"}%
%META:FIELD{name=\"Know.TopicClassification\" title=\"Know.TopicClassification\" value=\"Know.PublicSupported\"}%
%META:FIELD{name=\"Know.OperatingSystem\" title=\"Know.OperatingSystem\" value=\"Know.OsHPUX, Know.OsLinux\"}%
%META:FIELD{name=\"Know.OsVersion\" title=\"Know.OsVersion\" value=\"hhhhhh\"}%";
  
  TWiki::Plugins::ActionTrackerPlugin::beforeSaveHandler($text,"Topic2","Main");
  my $re = qr/ state=\"open\"/;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/ creator=\"Main.TestRunner\"/o;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/ created=\"3-Jun-2002\"/o;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/ due=\"3-Jun-2002\"/o;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/ who=\"Main.TestRunner\"/o;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/ uid=\"00000\d\"/o;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/ No description/o;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/^%META:TOPICINFO.*$/m;
  $this->assert_matches($re, $text); $text =~ s/$re//m;
  $re = qr/^%META:TOPICPARENT.*$/m;
  $this->assert_matches($re, $text); $text =~ s/$re//m;
  $re = qr/^%META:FORM.*$/m;
  $this->assert_matches($re, $text); $text =~ s/$re//m;
  $re = qr/^%META:FIELD.*$/m;
  $this->assert_matches($re, $text); $text =~ s/$re//m;
  $re = qr/^%META:FIELD.*$/m;
  $this->assert_matches($re, $text); $text =~ s/$re//m;
  $re = qr/^%META:FIELD.*$/m;
  $this->assert_matches($re, $text); $text =~ s/$re//m;
  $text =~ s/\n//gmo;
  $this->assert_str_equals( "%ACTION{ }%", $text);
}

sub testBeforeSaveHandler2 {
  my $this = shift;
  my $q = new CGI("");
  $q->param(closeactioneditor=>0);
  BaseFixture::setCGIQuery($q);
  my $text =
	"%META:TOPICINFO{author=\"guest\" date=\"1053267450\" format=\"1.0\" version=\"1.35\"}%
%META:TOPICPARENT{name=\"WebHome\"}%
%ACTION{}% <<EOF
A Description
EOF
%META:FORM{name=\"ThisForm\"}%
%META:FIELD{name=\"Know.TopicClassification\" title=\"Know.TopicClassification\" value=\"Know.PublicSupported\"}%
%META:FIELD{name=\"Know.OperatingSystem\" title=\"Know.OperatingSystem\" value=\"Know.OsHPUX, Know.OsLinux\"}%
%META:FIELD{name=\"Know.OsVersion\" title=\"Know.OsVersion\" value=\"hhhhhh\"}%";
  
  TWiki::Plugins::ActionTrackerPlugin::beforeSaveHandler($text,"Topic2","Main");
  my $re = qr/ state=\"open\"/o;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/ creator=\"Main.TestRunner\"/o;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/ created=\"3-Jun-2002\"/o;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/ due=\"3-Jun-2002\"/o;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/ who=\"Main.TestRunner\"/o;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/ uid=\"00000\d\"/o;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/^%META:TOPICINFO.*$/m;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/^%META:TOPICPARENT.*$/m;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/^%META:FORM.*$/m;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/^%META:FIELD.*$/m;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/^%META:FIELD.*$/m;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/^%META:FIELD.*$/m;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $text =~ s/\n//gmo;
  $this->assert_str_equals( "%ACTION{ }% A Description", $text);
}

1;
