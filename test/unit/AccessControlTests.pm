use strict;

package AccessControlTests;

use base qw(Test::Unit::TestCase);

BEGIN {
    unshift @INC, '../../bin';
    require 'setlib.cfg';
}

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

use TWiki;
use TWiki::Access;

my $peopleWeb = "AccessControlPeopleTestWeb";
my $testWeb = "AccessControlTestsWeb";
my $twiki;
my $currUser;
my $savePeople;

sub make_web {
    my $web = shift;
    die $TWiki::cfg{DataDir} unless -d $TWiki::cfg{DataDir};
    mkdir "$TWiki::cfg{DataDir}/$web";
}

sub unmake_web {
    my $web = shift;
    die unless $web;
    die unless -d $TWiki::cfg{DataDir};
    `rm -rf $TWiki::cfg{DataDir}/$web`;
}

sub create_user {
    my $name = shift;
    my $meta = new TWiki::Meta($twiki, $peopleWeb, $name);
    $meta->put( "TOPICPARENT", { name => "$peopleWeb.WebHome" } );
    $twiki->{store}->saveTopic( $currUser, $peopleWeb, $name, "", $meta);
}

sub set_up {
    $twiki = new TWiki();

    make_web($peopleWeb);
    make_web($testWeb);

    $savePeople = $TWiki::cfg{UsersWebName};
    $TWiki::cfg{UsersWebName} = $peopleWeb;
    $currUser = $twiki->{users}->findUser($TWiki::cfg{DefaultUserLogin});
    create_user($TWiki::cfg{DefaultUserWikiName});
    create_user("MrWhite");
    create_user("MrBlue");
    create_user("MrOrange");
    create_user("MrGreen");
    create_user("MrOrange");
    $twiki->{store}->saveTopic( $currUser, $peopleWeb, "ReservoirDogsGroup",
                                <<THIS
   * Set GROUP=MrWhite,$peopleWeb.MrBlue
THIS
                                , undef);
}

sub tear_down {
    $TWiki::cfg{UsersWebName} = $savePeople;
    unmake_web($peopleWeb);
    unmake_web($testWeb);
}

sub DENIED {
    my( $this, $web, $topic, $mode, $user ) = @_;
    $this->assert(!$twiki->{security}->checkAccessPermission
                  ($mode, $twiki->{users}->findUser($user),undef,$topic,$web),
                  "$user $mode $web.$topic");
}

sub PERMITTED {
    my( $this, $web, $topic, $mode, $user ) = @_;
    $this->assert($twiki->{security}->checkAccessPermission
                  ($mode, $twiki->{users}->findUser($user),undef,$topic,$web),
                 "$user $mode $web.$topic");
}

sub test_denytopic {
    my $this = shift;
    $twiki->{store}->saveTopic( $currUser, $testWeb, "TestTopic",
                                <<THIS
If DENYTOPIC is set to a list of wikinames
    * people in the list will be DENIED.
\t* Set DENYTOPICVIEW=MrGreen
   * Set DENYTOPICVIEW=MrYellow,$peopleWeb.MrOrange,%MAINWEB%.ReservoirDogsGroup
THIS
                                , undef);

    $this->PERMITTED($testWeb,"TestTopic","VIEW","MrGreen");
    $this->DENIED($testWeb,"TestTopic","VIEW","MrYellow");
    $this->DENIED($testWeb,"TestTopic","VIEW","MrOrange");
    $this->DENIED($testWeb,"TestTopic","VIEW","MrWhite");
    $this->DENIED($testWeb,"TestTopic","view","MrBlue");

}

sub test_empty_denytopic {
    my $this = shift;
    $twiki->{store}->saveTopic( $currUser, $testWeb, "TestTopic",
                                <<THIS
If DENYTOPIC is set to empty ( i.e. Set DENYTOPIC = )
    * access is PERMITTED _i.e _ no-one is denied access to this topic
   * Set DENYTOPICVIEW=
THIS
                                , undef);
    $this->PERMITTED($testWeb,"TestTopic","VIEW","MrGreen");
    $this->PERMITTED($testWeb,"TestTopic","VIEW","MrYellow");
    $this->PERMITTED($testWeb,"TestTopic","VIEW","MrOrange");
    $this->PERMITTED($testWeb,"TestTopic","VIEW","MrWhite");
    $this->PERMITTED($testWeb,"TestTopic","view","MrBlue");
}

sub test_allowtopic {
    my $this = shift;
    $twiki->{store}->saveTopic( $currUser, $testWeb, "TestTopic",
                                <<THIS
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
\t* Set ALLOWTOPICVIEW = %MAINWEB%.MrOrange
THIS
                                , undef);
    $this->PERMITTED($testWeb,"TestTopic","VIEW","MrOrange");
    $this->DENIED($testWeb,"TestTopic","VIEW","MrGreen");
    $this->DENIED($testWeb,"TestTopic","VIEW","MrYellow");
    $this->DENIED($testWeb,"TestTopic","VIEW","MrWhite");
    $this->DENIED($testWeb,"TestTopic","view","MrBlue");
}

sub test_denyweb {
    my $this = shift;
    $twiki->{store}->saveTopic( $currUser, $testWeb, "WebPreferences",
                                <<THIS
If DENYWEB is set to a list of wikiname
    * people in the list are DENIED access
\t* Set DENYWEBVIEW = $peopleWeb.MrOrange %MAINWEB%.MrBlue
THIS
                                , undef);
    # renew TWiki, so WebPreferences gets re-read
    $twiki = new TWiki();
    $twiki->{store}->saveTopic( $currUser, $testWeb, "TestTopic",
                                "Null points");
    $this->DENIED($testWeb,"TestTopic","VIEW","MrOrange");
    $this->PERMITTED($testWeb,"TestTopic","VIEW","MrGreen");
    $this->PERMITTED($testWeb,"TestTopic","VIEW","MrYellow");
    $this->PERMITTED($testWeb,"TestTopic","VIEW","MrWhite");
    $this->DENIED($testWeb,"TestTopic","view","MrBlue");
}

sub test_allow_web {
    my $this = shift;
    $twiki->{store}->saveTopic( $currUser, $testWeb, "WebPreferences",
                                <<THIS
If ALLOWWEB is set to a list of wikinames
    * people in the list will be PERMITTED
    * everyone else will be DENIED
\t* Set ALLOWWEBVIEW = MrGreen MrYellow MrWhite
THIS
                                , undef);
    # renew TWiki, so WebPreferences gets re-read
    $twiki = new TWiki();
    $twiki->{store}->saveTopic( $currUser, $testWeb, "TestTopic",
                                "Null points");
    $this->DENIED($testWeb,"TestTopic","VIEW","MrOrange");
    $this->PERMITTED($testWeb,"TestTopic","VIEW","MrGreen");
    $this->PERMITTED($testWeb,"TestTopic","VIEW","MrYellow");
    $this->PERMITTED($testWeb,"TestTopic","VIEW","MrWhite");
    $this->DENIED($testWeb,"TestTopic","view","MrBlue");
}

1;
