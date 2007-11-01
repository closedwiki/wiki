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

sub test_newUpdateIndex {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newUpdateIndex();

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

    my $start_time = time();

    my @webs = $ind->websToIndex();

    foreach my $web (@webs) {
	$ind->saveUpdateMarker($web, $start_time);
    }
    
    # Now I do a change
    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},$this->{users_web}, "NewOrChangedTopic", <<'HERE');
Just an example topic
Keyword: startpoint
HERE

    $ind->updateIndex();
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

sub test_changedTopics {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    my $start_time = time();
    $ind->saveUpdateMarker($this->{users_web}, $start_time);

    my @changes;
    my $change;

    # No there should not be any changed topics after the mark I just set.
    @changes = $ind->changedTopics($this->{users_web});
    $this->assert(!@changes, "Changes found even if there are non.");
    
    # Now I do a change
    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},$this->{users_web}, "NewOrChangedTopic", <<'HERE');
Just an example topic
Keyword: startpoint
HERE

    @changes = $ind->changedTopics($this->{users_web});

    $this->assert(@changes, "Changed topics not returned.");

    # The first change should be the one I just did. 
    foreach $change (reverse @changes ){
	$this->assert_str_equals($change, "NewOrChangedTopic", "Last change not detected.");
	last;
    }
}

sub test_removeTopics {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    # Fiest I create the index
    $ind->createIndex();

    # Now I remove some of the topics
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
    $ind->saveUpdateMarker($this->{users_web}, $start_time);

    my $red_time = $ind->readUpdateMarker($this->{users_web});
    $this->assert_str_equals($start_time, $red_time, "Red time does not fit saved time.");
}

sub test_readChanges {
    my $this = shift;
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();

    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},$this->{users_web}, "NewOrChangedTopic", <<'HERE');
Just an example topic
Keyword: startpoint
HERE
    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},$this->{users_web}, "NewOrChangedTopic", <<'HERE');
Just an example topic: Updated
Keyword: startpoint
HERE

    my @changes = $ind->readChanges($this->{users_web});
    my $change;

    $this->assert(@changes, "Changes not returned.");

    # The first change should be the one I just did. 
    foreach $change (reverse @changes ){
	my ($topicName, $userName, $changeTime, $revision) = split( /\t/, $change);
	$this->assert_str_equals($topicName, "NewOrChangedTopic", "Last change not detected.");
	last;
    }
}

1;
