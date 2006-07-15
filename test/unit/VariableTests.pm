use strict;

# tests for the correct expansion of programmed TWiki variables (*not* TWikiFns, which
# should have their own individual testcase)

package GenericVariablesTests;

use base qw( TWikiTestCase );

use TWiki;
use Error qw( :try );

my $twiki;

my $testWeb = 'TemporaryTestWeb';
my $testTopic = 'TestTopic';
my $testUsersWeb = "TemporaryTestVariablesUsersWeb";

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

    $this->removeWebFixture( $twiki, $testWeb );

    $this->SUPER::tear_down();
}

sub new {
    my $self = shift()->SUPER::new(@_);
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
    $TWiki::cfg{AntiSpam}{HideUserDetails} = 0;
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
%USERINFO{"TWikiGuest" format="$emails,$username,$wikiname,$wikiusername"}%
END
    $twiki->{user} = $user;
    my $result = $twiki->handleCommonTags($text, $testWeb, $testTopic);
    my $xpect = <<'END';
fnurgle
FrankNurgle
TemporaryTesUsersUsersWeb.FrankNurgle
fnurgle, TemporaryTesUsersUsersWeb.FrankNurgle, frank@nurgle.org,mad@sad.com
frank@nurgle.org,mad@sad.com,fnurgle,FrankNurgle,TemporaryTesUsersUsersWeb.FrankNurgle
,guest,TWikiGuest,TemporaryTesUsersUsersWeb.TWikiGuest
END
    $this->assert_str_equals($xpect, $result);
}

1;
