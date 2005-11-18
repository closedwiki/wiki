use strict;

package ActionTrackerPluginTests;

use base qw(TWikiTestCase);

use TWiki::Plugins::ActionTrackerPlugin;
use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::ActionSet;
use TWiki::Plugins::ActionTrackerPlugin::Format;
use Time::ParseDate;

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

BEGIN {
    new TWiki();
    $TWiki::cfg{Plugins}{ActionTrackerPlugin}{Enabled} = 1;
};

my $peopleWeb = "TemporaryActionTrackerTestUsersWeb";
my $savePeople;
my $testWeb = "TemporaryActionTrackerTestTopicsWeb";
my $twiki;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $twiki = new TWiki();
    $TWiki::Plugins::SESSION = $twiki;
    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("3 Jun 2002");
    $savePeople = $TWiki::cfg{UsersWebName};
    $TWiki::cfg{UsersWebName} = $peopleWeb;
    $twiki->{store}->createWeb($twiki->{user}, $testWeb);
    $twiki->{store}->createWeb($twiki->{user}, $peopleWeb);

    $twiki->{store}->saveTopic($twiki->{user}, $testWeb, "Topic1", "
%ACTION{who=$peopleWeb.Sam,due=\"3 Jan 02\",open}% Test0: Sam_open_late");

    $twiki->{store}->saveTopic($twiki->{user}, $testWeb, "Topic2", "
%ACTION{who=Fred,due=\"2 Jan 02\",open}% Test1: Fred_open_ontime");

    $twiki->{store}->saveTopic($twiki->{user}, $testWeb, "WebNotify", "
   * $peopleWeb.Fred - fred\@sesame.street.com
");

    $twiki->{store}->saveTopic($twiki->{user}, $testWeb, "WebPreferences", "
   * Set ACTIONTRACKERPLUGIN_HEADERCOL = green
   * Set ACTIONTRACKERPLUGIN_EXTRAS = |plaintiffs,names,16|decision,text,16|sentencing,date|sentence,select,\"life\",\"5 years\",\"community service\"|
");

    $twiki->{store}->saveTopic($twiki->{user}, $peopleWeb, "Topic2", "
%META:TOPICINFO{author=\"guest\" date=\"1053267450\" format=\"1.0\" version=\"1.35\"}%
%META:TOPICPARENT{name=\"WebHome\"}%
%ACTION{who=$peopleWeb.Fred,due=\"1 Jan 02\",closed}% Main0: Fred_closed_ontime
%ACTION{who=Joe,due=\"29 Jan 2010\",open}% Main1: Joe_open_ontime
%ACTION{who=TheWholeBunch,due=\"29 Jan 2001\",open}% Main2: Joe_open_ontime
%META:FORM{name=\"ThisForm\"}%
%META:FIELD{name=\"Know.TopicClassification\" title=\"Know.TopicClassification\" value=\"Know.PublicSupported\"}%
%META:FIELD{name=\"Know.OperatingSystem\" title=\"Know.OperatingSystem\" value=\"Know.OsHPUX, Know.OsLinux\"}%
%META:FIELD{name=\"Know.OsVersion\" title=\"Know.OsVersion\" value=\"hhhhhh\"}%
");
  
  $twiki->{store}->saveTopic($twiki->{user}, $peopleWeb, "WebNotify", "
   * $peopleWeb.Sam - sam\@sesame.street.com
");
  $twiki->{store}->saveTopic($twiki->{user}, $peopleWeb, "Joe", "
   * Email: joe\@sesame.street.com
");
  $twiki->{store}->saveTopic($twiki->{user}, $peopleWeb, "TheWholeBunch", "
   * Email: joe\@sesame.street.com
   * Email: fred\@sesame.street.com
   * Email: sam\@sesame.street.com
   * $peopleWeb.GungaDin - gunga-din\@war_lords-home.ind
");
  TWiki::Plugins::ActionTrackerPlugin::initPlugin("Topic",$testWeb,"User","Blah");
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    $twiki->{store}->removeWeb($twiki->{user}, $testWeb);
    $twiki->{store}->removeWeb($twiki->{user}, $peopleWeb);
}

sub testActionSearchFn {
  my $this = shift;
  my $chosen = TWiki::Plugins::ActionTrackerPlugin::_handleActionSearch($peopleWeb, "web=\".*\"");
  $this->assert_matches(qr/Test0:/, $chosen);
  $this->assert_matches(qr/Test1:/, $chosen);
  $this->assert_matches(qr/Main0:/, $chosen);
  $this->assert_matches(qr/Main1:/, $chosen);
  $this->assert_matches(qr/Main2:/, $chosen);

}

sub testActionSearchFnSorted {
  my $this = shift;
  my $chosen = TWiki::Plugins::ActionTrackerPlugin::_handleActionSearch($peopleWeb, "web=\".*\" sort=\"state,who\"");
  $this->assert_matches(qr/Test0:/, $chosen);
  $this->assert_matches(qr/Test1:/, $chosen);
  $this->assert_matches(qr/Main0:/, $chosen);
  $this->assert_matches(qr/Main1:/, $chosen);
  $this->assert_matches(qr/Main2:/, $chosen);
  $this->assert_matches(qr/Main0:.*Test1:.*Main1:.*Test0:.*Main2:/so, $chosen);
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
  TWiki::Plugins::ActionTrackerPlugin::commonTagsHandler($chosen, "Finagle", $peopleWeb);

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
   %ACTION{who=$peopleWeb.ActorTwo,due=\"Mon, 11 Mar 2002\",closed}% Open <table><td>status<td>status2</table>
text %ACTION{who=$peopleWeb.ActorThree,due=\"Sun, 11 Mar 2001\",closed}%The *world* is flat
%ACTION{who=$peopleWeb.ActorFour,due=\"Sun, 11 Mar 2001\",open}% _Late_ the late great *date*
%ACTION{who=$peopleWeb.ActorFiveVeryLongNameBecauseItsATest,due=\"Wed, 13 Feb 2002\",open}% <<EOF
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
}

sub anchor {
  my $tag = shift;
  return "<a name=\"$tag\"></a>";
}

sub edit {
  my $tag = shift;
  my $url = "%SCRIPTURLPATH%/edit%SCRIPTSUFFIX%/TheWeb/TheTopic?skin=action&action=$tag&t={*\\d+*}";
  return "<a href=\"$url\" onclick=\"return editWindow('$url')\">edit</a>";
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
  my $q = new CGI({atp_action=>"AcTion0",
                   skin=>'action'});
  $twiki->{cgiQuery} = $q;
  my $text = '%ACTION{who=Fred,due="2 Jan 02",open}% Test1: Fred_open_ontime';
  TWiki::Plugins::ActionTrackerPlugin::beforeEditHandler($text,"Topic2",$peopleWeb,undef);
  $text = $this->assert_html_matches("<input type=\"text\" name=\"who\" value=\"$peopleWeb\.Fred\" size=\"35\"/>", $text);
}

sub testAfterEditHandler {
  my $this = shift;
  my $q = new CGI({
                   closeactioneditor=>1,
                   pretext=>"%ACTION{}% Before\n",
                   posttext=>"After",
                   who=>"AlexanderPope",
                   due=>"3 may 2009",
                   state=>"closed" });
  # populate with edit fields
  $twiki->{cgiQuery} = $q;
  my $text = "%ACTION{}%";
  TWiki::Plugins::ActionTrackerPlugin::afterEditHandler($text,"Topic","Web");
  $this->assert($text =~ m/(%ACTION.*)(%ACTION.*)$/so);
  my $first = $1;
  my $second = $2;
  my $re = qr/\s+state=\"open\"\s+/;
  $this->assert_matches($re, $first); $first =~ s/$re/ /;
  $re = qr/\s+creator=\"$peopleWeb\.TWikiGuest\"\s+/o;
  $this->assert_matches($re, $first); $first =~ s/$re/ /;
  $re = qr/\s+due=\"3-Jun-2002\"\s+/;
  $this->assert_matches($re, $first); $first =~ s/$re/ /;
  $re = qr/\s+created=\"3-Jun-2002\"\s+/;
  $this->assert_matches($re, $first); $first =~ s/$re/ /;
  $re = qr/\s+who=\"$peopleWeb.TWikiGuest\"\s+/;
  $this->assert_matches($re, $first); $first =~ s/$re/ /;
}

sub testBeforeSaveHandler1 {
  my $this = shift;
  my $q = new CGI( {
                    closeactioneditor=>1,
                   });
  $twiki->{cgiQuery} = $q;
  my $text =
	"%META:TOPICINFO{author=\"guest\" date=\"1053267450\" format=\"1.0\" version=\"1.35\"}%
%META:TOPICPARENT{name=\"WebHome\"}%
%ACTION{}%
%META:FORM{name=\"ThisForm\"}%
%META:FIELD{name=\"Know.TopicClassification\" title=\"Know.TopicClassification\" value=\"Know.PublicSupported\"}%
%META:FIELD{name=\"Know.OperatingSystem\" title=\"Know.OperatingSystem\" value=\"Know.OsHPUX, Know.OsLinux\"}%
%META:FIELD{name=\"Know.OsVersion\" title=\"Know.OsVersion\" value=\"hhhhhh\"}%";
  
  TWiki::Plugins::ActionTrackerPlugin::beforeSaveHandler($text,"Topic2",$peopleWeb);
  my $re = qr/ state=\"open\"/;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/ creator=\"$peopleWeb.TWikiGuest\"/o;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/ created=\"3-Jun-2002\"/o;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/ due=\"3-Jun-2002\"/o;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/ who=\"$peopleWeb.TWikiGuest\"/o;
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
}

sub testBeforeSaveHandler2 {
  my $this = shift;
  my $q = new CGI( {
                    closeactioneditor=>0,
                   } );
  $twiki->{cgiQuery} = $q;
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
  
  TWiki::Plugins::ActionTrackerPlugin::beforeSaveHandler($text,"Topic2",$peopleWeb);
  my $re = qr/ state=\"open\"/o;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/ creator=\"$peopleWeb.TWikiGuest\"/o;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/ created=\"3-Jun-2002\"/o;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/ due=\"3-Jun-2002\"/o;
  $this->assert_matches($re, $text); $text =~ s/$re//;
  $re = qr/ who=\"$peopleWeb.TWikiGuest\"/o;
  $this->assert_matches($re, $text); $text =~ s/$re//;
}

1;
