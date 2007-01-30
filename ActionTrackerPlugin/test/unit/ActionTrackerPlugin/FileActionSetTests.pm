# Tests for module ActionSet.pm

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

my $textonlyfmt = new TWiki::Plugins::ActionTrackerPlugin::Format(
    "Text", "\$text", "cols", "\$text", "", "");

my $testweb1 = "ActionTrackerPluginTestWeb";
my $testweb2 = "Secondary$testweb1";
my $twiki;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $TWiki::cfg{Plugins}{ActionTrackerPlugin}{Enabled} = 1;

    TWiki::Plugins::ActionTrackerPlugin::Action::forceTime("2 Jan 2002");

    $twiki = new TWiki();
    $TWiki::Plugins::SESSION = $twiki;

    $twiki->{store}->createWeb($twiki->{user}, $testweb1);
    $twiki->{store}->createWeb($twiki->{user}, $testweb2);

    $twiki->{store}->saveTopic( $twiki->{user}, $testweb1, "Topic1", <<'HERE'
%ACTION{who=Main.C,due="3 Jan 02",open}% C_open_ontime"),
HERE
                               );

    $twiki->{store}->saveTopic($twiki->{user},$testweb1, "Topic2", <<'HERE');
%ACTION{who=A,due="1 Jun 2001",open}% <<EOF
A_open_late
EOF
%ACTION{who=TestRunner,due="1 Jun 2001",open}% TestRunner_open_late
HERE

    $twiki->{store}->saveTopic($twiki->{user}, $testweb2,
                               "WebNotify", <<'HERE');
   * MowGli - mowgli\@jungle.book

HERE

    $twiki->{store}->saveTopic($twiki->{user},$testweb2, "Topic2", <<'HERE');
%ACTION{who=Main.A,due="1 Jan 02",closed}% A_closed_ontime
%ACTION{who=Blah.B,due="29 Jan 2010",open}% B_open_ontime
HERE

    $twiki->{store}->saveTopic($twiki->{user},$testweb2, "Topic2", <<'HERE');
%ACTION{who=Main.A,due="1 Jan 02",closed}% A_closed_ontime
%ACTION{who=Blah.B,due="29 Jan 2010",open}% B_open_ontime
HERE

    # Create a secret topic that should *NOT* be found
    $twiki->{store}->saveTopic($twiki->{user},$testweb2, "SecretTopic", <<'HERE');
%ACTION{who=Main.IlyaKuryakin,due="1 Jan 02",closed}% A_closed_ontime
%ACTION{who=JamesBond,due="29 Jan 2010",open}% B_open_ontime
   * Set ALLOWTOPICVIEW = Main.ErnstBlofeld
HERE
    $twiki->{user} = $twiki->{users}->findUser('TestRunner');
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    $twiki->{store}->removeWeb($twiki->{user}, $testweb1);
    $twiki->{store}->removeWeb($twiki->{user}, $testweb2);
}

sub testAllActionsInWebTest {
    my $this = shift;
    my $attrs = new TWiki::Attrs("topic=\".*\"", 1);
    my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb($testweb1, $attrs, 0);
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
    delete($actionees{"Main.C"});
    $this->assert_not_null($actionees{"Main.A"});
    delete($actionees{"Main.A"});
    $this->assert_not_null($actionees{"Main.TestRunner"});
    delete($actionees{"Main.TestRunner"});
    $this->assert_equals(0, scalar(keys %actionees));
}

sub testAllActionsInWebMain {
    my $this = shift;
    my $attrs = new TWiki::Attrs();
    my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb($testweb2, $attrs, 0);
    my $fmt = $textonlyfmt;
    my $chosen = $actions->formatAsString( $fmt );
    $this->assert_does_not_match(qr/C_open_ontime/o, $chosen);
    $this->assert_does_not_match(qr/A_open_late/o, $chosen);
    $this->assert_does_not_match(qr/TestRunner_open_late/o, $chosen);
    $this->assert_matches(qr/A_closed_ontime/o, $chosen);
    $this->assert_matches(qr/B_open_ontime/o, $chosen);

    my %actionees;
    $actions->getActionees(\%actionees);
    $this->assert_not_null($actionees{"Main.A"});
    delete($actionees{"Main.A"});
    $this->assert_not_null($actionees{"Blah.B"});
    delete($actionees{"Blah.B"});
    # If the perms checks are working, Bond and Kuryakin should be excluded
    $this->assert_equals(0, scalar(keys %actionees));
}

sub testOpenActions {
    my $this = shift;
    my $attrs = new TWiki::Attrs("open",1);
    my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb($testweb1, $attrs, 0 );
    my $fmt = $textonlyfmt;
    my $chosen = $actions->formatAsString($fmt);
    $this->assert_not_null($chosen);
    $this->assert_matches(qr/C_open_ontime/o, $chosen);
    $this->assert_matches(qr/A_open_late/o, $chosen);
    $this->assert_matches(qr/TestRunner_open_late/o, $chosen);
    $this->assert_does_not_match(qr/A_closed_ontime/o, $chosen);
    $this->assert_does_not_match(qr/B_open_ontime/o, $chosen);
    my %actionees;
    $actions->getActionees(\%actionees);
    $this->assert_not_null($actionees{"Main.A"});
    delete($actionees{"Main.A"});
    $this->assert_not_null($actionees{"Main.C"});
    delete($actionees{"Main.C"});
    $this->assert_not_null($actionees{"Main.TestRunner"});
    delete($actionees{"Main.TestRunner"});
    $this->assert_equals(0, scalar(keys %actionees));
}

#%ACTION{who=C,     due="3 Jan 02",open}%    C_open_ontime
#%ACTION{who=A,     due="1 Jun 2001",open}%  A_open_late
#%ACTION{who=TestRunner,     due="1 Jun 2001",open}%  TestRunner_open_late
#%ACTION{who=A,     due="1 Jan 02",closed}%  A_closed_ontime
#%ACTION{who=Blah.B,due="29 Jan 2010",open}% B_open_ontime");
sub testLateActions {
    my $this = shift;
    my $attrs = new TWiki::Attrs("late",1);
    my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb($testweb1, $attrs, 0 );
    my $fmt = $textonlyfmt;
    my $chosen = $actions->formatAsString($fmt);

    $this->assert_does_not_match(qr/C_open_ontime/o, $chosen);
    $this->assert_matches(qr/A_open_late/o, $chosen);
    $this->assert_matches(qr/TestRunner_open_late/o, $chosen);
    $this->assert_does_not_match(qr/A_closed_ontime/o, $chosen);
    $this->assert_does_not_match(qr/B_open_ontime/o, $chosen);
    my %actionees;
    $actions->getActionees(\%actionees);
    $this->assert_not_null($actionees{"Main.A"});
    delete($actionees{"Main.A"});
    $this->assert_not_null($actionees{"Main.TestRunner"});
    delete($actionees{"Main.TestRunner"});
    $this->assert_equals(0, scalar(keys %actionees));
}

sub testMyActions {
    my $this = shift;
    my $attrs = new TWiki::Attrs("who=me", 1);
    my $actions = TWiki::Plugins::ActionTrackerPlugin::ActionSet::allActionsInWeb($testweb1, $attrs, 0);
    my $fmt = $textonlyfmt;
    my $chosen = $actions->formatAsString($fmt);
    $this->assert_not_null($chosen);
    $this->assert_does_not_match(qr/C_open_ontime/o, $chosen);
    $this->assert_does_not_match(qr/A_open_late/o, $chosen);
    $this->assert_does_not_match(qr/A_closed_ontime/o, $chosen);
    $this->assert_does_not_match(qr/B_open_ontime/o, $chosen);
    $this->assert_matches(qr/TestRunner_open_late/o, $chosen);
    my %actionees;
    $actions->getActionees(\%actionees);
    $this->assert_not_null($actionees{"Main.TestRunner"});
    delete($actionees{"Main.TestRunner"});
    $this->assert_equals(0, scalar(keys %actionees));
}

1;
