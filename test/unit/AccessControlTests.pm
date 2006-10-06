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
    $MrWhite = $this->createFakeUser($twiki, '', "White");
    $MrBlue = $this->createFakeUser($twiki, '', "Blue");
    $MrOrange = $this->createFakeUser($twiki, '', "Orange");
    $MrGreen = $this->createFakeUser($twiki, '', "Green");
    $MrYellow = $this->createFakeUser($twiki, '', "Yellow");
    $twiki->{store}->saveTopic( $currUser, $peopleWeb, "ReservoirDogsGroup",
                                <<THIS
   * Set GROUP = $MrWhite,$peopleWeb.$MrBlue
THIS
                                , undef);
}

sub tear_down {
    my $this = shift;
    $this->removeWebFixture($twiki, $peopleWeb);
    $this->removeWebFixture($twiki, $testWeb);
    eval {$twiki->finish()};
    $this->SUPER::tear_down();
}

sub DENIED {
    my( $this, $web, $topic, $mode, $user ) = @_;
    $this->assert(!$twiki->{security}->checkAccessPermission
                  ($mode, $twiki->{users}->findUser($user),undef,undef,$topic,$web),
                  "$user $mode $web.$topic");
}

sub PERMITTED {
    my( $this, $web, $topic, $mode, $user ) = @_;
    $this->assert($twiki->{security}->checkAccessPermission
                  ($mode, $twiki->{users}->findUser($user),undef,undef,$topic,$web),
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
\t* Set DENYTOPICVIEW = $MrGreen
   * Set DENYTOPICVIEW = $MrYellow,$peopleWeb.$MrOrange,%MAINWEB%.ReservoirDogsGroup
THIS
                                , undef);
    $twiki->finish();
    $twiki = new TWiki();

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
    $twiki->finish();
    $twiki = new TWiki();
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
    $twiki->finish();
    $twiki = new TWiki();
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
    $twiki->finish();
    $twiki = new TWiki(undef, $topicquery);
    $this->PERMITTED($testWeb,$testTopic,"VIEW",$MrOrange);
    $twiki->finish();
    $twiki = new TWiki(undef, $topicquery);
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrGreen);
    $twiki->finish();
    $twiki = new TWiki(undef, $topicquery);
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrYellow);
    $twiki->finish();
    $twiki = new TWiki(undef, $topicquery);
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrWhite);
    $twiki->finish();
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
    $twiki->finish();
    $twiki = new TWiki();
    $this->PERMITTED($testWeb,$testTopic,"VIEW",$MrOrange);
    $twiki->finish();
    $twiki = new TWiki();
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrGreen);
    $twiki->finish();
    $twiki = new TWiki();
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrYellow);
    $twiki->finish();
    $twiki = new TWiki();
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrWhite);
    $twiki->finish();
    $twiki = new TWiki();
    $this->DENIED($testWeb,$testTopic,"view",$MrBlue);
}

sub test_allowtopic_c {
    my $this = shift;
    $twiki->{store}->saveTopic( $currUser, $testWeb, $testTopic,
                                <<THIS
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
%META:PREFERENCE{name="ALLOWTOPICVIEW" title="ALLOWTOPICVIEW" type="Set" value="%25MAINWEB%25.$MrOrange $MrYellow"}%
THIS
                                , undef);
    # renew TWiki, so WebPreferences gets re-read
    $twiki->finish();
    $twiki = new TWiki();
    $this->PERMITTED($testWeb,$testTopic,"VIEW",$MrOrange);
    $twiki->finish();
    $twiki = new TWiki();
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrGreen);
    $twiki->finish();
    $twiki = new TWiki();
    $this->PERMITTED($testWeb,$testTopic,"VIEW",$MrYellow);
    $twiki->finish();
    $twiki = new TWiki();
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrWhite);
    $twiki->finish();
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
    $twiki->finish();
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
    $twiki->{store}->saveTopic(
        $currUser, $testWeb, $TWiki::cfg{WebPrefsTopicName},
        <<THIS
If ALLOWWEB is set to a list of wikinames
    * people in the list will be PERMITTED
    * everyone else will be DENIED
\t* Set ALLOWWEBVIEW = $MrGreen $MrYellow $MrWhite
THIS
                                , undef);
    # renew TWiki, so WebPreferences gets re-read
    $twiki->finish();
    $twiki = new TWiki();
    $twiki->{store}->saveTopic( $currUser, $testWeb, $testTopic,
                                "Null points");
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrOrange);
    $this->PERMITTED($testWeb,$testTopic,"VIEW",$MrGreen);
    $this->PERMITTED($testWeb,$testTopic,"VIEW",$MrYellow);
    $this->PERMITTED($testWeb,$testTopic,"VIEW",$MrWhite);
    $this->DENIED($testWeb,$testTopic,"view",$MrBlue);
}

sub checkText {
    my ($this, $text, $meta) = @_;

    $this->assert(!$twiki->{security}->checkAccessPermission
                  ('VIEW', $twiki->{users}->findUser($MrOrange),
                   $text,$meta,$testTopic,$testWeb),
                  " 'VIEW' $testWeb.$testTopic");
    $this->assert($twiki->{security}->checkAccessPermission
                  ('VIEW', $twiki->{users}->findUser($MrGreen),
                   $text,$meta,$testTopic,$testWeb),
                  " 'VIEW' $testWeb.$testTopic");
    $this->assert(!$twiki->{security}->checkAccessPermission
                  ('VIEW', $twiki->{users}->findUser($MrYellow),
                   $text,$meta,$testTopic,$testWeb),
                  " 'VIEW' $testWeb.$testTopic");
    $this->assert(!$twiki->{security}->checkAccessPermission
                  ('VIEW', $twiki->{users}->findUser($MrWhite),
                   $text,$meta,$testTopic,$testWeb),
                  " 'VIEW' $testWeb.$testTopic");
    $this->assert(!$twiki->{security}->checkAccessPermission
                  ('VIEW', $twiki->{users}->findUser($MrBlue),
                   $text,$meta,$testTopic,$testWeb),
                  " 'VIEW' $testWeb.$testTopic");
}

sub test_SetInText {
    my $this = shift;

    $twiki->{store}->saveTopic( $currUser, $testWeb, $testTopic, 'Empty');
    $twiki->finish();
    $twiki = new TWiki();

    my $text = <<THIS;
\t* Set ALLOWTOPICVIEW = %MAINWEB%.$MrGreen
THIS
    $this->checkText($text, undef);
}

sub test_setInMETA {
    my $this = shift;

    $twiki->{store}->saveTopic( $currUser, $testWeb, $testTopic, 'Empty');
    $twiki->finish();
    $twiki = new TWiki();
    my $meta = new TWiki::Meta($twiki,$testWeb,$testTopic);
    my $args =
      {
          name =>  'ALLOWTOPICVIEW',
          title => 'ALLOWTOPICVIEW',
          value => "%MAINWEB%.$MrGreen",
          type =>  "Set"
         };
    $meta->putKeyed('PREFERENCE', $args);
    $this->checkText('', $meta);
}

sub test_setInSetAndMETA {
    my $this = shift;

    $twiki->{store}->saveTopic( $currUser, $testWeb, $testTopic, 'Empty');
    $twiki->finish();
    $twiki = new TWiki();
    my $meta = new TWiki::Meta($twiki,$testWeb,$testTopic);
    my $args =
      {
          name =>  'ALLOWTOPICVIEW',
          title => 'ALLOWTOPICVIEW',
          value => "%MAINWEB%.$MrGreen",
          type =>  "Set"
         };
    $meta->putKeyed('PREFERENCE', $args);
    my $text = <<THIS;
\t* Set ALLOWTOPICVIEW = %MAINWEB%.$MrOrange
THIS
    $this->checkText($text, $meta);
}

sub test_setInEmbedAndNoMETA {
    my $this = shift;

    $twiki->{store}->saveTopic( $currUser, $testWeb, $testTopic, 'Empty');
    $twiki->finish();
    $twiki = new TWiki();
    my $text = <<THIS;
%META:PREFERENCE{name="ALLOWTOPICVIEW" title="ALLOWTOPICVIEW" type="Set" value="%25MAINWEB%25.$MrGreen"}%
THIS
    $this->checkText($text, undef);
}

sub test_setInEmbedAndMETA {
    my $this = shift;

    $twiki->{store}->saveTopic( $currUser, $testWeb, $testTopic, 'Empty');
    $twiki->finish();
    $twiki = new TWiki();
    my $meta = new TWiki::Meta($twiki,$testWeb,$testTopic);
    my $args =
      {
          name =>  'ALLOWTOPICVIEW',
          title => 'ALLOWTOPICVIEW',
          value => "%MAINWEB%.$MrGreen",
          type =>  "Set"
         };
    $meta->putKeyed('PREFERENCE', $args);
    my $text = <<THIS;
%META:PREFERENCE{name="ALLOWTOPICVIEW" title="ALLOWTOPICVIEW" type="Set" value="%25MAINWEB%25.$MrOrange"}%
THIS
    $this->checkText($text, $meta);
}

sub test_hierarchical_subweb_controls_Item2815 {
    my $this = shift;

    $TWiki::cfg{EnableHierarchicalWebs} = 1;
    $twiki->{store}->createWeb($twiki->{user}, "$testWeb/SubWeb");
    $twiki->{store}->saveTopic(
        $currUser, $testWeb, $TWiki::cfg{WebPrefsTopicName},
        <<THIS, undef);
\t* Set ALLOWWEBVIEW = $MrGreen
THIS
    $twiki->{store}->saveTopic(
        $currUser, "$testWeb/SubWeb", $TWiki::cfg{WebPrefsTopicName},
        <<THIS, undef);
\t* Set ALLOWWEBVIEW = $MrOrange
THIS

    $this->PERMITTED($testWeb,$testTopic,"VIEW",$MrGreen);
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrOrange);
    $this->PERMITTED($testWeb,$testTopic,"VIEW",$MrOrange);
    $this->DENIED($testWeb,$testTopic,"VIEW",$MrGreen);
}

1;
