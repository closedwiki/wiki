use strict;

# tests for the correct expansion of IF

package Fn_IF;

use base qw( TWikiFnTestCase );

use TWiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new('IF', @_);
    return $self;
}

sub test_correctIF {
    my $this = shift;
    $this->{twiki}->enterContext('test');
    $TWiki::cfg{Fnargle} = 'Fleeble';
    $TWiki::cfg{A}{B} = 'C';
    my $u = $this->{twiki}->{users};
    my @tests = (
        { test => 'A=B', then=>0, else=>1 },
        { test => 'A!=B', then=>1, else=>0 },
        { test => "A='A'", then=>1, else=>0 },
        { test => "'A'=B", then=>0, else=>1 },
        { test => 'context test', then=>1, else=>0 },
        { test => '{Fnargle}=Fleeble', then=>1, else=>0 },
        { test => '{A}{B}=C', then=>1, else=>0 },
        { test => '$ WIKINAME = '.$u->getWikiName($this->{twiki}->{user}),
          then=>1, else=>0 },
        { test => 'defined EDITBOXHEIGHT', then=>1, else=>0 },
        { test => '0>1', then=>0, else=>1 },
        { test => '1>0', then=>1, else=>0 },
        { test => '1<0', then=>0, else=>1 },
        { test => '0<1', then=>1, else=>0 },
        { test => "0>=\t1", then=>0, else=>1 },
        { test => '1>=0', then=>1, else=>0 },
        { test => '1>=1', then=>1, else=>0 },
        { test => '1<=0', then=>0, else=>1 },
        { test => '0<=1', then=>1, else=>0 },
        { test => '1<=1', then=>1, else=>0 },
        { test => 'not A=B', then=>1, else=>0 },
        { test => 'not NOT A=B', then=>0, else=>1 },
        { test => 'A=A AND B=B', then=>1, else=>0 },
        { test => 'A=A and B=B', then=>1, else=>0 },
        { test => 'A=A and B=B', then=>1, else=>0 },
        { test => '(A=B or A=A) and (B=B)', then=>1, else=>0 },
        { test => 'A=B or B=B', then=>1, else=>0 },
        { test => 'A=A or B=A', then=>1, else=>0 },
        { test => 'A=B or B=A', then=>0, else=>1 },
        { test => "\$PUBURLPATH='".$TWiki::cfg{PubUrlPath}."'", then=>1, else =>0 },
        { test => "'A'~'B'", then=>0, else=>1 },
        { test => "'ABLABA'~'B.AB'", then=>1, else=>0 },
        { test => '\"BABA\"~\"(BA)+\"', then=>1, else=>0 },
       );

    foreach my $test (@tests) {
        my $text = '%IF{"'.$test->{test}.'" then="'.
          $test->{then}.'" else="'.$test->{else}.'"}%';
        my $result = $this->{twiki}->handleCommonTags(
            $text, $this->{test_web}, $this->{test_topic});
        $this->assert_equals('1', $result, $text." => ".$result);
    }
}

sub test_INCLUDEparams {
    my $this = shift;

    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user},
        $this->{test_web},
        "DeadHerring",
        <<'SMELL');
one %IF{ "defined NAME" then="1" else="0" }%
two %IF{ "$ NAME='%NAME%'" then="1" else="0" }%
SMELL
    my $text = <<'PONG';
%INCLUDE{"DeadHerring" NAME="Red" warn="on"}%
PONG
    my $result = $this->{twiki}->handleCommonTags(
        $text, $this->{test_web}, $this->{test_topic});
    $this->assert_matches(qr/^\s*one 1\s+two 1\s*$/s, $result);
}

# check parse failures
sub test_badIF {
    my $this = shift;
    my @tests = (
        { test => 'A=?', expect => "Syntax error in 'A=?' at '?'" },
        { test => 'A==', expect => "Excess operators (= =) in 'A=='" },
        { test => 'A B', expect => "Missing operator in 'A B'" },
        { test => ' ', expect => "Empty expression" },
       );

    foreach my $test (@tests) {
        my $text = '%IF{"'.$test->{test}.'" then="1" else="0"}%';
        my $result = $this->{twiki}->handleCommonTags(
            $text, $this->{test_web}, $this->{test_topic});
        $this->assert($result =~ s/^.*}:\s*//s);
        $this->assert($result =~ s/<br.*$//s);
        $this->assert_str_equals($test->{expect}, $result);
    }
}

1;
