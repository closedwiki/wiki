use strict;

# tests for the correct expansion of programmed TWiki variables

package RenderingTests;
use base qw( TWikiTestCase );

use TWiki;
use Error qw( :try );

my $twiki;

my $testWeb = 'TemporaryTestWeb';
my $testTopic = 'TestTopic';
my $testUsersWeb = "TemporaryTesUsersUsersWeb";

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    my $query = new CGI("");
    $query->path_info("/$testWeb/$testTopic");
    $TWiki::cfg{UsersWebName} = $testUsersWeb;
    $TWiki::cfg{MapUserToWikiName} = 1;;
    $TWiki::cfg{Htpasswd}{FileName} = '/tmp/junkpasswd';
    $TWiki::cfg{PasswordManager} = 'TWiki::Users::HtPasswdUser';
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
    $user->setEmails('frank@nurgle.org','mad@sad.com');
    $this->assert_str_equals('fnurgle', $user->login());
    $this->assert_str_equals('FrankNurgle', $user->wikiName());

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
    my $result = $twiki->expandVariablesOnTopicCreation($text, $user);
    my $xpect = <<'END';
fnurgle

FrankNurgle
TemporaryTesUsersUsersWeb.FrankNurgle
%WEBCOLOR%
%STARTSECTION{name="fred" type="section"}%
fnurgle, TemporaryTesUsersUsersWeb.FrankNurgle, frank@nurgle.org,mad@sad.com
frank@nurgle.org,mad@sad.com,fnurgle,FrankNurgle,TemporaryTesUsersUsersWeb.FrankNurgle
%ENDSECTION{name="fred" type="section"}%
END
    $this->assert_str_equals($xpect, $result);
}

sub test_userExpansions {
    my $this = shift;
    my $user = new TWiki::User($twiki, "fnurgle", "FrankNurgle");
    $user->setEmails('frank@nurgle.org','mad@sad.com');
    $this->assert_str_equals('fnurgle', $user->login());
    $this->assert_str_equals('FrankNurgle', $user->wikiName());

    my $text = <<'END';
%USERNAME%
%WIKINAME%
%WIKIUSERNAME%
%USERINFO%
%USERINFO{format="$emails,$username,$wikiname,$wikiusername"}%
END
    $twiki->{user} = $user;
    my $result = $twiki->handleCommonTags($text, $testWeb, $testTopic);
    my $xpect = <<'END';
fnurgle
FrankNurgle
TemporaryTesUsersUsersWeb.FrankNurgle
fnurgle, TemporaryTesUsersUsersWeb.FrankNurgle, frank@nurgle.org,mad@sad.com
frank@nurgle.org,mad@sad.com,fnurgle,FrankNurgle,TemporaryTesUsersUsersWeb.FrankNurgle
END
    $this->assert_str_equals($xpect, $result);
}
sub dumpsec {
    my $sec = shift;
    return join(";", map { $_->stringify() } @$sec);
}

sub test_sections1 {
    my $this = shift;

    # Named section closed without being opened
    my $text = '0%ENDSECTION{"name"}%1';
    my( $nt, $s ) = TWiki::_parseSections( $text );
    $this->assert_str_equals("01",$nt);
    $this->assert_str_equals('',dumpsec($s));
}

sub test_sections2 {
    my $this = shift;

    # Named section opened but never closed
    my $text = '0%STARTSECTION{"name"}%1';
    my ( $nt, $s ) = TWiki::_parseSections( $text );
    $this->assert_str_equals("01",$nt);
    $this->assert_str_equals('end="2" name="name" start="1" type="section"',dumpsec($s));
}

sub test_sections3 {
    my $this = shift;

    # Unnamed section closed without being opened
    my $text = '0%ENDSECTION%1';
    my ( $nt, $s ) = TWiki::_parseSections( $text );
    $this->assert_str_equals("01",$nt);
    $this->assert_str_equals('',dumpsec($s));
}

sub test_sections4 {
    my $this = shift;

    # Unnamed section opened but never closed
    my $text = '0%STARTSECTION%1';
    my ( $nt, $s ) = TWiki::_parseSections( $text );
    $this->assert_str_equals("01",$nt);
    $this->assert_str_equals('end="2" name="_SECTION0" start="1" type="section"',dumpsec($s));
}

sub test_sections5 {
    my $this = shift;

    # Unnamed section closed by opening another section of the same type
    my $text = '0%STARTSECTION%1%STARTSECTION%2';
    my ( $nt, $s ) = TWiki::_parseSections( $text );
    $this->assert_str_equals("012",$nt);
    $this->assert_str_equals('end="2" name="_SECTION0" start="1" type="section";end="3" name="_SECTION1" start="2" type="section"',dumpsec($s));
}

sub test_sections6 {
    my $this = shift;

    # Named section overlaps unnamed section before it
    my $text = '0%STARTSECTION%1%STARTSECTION{"named"}%2%ENDSECTION%3%ENDSECTION{"named"}%4';
    my ( $nt, $s ) = TWiki::_parseSections( $text );
    $this->assert_str_equals("01234",$nt);
    $this->assert_str_equals('end="2" name="_SECTION0" start="1" type="section";end="4" name="named" start="2" type="section"',dumpsec($s));
}

sub test_sections7 {
    my $this = shift;

    # Named section overlaps unnamed section after it
    my $text = '0%STARTSECTION{"named"}%1%STARTSECTION%2%ENDSECTION{"named"}%3%ENDSECTION%4';
    my ( $nt, $s ) = TWiki::_parseSections( $text );
    $this->assert_str_equals("01234",$nt);
    $this->assert_str_equals('end="3" name="named" start="1" type="section";end="4" name="_SECTION0" start="2" type="section"',dumpsec($s));
}

sub test_sections8 {
    my $this = shift;

    # Unnamed sections of different types overlap
    my $text = '0%STARTSECTION{type="include"}%1%STARTSECTION{type="templateonly"}%2%ENDSECTION{type="include"}%3%ENDSECTION{type="templateonly"}%4';
    my ( $nt, $s ) = TWiki::_parseSections( $text );
    $this->assert_str_equals("01234",$nt);
    $this->assert_str_equals('end="3" name="_SECTION0" start="1" type="include";end="4" name="_SECTION1" start="2" type="templateonly"',dumpsec($s));
}

sub test_sections9 {
    my $this = shift;

    # Named sections of same type overlap
    my $text = '0%STARTSECTION{"one"}%1%STARTSECTION{"two"}%2%ENDSECTION{"one"}%3%ENDSECTION{"two"}%4';
    my ( $nt, $s ) = TWiki::_parseSections( $text );
    $this->assert_str_equals("01234",$nt);
    $this->assert_str_equals('end="3" name="one" start="1" type="section";end="4" name="two" start="2" type="section"',dumpsec($s));
}

sub test_sections10 {
    my $this = shift;

    # Named sections nested
    my $text = '0%STARTSECTION{name="one"}%1%STARTSECTION{name="two"}%2%ENDSECTION{name="two"}%3%ENDSECTION{name="one"}%4';
    my ( $nt, $s ) = TWiki::_parseSections( $text );
    $this->assert_str_equals("01234",$nt);
    $this->assert_str_equals('end="4" name="one" start="1" type="section";end="3" name="two" start="2" type="section"',dumpsec($s));
}

1;
