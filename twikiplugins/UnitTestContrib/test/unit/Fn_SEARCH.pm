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

sub Forking {
    require TWiki::Store::SearchAlgorithms::Forking;

    $TWiki::cfg{RCS}{SearchAlgorithm} =
      "TWiki::Store::SearchAlgorithms::Forking";
}

sub Native {
    $TWiki::cfg{RCS}{SearchAlgorithm} =
      "TWiki::Store::SearchAlgorithms::Native";
}

sub PurePerl {
    require TWiki::Store::SearchAlgorithms::PurePerl;

    $TWiki::cfg{RCS}{SearchAlgorithm} =
      "TWiki::Store::SearchAlgorithms::PurePerl";
}

sub fixture_groups {
    my $groups = [ 'Forking', 'PurePerl' ];
    eval "require TWiki::Store::SearchAlgorithms::Native";
    if ($@ || !defined(&NativeTWikiSearch::cgrep)) {
        print STDERR "\nWARNING: unable to test native search, module may not be installed\n";
    } else {
        push(@$groups, 'Native');
    }

    return ( $groups );
}

sub verify_simple  {
    my $this = shift;

    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"BLEEGLE" topic="Ok-Topic,Ok+Topic,OkTopic" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);
}

sub verify_angleb {
    my $this = shift;
    # Test regex with \< and \>, used in rename searches
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"\<matc[h]me\>" type="regex" topic="Ok-Topic,Ok+Topic,OkTopic" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);
}

sub verify_topicName {
    my $this = shift;
    # Test topic name search
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"Ok.*" type="regex" scope="topic" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);
}

sub verify_regex_trivial {
    my $this = shift;
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"blah" type="regex" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);
}

sub verify_literal {
    my $this = shift;
    # literal
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"blah" type="literal" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);
}


sub verify_keyword {
    my $this = shift;
    # keyword
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"blah" type="keyword" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);
}

sub verify_word {
    my $this = shift;

    # word
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"blah" type="word" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);
}

sub verify_regex_match {
    my $this = shift;

    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"match" type="regex" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);
}


sub verify_literal_match {
    my $this = shift;
    # literal
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"match" type="literal" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);
}

sub verify_keyword_match {
    my $this = shift;

    # keyword
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"match" type="keyword" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);
}

sub verify_word_match {
    my $this = shift;
    # word
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"match" type="word" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_does_not_match(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);
}

sub verify_regex_matchme {
    my $this = shift;

    # ---------------------
    # Search string 'matchme'
    # regex
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"matchme" type="regex" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);
}

sub verify_literal_matchme {
    my $this = shift;
    # literal
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"matchme" type="literal" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);
}

sub verify_keyword_matchme {
    my $this = shift;

    # keyword
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"matchme" type="keyword" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);

}

sub verify_word_matchme {
    my $this = shift;
    # word
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"matchme" type="word" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);

}

sub verify_minus_regex {
    my $this = shift;
    # ---------------------
    # Search string 'matchme -dont'
    # regex
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"matchme -dont" type="regex" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_does_not_match(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);
}

sub verify_minus_literal {
    my $this = shift;
    # literal
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"matchme -dont" type="literal" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_does_not_match(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);

}

sub verify_minus_keyword {
    my $this = shift;
    # keyword
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"matchme -dont" type="keyword" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);

}

sub verify_minus_word {
    my $this = shift;
    # word
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"matchme -dont" type="word" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);

}

sub verify_slash_regex {
    my $this = shift;
    # ---------------------
    # Search string 'blah/matchme.blah'
    # regex
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"blah/matchme.blah" type="regex" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);

}

sub verify_slash_literal {
    my $this = shift;
    # literal
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"blah/matchme.blah" type="literal" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);

}

sub verify_slash_keyword {
    my $this = shift;
    # keyword
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"blah/matchme.blah" type="keyword" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);

}

sub verify_slash_word {
    my $this = shift;
    # word
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"blah/matchme.blah" type="word" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);

}

sub verify_quote_regex {
    my $this = shift;
    # ---------------------
    # Search string 'BLEEGLE dont'
    # regex
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"\"BLEEGLE dont\"" type="regex" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_does_not_match(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);

}

sub verify_quote_literal {
    my $this = shift;
    # literal
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"\"BLEEGLE dont\"" type="literal" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_does_not_match(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok\+Topic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);

}

sub verify_quote_keyword {
    my $this = shift;
    # keyword
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"\"BLEEGLE dont\"" type="keyword" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_does_not_match(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);

}

sub verify_quote_word {
    my $this = shift;
    # word
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"\"BLEEGLE dont\"" type="word" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_does_not_match(qr/OkTopic/, $result);
    $this->assert_does_not_match(qr/Ok-Topic/, $result);
    $this->assert_matches(qr/Ok\+Topic/, $result);
}

sub verify_SEARCH_3860 {
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

sub verify_search_empty_regex {
    my $this = shift;

    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"" type="regex" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("", $result);
}

sub verify_search_empty_literal {
    my $this = shift;

    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"" type="literal" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("", $result);
}

sub verify_search_empty_keyword {
    my $this = shift;

    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"" type="keyword" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("", $result);
}

sub verify_search_empty_word {
    my $this = shift;

    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"" type="word" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("", $result);
}

sub verify_search_numpty_regex {
    my $this = shift;

    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"something.Very/unLikelyTo+search-for;-\)" type="regex" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("", $result);
}

sub verify_search_numpty_literal {
    my $this = shift;

    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"something.Very/unLikelyTo+search-for;-)" type="literal" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("", $result);
}

sub verify_search_numpty_keyword {
    my $this = shift;

    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"something.Very/unLikelyTo+search-for;-)" type="keyword" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("", $result);
}

sub verify_search_numpty_word {
    my $this = shift;

    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"something.Very/unLikelyTo+search-for;-)" type="word" scope="text" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("", $result);
}

sub set_up_for_queries {
    my $this = shift;
    my $text = <<'HERE';
%META:TOPICINFO{author="TWikiUserMapping_guest" date="1178612772" format="1.1" version="1.1"}%
%META:TOPICPARENT{name="WebHome"}%
This is QueryTopic FURTLE
%META:FORM{name="TestForm"}%
%META:FIELD{name="Field1" attributes="H" title="A Field" value="A Field"}%
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
This is QueryTopicTwo SMONG
%META:TOPICPARENT{name="QueryTopic"}%
%META:FORM{name="TestyForm"}%
%META:FIELD{name="FieldA" attributes="H" title="B Field" value="7"}%
%META:FIELD{name="FieldB" attributes="" title="Banother Field" value="8"}%
%META:FIELD{name="Firstname" attributes="" title="Pre Name" value="John"}%
%META:FIELD{name="Lastname" attributes="" title="Post Name" value="Peel"}%
%META:FIELD{name="form" attributes="" title="Blah" value="form good"}%
%META:FIELD{name="FORM" attributes="" title="Blah" value="FORM GOOD"}%
%META:FILEATTACHMENT{name="porn.gif" comment="Cor" date="15062" size="15504"}%
%META:FILEATTACHMENT{name="flib.xml" comment="Cor" date="1157965062" size="1"}%
HERE
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web},
        'QueryTopicTwo', $text);
}

# NOTE: most query ops are tested in Fn_IF.pm, and are not re-tested here

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
        '%SEARCH{"attachments[size > 0]"'.$stdCrap,
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('QueryTopic QueryTopicTwo', $result);
}

sub test_attachmentSizeQuery2 {
    my $this = shift;

    $this->set_up_for_queries();
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"META:FILEATTACHMENT[size > 10000]"'.$stdCrap,
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('QueryTopicTwo', $result);
}

sub test_indexQuery {
    my $this = shift;

    $this->set_up_for_queries();
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"attachments[name=\'flib.xml\']"'.$stdCrap,
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

sub test_4580Query1 {
    my $this = shift;

    $this->set_up_for_queries();
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"text ~ \'*SMONG*\' AND Lastname=\'Peel\'"'.$stdCrap,
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('QueryTopicTwo', $result);
}

sub test_4580Query2 {
    my $this = shift;

    $this->set_up_for_queries();
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"text ~ \'*FURTLE*\' AND Lastname=\'Peel\'"'.$stdCrap,
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('QueryTopic', $result);
}

sub test_gropeQuery2 {
    my $this = shift;

    $this->set_up_for_queries();
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"Lastname=\'Peel\'"'.$stdCrap,
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('QueryTopic QueryTopicTwo', $result);
}

sub test_formQuery {
    my $this = shift;

    $this->set_up_for_queries();
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"form.name=\'TestyForm\'"'.$stdCrap,
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('QueryTopicTwo', $result);
}

sub test_formQuery2 {
    my $this = shift;

    $this->set_up_for_queries();
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"TestForm"'.$stdCrap,
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('QueryTopic', $result);
}

sub test_formQuery3 {
    my $this = shift;

    $this->set_up_for_queries();
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"TestForm[name=\'Field1\'].value=\'A Field\'"'.$stdCrap,
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('QueryTopic', $result);
}

sub test_formQuery4 {
    my $this = shift;

    $this->set_up_for_queries();
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"TestForm.Field1=\'A Field\'"'.$stdCrap,
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('QueryTopic', $result);
}

sub test_formQuery5 {
    my $this = shift;

    $this->set_up_for_queries();
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"TestyForm.form=\'form good\'"'.$stdCrap,
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('QueryTopicTwo', $result);
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"TestyForm.FORM=\'FORM GOOD\'"'.$stdCrap,
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('QueryTopicTwo', $result);
}

sub test_refQuery {
    my $this = shift;

    $this->set_up_for_queries();
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"parent.name/(Firstname ~ \'*mm?\' AND Field2=2)"'.$stdCrap,
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('QueryTopicTwo', $result);
}

# make sure syntax errors are handled cleanly. All the error cases thrown by
# the infix parser are tested more thoroughly in Fn_IF, and don't have to
# be re-tested here.
sub test_badQuery1 {
    my $this = shift;

    $this->set_up_for_queries();
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"A * B"'.$stdCrap,
        $this->{test_web}, $this->{test_topic});
    $this->assert_matches(qr/Error was: Syntax error in 'A \* B' at ' \* B'/s, $result);
}

# Compare performance of an RE versus a query. Only enable this if you are
# interested in benchmarking.
sub benchmarktest_largeQuery {
    my $this = shift;
    # Generate 1000 topics
    # half (500) of these match the first term of the AND
    # 100 match the second
    # 10 match the third
    # 1 matches the fourth

    for my $n (1..21) {
        my $vA = ($n <= 500) ? 'A' : 'B';
        my $vB = ($n <= 100) ? 'A' : 'B';
        my $vC = ($n <= 10) ? 'A' : 'B';
        my $vD = ($n == 1) ? 'A' : 'B';
        my $vE = ($n == 2) ? 'A' : 'B';
        my $text = <<HERE;
%META:TOPICINFO{author="TWikiUserMapping_guest" date="12" format="1.1" version="1.2"}%
---+ Progressive Sexuality
A Symbol Interpreted In American Architecture. Meta-Physics Of Marxism & Poverty In The American Landscape. Exploration Of Crime In Mexican Sculptures: A Study Seen In American Literature. Brief Survey Of Suicide In Italian Art: The Big Picture. Special Studies In Bisexual Female Architecture. Brief Survey Of Suicide In Polytheistic Literature: Analysis, Analysis, and Critical Thinking. Radical Paganism: Modern Theories. Liberal Mexican Religion In The Modern Age. Selected Topics In Global Warming: $vD Policy In Modern America. Survey Of The Aesthetic Minority Revolution In The American Landscape. Populist Perspectives: Myth & Reality. Ethnicity In Modern America: The Bisexual Latino Condition. Postmodern Marxism In Modern America. Female Literature As A Progressive Genre. Horror & Life In Recent Times. The Universe Of Female Values In The Postmodern Era.

---++ Work, Politics, And Conflict In European Drama: A Symbol Interpreted In 20th Century Poetry
Sexuality & Socialism In Modern Society. Special Studies In Early Egyptian Art: A Study Of Globalism In The United States. Meta-Physics Of Synchronized Swimming: The Baxter-Floyd Principle At Work. Ad-Hoc Investigation Of Sex In Middle Eastern Art: Contemporary Theories. Concepts In Eastern Mexican Folklore. The Liberated Dimension Of Western Minority Mythology. French Art Interpretation: A Figure Interpreted In American Drama

---+ Theories Of Liberal Pre-Cubism & The Crowell Law.
We are committed to enhance vertical sub-functionalities and skill sets. Our function is to competently reinvent our mega-relationships. Our responsibility is to expertly engineer content. Our obligation is to continue to zealously simplify our customer-centric paradigms as part of our five-year plan to successfully market an overhyped more expensive line of products and produce more dividends for our serfs. $vA It is our mission to optimize progressive schemas and supply-chains to better serve the country. We are committed to astutely deliver our net-niches, user-centric face time, and assets in order to dominate the economy. It is our goal to conveniently facilitate our e-paradigms, our frictionless skill sets, and our architectures to shore up revenue for our workers. Our goal is to work towards skillfully enabling catalysts for metrics.

We resolve to endeavor to synthesize our sub-partnerships in order that we may intelligently unleash bleeding-edge total quality management as part of our master plan to burgeon our bottom line. It is our business to work to enhance our initiatives in order that we may take $vB over the nation and take over the country. It's our task to reinvent massively-parallel relationships. We execute a strategic plan to quickly facilitate our niches and enthusiastically maximize our extensible perspectives.

Our obligation is to work to spearhead cutting-edge portals so that hopefully we may successfully market an overhyped poor product line.

We have committed to work to effectively facilitate global e-channels as part of a larger $vC strategy to create a higher quality product and create a lot of bucks. Our duty is to work to empower our revolutionary functionalities and simplify our idiot-proof synergies as a component of our plan to beat the snot out of our enemies. We resolve to engage our mega-eyeballs, our e-bandwidth, and intuitive face time in order to earn a lot of scratch. It's our obligation to generate our niches.

---+ It is our job to strive to simplify our bandwidth.
We have committed to enable customer-centric supply-chains and our mega-channels as part of our business plan to meet the wants of our valued customers.
We have committed to take steps towards $vE reinventing our cyber-key players and harnessing frictionless net-communities so that hopefully we may better serve our customers.
%META:FORM{name="TestForm"}%
%META:FIELD{name="FieldA" attributes="" title="Banother Field" value="$vA"}%
%META:FIELD{name="FieldB" attributes="" title="Banother Field" value="$vB"}%
%META:FIELD{name="FieldC" attributes="" title="Banother Field" value="$vC"}%
%META:FIELD{name="FieldD" attributes="" title="Banother Field" value="$vD"}%
%META:FIELD{name="FieldE" attributes="" title="Banother Field" value="$vE"}%
HERE
        $this->{twiki}->{store}->saveTopic(
            $this->{twiki}->{user}, $this->{test_web},
            "QueryTopic$n", $text);
    }
    require Benchmark;

    # Search using a regular expression
    my $start = new Benchmark;
    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"^[%]META:FIELD{name=\"FieldA\".*\bvalue=\"A\";^[%]META:FIELD{name=\"FieldB\".*\bvalue=\"A\";^[%]META:FIELD{name=\"FieldC\".*\bvalue=\"A\";^[%]META:FIELD{name=\"FieldD\".*\bvalue=\"A\"|^[%]META:FIELD{name=\"FieldE\".*\bvalue=\"A\"" type="regex" nonoise="on" format="$topic" separator=" "}%',
        $this->{test_web}, $this->{test_topic});
    my $retime = Benchmark::timediff(new Benchmark, $start);
    $this->assert_str_equals('QueryTopic1 QueryTopic2', $result);

    # Repeat using a query
    $start = new Benchmark;
    $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"FieldA=\'A\' AND FieldB=\'A\' AND FieldC=\'A\' AND (FieldD=\'A\' OR FieldE=\'A\')" type="query" nonoise="on" format="$topic" separator=" "}%',
        $this->{test_web}, $this->{test_topic});
    my $querytime = Benchmark::timediff(new Benchmark, $start);
    $this->assert_str_equals('QueryTopic1 QueryTopic2', $result);
    print STDERR "Query ".Benchmark::timestr($querytime),"\nRE ".Benchmark::timestr($retime),"\n";
}

sub test_4347 {
    my $this = shift;

    my $result = $this->{twiki}->handleCommonTags(
        "%SEARCH{\"$this->{test_topic}\" scope=\"topic\" nonoise=\"on\" format=\"\$formfield(Blah)\"}%",
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals('', $result);
}

1;
