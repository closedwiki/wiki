# Copyright (C) 2005 Sven Dowideit
require 5.006;
package StoreTests;

use base qw(Test::Unit::TestCase);

BEGIN {
    unshift @INC, '../../bin';
    require 'setlib.cfg';
};

use TWiki;
use strict;
use Assert;

#Test the upper level Store API

#TODO
# attachments
# check meta data for correctness
# diffs?
# lists of topics & webs
# locking
# streams
# web creation with options for WebPreferences
# search

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

my $web = "TestStoreWeb";
my $topic = "TestStoreTopic";
my $thePathInfo = "/$web/$topic";
my $theUrl = "/save/$web/$topic";
my $twiki;
my $user;

sub set_up {
    my $this = shift;

    $twiki = new TWiki( $thePathInfo, $user, $topic, $theUrl );
	
	#TODO: we should share common set up and tear down code
    # we need to make sure we have a TestUser topic
	
	$twiki->{user} = $twiki->{users}->findUser('TestUser');
	$user = $twiki->{user};
}

sub tear_down {
    my $this = shift;
	$this->removeWeb($web);
}

#===============================================================================
# tests
sub test_CreateEmptyWeb {
    my $this = shift;

	$this->assert_not_null( $twiki->{store} );
	
	#create an empty web
	$this->assert( ! $twiki->{store}->createWeb($twiki->{user},$web));		#TODO: how can this succeed without a user? to check perms?
	$this->assert( $twiki->{store}->webExists($web) );
	my @topics = $twiki->{store}->getTopicNames($web);
	$this->assert_equals( 1, scalar(@topics), join(" ",@topics) );#we expect there to be only the home topic
}

sub test_CreateWeb {
    my $this = shift;

	$this->assert_not_null( $twiki->{store} );
	
	#create a web using _default 
	#TODO how should this fail if we are testing a store impl that does not have a _deault web ?
	$this->assert( ! $twiki->{store}->createWeb($twiki->{user}, $web, '_default'));		#TODO: how can this succeed without a user? to check perms?
	$this->assert( $twiki->{store}->webExists($web) );
	my @topics = $twiki->{store}->getTopicNames($web);
	my @defaultTopics = $twiki->{store}->getTopicNames('_default');
	$this->assert_equals( $#topics, $#defaultTopics );
}

sub test_CreateWebWithNonExistantBaseWeb {
    my $this = shift;

	$this->assert_not_null( $twiki->{store} );
	
	#create a web using non-exsisatant Web 
	$this->assert( defined $twiki->{store}->createWeb($twiki->{user}, $web, 'DoesNotExists'));
	$this->assert( ! $twiki->{store}->webExists($web) );
}


sub test_CreateSimpleTopic {
    my $this = shift;

	$this->assert( ! $twiki->{store}->createWeb($twiki->{user}, $web, '_default'));
	$this->assert( $twiki->{store}->webExists($web) );
	$this->assert( ! $twiki->{store}->topicExists($web, $topic) );
	
	my $meta = undef;
	my $text = "This is some test text\n   * some list\n   * content\n :) :)";
	$this->assert_equals('', $twiki->{store}->saveTopic( $user, $web, $topic, $text, $meta ));
	$this->assert( $twiki->{store}->topicExists($web, $topic) );
	
	my ($readMeta, $readText) = $twiki->{store}->readTopic($user, $web, $topic);

    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;

	$this->assert_equals($text, $readText);
}

sub test_CreateSimpleMetaTopic {
    my $this = shift;

	$this->assert( ! $twiki->{store}->createWeb($twiki->{user}, $web, '_default'));
	$this->assert( $twiki->{store}->webExists($web) );
	$this->assert( ! $twiki->{store}->topicExists($web, $topic) );
	
	my $text = '';
	my $meta = new TWiki::Meta($twiki, $web, $topic);
	$this->assert_equals('', $twiki->{store}->saveTopic( $user, $web, $topic, $text, $meta ));
	$this->assert( $twiki->{store}->topicExists($web, $topic) );
	
	my ($readMeta, $readText) = $twiki->{store}->readTopic($user, $web, $topic);
    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;

	$this->assert_equals($text, $readText);
	$this->assert_deep_equals($meta, $readMeta);
}

sub test_CreateSimpleCompoundTopic {
    my $this = shift;

	$this->assert( ! $twiki->{store}->createWeb($twiki->{user}, $web, '_default'));
	$this->assert( $twiki->{store}->webExists($web) );
	$this->assert( ! $twiki->{store}->topicExists($web, $topic) );
	
	my $text = "This is some test text\n   * some list\n   * content\n :) :)";
	my $meta = new TWiki::Meta($twiki, $web, $topic);
	$this->assert_equals('', $twiki->{store}->saveTopic( $user, $web, $topic, $text, $meta ));
	$this->assert( $twiki->{store}->topicExists($web, $topic) );
	
	my ($readMeta, $readText) = $twiki->{store}->readTopic($user, $web, $topic);

    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;

	$this->assert_equals($text, $readText);
	$this->assert_deep_equals($meta, $readMeta);
}

sub test_getRevisionInfo {
    my $this = shift;

	$this->assert( ! $twiki->{store}->createWeb($twiki->{user}, $web, '_default'));
	$this->assert( $twiki->{store}->webExists($web) );
	my $text = "This is some test text\n   * some list\n   * content\n :) :)";
	my $meta = new TWiki::Meta($twiki, $web, $topic);
	$this->assert_equals('', $twiki->{store}->saveTopic( $user, $web, $topic, $text, $meta ));

	$this->assert_equals(1, $twiki->{store}->getRevisionNumber($web, $topic));

    $text .= "\nnewline";
	$this->assert_equals('', $twiki->{store}->saveTopic( $user, $web, $topic, $text, $meta, { forcenewrevision => 1 } ));

	my ($readMeta, $readText) = $twiki->{store}->readTopic($user, $web, $topic);
    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;
	$this->assert_equals($text, $readText);
	$this->assert_equals(2, $twiki->{store}->getRevisionNumber($web, $topic));
	my ( $infodate, $infouser, $inforev, $infocomment ) = $twiki->{store}->getRevisionInfo($web, $topic);
	$this->assert_equals($user, $infouser);
	$this->assert_equals(2, $inforev);
	
	#TODO
	#getRevisionDiff (  $web, $topic, $rev1, $rev2, $contextLines  ) -> \@diffArray
}

sub test_moveTopic {
    my $this = shift;

	$this->assert( ! $twiki->{store}->createWeb($twiki->{user}, $web, '_default'));
	$this->assert( $twiki->{store}->webExists($web) );
	my $text = "This is some test text\n   * some list\n   * content\n :) :)";
	my $meta = new TWiki::Meta($twiki, $web, $topic);
	$this->assert_equals('', $twiki->{store}->saveTopic( $user, $web, $topic, $text, $meta ));

	$text = "This is some test text\n   * some list\n   * $topic\n   * content\n :) :)";
	$this->assert_equals('', $twiki->{store}->saveTopic( $user, $web, $topic.'a', $text, $meta ));
	$text = "This is some test text\n   * some list\n   * $topic\n   * content\n :) :)";
	$this->assert_equals('', $twiki->{store}->saveTopic( $user, $web, $topic.'b', $text, $meta ));
	$text = "This is some test text\n   * some list\n   * $topic\n   * content\n :) :)";
	$this->assert_equals('', $twiki->{store}->saveTopic( $user, $web, $topic.'c', $text, $meta ));
	
	$this->assert_equals('', $twiki->{store}->moveTopic($web, $topic, $web, 'TopicMovedToHere', $user));
	
	#compare number of refering topics?
	#compare list of references to moved topic
	
}

#===============================================================================
# utilities

# clean up after a test
sub removeWeb {
    my $this = shift;

	#TODO: also want a way to turn this off when looking for bugs
	
	#TODO: Store needs a way to remove Webs!!
	use File::Path;
    File::Path::rmtree("$TWiki::cfg{DataDir}/$web");
    File::Path::rmtree("$TWiki::cfg{PubDir}/$web");

	#$this->assert( ! $twiki->{store}->webExists($web.'Empty') );
}

1;
