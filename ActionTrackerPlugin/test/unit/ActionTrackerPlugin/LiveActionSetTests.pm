use strict;

package LiveActionSetTests;

use base qw(TWikiTestCase);

use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::ActionSet;
use TWiki::Plugins::ActionTrackerPlugin::Format;
use Time::ParseDate;
use CGI;

my $bit = time();
my $usersWeb = "TemporaryActionTrackerTest${bit}Users";
my $testWeb = "TemporaryActionTracker${bit}TestTopicsWeb";
my $twiki;

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

BEGIN {
    new TWiki();
    $TWiki::cfg{Plugins}{ActionTrackerPlugin}{Enabled} = 1;
};

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $twiki = new TWiki( $TWiki::cfg{DefaultUserLogin} );
    $TWiki::Plugins::SESSION = $twiki;
    my $user = $twiki->{users}->findUser($TWiki::cfg{DefaultUserLogin});

    $twiki->{store}->createWeb($twiki->{user},$usersWeb);
    $twiki->{store}->createWeb($twiki->{user},$testWeb);

    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("3 Jan 2002");

    my $meta = new TWiki::Meta($twiki,$testWeb,"WhoCares");

    $twiki->{store}->saveTopic( $user, $testWeb, "Topic1","
%ACTION{who=$usersWeb.C,due=\"16 Dec 02\",open}% Test_Topic1_C_open_ontime",
                                $meta, { forcenewrevision=>1 });

    $twiki->{store}->saveTopic( $user, $testWeb, "Topic2","
%ACTION{who=A,due=\"2 Jan 02\",open}% Test_Topic2_A_open_late
", $meta, { forcenewrevision=>1 });

    $twiki->{store}->saveTopic( $user, $testWeb, "WebNotify","
   * $usersWeb.A - fred\@sesame.street.com
");

    $twiki->{store}->saveTopic( $user, $usersWeb, "Topic2","
%ACTION{who=$usersWeb.A,due=\"1 Jan 02\",closed}% Main_Topic2_A_closed_ontime
%ACTION{who=B,due=\"29 Jan 2010\",open}% Main_Topic2_B_open_ontime
%ACTION{who=E,due=\"29 Jan 2001\",open}% Main_Topic2_E_open_ontime", $meta, { forcenewrevision=>1 });

    $twiki->{store}->saveTopic( $user, $usersWeb, "WebNotify","
   * $usersWeb.C - sam\@sesame.street.com
", $meta, { forcenewrevision=>1 });
    $twiki->{store}->saveTopic( $user, $usersWeb, "B","
   * Email: joe\@sesame.street.com
", $meta, { forcenewrevision=>1 });
    $twiki->{store}->saveTopic( $user, $usersWeb, "E","
   * Email: joe\@sesame.street.com
   * Email: fred\@sesame.street.com
   * Email: sam\@sesame.street.com
   * $usersWeb.GungaDin - gunga-din\@war_lords-home.ind
", $meta, { forcenewrevision=>1 });
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    $twiki->{store}->removeWeb($twiki->{user}, $testWeb);
    $twiki->{store}->removeWeb($twiki->{user}, $usersWeb);
}

sub test_GetAllInMain {
  my $this = shift;
  my $attrs = TWiki::Attrs->new();
  my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb("$usersWeb", $attrs);
  my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format("", "", "", "\$text");
  my $chosen = $actions->formatAsString($fmt);
  $this->assert_does_not_match(qr/Test_Topic1_C_open_ontime/o, $chosen);
  $this->assert_does_not_match(qr/Test_Topic2_A_open_late/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_A_closed_ontime/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_B_open_ontime/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_E_open_ontime/o, $chosen);
}

sub test_GetAllInTest {
  my $this = shift;
  my $attrs = TWiki::Attrs->new();
  my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb("$testWeb", $attrs);
  my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format("", "", "", "\$text");
  my $chosen = $actions->formatAsString($fmt);
  $this->assert_matches(qr/Test_Topic1_C_open_ontime/o, $chosen);
  $this->assert_matches(qr/Test_Topic2_A_open_late/o, $chosen);
  $this->assert_does_not_match(qr/Main_Topic2_A_closed_ontime/o, $chosen);
  $this->assert_does_not_match(qr/Main_Topic2_B_open_ontime/o, $chosen);
  $this->assert_does_not_match(qr/Main_Topic2_E_open_ontime/o, $chosen);
}

sub test_GetAllInAllWebs {
  my $this = shift;
  my $attrs = TWiki::Attrs->new('web=".*"', 1);
  my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWebs($usersWeb, $attrs);
  $actions->sort();
  my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format("", "", "", '$text');
  my $chosen = $actions->formatAsString($fmt);
  
  $this->assert_matches(qr/Test_Topic1_C_open_ontime/o, $chosen);
  $this->assert_matches(qr/Test_Topic2_A_open_late/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_A_closed_ontime/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_B_open_ontime/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_E_open_ontime/o, $chosen);

  # Make sure they are sorted correctly
  #%ACTION{who=E,due=\"29 Jan 2001\",open}% Main_Topic2_E_open_ontime");
  #%ACTION{who=A,due=\"1 Jan 02\",open}% Test_Topic2_A_open_late");
  #%ACTION{who=$usersWeb.A,due=\"1 Jan 02\",closed}% Main_Topic2_A_closed_ontime
  #%ACTION{who=$usersWeb.C,due=\"16 Dec 02\",open}% Test_Topic1_C_open_ontime
  #%ACTION{who=B,due=\"29 Jan 2010\",open}% Main_Topic2_B_open_ontime

  $this->assert_matches(qr/Main_Topic2_E_open_ontime.*Main_Topic2_A_closed_ontime.*Test_Topic2_A_open_late.*Test_Topic1_C_open_ontime.*Main_Topic2_B_open_ontime/so, $chosen, $chosen);
}

sub test_SortAllWebs {
  my $this = shift;
  my $attrs = TWiki::Attrs->new("web=\".*\"");
  my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWebs("$usersWeb", $attrs);
  $actions->sort("who,state");
  my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format("", "", "", '$who $state $text');
  my $chosen = $actions->formatAsString($fmt);
  $this->assert_matches(qr/Test_Topic2_A_open_late.*Main_Topic2_B_open_ontime.*Main_Topic2_E_open_ontime.*Main_Topic2_A_closed_ontime.*Test_Topic1_C_open_ontime/so, $chosen);
}

sub test_AllInTestWebRE {
  my $this = shift;
  my $attrs = TWiki::Attrs->new('web=".*'.$testWeb.'.*"',1);
  my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWebs("$usersWeb", $attrs);
  my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format("", "", "", "\$text");
  my $chosen = $actions->formatAsString($fmt);
  
  $this->assert_matches(qr/Test_Topic1_C_open_ontime/o, $chosen);
  $this->assert_matches(qr/Test_Topic2_A_open_late/o, $chosen);
  $this->assert_does_not_match(qr/Main_Topic2_A_closed_ontime/o, $chosen);
  $this->assert_does_not_match(qr/Main_Topic2_B_open_ontime/o, $chosen);
  $this->assert_does_not_match(qr/Main_Topic2_E_open_ontime/o, $chosen);
}

sub test_AllInMainWebRE {
  my $this = shift;

  my $attrs = TWiki::Attrs->new('web=".*'.$bit.'Users"');
  my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWebs("$usersWeb", $attrs);
  my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format("", "", "", "\$text");
  my $chosen = $actions->formatAsString($fmt);
  
  $this->assert_does_not_match(qr/Test_Topic1_C_open_ontime/o, $chosen);
  $this->assert_does_not_match(qr/Test_Topic2_A_open_late/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_A_closed_ontime/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_B_open_ontime/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_E_open_ontime/o, $chosen);
}

sub test_AllTopicRE {
  my $this = shift;
  my $attrs = TWiki::Attrs->new("web=$testWeb topic=\".*2\"",1);
  my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWebs("$testWeb", $attrs);
  my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format("", "", "", "\$text");
  my $chosen = $actions->formatAsString($fmt);
  $this->assert_does_not_match(qr/Test_Topic1_C_open_ontime/o, $chosen);
  $this->assert_matches(qr/Test_Topic2_A_open_late/o, $chosen);
  $this->assert_does_not_match(qr/Main_Topic2_A_closed_ontime/o, $chosen);
  $this->assert_does_not_match(qr/Main_Topic2_B_open_ontime/o, $chosen);
  $this->assert_does_not_match(qr/Main_Topic2_E_open_ontime/o, $chosen);
}

sub test_AllWebsTopicRE {
  my $this = shift;
  my $attrs = TWiki::Attrs->new("web=\".*\",topic=\".*2\"",1);
  my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWebs("$usersWeb", $attrs);
  my $fmt = new TWiki::Plugins::ActionTrackerPlugin::Format("", "", "", "\$text");
  my $chosen = $actions->formatAsString($fmt);
  $this->assert_does_not_match(qr/Test_Topic1_C_open_ontime/o, $chosen);
  $this->assert_matches(qr/Test_Topic2_A_open_late/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_A_closed_ontime/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_B_open_ontime/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_E_open_ontime/o, $chosen);
}

1;
