use strict;

# tests for the correct expansion of programmed TWiki variables

package RenderingTests;
use base qw( TWikiTestCase );

use TWiki;
use Error qw( :try );

my $twiki;

my $testWeb = 'TemporaryTestWeb';
my $testTopic = 'TestTopic';

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    my $query = new CGI("");
    $query->path_info("/$testWeb/$testTopic");
    $twiki = new TWiki(undef, $query);
    $twiki->{store}->createWeb( $twiki->{user}, $testWeb );
}

sub tear_down {
    my $this = shift;

    $twiki->{store}->removeWeb( $twiki->{user}, $testWeb );

    $this->SUPER::tear_down();
}

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub test_SCRIPTURL {
    my $this = shift;

    $TWiki::cfg{ScriptUrlPaths}{snarf} = "sausages";
    undef $TWiki::cfg{ScriptUrlPaths}{view};
    $TWiki::cfg{ScriptSuffix} = ".dot";

    my $result = $twiki->handleCommonTags("%SCRIPTURL%", $testWeb, $testTopic);
    $this->assert_str_equals(
        "$TWiki::cfg{DefaultUrlHost}$TWiki::cfg{ScriptUrlPath}", $result);

    $result = $twiki->handleCommonTags(
        "%SCRIPTURLPATH{view}%", $testWeb, $testTopic);
    $this->assert_str_equals("$TWiki::cfg{ScriptUrlPath}/view.dot", $result);

    $result = $twiki->handleCommonTags(
        "%SCRIPTURLPATH{snarf}%", $testWeb, $testTopic);
    $this->assert_str_equals("sausages", $result);
}

sub test_NOP {
    my $this = shift;

    my $result = $twiki->handleCommonTags("%NOP%", $testWeb, $testTopic);
    $this->assert_equals('<nop>', $result);

    $result = $twiki->handleCommonTags("%NOP{   ignore me   }%", $testWeb, $testTopic);
    $this->assert_equals("   ignore me   ", $result);

    $result = $twiki->handleCommonTags("%NOP{%SWINE%}%", $testWeb, $testTopic);
    $this->assert_equals("%SWINE%", $result);

    $result = $twiki->handleCommonTags("%NOP{%WEB%}%", $testWeb, $testTopic);
    $this->assert_equals($testWeb, $result);

    $result = $twiki->handleCommonTags("%NOP{%WEB{}%}%", $testWeb, $testTopic);
    $this->assert_equals($testWeb, $result);

    $result = $twiki->expandVariablesOnTopicCreation("%NOP%");
    $this->assert_equals('', $result);

    $result = $twiki->expandVariablesOnTopicCreation("%GM%NOP%TIME%");
    $this->assert_equals('%GMTIME%', $result);

    $result = $twiki->expandVariablesOnTopicCreation("%NOP{   ignore me   }%");
    $this->assert_equals('', $result);

    # this *ought* to work, but by the definition of TML, it doesn't.
    #$result = $twiki->handleCommonTags("%NOP{%FLEEB{}%}%", $testWeb, $testTopic);
    #$this->assert_equals("%FLEEB{}%", $result);

}

sub test_SEP {
    my $this = shift;
    my $a = $twiki->handleCommonTags("%TMPL:P{sep}%", $testWeb, $testTopic);
    my $b = $twiki->handleCommonTags("%SEP%", $testWeb, $testTopic);
    $this->assert_str_equals($a,$b);
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

    my $result = $twiki->handleCommonTags("%%A%%B%%", $testWeb, $testTopic);
    $this->assert_equals('Egg sample', $result);

    $result = $twiki->handleCommonTags("%C%%D%", $testWeb, $testTopic);
    $this->assert_equals('Egg sample', $result);

    $result = $twiki->handleCommonTags("%E%%F%", $testWeb, $testTopic);
    $this->assert_equals('Egg sample', $result);

    $result = $twiki->handleCommonTags("%%XA{}%%XB{}%%", $testWeb, $testTopic);
    $this->assert_equals('Exem plar', $result);

    $result = $twiki->handleCommonTags("%%XA%%XB%{}%", $testWeb, $testTopic);
    $this->assert_equals('Exem plar', $result);

    $result = $twiki->handleCommonTags("%%%PA%%%%SB{}%%%", $testWeb, $testTopic);
    $this->assert_equals('Egg sample', $result);

}

sub test_topicCreationExpansions {
    my $this = shift;
    my $user = new TWiki::User($twiki, "fnurgle", "FrankNurgle");
    $this->assert_str_equals('fnurgle', $user->login());
    $this->assert_str_equals('FrankNurgle', $user->wikiName());

    my $text = <<END;
%USERNAME%
%WIKINAME%
%MAINWEB%
%WIKIUSERNAME%
%WEBCOLOR%
END
    my $result = $twiki->expandVariablesOnTopicCreation($text, $user);
    my $xpect = <<END;
fnurgle
FrankNurgle
%MAINWEB%
Main.FrankNurgle
%WEBCOLOR%
END
    $this->assert_str_equals($xpect, $result);
}

1;
