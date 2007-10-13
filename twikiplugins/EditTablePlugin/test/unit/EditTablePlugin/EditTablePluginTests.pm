use strict;

# tests for basic formatting

package EditTablePluginTests;

use base qw( TWikiFnTestCase );

use TWiki;
use Error qw( :try );
use TWiki::Plugins::EditTablePlugin;
use TWiki::Plugins::EditTablePlugin::Core;

sub new {
    my $self = shift()->SUPER::new('EditTableFunctions', @_);
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
#    $this->{sup} = $this->{twiki}->getScriptUrl(0, 'view');
    $TWiki::cfg{AntiSpam}{RobotsAreWelcome} = 1;
    $TWiki::cfg{AntiSpam}{EmailPadding} = 'STUFFED';
    $TWiki::cfg{AllowInlineScript} = 1;
    $ENV{SCRIPT_NAME} = ''; #  required by fake sort URLs in expected text
}

# This formats the text up to immediately before <nop>s are removed, so we
# can see the nops.
sub do_test {
    my ($this, $expected, $actual) = @_;
    my $session = $this->{twiki};
    my $webName = $this->{test_web};
    my $topicName = $this->{test_topic};

    $actual = $session->handleCommonTags( $actual, $webName, $topicName );
    $actual = $session->renderer->getRenderedVersion( $actual, $webName, $topicName );

    $this->assert_html_equals($expected, $actual);
}

sub test_parseFormat {
    my $this = shift;
    my $session = $this->{twiki};
    my $webName = $this->{test_web};
    my $topicName = $this->{test_topic};
    
    my $format = 'row, -1 | text, 20, init | date, 12 | select, 1, one, two, three, four | label, 0, 13 Oct 2007 01:08';
    my $expected = 'row, -1,text, 20, init,date, 12,select, 1, one, two, three, four,label, 0, 13 Oct 2007 01:08';

	my $doExpand = 0;
    my @resultList = TWiki::Plugins::EditTablePlugin::Core::parseFormat($format,$topicName,$webName,$doExpand);
    my $resultLength = scalar @resultList;
    $this->assert_equals($resultLength, 5);
    my $result = join(",", @resultList);
    $this->assert_equals($result, $expected);
}


1;
