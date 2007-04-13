use strict;

# tests for the correct expansion of INCLUDE

package Fn_INCLUDE;

use base qw( TWikiFnTestCase );

use TWiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new('INCLUDE', @_);
    return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $this->{other_web} = "$this->{test_web}other";
    $this->{twiki}->{store}->createWeb( $this->{twiki}->{user},
                                        $this->{other_web} );
}

sub tear_down {
    my $this = shift;
    $this->removeWebFixture( $this->{twiki}, $this->{other_web} );
    $this->SUPER::tear_down();
}

# Test that web references are correctly expanded when a topic is included
# from another web. Verifies that verbatim, literal and noautolink zones
# are correctly honoured.
sub test_webExpansion {
    my $this = shift;
    # Create topic to include
    my $includedTopic = "TopicToInclude";
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{other_web},
        $includedTopic, <<THIS);
<literal>
1 [[$includedTopic][one]] $includedTopic
</literal>
<verbatim>
2 [[$includedTopic][two]] $includedTopic
</verbatim>
<pre>
3 [[$includedTopic][three]] $includedTopic
</pre>
<noautolink>
4 [[$includedTopic][four]] [[$includedTopic]] $includedTopic
</noautolink>
5 [[$includedTopic][five]] $includedTopic
$includedTopic 6
7 ($includedTopic)
8 #$includedTopic
9 [[TWiki.$includedTopic]]
10 [[$includedTopic]]
11 [[http://fleegle][$includedTopic]]
THIS
    # Expand an include in the context of the test web
    my $text = $this->{twiki}->handleCommonTags(
        "%INCLUDE{$this->{other_web}.$includedTopic}%",
        $this->{test_web}, $this->{test_topic});
    my @get = split(/\n/, $text);
    my @expect = split(/\n/, <<THIS);
<literal>
1 [[$includedTopic][one]] $includedTopic
</literal>
<verbatim>
2 [[$includedTopic][two]] $includedTopic
</verbatim>
<pre>
3 [[$this->{other_web}.$includedTopic][three]] $this->{other_web}.$includedTopic
</pre>
<noautolink>
4 [[$this->{other_web}.$includedTopic][four]] [[$this->{other_web}.$includedTopic][$includedTopic]] $includedTopic
</noautolink>
5 [[$this->{other_web}.$includedTopic][five]] $this->{other_web}.$includedTopic
$this->{other_web}.$includedTopic 6
7 ($this->{other_web}.$includedTopic)
8 #$includedTopic
9 [[TWiki.$includedTopic]]
10 [[$this->{other_web}.$includedTopic][$includedTopic]]
11 [[http://fleegle][$includedTopic]]
THIS
    while (my $e = pop(@expect)) {
        $this->assert_str_equals($e, pop(@get));
    }

}

1;
