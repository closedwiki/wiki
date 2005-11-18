# Tests for module Action.pm

package FileActionSetTests;

use strict;
use base qw(TWikiTestCase);

use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::ActionSet;
use TWiki::Plugins::ActionTrackerPlugin::Format;
use Time::ParseDate;

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

my $textonlyfmt = new TWiki::Plugins::ActionTrackerPlugin::Format("Text", "\$text", "cols", "\$text", "", "");

my $testweb1 = "ActionTrackerPluginTestWeb";
my $testweb2 = "ActionTrackerPluginTestSecondaryWeb";
my $twiki;

BEGIN {
    new TWiki();
    $TWiki::cfg{Plugins}{ActionTrackerPlugin}{Enabled} = 1;
};

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("2 Jan 2002");

    $twiki = new TWiki();
    $TWiki::Plugins::SESSION = $twiki;

    $twiki->{store}->createWeb($twiki->{user}, $testweb1);
    $twiki->{store}->createWeb($twiki->{user}, $testweb2);

    $twiki->{store}->saveTopic( $twiki->{user}, $testweb1, "Topic1",
                                <<'HERE'
%ACTION{who=Main.C,due="3 Jan 02",open}% C_open_ontime"),
HERE
                                );

  $twiki->{store}->saveTopic($twiki->{user},$testweb1, "Topic2",
                             <<'HERE'
%ACTION{who=A,due="1 Jun 2001",open}% <<EOF
A_open_late
EOF
%ACTION{who=TestRunner,due="1 Jun 2001",open}% TestRunner_open_late
HERE
                             );

  $twiki->{store}->saveTopic($twiki->{user},$testweb2, "WebNotify",
                             <<'HERE'
   * MowGli - mowgli\@jungle.book

HERE
                            );
  $twiki->{store}->saveTopic($twiki->{user},$testweb2, "Topic2",
                             <<'HERE'
%ACTION{who=Main.A,due=\"1 Jan 02\",closed}% A_closed_ontime
%ACTION{who=Blah.B,due=\"29 Jan 2010\",open}% B_open_ontime
HERE
                            );
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    $twiki->{store}->removeWeb($twiki->{user}, $testweb1);
    $twiki->{store}->removeWeb($twiki->{user}, $testweb2);
}

sub testAllActionsInWebTest {
  my $this = shift;
  my $attrs = new TWiki::Attrs("topic=\".*\"");
  my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb($testweb1, $attrs);
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
  my $attrs = new TWiki::Attrs();
  my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb($testweb2, $attrs);
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
  my $attrs = new TWiki::Attrs("open",1);
  my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb($testweb1, $attrs );
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
  my $attrs = new TWiki::Attrs("late",1);
  my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb($testweb1, $attrs );
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
  my $attrs = new TWiki::Attrs("who=me");
  my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb($testweb1, $attrs);
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
