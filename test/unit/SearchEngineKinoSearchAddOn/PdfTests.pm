# Test for PDF.pm
package PdfTests;
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

    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},$this->{users_web}, "TopicWithPdfAttachment", <<'HERE');
Just an example topic with PDF
Keyword: redmond
HERE
    $this->{twiki}->{store}->saveAttachment($this->{users_web}, "TopicWithPdfAttachment", "Simple_example.pdf",
                                            $this->{twiki}->{user}, {file => "attachement_examples/Simple_example.pdf"})
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub test_stringForFile {
    my $this = shift;
    my $stringifier = TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::PDF->new();

    my $text  = $stringifier->stringForFile('attachement_examples/Simple_example.pdf');
    my $text2 = TWiki::Contrib::SearchEngineKinoSearchAddOn::Stringifier->stringFor('attachement_examples/Simple_example.pdf');

    $this->assert(defined($text), "No text returned.");
    $this->assert_str_equals($text, $text2, "PDF stringifier not well registered.");

    my $ok = $text =~ /Adobe/;
    $this->assert($ok, "Text Adobe not included")
}

1;
