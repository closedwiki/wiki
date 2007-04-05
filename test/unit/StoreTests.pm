# Copyright (C) 2005 Sven Dowideit & Crawford Currie
require 5.006;
package StoreTests;

use base qw(TWikiTestCase);

use TWiki;
use strict;
use Assert;
use Error qw( :try );

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

my $web = "TemporaryTestStoreWeb";
my $topic = "TestStoreTopic";

my $twiki;
my $user;

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $twiki = new TWiki();
	
	#TODO: we should share common set up and tear down code
    # we need to make sure we have a TestUser topic
	
	$twiki->{user} = 'TestUser';
	$user = $twiki->{user};
}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture($twiki, $web)
      if( $twiki->{store}->webExists( $web ));

    eval {$twiki->finish()};
    $this->SUPER::tear_down();
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
	$twiki->{store}->removeWeb($twiki->{user}, $web);
}

sub test_CreateWeb {
    my $this = shift;

	$this->assert_not_null( $twiki->{store} );
	
	#create a web using _default 
	#TODO how should this fail if we are testing a store impl that does not have a _deault web ?
	$twiki->{store}->createWeb($twiki->{user}, $web, '_default');
	$this->assert( $twiki->{store}->webExists($web) );
	my @topics = $twiki->{store}->getTopicNames($web);
	my @defaultTopics = $twiki->{store}->getTopicNames('_default');
	$this->assert_equals( $#topics, $#defaultTopics,
                          join(",",@topics)." != ".join(',',@defaultTopics));
	$twiki->{store}->removeWeb($twiki->{user}, $web);
}

sub test_CreateWebWithNonExistantBaseWeb {
    my $this = shift;

	$this->assert_not_null( $twiki->{store} );
	
	#create a web using non-exsisatant Web 
    my $ok = 0;
    try {
        $twiki->{store}->createWeb($twiki->{user}, $web, 'DoesNotExists');
    } catch Error::Simple with {
        $ok = 1;
    };
    $this->assert($ok);
	$this->assert( ! $twiki->{store}->webExists($web) );
}


sub test_CreateSimpleTopic {
    my $this = shift;

	$twiki->{store}->createWeb($twiki->{user}, $web, '_default');
	$this->assert( $twiki->{store}->webExists($web) );
	$this->assert( ! $twiki->{store}->topicExists($web, $topic) );
	
	my $meta = undef;
	my $text = "This is some test text\n   * some list\n   * content\n :) :)";
	$twiki->{store}->saveTopic( $user, $web, $topic, $text, $meta );
	$this->assert( $twiki->{store}->topicExists($web, $topic) );
	my ($readMeta, $readText) = $twiki->{store}->readTopic($user, $web, $topic);

    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;

	$this->assert_equals($text, $readText);
	$twiki->{store}->removeWeb($twiki->{user}, $web);
}

sub test_CreateSimpleMetaTopic {
    my $this = shift;

	$twiki->{store}->createWeb($twiki->{user}, $web, '_default');
	$this->assert( $twiki->{store}->webExists($web) );
	$this->assert( ! $twiki->{store}->topicExists($web, $topic) );
	
	my $text = '';
	my $meta = new TWiki::Meta($twiki, $web, $topic);
	$twiki->{store}->saveTopic( $user, $web, $topic, $text, $meta );
	$this->assert( $twiki->{store}->topicExists($web, $topic) );
	
	my ($readMeta, $readText) = $twiki->{store}->readTopic($user, $web, $topic);
    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;

	$this->assert_equals($text, $readText);
    # remove topicinfo, useless for test
    $readMeta->remove('TOPICINFO');
    $meta->remove('TOPICINFO');
    @{$meta->{FILEATTACHMENT}} = () unless $meta->{FILEATTACHMENT};
	$this->assert_deep_equals($meta, $readMeta);
	$twiki->{store}->removeWeb($twiki->{user}, $web);
}

sub test_CreateSimpleCompoundTopic {
    my $this = shift;

	$twiki->{store}->createWeb($twiki->{user}, $web, '_default');
	$this->assert( $twiki->{store}->webExists($web) );
	$this->assert( ! $twiki->{store}->topicExists($web, $topic) );
	
	my $text = "This is some test text\n   * some list\n   * content\n :) :)";
	my $meta = new TWiki::Meta($twiki, $web, $topic);
	$twiki->{store}->saveTopic( $user, $web, $topic, $text, $meta );
	$this->assert( $twiki->{store}->topicExists($web, $topic) );
	
	my ($readMeta, $readText) = $twiki->{store}->readTopic($user, $web, $topic);

    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;

	$this->assert_equals($text, $readText);
    # remove topicinfo, useless for test
    $readMeta->remove('TOPICINFO');
    $meta->remove('TOPICINFO');
    @{$meta->{FILEATTACHMENT}} = () unless $meta->{FILEATTACHMENT};
    $this->assert_deep_equals($meta, $readMeta);
	$twiki->{store}->removeWeb($twiki->{user}, $web);
}

sub test_getRevisionInfo {
    my $this = shift;

	$twiki->{store}->createWeb($twiki->{user}, $web, '_default');
	$this->assert( $twiki->{store}->webExists($web) );
	my $text = "This is some test text\n   * some list\n   * content\n :) :)";
	my $meta = new TWiki::Meta($twiki, $web, $topic);
	$twiki->{store}->saveTopic( $user, $web, $topic, $text, $meta );

	$this->assert_equals(1, $twiki->{store}->getRevisionNumber($web, $topic));

    $text .= "\nnewline";
	$twiki->{store}->saveTopic( $user, $web, $topic, $text, $meta, { forcenewrevision => 1 } );

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
	$twiki->{store}->removeWeb($twiki->{user}, $web);
}

sub test_moveTopic {
    my $this = shift;

	$twiki->{store}->createWeb($twiki->{user}, $web, '_default');
	$this->assert( $twiki->{store}->webExists($web) );
	my $text = "This is some test text\n   * some list\n   * content\n :) :)";
	my $meta = new TWiki::Meta($twiki, $web, $topic);
	$twiki->{store}->saveTopic( $user, $web, $topic, $text, $meta );

	$text = "This is some test text\n   * some list\n   * $topic\n   * content\n :) :)";
	$twiki->{store}->saveTopic( $user, $web, $topic.'a', $text, $meta );
	$text = "This is some test text\n   * some list\n   * $topic\n   * content\n :) :)";
	$twiki->{store}->saveTopic( $user, $web, $topic.'b', $text, $meta );
	$text = "This is some test text\n   * some list\n   * $topic\n   * content\n :) :)";
	$twiki->{store}->saveTopic( $user, $web, $topic.'c', $text, $meta );
	
	$twiki->{store}->moveTopic($web, $topic, $web, 'TopicMovedToHere', $user);
	
	#compare number of refering topics?
	#compare list of references to moved topic
	$twiki->{store}->removeWeb($twiki->{user}, $web);

}

sub test_leases {
    my $this = shift;

	$twiki->{store}->createWeb($twiki->{user}, $web, '_default');
    my $testtopic = $TWiki::cfg{HomeTopicName};

    my $lease = $twiki->{store}->getLease($web, $testtopic);
    $this->assert_null($lease);

    my $locker = $twiki->{user};
    my $set = time();
    $twiki->{store}->setLease($web, $testtopic, $locker, 10);

    # check the lease
    $lease = $twiki->{store}->getLease($web, $testtopic);
    $this->assert_not_null($lease);
    $this->assert_str_equals($locker, $lease->{user});
    $this->assert($set, $lease->{taken});
    $this->assert($lease->{taken}+10, $lease->{expires});

    # clear the lease
    $twiki->{store}->clearLease( $web, $testtopic );
    $lease = $twiki->{store}->getLease($web, $testtopic);
    $this->assert_null($lease);
	$twiki->{store}->removeWeb($twiki->{user}, $web);
}

# Handler used in next test
sub beforeSaveHandler {
    my( $text, $topic, $web, $meta ) = @_;
    if( $text =~ /CHANGETEXT/ ) {
        $_[0] =~ s/fieldvalue/text/;
    }
    if( $text =~ /CHANGEMETA/ ) {
        $meta->putKeyed('FIELD', {name=>'fieldname', value=>'meta'});
    }
}

use TWiki::Plugin;

sub test_beforeSaveHandlerChangeText {
    my $this = shift;
    my $args = {
        name => "fieldname",
        value  => "fieldvalue",
       };

	$twiki->{store}->createWeb($twiki->{user}, $web, '_default');
	$this->assert( $twiki->{store}->webExists($web) );
	$this->assert( ! $twiki->{store}->topicExists($web, $topic) );
	
    # inject a handler directly into the plugins object
    push(@{$twiki->{plugins}->{registeredHandlers}{beforeSaveHandler}},
        new TWiki::Plugin($twiki, "StoreTestPlugin", 'StoreTests'));

	my $text = 'CHANGETEXT';
	my $meta = new TWiki::Meta($twiki, $web, $topic);
    $meta->putKeyed( "FIELD", $args );

	$twiki->{store}->saveTopic( $user, $web, $topic, $text, $meta );
	$this->assert( $twiki->{store}->topicExists($web, $topic) );
	
	my ($readMeta, $readText) = $twiki->{store}->readTopic($user, $web, $topic);
    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;

	$this->assert_equals($text, $readText);
    # remove topicinfo, useless for test
    $readMeta->remove('TOPICINFO');
    # set expected meta
    $meta->putKeyed('FIELD', {name=>'fieldname', value=>'text'});
	$this->assert_str_equals($meta->stringify(), $readMeta->stringify());
	$twiki->{store}->removeWeb($twiki->{user}, $web);
}

sub test_beforeSaveHandlerChangeMeta {
    my $this = shift;
    my $args = {
        name => "fieldname",
        value  => "fieldvalue",
       };

	$twiki->{store}->createWeb($twiki->{user}, $web, '_default');
	$this->assert( $twiki->{store}->webExists($web) );
	$this->assert( ! $twiki->{store}->topicExists($web, $topic) );
	
    # inject a handler directly into the plugins object
    push(@{$twiki->{plugins}->{registeredHandlers}{beforeSaveHandler}},
        new TWiki::Plugin($twiki, "StoreTestPlugin", 'StoreTests'));

	my $text = 'CHANGEMETA';
	my $meta = new TWiki::Meta($twiki, $web, $topic);
    $meta->putKeyed( "FIELD", $args );

	$twiki->{store}->saveTopic( $user, $web, $topic, $text, $meta );
	$this->assert( $twiki->{store}->topicExists($web, $topic) );
	
	my ($readMeta, $readText) = $twiki->{store}->readTopic($user, $web, $topic);
    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;

	$this->assert_equals($text, $readText);
    # set expected meta
    $meta->putKeyed('FIELD', {name=>'fieldname', value=>'meta'});
	$this->assert_str_equals($meta->stringify(), $readMeta->stringify());
	$twiki->{store}->removeWeb($twiki->{user}, $web);
}

sub test_beforeSaveHandlerChangeBoth {
    my $this = shift;
    my $args = {
        name => "fieldname",
        value  => "fieldvalue",
       };

	$twiki->{store}->createWeb($twiki->{user}, $web, '_default');
	$this->assert( $twiki->{store}->webExists($web) );
	$this->assert( ! $twiki->{store}->topicExists($web, $topic) );
	
    # inject a handler directly into the plugins object
    push(@{$twiki->{plugins}->{registeredHandlers}{beforeSaveHandler}},
        new TWiki::Plugin($twiki, "StoreTestPlugin", 'StoreTests'));

	my $text = 'CHANGEMETA CHANGETEXT';
	my $meta = new TWiki::Meta($twiki, $web, $topic);
    $meta->putKeyed( "FIELD", $args );

	$twiki->{store}->saveTopic( $user, $web, $topic, $text, $meta );
	$this->assert( $twiki->{store}->topicExists($web, $topic) );
	
	my ($readMeta, $readText) = $twiki->{store}->readTopic($user, $web, $topic);
    # ignore whitspace at end of data
    $readText =~ s/\s*$//s;

	$this->assert_equals($text, $readText);
    # set expected meta
    $meta->putKeyed('FIELD', {name=>'fieldname', value=>'meta'});
	$this->assert_str_equals($meta->stringify(), $readMeta->stringify());
	$twiki->{store}->removeWeb($twiki->{user}, $web);
}

my $attachment = "afile.txt";

# Handler used in next test
sub beforeAttachmentSaveHandler {
    my( $attrHash, $topic, $web ) = @_;
    die "attachment $attrHash->{attachment}"
      unless $attrHash->{attachment} eq $attachment;
    die "comment $attrHash->{comment}"
      unless $attrHash->{comment} eq "a comment";
    die "user ".$user unless $user eq $twiki->{user};

    open(F, "<".$attrHash->{tmpFilename}) ||
      die "$attrHash->{tmpFilename}: $!";
    local $/ = undef;
    my $text = <F>;
    close(F) || die "$attrHash->{tmpFilename}: $!";

    $text =~ s/two/four/;

    open(F, ">".$attrHash->{tmpFilename}) ||
      die "$attrHash->{tmpFilename}: $!";
    print F $text;
    close(F) || die "$attrHash->{tmpFilename}: $!";
}

# Handler used in next test
sub afterAttachmentSaveHandler {
    my( $attrHash, $topic, $web, $error ) = @_;
    die "attachment $attrHash->{attachment}"
      unless $attrHash->{attachment} eq $attachment;
    die "comment $attrHash->{comment}"
      unless $attrHash->{comment} eq "a comment";
    die "user ".$user->stringify()
      unless $user eq $twiki->{user};
}

sub test_attachmentSaveHandlers {
    my $this = shift;
    my $args = {
        name => "fieldname",
        value  => "fieldvalue",
       };

    open( FILE, ">/tmp/$attachment" );
    print FILE "one two three";
    close(FILE);

	$twiki->{store}->createWeb($twiki->{user}, $web, '_default');
	$twiki->{store}->saveTopic( $twiki->{user}, $web, $topic, "", undef );

    # SMELL: assumed implementation
    push(@{$twiki->{plugins}->{registeredHandlers}{beforeAttachmentSaveHandler}},
        new TWiki::Plugin($twiki, "StoreTestPlugin", 'StoreTests'));
    push(@{$twiki->{plugins}->{registeredHandlers}{afterAttachmentSaveHandler}},
        new TWiki::Plugin($twiki, "StoreTestPlugin", 'StoreTests'));

    $twiki->{store}->saveAttachment($web, $topic, $attachment, $user,
                                    { file => "/tmp/$attachment",
                                      comment => "a comment" } );

    my $text = $twiki->{store}->readAttachment(
        $twiki->{user},
        $web, $topic, $attachment);
    $this->assert_str_equals("one four three", $text);

    unlink("/tmp/$attachment");

	$twiki->{store}->removeWeb($twiki->{user}, $web);
}

1;
