use strict;

package AccessControlTests;

use base qw(TWikiFnTestCase);

sub new {
    my $self = shift()->SUPER::new('AccessControl', @_);
    return $self;
}

use TWiki;
use TWiki::Access;

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

    $currUser = $TWiki::cfg{DefaultUserLogin};
    $twiki->{store}->saveTopic($twiki->{user},
                               $TWiki::cfg{UsersWebName},
                               $TWiki::cfg{DefaultUserWikiName},'');
    $this->registerUser(
        'white', 'Mr', "White", 'white@example.com');
    $MrWhite = 'white';
    $this->registerUser(
        'blue', 'Mr', "Blue", 'blue@example.com');
    $MrBlue = 'blue';
    $this->registerUser(
        'orange', 'Mr', "Orange", 'orange@example.com');
    $MrOrange = 'orange';
    $this->registerUser(
        'green', 'Mr', "Green", 'green@example.com');
    $MrGreen = 'green';
    $this->registerUser(
        'yellow', 'Mr', "Yellow", 'yellow@example.com');
    $MrYellow = 'yellow';
    $twiki->{store}->saveTopic(
        $currUser, $this->{users_web}, "ReservoirDogsGroup", <<THIS);
   * Set GROUP = MrWhite, $this->{users_web}.MrBlue
THIS
}

sub DENIED {
    my( $this, $web, $topic, $mode, $user ) = @_;
    $this->assert(!$twiki->{security}->checkAccessPermission
                  ($mode, $user,undef,undef,$topic,$web),
                  "$user $mode $web.$topic");
}

sub PERMITTED {
    my( $this, $web, $topic, $mode, $user ) = @_;
    $this->assert($twiki->{security}->checkAccessPermission
                  ($mode, $user,undef,undef,$topic,$web),
                 "$user $mode $web.$topic");
}

# Note: As we do not initialize twiki with a query, the topic that topic prefs
# are initialized from is WebHome. Thus these tests also test reading a topic
# other than the current topic.

sub test_denytopic {
    my $this = shift;
    $twiki->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic,
                                <<THIS
If DENYTOPIC is set to a list of wikinames
    * people in the list will be DENIED.
\t* Set DENYTOPICVIEW = MrGreen
   * Set DENYTOPICVIEW = MrYellow,$this->{users_web}.MrOrange,%MAINWEB%.ReservoirDogsGroup
THIS
                                , undef);
    $twiki->finish();
    $twiki = new TWiki();

    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrGreen);
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrYellow);
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrOrange);
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrWhite);
    $this->DENIED($this->{test_web},$testTopic,"view",$MrBlue);

}

sub test_empty_denytopic {
    my $this = shift;
    $twiki->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic,
                                <<THIS
If DENYTOPIC is set to empty ( i.e. Set DENYTOPIC = )
    * access is PERMITTED _i.e _ no-one is denied access to this topic
   * Set DENYTOPICVIEW=
THIS
                                , undef);
    $twiki->finish();
    $twiki = new TWiki();
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrGreen);
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrYellow);
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrOrange);
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrWhite);
    $this->PERMITTED($this->{test_web},$testTopic,"view",$MrBlue);
}

sub test_allowtopic {
    my $this = shift;
    $twiki->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic,
                                <<THIS
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
\t* Set ALLOWTOPICVIEW = %MAINWEB%.MrOrange
THIS
                                , undef);
    $twiki->finish();
    $twiki = new TWiki();
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrOrange);
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrGreen);
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrYellow);
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrWhite);
    $this->DENIED($this->{test_web},$testTopic,"view",$MrBlue);
}

sub test_allowtopic_a {
    my $this = shift;
    $twiki->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic,
                                <<THIS
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
\t* Set ALLOWTOPICVIEW = %MAINWEB%.MrOrange
THIS
                                , undef);
    my $topicquery = new CGI( "" );
    $topicquery->path_info("/$this->{test_web}/$testTopic");
    # renew TWiki, so WebPreferences gets re-read
    $twiki->finish();
    $twiki = new TWiki(undef, $topicquery);
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrOrange);
    $twiki->finish();
    $twiki = new TWiki(undef, $topicquery);
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrGreen);
    $twiki->finish();
    $twiki = new TWiki(undef, $topicquery);
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrYellow);
    $twiki->finish();
    $twiki = new TWiki(undef, $topicquery);
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrWhite);
    $twiki->finish();
    $twiki = new TWiki(undef, $topicquery);
    $this->DENIED($this->{test_web},$testTopic,"view",$MrBlue);
}

sub test_allowtopic_b {
    my $this = shift;
    $twiki->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic,
                                <<THIS
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
\t* Set ALLOWTOPICVIEW = %MAINWEB%.MrOrange
THIS
                                , undef);
    # renew TWiki, so WebPreferences gets re-read
    $twiki->finish();
    $twiki = new TWiki();
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrOrange);
    $twiki->finish();
    $twiki = new TWiki();
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrGreen);
    $twiki->finish();
    $twiki = new TWiki();
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrYellow);
    $twiki->finish();
    $twiki = new TWiki();
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrWhite);
    $twiki->finish();
    $twiki = new TWiki();
    $this->DENIED($this->{test_web},$testTopic,"view",$MrBlue);
}

sub test_allowtopic_c {
    my $this = shift;
    $twiki->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic,
                                <<THIS
If ALLOWTOPIC is set
   1. people in the list are PERMITTED
   2. everyone else is DENIED
%META:PREFERENCE{name="ALLOWTOPICVIEW" title="ALLOWTOPICVIEW" type="Set" value="%25MAINWEB%25.MrOrange MrYellow"}%
THIS
                                , undef);
    # renew TWiki, so WebPreferences gets re-read
    $twiki->finish();
    $twiki = new TWiki();
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrOrange);
    $twiki->finish();
    $twiki = new TWiki();
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrGreen);
    $twiki->finish();
    $twiki = new TWiki();
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrYellow);
    $twiki->finish();
    $twiki = new TWiki();
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrWhite);
    $twiki->finish();
    $twiki = new TWiki();
    $this->DENIED($this->{test_web},$testTopic,"view",$MrBlue);
}

sub test_denyweb {
    my $this = shift;
    $twiki->{store}->saveTopic( $currUser, $this->{test_web}, $TWiki::cfg{WebPrefsTopicName},
                                <<THIS
If DENYWEB is set to a list of wikiname
    * people in the list are DENIED access
\t* Set DENYWEBVIEW = $this->{users_web}.MrOrange %MAINWEB%.MrBlue
THIS
                                , undef);
    # renew TWiki, so WebPreferences gets re-read
    $twiki->finish();
    $twiki = new TWiki();
    $twiki->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic,
                                "Null points");
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrOrange);
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrGreen);
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrYellow);
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrWhite);
    $this->DENIED($this->{test_web},$testTopic,"view",$MrBlue);
}

sub test_allow_web {
    my $this = shift;
    $twiki->{store}->saveTopic(
        $currUser, $this->{test_web}, $TWiki::cfg{WebPrefsTopicName},
        <<THIS
If ALLOWWEB is set to a list of wikinames
    * people in the list will be PERMITTED
    * everyone else will be DENIED
\t* Set ALLOWWEBVIEW = MrGreen MrYellow MrWhite
THIS
                                , undef);
    # renew TWiki, so WebPreferences gets re-read
    $twiki->finish();
    $twiki = new TWiki();
    $twiki->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic,
                                "Null points");
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrOrange);
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrGreen);
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrYellow);
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrWhite);
    $this->DENIED($this->{test_web},$testTopic,"view",$MrBlue);
}

sub checkText {
    my ($this, $text, $meta) = @_;

    $this->assert(!$twiki->{security}->checkAccessPermission
                  ('VIEW', $MrOrange,
                   $text,$meta,$testTopic,$this->{test_web}),
                  " 'VIEW' $this->{test_web}.$testTopic");
    $this->assert($twiki->{security}->checkAccessPermission
                  ('VIEW', $MrGreen,
                   $text,$meta,$testTopic,$this->{test_web}),
                  " 'VIEW' $this->{test_web}.$testTopic");
    $this->assert(!$twiki->{security}->checkAccessPermission
                  ('VIEW', $MrYellow,
                   $text,$meta,$testTopic,$this->{test_web}),
                  " 'VIEW' $this->{test_web}.$testTopic");
    $this->assert(!$twiki->{security}->checkAccessPermission
                  ('VIEW', $MrWhite,
                   $text,$meta,$testTopic,$this->{test_web}),
                  " 'VIEW' $this->{test_web}.$testTopic");
    $this->assert(!$twiki->{security}->checkAccessPermission
                  ('VIEW', $MrBlue,
                   $text,$meta,$testTopic,$this->{test_web}),
                  " 'VIEW' $this->{test_web}.$testTopic");
}

sub test_SetInText {
    my $this = shift;

    $twiki->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic, 'Empty');
    $twiki->finish();
    $twiki = new TWiki();

    my $text = <<THIS;
\t* Set ALLOWTOPICVIEW = %MAINWEB%.MrGreen
THIS
    $this->checkText($text, undef);
}

sub test_setInMETA {
    my $this = shift;

    $twiki->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic, 'Empty');
    $twiki->finish();
    $twiki = new TWiki();
    my $meta = new TWiki::Meta($twiki,$this->{test_web},$testTopic);
    my $args =
      {
          name =>  'ALLOWTOPICVIEW',
          title => 'ALLOWTOPICVIEW',
          value => "%MAINWEB%.MrGreen",
          type =>  "Set"
         };
    $meta->putKeyed('PREFERENCE', $args);
    $this->checkText('', $meta);
}

sub test_setInSetAndMETA {
    my $this = shift;

    $twiki->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic, 'Empty');
    $twiki->finish();
    $twiki = new TWiki();
    my $meta = new TWiki::Meta($twiki,$this->{test_web},$testTopic);
    my $args =
      {
          name =>  'ALLOWTOPICVIEW',
          title => 'ALLOWTOPICVIEW',
          value => "%MAINWEB%.MrGreen",
          type =>  "Set"
         };
    $meta->putKeyed('PREFERENCE', $args);
    my $text = <<THIS;
\t* Set ALLOWTOPICVIEW = %MAINWEB%.MrOrange
THIS
    $this->checkText($text, $meta);
}

sub test_setInEmbedAndNoMETA {
    my $this = shift;

    $twiki->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic, 'Empty');
    $twiki->finish();
    $twiki = new TWiki();
    my $text = <<THIS;
%META:PREFERENCE{name="ALLOWTOPICVIEW" title="ALLOWTOPICVIEW" type="Set" value="%25MAINWEB%25.MrGreen"}%
THIS
    $this->checkText($text, undef);
}

sub test_setInEmbedAndMETA {
    my $this = shift;

    $twiki->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic, 'Empty');
    $twiki->finish();
    $twiki = new TWiki();
    my $meta = new TWiki::Meta($twiki,$this->{test_web},$testTopic);
    my $args =
      {
          name =>  'ALLOWTOPICVIEW',
          title => 'ALLOWTOPICVIEW',
          value => "%MAINWEB%.MrGreen",
          type =>  "Set"
         };
    $meta->putKeyed('PREFERENCE', $args);
    my $text = <<THIS;
%META:PREFERENCE{name="ALLOWTOPICVIEW" title="ALLOWTOPICVIEW" type="Set" value="%25MAINWEB%25.MrOrange"}%
THIS
    $this->checkText($text, $meta);
}

sub test_hierarchical_subweb_controls_Item2815 {
    my $this = shift;
    my $subweb = "$this->{test_web}.SubWeb";

    $TWiki::cfg{EnableHierarchicalWebs} = 1;
    $twiki->{store}->createWeb($twiki->{user}, $subweb);
    $twiki->{store}->saveTopic( $currUser, $this->{test_web}, $testTopic, "Nowt");
    $twiki->{store}->saveTopic(
        $currUser, $this->{test_web}, $TWiki::cfg{WebPrefsTopicName},
        <<THIS, undef);
\t* Set ALLOWWEBVIEW = MrGreen
THIS
    $twiki->{store}->saveTopic(
        $currUser, $subweb, $TWiki::cfg{WebPrefsTopicName},
        <<THIS, undef);
\t* Set ALLOWWEBVIEW = MrOrange
THIS
    $twiki->finish();
    $twiki = new TWiki();
    $this->PERMITTED($subweb,$testTopic,"VIEW",$MrOrange);
    $this->DENIED($subweb,$testTopic,"VIEW",$MrGreen);
    $this->PERMITTED($this->{test_web},$testTopic,"VIEW",$MrGreen);
    $this->DENIED($this->{test_web},$testTopic,"VIEW",$MrOrange);
}

1;
