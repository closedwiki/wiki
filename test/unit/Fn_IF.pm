use strict;

# tests for the correct expansion of IF

package IFTests;

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
    my @tests = (
        { test => 'A=B', then=>0, else=>1 },
        { test => 'A!=B', then=>1, else=>0 },
        { test => "A='A'", then=>1, else=>0 },
        { test => "'A'=B", then=>0, else=>1 },
        { test => 'context test', then=>1, else=>0 },
        { test => '{Fnargle}=Fleeble', then=>1, else=>0 },
        { test => '{A}{B}=C', then=>1, else=>0 },
        { test => '$ WIKINAME = '.$this->{twiki}->{user}->wikiName(), then=>1, else=>0 },
        { test => 'defined EDITBOXHEIGHT', then=>1, else=>0 },
        { test => '0>1', then=>0, else=>1 },
        { test => '1>0', then=>1, else=>0 },
        { test => '1<0', then=>0, else=>1 },
        { test => '0<1', then=>1, else=>0 },
        { test => '0>=1', then=>0, else=>1 },
        { test => '1>=0', then=>1, else=>0 },
        { test => '1>=1', then=>1, else=>0 },
        { test => '1<=0', then=>0, else=>1 },
        { test => '0<=1', then=>1, else=>0 },
        { test => '1<=1', then=>1, else=>0 },
        { test => 'not A=B', then=>1, else=>0 },
        { test => 'not not A=B', then=>0, else=>1 },
        { test => 'A=A AND B=B', then=>1, else=>0 },
        { test => 'A=A and B=B', then=>1, else=>0 },
        { test => 'A=A and B=B', then=>1, else=>0 },
        { test => 'A=B or B=B', then=>1, else=>0 },
        { test => 'A=A or B=A', then=>1, else=>0 },
        { test => 'A=B or B=A', then=>0, else=>1 },
        { test => "\$PUBURLPATH='".$TWiki::cfg{PubUrlPath}."'", then=>1, else =>0 },
       );

    foreach my $test (@tests) {
        my $text = '%IF{"'.$test->{test}.'" then="'.
          $test->{then}.'" else="'.$test->{else}.'"}%';
        my $result = $this->{twiki}->handleCommonTags($text, $this->{test_web}, $this->{test_topic});
        $this->assert_equals('1', $result, $text." => ".$result);
    }
}

1;
