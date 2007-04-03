use strict;

# tests for the correct expansion of programmed TWiki variables (*not* TWikiFns, which
# should have their own individual testcase)

package GenericVariablesTests;

use base qw( TWikiFnTestCase );

use TWiki;
use Error qw( :try );

my $twiki;

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    my $query = new CGI("");
    $query->path_info("/$this->{test_web}/$this->{test_topic}");
    $twiki = new TWiki('scum', $query);
}

sub new {
    my $self = shift()->SUPER::new('Variables', @_);
    return $self;
}

sub test_embeddedExpansions {
    my $this = shift;
    $twiki->{prefs}->pushPreferenceValues(
        'TOPIC',
        { EGGSAMPLE => 'Egg sample',
          A => 'EGG',
          B => 'SAMPLE',
          C => '%%A%',
          D => '%B%%',
          E => '%EGG',
          F => 'SAMPLE%',
          PA => 'A',
          SB => 'B',
          EXEMPLAR => 'Exem plar',
          XA => 'EXEM',
          XB => 'PLAR',
      });

    my $result = $twiki->handleCommonTags("%%A%%B%%", $this->{test_web}, $this->{test_topic});
    $this->assert_equals('Egg sample', $result);

    $result = $twiki->handleCommonTags("%C%%D%", $this->{test_web}, $this->{test_topic});
    $this->assert_equals('Egg sample', $result);

    $result = $twiki->handleCommonTags("%E%%F%", $this->{test_web}, $this->{test_topic});
    $this->assert_equals('Egg sample', $result);

    $result = $twiki->handleCommonTags("%%XA{}%%XB{}%%", $this->{test_web}, $this->{test_topic});
    $this->assert_equals('Exem plar', $result);

    $result = $twiki->handleCommonTags("%%XA%%XB%{}%", $this->{test_web}, $this->{test_topic});
    $this->assert_equals('Exem plar', $result);

    $result = $twiki->handleCommonTags("%%%PA%%%%SB{}%%%", $this->{test_web}, $this->{test_topic});
    $this->assert_equals('Egg sample', $result);

}

sub test_topicCreationExpansions {
    my $this = shift;

    my $text = <<'END';
%USERNAME%
%STARTSECTION{type="templateonly"}%
Kill me
%ENDSECTION{type="templateonly"}%
%WIKINAME%
%WIKIUSERNAME%
%WEBCOLOR%
%STARTSECTION{name="fred" type="section"}%
%USERINFO%
%USERINFO{format="$emails,$username,$wikiname,$wikiusername"}%
%ENDSECTION{name="fred" type="section"}%
END
    my $result = $twiki->expandVariablesOnTopicCreation($text, $this->{test_user});
    my $xpect = <<END;
scum

ScumBag
$this->{users_web}.ScumBag
%WEBCOLOR%
%STARTSECTION{name="fred" type="section"}%
scum, $this->{users_web}.ScumBag, scumbag\@example.com
scumbag\@example.com,scum,ScumBag,$this->{users_web}.ScumBag
%ENDSECTION{name="fred" type="section"}%
END
    $this->assert_str_equals($xpect, $result);
}

sub test_userExpansions {
    my $this = shift;
    $TWiki::cfg{AntiSpam}{HideUserDetails} = 0;

    my $text = <<'END';
%USERNAME%
%WIKINAME%
%WIKIUSERNAME%
%USERINFO%
%USERINFO{format="$emails,$username,$wikiname,$wikiusername"}%
%USERINFO{"TWikiGuest" format="$emails,$username,$wikiname,$wikiusername"}%
END
    my $result = $twiki->handleCommonTags($text, $this->{test_web}, $this->{test_topic});
    my $xpect = <<END;
scum
ScumBag
$this->{users_web}.ScumBag
scum, $this->{users_web}.ScumBag, scumbag\@example.com
scumbag\@example.com,scum,ScumBag,$this->{users_web}.ScumBag
,guest,TWikiGuest,$this->{users_web}.TWikiGuest
END
    $this->assert_str_equals($xpect, $result);
}

1;
