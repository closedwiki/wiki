# Test for Index.pm
package IndexTests;
use base qw( TWikiFnTestCase );

use strict;

use TWiki::Contrib::SearchEngineKinoSearchAddOn::Index;

sub new {
    my $self = shift()->SUPER::new('Index', @_);
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    # Use RcsLite so we can manually gen topic revs
    $TWiki::cfg{StoreImpl} = 'RcsLite';

    $this->registerUser("TestUser", "User", "TestUser", 'testuser@an-address.net');
    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},$this->{users_web}, "TopicWithoutAttachment", <<'HERE');
Just an example topic
Keyword: startpoint
HERE
    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},$this->{users_web}, "TopicWithWordAttachment", <<'HERE');
Just an example topic wird MS Word
Keyword: redmond
HERE
    $this->{twiki}->{store}->saveAttachment($this->{users_web}, "TopicWithWordAttachment", "Simple_example.doc",
                                            $this->{twiki}->{user}, {file => "attachement_examples/Simple_example.doc"})
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub test_newCreateIndex {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    $this->assert(defined($ind), "Index exemplar not created.")
}

sub test_createIndex {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    $ind->createIndex();
}

sub test_updateIndex {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newUpdateIndex();

    $ind->updateIndex();
}

sub test_updateMarkerFile {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    my $file = $ind->updateMarkerFile('Main');
    my $expected_file = $TWiki::cfg{DataDir}."/Main/.kinoupdate";
    $this->assert_str_equals($expected_file, $file, "File not O.K.")
}

sub test_saveUpdateMarker{
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();
    my $start_time = time();
    $ind->saveUpdateMarker('Main', $start_time);

    my $red_time = $ind->readUpdateMarker('Main');
    $this->assert_str_equals($start_time, $red_time, "Red time does not fit saved time.");
}

sub test_indexer {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    my $analyser = $ind->analyser('de');
    my $indexer  = $ind->indexer($analyser, 0, $ind->readFieldNames());

    $this->assert(defined($indexer), "Indexer not created.");
}

sub test_attachmentsOfTopic {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    my @atts;

    @atts = $ind->attachmentsOfTopic($this->{users_web}, "TopicWithoutAttachment");
    $this->assert(!@atts, "Atts should be undefined.");

    @atts = $ind->attachmentsOfTopic($this->{users_web}, "TopicWithWordAttachment");
    $this->assert(@atts, "Atts should be defined.");
    $this->assert_str_equals($atts[0]->{'name'}, "Simple_example.doc", "Attachment name not O.K.");
}

sub test_readChanges {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();
}

1;
