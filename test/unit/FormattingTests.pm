use strict;

# tests for basic formatting

package FormattingTests;

use base qw( TWikiFnTestCase );

use TWiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new('Formatting', @_);
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $this->{sup} = $this->{twiki}->getScriptUrl(0, 'view');
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web},
        'H_', "BLEEGLE");
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web},
        'Underscore_topic', "BLEEGLE");
    $this->{twiki}->{store}->saveTopic(
        $this->{twiki}->{user}, $this->{test_web},
        $TWiki::cfg{HomeTopicName}, "BLEEGLE");
    $TWiki::cfg{AntiSpam}{RobotsAreWelcome} = 1;
    $TWiki::cfg{AntiSpam}{EmailPadding} = 'STUFFED';
}

# This formats the text up to immediately before <nop>s are removed, so we
# can see the nops.
sub do_test {
    my ($this, $expected, $actual) = @_;
    my $session = $this->{twiki};
    my $webName = $this->{test_web};
    my $topicName = $this->{test_topic};

    $actual = $session->handleCommonTags( $actual, $webName, $topicName );
    $actual = $session->{renderer}->getRenderedVersion( $actual, $webName, $topicName );

    $this->assert_html_equals($expected, $actual);
}

sub test_simpleWikiword {
    my $this = shift;
    my $expected = <<EXPECTED;
<a class="twikiLink" href="$this->{sup}/$this->{test_web}/$TWiki::cfg{HomeTopicName}">$TWiki::cfg{HomeTopicName}</a>
EXPECTED

    my $actual = <<ACTUAL;
$TWiki::cfg{HomeTopicName}
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_squabbedWikiword {
    my $this = shift;
    my $expected = <<EXPECTED;
<a class="twikiLink" href="$this->{sup}/$this->{test_web}/$TWiki::cfg{HomeTopicName}">$TWiki::cfg{HomeTopicName}</a>
EXPECTED

    my $actual = <<ACTUAL;
[[$TWiki::cfg{HomeTopicName}]]
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_squabbedWebWikiword {
    my $this = shift;
    my $expected = <<EXPECTED;
<a class="twikiLink" href="$this->{sup}/$TWiki::cfg{SystemWebName}/$TWiki::cfg{HomeTopicName}">$TWiki::cfg{SystemWebName}.$TWiki::cfg{HomeTopicName}</a>
EXPECTED

    my $actual = <<ACTUAL;
[[$TWiki::cfg{SystemWebName}.$TWiki::cfg{HomeTopicName}]]
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_squabbedWebWikiWordAltText {
    my $this = shift;
    my $expected = <<EXPECTED;
<a class="twikiLink" href="$this->{sup}/$TWiki::cfg{SystemWebName}/$TWiki::cfg{HomeTopicName}">home</a>
EXPECTED

    my $actual = <<ACTUAL;
[[$TWiki::cfg{SystemWebName}.$TWiki::cfg{HomeTopicName}][home]]
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_escapedWikiWord {
    my $this = shift;
    my $expected = <<EXPECTED;
<nop>$TWiki::cfg{HomeTopicName}
EXPECTED

    my $actual = <<ACTUAL;
!$TWiki::cfg{HomeTopicName}
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_escapedSquab {
    my $this = shift;
    my $expected = <<EXPECTED;
[<nop>[$TWiki::cfg{SystemWebName}.$TWiki::cfg{HomeTopicName}]]
EXPECTED

    my $actual = <<ACTUAL;
![[$TWiki::cfg{SystemWebName}.$TWiki::cfg{HomeTopicName}]]
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_noppedSquab {
    my $this = shift;
    my $expected = <<EXPECTED;
[<nop>[$this->{test_web}.$TWiki::cfg{HomeTopicName}]]
EXPECTED

    my $actual = <<ACTUAL;
[<nop>[$this->{test_web}.$TWiki::cfg{HomeTopicName}]]
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_underscoreTopic {
    my $this = shift;
    my $expected = <<EXPECTED;
Underscore_topic
EXPECTED

    my $actual = <<ACTUAL;
Underscore_topic
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_squabbedUnderscoreTopic {
    my $this = shift;
    my $expected = <<EXPECTED;
<a class="twikiLink" href="$this->{sup}/$this->{test_web}/Underscore_topic">Underscore_topic</a>
EXPECTED

    my $actual = <<ACTUAL;
[[Underscore_topic]]
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_squabbedWebUnderscroe {
    my $this = shift;
    my $expected = <<EXPECTED;
<a class="twikiLink" href="$this->{sup}/$this->{test_web}/Underscore_topic">$this->{test_web}.Underscore_topic</a>
EXPECTED

    my $actual = <<ACTUAL;
[[$this->{test_web}.Underscore_topic]]
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_squabbedWebUnderscoreAlt {
    my $this = shift;
    my $expected = <<EXPECTED;
<a class="twikiLink" href="$this->{sup}/$this->{test_web}/Underscore_topic">topic</a>
EXPECTED

    my $actual = <<ACTUAL;
[[$this->{test_web}.Underscore_topic][topic]]
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_noppedUnderscore {
    my $this = shift;
    my $expected = <<EXPECTED;
<nop>Underscore_topic
EXPECTED

    my $actual = <<ACTUAL;
!Underscore_topic
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_escapedSquabbedUnderscore {
    my $this = shift;
    my $expected = <<EXPECTED;
[<nop>[$this->{test_web}.Underscore_topic]]
EXPECTED

    my $actual = <<ACTUAL;
![[$this->{test_web}.Underscore_topic]]
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_noppedSquabUnderscore {
    my $this = shift;
    my $expected = <<EXPECTED;
[<nop>[$this->{test_web}.Underscore_topic]]
EXPECTED

    my $actual = <<ACTUAL;
[<nop>[$this->{test_web}.Underscore_topic]]
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_notATopic1 {
    my $this = shift;
    my $expected = <<EXPECTED;
123_num
EXPECTED

    my $actual = <<ACTUAL;
123_num
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_notATopic2 {
    my $this = shift;
    my $expected = <<EXPECTED;
H_
EXPECTED

    my $actual = <<ACTUAL;
H_
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_squabbedUS {
    my $this = shift;
    my $expected = <<EXPECTED;
<a class="twikiLink" href="$this->{sup}/$this->{test_web}/H_">H_</a>
EXPECTED

    my $actual = <<ACTUAL;
[[H_]]
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_emmedWords {
    my $this = shift;
    my $expected = <<EXPECTED;
<em>your words</em>
EXPECTED

    my $actual = <<ACTUAL;
_your words_
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_strongEmmedWords {
    my $this = shift;
    my $expected = <<EXPECTED;
<strong><em>your words</em></strong>
EXPECTED

    my $actual = <<ACTUAL;
__your words__
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_mixedUpTopicNameAndEm {
    my $this = shift;
    my $expected = <<EXPECTED;
<em>text with H</em> link_
EXPECTED

    my $actual = <<ACTUAL;
_text with H_ link_
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_mixedUpEmAndTopicName {
    my $this = shift;
    my $expected = <<EXPECTED;
<strong><em>text with H_ link</em></strong>
EXPECTED

    my $actual = <<ACTUAL;
__text with H_ link__
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_squabbedEmmedTopic {
    my $this = shift;
    my $expected = <<EXPECTED;
<em>text with <a class="twikiLink" href="$this->{sup}/$this->{test_web}/H_">H_</a> link</em>
EXPECTED

    my $actual = <<ACTUAL;
_text with [[H_]] link_
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_codedScrote {
    my $this = shift;
    my $expected = <<EXPECTED;
<code>_your words_</code>
EXPECTED

    my $actual = <<ACTUAL;
=_your words_=
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_noppedScrote {
    my $this = shift;
    my $expected = <<EXPECTED;
<code>your words_</code>
EXPECTED

    my $actual = <<ACTUAL;
=your words_=
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_verboWords {
    my $this = shift;
    my $expected = <<EXPECTED;
<pre>
your words
</pre>
EXPECTED

    my $actual = <<ACTUAL;
<verbatim>
your words
</verbatim>
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_USInHeader {
    my $this = shift;
    my $expected = <<EXPECTED;
<nop><h3><a name="Test_with_link_in_header_Undersc"></a>Test with link in header: Underscore_topic</h3>
EXPECTED

    my $actual = <<ACTUAL;
---+++ Test with link in header: Underscore_topic
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_protocols {
    my $this = shift;
    my %urls = (
        'file://fnurfle' => 0,
        'ftp://bleem@snot.grumph:flibble' => 0,
        'gopher://go.for.it/' => 0,
        'http://flim.flam.example.com/path:8080' => 0,
        'https://flim.flam.example.com/path' => 0,
        'irc://irc.com/' => 0,
        'mailto:pitiful@example.com' => '<a href="mailto:pitiful@exampleSTUFFED.com">mailto:pitiful@exampleSTUFFED.com</a>',
        'news:b52.on.moon'=> 0,
        'nntp:slobba.dobba'=>0,
        'telnet://some.address:5' => 0,
       );

    foreach my $url (keys %urls) {
        my $expected = $urls{$url} || <<EXPECTED;
<a href="$url" target="_top">$url</a>
EXPECTED

        # URL in text
        my $actual = <<ACTUAL;
$url
ACTUAL
        $this->do_test($expected, $actual);

        # URL in squabs
        $actual = <<ACTUAL;
[[$url]]
ACTUAL
        $this->do_test($expected, $actual);
    }

}

1;
