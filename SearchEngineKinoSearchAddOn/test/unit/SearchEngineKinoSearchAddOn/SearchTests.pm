# Test for Search.pm
package SearchTests;
use base qw( TWikiFnTestCase );

use strict;

use TWiki::Contrib::SearchEngineKinoSearchAddOn::Search;
use TWiki::Contrib::SearchEngineKinoSearchAddOn::Index;

sub new {
    my $self = shift()->SUPER::new('Search', @_);
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
    #$this->{twiki}->{store}->saveAttachment($this->{users_web}, "TopicWithWordAttachment", "Simple_example.doc",
    #                                        $this->{twiki}->{user}, {file => "attachement_examples/Simple_example.doc"})
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub test_newSearch {
    my $this = shift;
    my $search = TWiki::Contrib::SearchEngineKinoSearchAddOn::Search->newSearch();

    $this->assert(defined($search), "Search exemplar not created.")
}

sub test_docsForQuery {
    my $this = shift;
    my $search = TWiki::Contrib::SearchEngineKinoSearchAddOn::Search->newSearch();

    # Create an index of the current situation.
    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();
    $ind->createIndex();

    # Now I search for something that does not exist.
    my $docs = $search->docsForQuery( "ThisDoesNotExist");
    my $hit  = $docs->fetch_hit_hashref;
    $this->assert(!defined($hit), "Bad hit found.");

    # Let's create something
    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},$this->{users_web}, "TopicTitleToSearch", <<'HERE');
Just an example topic
Keyword: BodyToSearchFor
HERE

    # Create an index of the current situation.
    $ind->createIndex();

    # Now I search for the title
    $docs = $search->docsForQuery( "TopicTitleToSearch");
    $hit  = $docs->fetch_hit_hashref;
    $this->assert(defined($hit), "Hit for title not found.");
    my $topic = $hit->{topic};
    $topic =~ s/ .*//;
    $this->assert_str_equals($topic, "TopicTitleToSearch", "Wrong topic for tile.");

    $docs = $search->docsForQuery( "BodyToSearchFor");
    $hit  = $docs->fetch_hit_hashref;
    $this->assert(defined($hit), "Hit for body not found.");
    $topic = $hit->{topic};
    $topic =~ s/ .*//;
    $this->assert_str_equals($topic, "TopicTitleToSearch", "Wrong topic for body.");
}

sub test_renderHtmlStringFor {
    my $this = shift;
    my $search = TWiki::Contrib::SearchEngineKinoSearchAddOn::Search->newSearch();

    # Let's create something
    $this->{twiki}->{store}->saveTopic($this->{twiki}->{user},$this->{users_web}, "TopicTitleToSearch", <<'HERE');
Just an example topic
Keyword: BodyToSearchFor
HERE

    my $ind = TWiki::Contrib::SearchEngineKinoSearchAddOn::Index->newCreateIndex();
    $ind->createIndex();

    # Now I search for the title
    my $docs = $search->docsForQuery( "TopicTitleToSearch");
    my $hit  = $docs->fetch_hit_hashref;

    # load the template
    my $tmpl = TWiki::Func::readTemplate( "kinosearch" );
    $tmpl =~ s/\%META{.*?}\%//go;  # remove %META{"parent"}%;
    # split the template into sections
    my( $tmplHead, $tmplSearch,
        $tmplTable, $tmplNumber, $tmplTail ) = split( /%SPLIT%/, $tmpl );

    # prepare for the result list
    my( $beforeText, $repeatText, $afterText ) = split( /%REPEAT%/, $tmplTable );

    my $nosummary = "";
    my $htmlString = $search->renderHtmlStringFor($hit, $repeatText, $nosummary);

    #print "HTML Result: #############################\n";
    #print "$htmlString\n";

    $this->assert(index($htmlString, $hit->{web}),   "Web not in result");
    my $restopic = $hit->{topic};
    # For partial name search of topics, just hold the first part of the string
    if($restopic =~ m/(\w+)/) { $restopic =~ s/ .*//; }
    $this->assert(index($htmlString, $restopic), "Topic not in result");
    
}

1;
