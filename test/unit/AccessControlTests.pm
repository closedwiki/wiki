use strict;

package AccessControlTests;

use base qw(TWikiTestCase);

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

use TWiki;
use TWiki::Access;

my $peopleWeb = "TemporaryAccessControlPeopleTestWeb";
my $testWeb = "TemporaryAccessControlTestsWeb";
my $testTopic = "TemporaryTestTopic";
my $twiki;
my $currUser;
my $savePeople;
my $MrWhite;
my $MrBlue;
my $MrOrange;
my $MrGreen;
my $MrYellow;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $twiki = new TWiki();

    $twiki->{store}->createWeb($twiki->{user}, $peopleWeb);
    $twiki->{store}->createWeb($twiki->{user}, $testWeb);

    $TWiki::cfg{UsersWebName} = $peopleWeb;
    $currUser = $twiki->{users}->findUser($TWiki::cfg{DefaultUserLogin});
    $twiki->{store}->saveTopic($twiki->{user},
                               $TWiki::cfg{UsersWebName},
                               $TWiki::cfg{DefaultUserWikiName},'');
    $MrWhite = $this->createFakeUser($twiki);
    $MrBlue = $this->createFakeUser($twiki);
    $MrOrange = $this->createFakeUser($twiki);
    $MrGreen = $this->createFakeUser($twiki);
    $MrYellow = $this->createFakeUser($twiki);
    $twiki->{store}->saveTopic( $currUser, $peopleWeb, "ReservoirDogsGroup",
                                <<THIS
   * Set GROUP=$MrWhite,$peopleWeb.$MrBlue
THIS
                                , undef);
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    $twiki->{store}->removeWeb($twiki->{user}, $peopleWeb);
    $twiki->{store}->removeWeb($twiki->{user}, $testWeb);
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

# Note: As we do not initialize twiki with a query, the topic that topic prefs
# are initialized from is WebHome. Thus these tests also test reading a topic
# other than the current topic.

sub test_denytopic {
    my $this = shift;
    $twiki->{store}->saveTopic( $currUser, $testWeb, $testTopic,
                                <<THIS
If DENYTOPIC is set to a list of wikinames
    * people in the list will be DENIED.
\t* Set DENYTOPICVIEW=$MrGreen
   * Set DENYTOPICVIEW=$MrYellow,$peopleWeb.$MrOrange,%MAINWEB%.ReservoirDogsGroup
THIS
                                , undef);

    $this->PERMITTED($testWeb,$testTopic,"VIEW",$MrGreen);
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrYellow);
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrOrange);
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrWhite);
    $this->DENIED($testWeb,$testTopic,"view",$MrBlue);

}

sub test_empty_denytopic {
    my $this = shift;
    $twiki->{store}->saveTopic( $currUser, $testWeb, $testTopic,
                                <<THIS
If DENYTOPIC is set to empty ( i.e. Set DENYTOPIC = )
    * access is PERMITTED _i.e _ no-one is denied access to this topic
   * Set DENYTOPICVIEW=
THIS
                                , undef);
    $this->PERMITTED($testWeb,$testTopic,"VIEW",$MrGreen);
    $this->PERMITTED($testWeb,$testTopic,"VIEW",$MrYellow);
    $this->PERMITTED($testWeb,$testTopic,"VIEW",$MrOrange);
    $this->PERMITTED($testWeb,$testTopic,"VIEW",$MrWhite);
    $this->PERMITTED($testWeb,$testTopic,"view",$MrBlue);
}

sub test_allowtopic {
    my $this = shift;
    $twiki->{store}->saveTopic( $currUser, $testWeb, $testTopic,
                                <<THIS
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
\t* Set ALLOWTOPICVIEW = %MAINWEB%.$MrOrange
THIS
                                , undef);
    $this->PERMITTED($testWeb,$testTopic,"VIEW",$MrOrange);
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrGreen);
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrYellow);
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrWhite);
    $this->DENIED($testWeb,$testTopic,"view",$MrBlue);
}

sub test_allowtopic_a {
    my $this = shift;
    $twiki->{store}->saveTopic( $currUser, $testWeb, $testTopic,
                                <<THIS
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
\t* Set ALLOWTOPICVIEW = %MAINWEB%.$MrOrange
THIS
                                , undef);
    my $topicquery = new CGI( "" );
    $topicquery->path_info("/$testWeb/$testTopic");
    # renew TWiki, so WebPreferences gets re-read
    $twiki = new TWiki(undef, $topicquery);
    $this->PERMITTED($testWeb,$testTopic,"VIEW",$MrOrange);
    $twiki = new TWiki(undef, $topicquery);
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrGreen);
    $twiki = new TWiki(undef, $topicquery);
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrYellow);
    $twiki = new TWiki(undef, $topicquery);
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrWhite);
    $twiki = new TWiki(undef, $topicquery);
    $this->DENIED($testWeb,$testTopic,"view",$MrBlue);
}

sub test_allowtopic_b {
    my $this = shift;
    $twiki->{store}->saveTopic( $currUser, $testWeb, $testTopic,
                                <<THIS
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
\t* Set ALLOWTOPICVIEW = %MAINWEB%.$MrOrange
THIS
                                , undef);
    # renew TWiki, so WebPreferences gets re-read
    $twiki = new TWiki();
    $this->PERMITTED($testWeb,$testTopic,"VIEW",$MrOrange);
    $twiki = new TWiki();
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrGreen);
    $twiki = new TWiki();
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrYellow);
    $twiki = new TWiki();
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrWhite);
    $twiki = new TWiki();
    $this->DENIED($testWeb,$testTopic,"view",$MrBlue);
}

sub test_denyweb {
    my $this = shift;
    $twiki->{store}->saveTopic( $currUser, $testWeb, $TWiki::cfg{WebPrefsTopicName},
                                <<THIS
If DENYWEB is set to a list of wikiname
    * people in the list are DENIED access
\t* Set DENYWEBVIEW = $peopleWeb.$MrOrange %MAINWEB%.$MrBlue
THIS
                                , undef);
    # renew TWiki, so WebPreferences gets re-read
    $twiki = new TWiki();
    $twiki->{store}->saveTopic( $currUser, $testWeb, $testTopic,
                                "Null points");
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrOrange);
    $this->PERMITTED($testWeb,$testTopic,"VIEW",$MrGreen);
    $this->PERMITTED($testWeb,$testTopic,"VIEW",$MrYellow);
    $this->PERMITTED($testWeb,$testTopic,"VIEW",$MrWhite);
    $this->DENIED($testWeb,$testTopic,"view",$MrBlue);
}

sub test_allow_web {
    my $this = shift;
    $twiki->{store}->saveTopic( $currUser, $testWeb, $TWiki::cfg{WebPrefsTopicName},
                                <<THIS
If ALLOWWEB is set to a list of wikinames
    * people in the list will be PERMITTED
    * everyone else will be DENIED
\t* Set ALLOWWEBVIEW = $MrGreen $MrYellow $MrWhite
THIS
                                , undef);
    # renew TWiki, so WebPreferences gets re-read
    $twiki = new TWiki();
    $twiki->{store}->saveTopic( $currUser, $testWeb, $testTopic,
                                "Null points");
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrOrange);
    $this->PERMITTED($testWeb,$testTopic,"VIEW",$MrGreen);
    $this->PERMITTED($testWeb,$testTopic,"VIEW",$MrYellow);
    $this->PERMITTED($testWeb,$testTopic,"VIEW",$MrWhite);
    $this->DENIED($testWeb,$testTopic,"view",$MrBlue);
}

1;
