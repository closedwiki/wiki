use strict;

package LiveActionSetTests;

use base qw(BaseFixture);

use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::ActionSet;
use TWiki::Plugins::ActionTrackerPlugin::Format;
use Time::ParseDate;
use CGI;

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

sub set_up {
  my $this = shift;
  $this->SUPER::set_up();
  
  ActionTrackerPlugin::Action::forceTime("2 Jan 2002");
  
  BaseFixture::writeTopic("Test", "Topic1", "
%ACTION{who=Main.C,due=\"16 Dec 02\",open}% Test_Topic1_C_open_ontime");
  
  BaseFixture::writeTopic("Test", "Topic2", "
%ACTION{who=A,due=\"1 Jan 02\",open}% Test_Topic2_A_open_late");
  
  BaseFixture::writeTopic("Test", "WebNotify", "
   * Main.A - fred\@sesame.street.com
");
  
  BaseFixture::writeTopic("Main", "Topic2", "
%ACTION{who=Main.A,due=\"1 Jan 02\",closed}% Main_Topic2_A_closed_ontime
%ACTION{who=B,due=\"29 Jan 2010\",open}% Main_Topic2_B_open_ontime
%ACTION{who=E,due=\"29 Jan 2001\",open}% Main_Topic2_E_open_ontime");
  
  BaseFixture::writeTopic("Main", "WebNotify", "
   * Main.C - sam\@sesame.street.com
");
  BaseFixture::writeTopic("Main", "B", "
   * Email: joe\@sesame.street.com
");
  BaseFixture::writeTopic("Main", "E", "
   * Email: joe\@sesame.street.com
   * Email: fred\@sesame.street.com
   * Email: sam\@sesame.street.com
   * Main.GungaDin - gunga-din\@war_lords-home.ind
");
}

sub test_GetAllInMain {
  my $this = shift;
  my $attrs = TWiki::Contrib::Attrs->new();
  my $actions = ActionTrackerPlugin::ActionSet::allActionsInWeb("Main", $attrs);
  my $fmt = new ActionTrackerPlugin::Format("", "", "", "\$text");
  my $chosen = $actions->formatAsString($fmt);
  $this->assert_does_not_match(qr/Test_Topic1_C_open_ontime/o, $chosen);
  $this->assert_does_not_match(qr/Test_Topic2_A_open_late/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_A_closed_ontime/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_B_open_ontime/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_E_open_ontime/o, $chosen);
}

sub test_GetAllInTest {
  my $this = shift;
  my $attrs = TWiki::Contrib::Attrs->new();
  my $actions = ActionTrackerPlugin::ActionSet::allActionsInWeb("Test", $attrs);
  my $fmt = new ActionTrackerPlugin::Format("", "", "", "\$text");
  my $chosen = $actions->formatAsString($fmt);
  $this->assert_matches(qr/Test_Topic1_C_open_ontime/o, $chosen);
  $this->assert_matches(qr/Test_Topic2_A_open_late/o, $chosen);
  $this->assert_does_not_match(qr/Main_Topic2_A_closed_ontime/o, $chosen);
  $this->assert_does_not_match(qr/Main_Topic2_B_open_ontime/o, $chosen);
  $this->assert_does_not_match(qr/Main_Topic2_E_open_ontime/o, $chosen);
}

sub test_GetAllInAllWebs {
  my $this = shift;
  my $attrs = TWiki::Contrib::Attrs->new("web=\".*\"");
  my $actions = ActionTrackerPlugin::ActionSet::allActionsInWebs("Main", $attrs);
  $actions->sort();
  my $fmt = new ActionTrackerPlugin::Format("", "", "", "\$text");
  my $chosen = $actions->formatAsString($fmt);
  
  $this->assert_matches(qr/Test_Topic1_C_open_ontime/o, $chosen);
  $this->assert_matches(qr/Test_Topic2_A_open_late/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_A_closed_ontime/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_B_open_ontime/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_E_open_ontime/o, $chosen);
  
  # Make sure they are sorted correctly
  #%ACTION{who=E,due=\"29 Jan 2001\",open}% Main_Topic2_E_open_ontime");
  #%ACTION{who=A,due=\"1 Jan 02\",open}% Test_Topic2_A_open_late");
  #%ACTION{who=Main.A,due=\"1 Jan 02\",closed}% Main_Topic2_A_closed_ontime
  #%ACTION{who=Main.C,due=\"16 Dec 02\",open}% Test_Topic1_C_open_ontime
  #%ACTION{who=B,due=\"29 Jan 2010\",open}% Main_Topic2_B_open_ontime

  $this->assert_matches(qr/Main_Topic2_E_open_ontime.*Main_Topic2_A_closed_ontime.*Test_Topic2_A_open_late.*Test_Topic1_C_open_ontime.*Main_Topic2_B_open_ontime/so, $chosen, $chosen);
}

sub test_SortAllWebs {
  my $this = shift;
  my $attrs = TWiki::Contrib::Attrs->new("web=\".*\"");
  my $actions = ActionTrackerPlugin::ActionSet::allActionsInWebs("Main", $attrs);
  $actions->sort("who,state");
  my $fmt = new ActionTrackerPlugin::Format("", "", "", "\$text");
  my $chosen = $actions->formatAsString($fmt);
  $this->assert_matches(qr/Main_Topic2_A_closed_ontime.*Test_Topic2_A_open_late.*Main_Topic2_B_open_ontime.*Test_Topic1_C_open_ontime.*Main_Topic2_E_open_ontime/so, $chosen);
}

sub test_AllInTestWebRE {
  my $this = shift;
  my $attrs = TWiki::Contrib::Attrs->new("web=\"T.*\"");
  my $actions = ActionTrackerPlugin::ActionSet::allActionsInWebs("Main", $attrs);
  my $fmt = new ActionTrackerPlugin::Format("", "", "", "\$text");
  my $chosen = $actions->formatAsString($fmt);
  
  $this->assert_matches(qr/Test_Topic1_C_open_ontime/o, $chosen);
  $this->assert_matches(qr/Test_Topic2_A_open_late/o, $chosen);
  $this->assert_does_not_match(qr/Main_Topic2_A_closed_ontime/o, $chosen);
  $this->assert_does_not_match(qr/Main_Topic2_B_open_ontime/o, $chosen);
  $this->assert_does_not_match(qr/Main_Topic2_E_open_ontime/o, $chosen);
}

sub test_AllInMainWebRE {
  my $this = shift;
  my $attrs = TWiki::Contrib::Attrs->new("web=\".*ain\"");
  my $actions = ActionTrackerPlugin::ActionSet::allActionsInWebs("Main", $attrs);
  my $fmt = new ActionTrackerPlugin::Format("", "", "", "\$text");
  my $chosen = $actions->formatAsString($fmt);
  
  $this->assert_does_not_match(qr/Test_Topic1_C_open_ontime/o, $chosen);
  $this->assert_does_not_match(qr/Test_Topic2_A_open_late/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_A_closed_ontime/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_B_open_ontime/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_E_open_ontime/o, $chosen);
}

sub test_AllTopicRE {
  my $this = shift;
  my $attrs = TWiki::Contrib::Attrs->new("web=Test topic=\".*2\"");
  my $actions = ActionTrackerPlugin::ActionSet::allActionsInWebs("Test", $attrs);
  my $fmt = new ActionTrackerPlugin::Format("", "", "", "\$text");
  my $chosen = $actions->formatAsString($fmt);
  $this->assert_does_not_match(qr/Test_Topic1_C_open_ontime/o, $chosen);
  $this->assert_matches(qr/Test_Topic2_A_open_late/o, $chosen);
  $this->assert_does_not_match(qr/Main_Topic2_A_closed_ontime/o, $chosen);
  $this->assert_does_not_match(qr/Main_Topic2_B_open_ontime/o, $chosen);
  $this->assert_does_not_match(qr/Main_Topic2_E_open_ontime/o, $chosen);
}

sub test_AllWebsTopicRE {
  my $this = shift;
  my $attrs = TWiki::Contrib::Attrs->new("web=\".*\",topic=\".*2\"");
  my $actions = ActionTrackerPlugin::ActionSet::allActionsInWebs("Main", $attrs);
  my $fmt = new ActionTrackerPlugin::Format("", "", "", "\$text");
  my $chosen = $actions->formatAsString($fmt);
  $this->assert_does_not_match(qr/Test_Topic1_C_open_ontime/o, $chosen);
  $this->assert_matches(qr/Test_Topic2_A_open_late/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_A_closed_ontime/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_B_open_ontime/o, $chosen);
  $this->assert_matches(qr/Main_Topic2_E_open_ontime/o, $chosen);
}

1;
