use strict;

# tests for the correct expansion of SEARCH

package Fn_SEARCH;

use base qw( TWikiFnTestCase );

use TWiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new('SEARCH', @_);
    return $self;
}

sub test_SEARCH_Item2625 {
    my $this = shift;

    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web},
        'OkTopic', "BLEEGLE");
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web},
        'Ok-Topic', "BLEEGLE");

    my $result = $this->{twiki}->handleCommonTags(
        '%SEARCH{"BLEEGLE" topic="Ok-Topic,OkTopic" nonoise="on" format="$topic"}%',
        $this->{test_web}, $this->{test_topic});

    $this->assert_matches(qr/OkTopic/, $result);
    $this->assert_matches(qr/Ok-Topic/, $result);
}

1;
