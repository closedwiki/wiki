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
        "%SCRIPTURL{view}%", $testWeb, $testTopic);
    $this->assert_str_equals("$TWiki::cfg{ScriptUrlPath}/view.dot", $result);

    $result = $twiki->handleCommonTags(
        "%SCRIPTURL{snarf}%", $testWeb, $testTopic);
    $this->assert_str_equals("sausages", $result);
}

1;
