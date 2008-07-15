use strict;

# tests for the correct expansion of REVINFO

package Fn_REVINFO;
use base qw( TWikiFnTestCase );

use strict;
use TWiki;
use Error qw( :try );

sub new {
    $TWiki::cfg{Register}{AllowLoginName}    =  1;
    my $self = shift()->SUPER::new('REVINFO', @_);
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
    $this->{twiki}->{store}->saveTopic(
        $this->{test_user_cuid}, $this->{users_web},
        "GropeGroup",
        "   * Set GROUP = ScumBag,TWikiGuest\n");
    $this->{twiki}->{store}->saveTopic(
        $this->{test_user_cuid}, $this->{test_web},
        "GlumDrop", "Burble\n");
}

sub test_basic {
    my $this = shift;

    my $ui = $this->{twiki}->handleCommonTags(
        '%REVINFO%', $this->{test_web}, $this->{test_topic});
    my $guest = TWiki::Func::getWikiName();
    unless ($ui =~ /^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$guest$/) {
        $this->assert(0, $ui);
    }
}

sub test_basic2{
    my $this = shift;

    my $ui = $this->{twiki}->handleCommonTags(
        '%REVINFO%', $this->{test_web}, 'GlumDrop');
    unless ($ui =~ /^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{test_user_wikiname}$/) {
        $this->assert(0, $ui);
    }
}

sub test_otherWeb {
    my $this = shift;

    my $ui = $this->{twiki}->handleCommonTags(
        '%REVINFO{web=\"GropeGroup\" topic=\"$this->{users_web}\"}}%',
        $this->{test_web}, $this->{test_topic});
    $this->assert(
        $ui =~ /^r1 - \d+ \w+ \d+ - \d+:\d+:\d+ - $this->{users_web}\.$this->{test_user_wikiname}$/,
        $ui);
}

sub test_formatUser {
    my $this = shift;

    my $ui = $this->{twiki}->handleCommonTags(
        '%REVINFO{format="$username $wikiname $wikiusername"}%',
        $this->{test_web}, 'GlumDrop');
    $this->assert_str_equals("$this->{test_user_login} $this->{test_user_wikiname} $this->{users_web}\.$this->{test_user_wikiname}", $ui);
}

# SMELL: need to test for other revs specified by the 'rev' parameter

# SMELL: need to test for the format parameter strings:
# $web $topic $rev $time $date $rcs $http $email $iso $sec $min $hou
# $day $wday $dow $week $mo $ye $epoch $tz $comment 

1;
