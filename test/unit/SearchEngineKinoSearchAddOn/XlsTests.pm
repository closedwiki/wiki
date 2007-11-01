# Test for XLS.pm
package XlsTests;
use base qw( TWikiFnTestCase );

use strict;

use TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyBase;
use TWiki::Contrib::SearchEngineKinoSearchAddOn::Stringifier;

sub set_up {
        my $this = shift;

    $this->SUPER::set_up();
    # Use RcsLite so we can manually gen topic revs
    $TWiki::cfg{StoreImpl} = 'RcsLite';

    $this->registerUser("TestUser", "User", "TestUser", 'testuser@an-address.net');

    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},$this->{users_web}, "TopicWithXLSAttachment", <<'HERE');
Just an example topic wird MS Excel
Keyword: spreadsheet
HERE
    $this->{twiki}->{store}->saveAttachment($this->{users_web}, "TopicWithExcelAttachment", "Simple_example.xls",
                                            $this->{twiki}->{user}, {file => "attachement_examples/Simple_example.xls"})
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub test_stringForFile {
    my $this = shift;
    my $stringifier = TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::XLS->new();

    my $text  = $stringifier->stringForFile('attachement_examples/Simple_example.xls');
    my $text2 = TWiki::Contrib::SearchEngineKinoSearchAddOn::Stringifier->stringFor('attachement_examples/Simple_example.xls');

    $this->assert(defined($text), "No text returned.");
    $this->assert_str_equals($text, $text2, "DOC stringifier not well registered.");

    my $ok = $text =~ /dummy/;
    $this->assert($ok, "Text dummy not included")
}

1;
