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
        { test => "'A'='B'", then=>0, else=>1 },
        { test => "'A'!='B'", then=>1, else=>0 },
        { test => "'A'='A'", then=>1, else=>0 },
        { test => "'A'='B'", then=>0, else=>1 },
        { test => 'context test', then=>1, else=>0 },
        { test => "{Fnargle}='Fleeble'", then=>1, else=>0 },
        { test => "{A}{B}='C'", then=>1, else=>0 },
        { test => '$ WIKINAME = \''.$u->getWikiName($this->{twiki}->{user})."'",
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
        { test => "not 'A'='B'", then=>1, else=>0 },
        { test => "not NOT 'A'='B'", then=>0, else=>1 },
        { test => "'A'='A' AND 'B'='B'", then=>1, else=>0 },
        { test => "'A'='A' and 'B'='B'", then=>1, else=>0 },
        { test => "'A'='A' and 'B'='B'", then=>1, else=>0 },
        { test => "('A'='B' or 'A'='A') and ('B'='B')", then=>1, else=>0 },
        { test => "'A'='B' or 'B'='B'", then=>1, else=>0 },
        { test => "'A'='A' or 'B'='A'", then=>1, else=>0 },
        { test => "'A'='B' or 'B'='A'", then=>0, else=>1 },
        { test => "\$PUBURLPATH='".$TWiki::cfg{PubUrlPath}."'", then=>1, else =>0 },
        { test => "'A'~'B'", then=>0, else=>1 },
        { test => "'ABLABA'~'*B?AB*'", then=>1, else=>0 },
        { test => '\"BABBA\"~\"*BB?\"', then=>1, else=>0 },
        { test => "lc('FRED')='fred'", then=>1, else=>0 },
        { test => "('FRED')=uc 'fred'", then=>1, else=>0 },
        { test => "d2n('2007-03-26')=".TWiki::Time::parseTime('2007-03-26', 1), then=>1, else=>0 },
        { test => "d2n('wibble')=1174863600", then=>0, else=>1 },
        { test => "1 = 1 > 0", then=>1, else=>0 },
        { test => "1 > 1 = 0", then=>1, else=>0 },
        { test => "not 1 = 2", then=>1, else=>0 },
        { test => "not not 1 and 1", then=>1, else=>0 },
        { test => "0 or not not 1 and 1", then=>1, else=>0 },
       );

    my $meta = new TWiki::Meta($this->{twiki}, $this->{test_web},
                               $this->{test_topic});
    foreach my $test (@tests) {
        my $text = '%IF{"'.$test->{test}.'" then="'.
          $test->{then}.'" else="'.$test->{else}.'"}%';
        my $result = $this->{twiki}->handleCommonTags(
            $text, $this->{test_web}, $this->{test_topic}, $meta);
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
three %IF{ "$ NAME=$ 'NAME{}'" then="1" else="0" }%
SMELL
    my $text = <<'PONG';
%INCLUDE{"DeadHerring" NAME="Red" warn="on"}%
PONG
    my $result = $this->{twiki}->handleCommonTags(
        $text, $this->{test_web}, $this->{test_topic});
    $this->assert_matches(qr/^\s*one 1\s+two 1\s+three 1\s*$/s, $result);
}

# check parse failures
sub test_badIF {
    my $this = shift;
    my @tests = (
        { test => "'A'=?", expect => "Syntax error in ''A'=?' at '?'" },
        { test => "'A'==", expect => "Excess operators (= =) in ''A'=='" },
        { test => "'A' 'B'", expect => "Missing operator in ''A' 'B''" },
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

sub test_ContentAccessSyntax {
    my $this = shift;

    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user},
        $this->{test_web},
        "DeadHerring",
        <<'SMELL');
one %IF{ "BleaghForm.Wibble='Woo'" then="1" else="0" }%
%META:FORM{name="BleaghForm"}%
%META:FIELD{name="Wibble" title="Wobble" value="Woo"}%
SMELL
    my $text = <<'PONG';
%INCLUDE{"DeadHerring" NAME="Red" warn="on"}%
PONG
    my $result = $this->{twiki}->handleCommonTags(
        $text, $this->{test_web}, $this->{test_topic});
    $this->assert_matches(qr/^\s*one 1\s*$/s, $result);
}

sub test_ALLOWS_and_EXISTS{
    my $this = shift;
    my $wn = $this->{twiki}->{users}->getWikiName($this->{twiki}->{user});
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user},
        $this->{test_web},
        "DeadDog",
        <<PONG);
   * Set ALLOWTOPICVIEW = WibbleFloon
   * Set ALLOWTOPICCHANGE = $wn
PONG
    my @tests;
    push(@tests, {
        test => "'%TOPIC%' allows 'change'",
        expect => "1"
       });
    push(@tests, {
        test => "istopic '%TOPIC%'",
        expect => "1"
       });
    push(@tests, {
            test => "'%TOPIC%' allows 'view'",
            expect => "1",
        });
    push(@tests, {
            test => "'%WEB%.%TOPIC%' ALLOWS 'change'",
            expect => "1",
        });
    push(@tests, {
            test => "'%WEB%.%TOPIC%' allows 'view'",
            expect => "1",
        });
    push(@tests, {
            test => "'DeadDog' ALLOWS 'view'",
            expect => "0",
        });
    push(@tests, {
        test => "'$this->{test_web}' allows 'view'",
        expect => "1"
       });
    push(@tests, {
            test => '\''.$this->{test_web}.'.DeadDog\' allows \'change\'',
            expect => "1"
        });
    push(@tests, {
        test => "istopic 'LazyFox'",
        expect => "0"
       });
    push(@tests, {
        test => "istopic '$this->{test_web}.LazyFox'",
        expect => "0"
       });
    push(@tests, {
        test => "istopic '$this->{test_web}.DeadDog'",
        expect => "1"
       });
    push(@tests, {
        test => "isweb '$this->{test_web}'",
        expect => "1"
       });
    push(@tests, {
        test => "isweb '%WEB%'",
        expect => "1"
       });
    push(@tests, {
        test => "isweb 'NotAHopeInHellPal'",
        expect => "0"
       });
    push(@tests, {
        test => "'NotAHopeInHellPal' allows 'view'",
        expect => "0"
       });
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki();
    $this->{twiki}->{webName} = $this->{test_web}; # hack

    foreach my $test (@tests) {
        my $text = '%IF{"'.$test->{test}.'" then="1" else="0"}%';
        my $result = $this->{twiki}->handleCommonTags(
            $text, $this->{test_web}, $this->{test_topic});
        $this->assert_str_equals($test->{expect}, $result,
                                 "$text: '$result'");
    }
}

1;
