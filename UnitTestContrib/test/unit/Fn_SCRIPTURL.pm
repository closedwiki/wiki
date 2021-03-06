use strict;

# tests for the correct expansion of SCRIPTURL

package Fn_SCRIPTURL;

use base qw( TWikiFnTestCase );

use TWiki;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new('SCRIPTURL', @_);
    return $self;
}

sub test_SCRIPTURL {
    my $this = shift;

    $TWiki::cfg{ScriptUrlPaths}{snarf} = "sausages";
    undef $TWiki::cfg{ScriptUrlPaths}{view};
    $TWiki::cfg{ScriptSuffix} = ".dot";

    my $result = $this->{twiki}->handleCommonTags("%SCRIPTURL%", $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals(
        "$TWiki::cfg{DefaultUrlHost}$TWiki::cfg{ScriptUrlPath}", $result);

    $result = $this->{twiki}->handleCommonTags(
        "%SCRIPTURLPATH{view}%", $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("$TWiki::cfg{ScriptUrlPath}/view.dot", $result);

    $result = $this->{twiki}->handleCommonTags(
        '%SCRIPTURLPATH{"view" web="Foo"}%',
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("$TWiki::cfg{ScriptUrlPath}/view.dot/Foo",
                             $result);

    $result = $this->{twiki}->handleCommonTags(
        '%SCRIPTURLPATH{"view" web="Foo.Bar"}%',
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("$TWiki::cfg{ScriptUrlPath}/view.dot/Foo/Bar",
                             $result);

    $result = $this->{twiki}->handleCommonTags(
        '%SCRIPTURLPATH{"view" web="Foo" topic="TestTopic"}%',
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals(
        "$TWiki::cfg{ScriptUrlPath}/view.dot/Foo/TestTopic", $result);

    $result = $this->{twiki}->handleCommonTags(
        '%SCRIPTURLPATH{"view" topic="TestTopic"}%',
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals(
        "$TWiki::cfg{ScriptUrlPath}/view.dot/$this->{test_web}/TestTopic",
        $result);

    $result = $this->{twiki}->handleCommonTags(
        '%SCRIPTURLPATH{"view" topic="Foo.TestTopic"}%',
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals(
        "$TWiki::cfg{ScriptUrlPath}/view.dot/Foo/TestTopic", $result);

    $result = $this->{twiki}->handleCommonTags(
        '%SCRIPTURLPATH{"view" web="Bar" topic="Foo.TestTopic"}%',
        $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals(
        "$TWiki::cfg{ScriptUrlPath}/view.dot/Foo/TestTopic", $result);

    $result = $this->{twiki}->handleCommonTags(
        "%SCRIPTURLPATH{snarf}%", $this->{test_web}, $this->{test_topic});
    $this->assert_str_equals("sausages", $result);
}

1;
