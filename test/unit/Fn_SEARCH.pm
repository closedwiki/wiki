use strict;

# tests for the correct expansion of SEARCH
# SMELL: this test is pathetic, becase SEARCH has dozens of untested modes

package Fn_SEARCH;

use base qw( TWikiFnTestCase );

use TWiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new('SEARCH', @_);
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web},
        'OkTopic', "BLEEGLE blah/matchme.blah");
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web},
        'Ok-Topic', "BLEEGLE dontmatchme.blah");
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web},
        'Ok+Topic', "BLEEGLE dont.matchmeblah");
}

# Add tests in this function; it is invoked for each algorithm
sub std_tests  {
    my $this = shift;

    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"BLEEGLE" topic="Ok-Topic,Ok+Topic,OkTopic" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);

    # Test regex with \< and \>, used in rename searches
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"\<matc[h]me\>" type="regex" topic="Ok-Topic,Ok+Topic,OkTopic" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);

    # Test topic name search
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"Ok.*" type="regex" scope="topic" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);

    # Test search types

    # ---------------------
    # Search string 'blah'
    # regex
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"blah" type="regex" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);

    # literal
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"blah" type="literal" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);

    # keyword
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"blah" type="keyword" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);

    # word
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"blah" type="word" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);

    # ---------------------
    # Search string 'match'
    # regex
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"match" type="regex" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);

    # literal
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"match" type="literal" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);

    # keyword
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"match" type="keyword" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);

    # word
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"match" type="word" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_does_not_match(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);

    # ---------------------
    # Search string 'matchme'
    # regex
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"matchme" type="regex" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);

    # literal
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"matchme" type="literal" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);

    # keyword
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"matchme" type="keyword" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);

    # word
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"matchme" type="word" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);

    # ---------------------
    # Search string 'matchme -dont'
    # regex
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"matchme -dont" type="regex" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_does_not_match(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);

    # literal
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"matchme -dont" type="literal" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_does_not_match(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);

    # keyword
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"matchme -dont" type="keyword" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);

    # word
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"matchme -dont" type="word" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);

    # ---------------------
    # Search string 'blah/matchme.blah'
    # regex
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"blah/matchme.blah" type="regex" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);

    # literal
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"blah/matchme.blah" type="literal" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);

    # keyword
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"blah/matchme.blah" type="keyword" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);

    # word
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"blah/matchme.blah" type="word" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);

    # ---------------------
    # Search string 'BLEEGLE dont'
    # regex
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"\"BLEEGLE dont\"" type="regex" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_does_not_match(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);

    # literal
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"\"BLEEGLE dont\"" type="literal" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_does_not_match(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);

    # keyword
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"\"BLEEGLE dont\"" type="keyword" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_does_not_match(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);

    # word
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"\"BLEEGLE dont\"" type="word" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_does_not_match(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);
}

sub detest_SEARCH_Forking {
    my $this = shift;

    $TWiki::cfg{RCS}{SearchAlgorithm} =
      "TWiki::Store::SearchAlgorithms::Forking";

    $this->std_tests();
}

sub detest_SEARCH_PurePerl {
    my $this = shift;

    $TWiki::cfg{RCS}{SearchAlgorithm} =
      "TWiki::Store::SearchAlgorithms::PurePerl";

    $this->std_tests();
}

sub detest_SEARCH_Native {
    my $this = shift;

    # Need to try all three of the default algorithms
    eval "require TWiki::Store::SearchAlgorithms::Native";
    if ($@) {
        print STDERR "\nWARNING: unable to test native search, extension module may not be installed\n";
        return;
    }

    $TWiki::cfg{RCS}{SearchAlgorithm} =
          "TWiki::Store::SearchAlgorithms::Native";

    $this->std_tests();
}

sub detest_SEARCH_3860 {
    my $this = shift;
    my $result = $this->{twiki}->handleCommonTags(
        <<'HERE', $this->{test_web}, $this->{test_topic});
%SEARCH{"BLEEGLE" topic="OkTopic" format="$wikiname $wikiusername" nonoise="on" }%
HERE
    my $wn = $this->{twiki}->{users}->getWikiName($this->{twiki}->{user});
    $this->assert_str_equals("$wn $this->{users_web}.$wn\n", $result);
    $result = $this->{twiki}->handleCommonTags(
        <<'HERE', $this->{test_web}, $this->{test_topic});
%SEARCH{"BLEEGLE" topic="OkTopic" format="$createwikiname $createwikiusername" nonoise="on" }%
HERE
    $this->assert_str_equals("$wn $this->{users_web}.$wn\n", $result);
}

sub set_up_for_queries {
    my $this = shift;
    my $text = <<'HERE';
%META:TOPICINFO{author="TWikiUserMapping_guest" date="1178612772" format="1.1" version="1.1"}%
%META:TOPICPARENT{name="WebHome"}%
This is QueryTopic
%META:FORM{name="TestForm"}%
%META:FIELD{name="Field1" attributes="H" title="A Field" value="1"}%
%META:FIELD{name="Field2" attributes="" title="Another Field" value="2"}%
%META:FIELD{name="Firstname" attributes="" title="First Name" value="Emma"}%
%META:FIELD{name="Lastname" attributes="" title="First Name" value="Peel"}%
%META:TOPICMOVED{by="TWikiUserMapping_guest" date="1176311052" from="Sandbox.TestETP" to="Sandbox.TestEarlyTimeProtocol"}%
%META:FILEATTACHMENT{name="README" comment="Blah Blah" date="1157965062" size="5504"}%
HERE
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web},
        'QueryTopic', $text);

    $text = <<'HERE';
%META:TOPICINFO{author="TWikiUserMapping_guest" date="12" format="1.1" version="1.2"}%
This is QueryTopicTwo
%META:TOPICPARENT{name="QueryTopic"}%
%META:FORM{name="TestForm"}%
%META:FIELD{name="Field1" attributes="H" title="A Field" value="7"}%
%META:FIELD{name="Field2" attributes="" title="Another Field" value="8"}%
%META:FIELD{name="Firstname" attributes="" title="First Name" value="John"}%
%META:FIELD{name="Lastname" attributes="" title="First Name" value="Peel"}%
%META:FILEATTACHMENT{name="porn.gif" comment="Cor" date="15062" size="15504"}%
%META:FILEATTACHMENT{name="flib.xml" comment="Cor" date="1157965062" size="1"}%
HERE
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web},
        'QueryTopicTwo', $text);
}


my $stdCrap = 'type="query" nonoise="on" format="$topic" separator=" "}%';

sub test_parentQuery {
    my $this = shift;

    $this->set_up_for_queries();
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"parent.name=\'WebHome\'"'.$stdCrap,
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('QueryTopic', $result);
}

sub test_attachmentSizeQuery1 {
    my $this = shift;

    $this->set_up_for_queries();
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"attachments[?size > 0]"'.$stdCrap,
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('QueryTopic QueryTopicTwo', $result);
}

sub test_attachmentSizeQuery2 {
    my $this = shift;

    $this->set_up_for_queries();
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"attachments[?size > 10000]"'.$stdCrap,
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('QueryTopicTwo', $result);
}

sub test_indexQuery {
    my $this = shift;

    $this->set_up_for_queries();
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"attachments[1].name=\'flib.xml\'"'.$stdCrap,
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('QueryTopicTwo', $result);
}

sub test_gropeQuery {
    my $this = shift;

    $this->set_up_for_queries();
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"Lastname=\'Peel\'"'.$stdCrap,
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('QueryTopic QueryTopicTwo', $result);
}

sub test_gropeQuery2 {
    my $this = shift;

    $this->set_up_for_queries();
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"Firstname=\'Emma\' AND Lastname=\'Peel\'"'.$stdCrap,
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('QueryTopic', $result);
}

sub test_refQuery {
    my $this = shift;

    $this->set_up_for_queries();
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"parent.name:Firstname ~ \'^Emma$\'"'.$stdCrap,
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('QueryTopicTwo', $result);
}

# make sure syntax errors are handled cleanly
sub test_badQuery1 {
    my $this = shift;

    $this->set_up_for_queries();
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"A * B"'.$stdCrap,
        $this->{test_web}, $this->{test_topic});
    $this->assert_matches(qr/Error was: Syntax error in 'A \* B' at ' \* B'/s, $result);
}

1;
