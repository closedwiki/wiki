# Tests for module Action.pm
use strict;

package FileActionSetTests;

use base qw(BaseFixture);

use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::ActionSet;
use TWiki::Plugins::ActionTrackerPlugin::Format;
use Time::ParseDate;

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

my $textonlyfmt = new TWiki::Plugins::ActionTrackerPlugin::Format("Text", "\$text", "cols", "\$text", "", "");

sub set_up {
  my $this = shift;
  $this->SUPER::set_up();

  TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("2 Jan 2002");

  # All actions in a web
  BaseFixture::writeTopic("Test", "Topic1", "
%ACTION{who=Main.C,due=\"3 Jan 02\",open}% C_open_ontime");
  BaseFixture::writeTopic("Test", "Topic2", "
%ACTION{who=A,due=\"1 Jun 2001\",open}% <<EOF
A_open_late
EOF
%ACTION{who=TestRunner,due=\"1 Jun 2001\",open}% TestRunner_open_late");

  BaseFixture::writeTopic("Main", "WebNotify", "
   * MowGli - mowgli\@jungle.book
");
  BaseFixture::writeTopic("Main", "Topic2", "
%ACTION{who=Main.A,due=\"1 Jan 02\",closed}% A_closed_ontime
%ACTION{who=Blah.B,due=\"29 Jan 2010\",open}% B_open_ontime");
}

sub testAllActionsInWebTest {
  my $this = shift;
  my $attrs = new TWiki::Contrib::Attrs("topic=\".*\"");
  my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb("Test", $attrs);
  my $fmt = $textonlyfmt;
  my $chosen = $actions->formatAsString($fmt);
  
  $this->assert_matches(qr/C_open_ontime/o, $chosen);
  $this->assert_matches(qr/A_open_late/o, $chosen);
  $this->assert_matches(qr/TestRunner_open_late/o, $chosen);
  $this->assert_does_not_match(qr/A_closed_ontime/o, $chosen);
  $this->assert_does_not_match(qr/B_open_ontime/o, $chosen);
  
  my %actionees;
  $actions->getActionees(\%actionees);
  $this->assert_not_null($actionees{"Main.C"});
  $this->assert_not_null($actionees{"Main.A"});
  $this->assert_not_null($actionees{"Main.TestRunner"});
  $this->assert_null($actionees{"Blah.B"});
}

sub notestAllActionsInWebMain {
  my $this = shift;
  my $attrs = new TWiki::Contrib::Attrs();
  my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb("Main", $attrs);
  my $fmt = $textonlyfmt;
  my $chosen = $actions->formatAsString( $fmt );
  $this->assert_does_not_match(qr/C_open_ontime/o, $chosen);
  $this->assert_does_not_match(qr/A_open_late/o, $chosen);
  $this->assert_does_not_match(qr/TestRunner_open_late/o, $chosen);
  $this->assert_matches(qr/A_closed_ontime/o, $chosen);
  $this->assert_matches(qr/B_open_ontime/o, $chosen);
  
  my %actionees;
  $actions->getActionees(\%actionees);
  $this->assert_null($actionees{"Main.C"});
  $this->assert_not_null($actionees{"Main.A"});
  $this->assert_null($actionees{"Main.TestRunner"});
  $this->assert_not_null($actionees{"Blah.B"});
}

sub notestOpenActions {
  my $this = shift;
  my $attrs = new TWiki::Contrib::Attrs("open");
  my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb("Test", $attrs );
  my $fmt = $textonlyfmt;
  my $chosen = $actions->formatAsString($fmt);
  $this->assert_not_null($chosen);
  $this->assert_matches(qr/C_open_ontime/o, $chosen);
  $this->assert_matches(qr/A_open_late/o, $chosen);
  $this->assert_matches(qr/TestRunner_open_late/o, $chosen);
  $this->assert_does_not_match(/A_closed_ontime/o, $chosen);
  $this->assert_does_not_match(/B_open_ontime/o, $chosen);
}

#%ACTION{who=C,     due=\"3 Jan 02\",open}%    C_open_ontime
#%ACTION{who=A,     due=\"1 Jun 2001\",open}%  A_open_late
#%ACTION{who=TestRunner,     due=\"1 Jun 2001\",open}%  TestRunner_open_late
#%ACTION{who=A,     due=\"1 Jan 02\",closed}%  A_closed_ontime
#%ACTION{who=Blah.B,due=\"29 Jan 2010\",open}% B_open_ontime");
sub notestLateActions {
  my $this = shift;
  my $attrs = new TWiki::Contrib::Attrs("late");
  my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb("Test", $attrs );
  my $fmt = $textonlyfmt;
  my $chosen = $actions->formatAsString($fmt);
  
  $this->assert_does_not_match(qr/C_open_ontime/o, $chosen);
  $this->assert_matches(qr/A_open_late/o, $chosen);
  $this->assert_matches(qr/TestRunner_open_late/o, $chosen);
  $this->assert_does_not_match(/A_closed_ontime/o, $chosen);
  $this->assert_does_not_match(/B_open_ontime/o, $chosen);
}

sub notestMyActions {
  my $this = shift;
  my $attrs = new TWiki::Contrib::Attrs("who=me");
  my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb("Test", $attrs);
  my $fmt = $textonlyfmt;
  my $chosen = $actions->formatAsString($fmt);
  $this->assert_not_null($chosen);
  $this->assert_does_not_match(qr/C_open_ontime/o, $chosen);
  $this->assert_does_not_match(qr/A_open_late/o, $chosen);
  $this->assert_does_not_match(qr/A_closed_ontime/o, $chosen);
  $this->assert_does_not_match(qr/B_open_ontime/o, $chosen);
  $this->assert_matches(qr/TestRunner_open_late/o, $chosen);
}

1;
