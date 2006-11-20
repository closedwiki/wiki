use strict;

package ViewScriptTests;

use base qw(TWikiTestCase);

use strict;
use TWiki;
use TWiki::UI::View;
use CGI;
use Error qw( :try );

my $testweb = "TemporaryViewScriptTestsWeb";

my $twiki;
my $testuser;

my $topic1 = <<'HERE';
CONTENT
HERE

my $templateTopicContent1 = <<'HERE';
pretemplate%STARTTEXT%pre%TEXT%post%ENDTEXT%posttemplate
HERE

my $templateTopicContent2 = <<'HERE';
pretemplate%TEXT%post%ENDTEXT%posttemplate
HERE

my $templateTopicContent3 = <<'HERE';
pretemplate%STARTTEXT%pre%TEXT%posttemplate
HERE

my $templateTopicContent4 = <<'HERE';
pretemplate%TEXT%posttemplate
HERE

my $templateTopicContent5 = <<'HERE';
pretemplate%STARTTEXT%posttemplate
HERE

## Should this be supported?
my $templateTopicContentX = <<'HERE';
pretemplate%STARTTEXT%pre%ENDTEXT%posttemplate
HERE

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $twiki = new TWiki();

    $testuser = $twiki->{users}->findUser($this->createFakeUser($twiki));

    $twiki->{store}->createWeb($testuser, $testweb);

    $twiki->{store}->saveTopic( $testuser, $testweb, 'TestTopic1',
                                $topic1, undef );
    $twiki->{store}->saveTopic( $testuser, $testweb, 'ViewoneTemplate',
                                $templateTopicContent1, undef );
    $twiki->{store}->saveTopic( $testuser, $testweb, 'ViewtwoTemplate',
                                $templateTopicContent2, undef );
    $twiki->{store}->saveTopic( $testuser, $testweb, 'ViewthreeTemplate',
                                $templateTopicContent3, undef );
    $twiki->{store}->saveTopic( $testuser, $testweb, 'ViewfourTemplate',
                                $templateTopicContent4, undef );
    $twiki->{store}->saveTopic( $testuser, $testweb, 'ViewfiveTemplate',
                                $templateTopicContent5, undef );

    $TWiki::Plugins::SESSION = $twiki;
}

sub tear_down {
    my $this = shift;
    $this->removeWebFixture($twiki, $testweb);
    eval {$twiki->finish()};
    $this->SUPER::tear_down();
}

sub setup_view {
    my ( $this, $web, $topic, $tmpl, $testuser ) = @_;
    my $query = new CGI({
        webName => [ $web ],
        topicName => [ $topic ],
        template => [ $tmpl ],
    });
    $query->path_info( "$web/$topic" );
    $twiki = new TWiki( $testuser->login(), $query );
    my ($text, $result) = $this->capture( \&TWiki::UI::View::view, $twiki);
    my @lines = split( /\n\r?/, $text ) if $result;
    shift @lines; shift @lines; shift @lines; shift @lines; shift @lines;
    return join("\n", @lines);
}

# This test verifies the handling of preamble (the text following
# %STARTTEXT%) and postamble (the text between %TEXT% and %ENDTEXT%).
sub test_prepostamble {
    my $this = shift;
    my $text;

    $text = $this->setup_view( $testweb, 'TestTopic1', 'viewone', $testuser );
    $this->assert_equals('pretemplatepreCONTENT
postposttemplate', $text);

    $text = $this->setup_view( $testweb, 'TestTopic1', 'viewtwo', $testuser );
    $this->assert_equals('pretemplateCONTENT
postposttemplate', $text);

    $text = $this->setup_view( $testweb, 'TestTopic1', 'viewthree', $testuser );
    $this->assert_equals('pretemplatepreCONTENTposttemplate', $text);

    $text = $this->setup_view( $testweb, 'TestTopic1', 'viewfour', $testuser );
    $this->assert_equals('pretemplateCONTENTposttemplate', $text);

    $text = $this->setup_view( $testweb, 'TestTopic1', 'viewfive', $testuser );
    $this->assert_equals('pretemplateposttemplate', $text);
}

1;
