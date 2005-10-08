use strict;

#
# Unit tests for TWiki::Func
#

package FuncTests;

use base qw(TWikiTestCase);

use TWiki;
use TWiki::Func;

sub new {
	my $self = shift()->SUPER::new(@_);
	return $self;
}

my $twiki;
my $testweb = "TemporaryFuncModuleTestWeb";
my $testextra = $testweb."Extra";

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $TWiki::cfg{StoreImpl} = "RcsWrap";
    $twiki = new TWiki();
    $TWiki::cfg{AutoAttachPubFiles} = 0;
    $TWiki::Plugins::SESSION = $twiki;
    $this->assert_null($twiki->{store}->createWeb($twiki->{user}, $testweb));
    $this->assert_null($twiki->{store}->createWeb($twiki->{user}, $testextra));
    $this->assert($twiki->{store}->webExists($testweb));
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    $twiki->{store}->removeWeb($twiki->{user},$testweb);
    $twiki->{store}->removeWeb($twiki->{user},$testextra);
}

sub test_web {
    my $this = shift;

    TWiki::Func::createWeb($testweb."Blah");
    $this->assert(TWiki::Func::webExists($testweb."Blah"));

    TWiki::Func::moveWeb($testweb."Blah", $testweb."Blah2");
    $this->assert(!TWiki::Func::webExists($testweb."Blah"));
    $this->assert(TWiki::Func::webExists($testweb."Blah2"));

    TWiki::Func::moveWeb($testweb."Blah2",
                         $TWiki::cfg{TrashWebName}.'.'.$testweb);
    $this->assert(!TWiki::Func::webExists($testweb."Blah2"));
    $this->assert(TWiki::Func::webExists(
        $TWiki::cfg{TrashWebName}.'.'.$testweb));

    $twiki->{store}->removeWeb($twiki->{user},
                               $TWiki::cfg{TrashWebName}.'.'.$testweb);
}

sub test_getViewUrl {
    my $this = shift;

    $TWiki::Plugins::SESSION = new TWiki();
    my $ss = 'view'.$TWiki::cfg{ScriptSuffix};
    my $result = TWiki::Func::getViewUrl ( "Main", "WebHome" );
    $this->assert_matches(qr!/$ss/Main/WebHome!, $result );

    $result = TWiki::Func::getViewUrl ( "", "WebHome" );
    $this->assert_matches(qr!/$ss/Main/WebHome!, $result );

    $TWiki::Plugins::SESSION = new TWiki(
        undef,
        new CGI( { topic=>"Sausages.AndMash" } ));

    $result = TWiki::Func::getViewUrl ( "Sausages", "AndMash" );
    $this->assert_matches(qr!/$ss/Sausages/AndMash!, $result );
    $this->assert_matches(qr!!, $result );

    $result = TWiki::Func::getViewUrl ( "", "AndMash" );
    $this->assert_matches(qr!/$ss/Sausages/AndMash!, $result );
}

sub test_getScriptUrl {
    my $this = shift;

    $TWiki::Plugins::SESSION = new TWiki();
    my $ss = 'wibble'.$TWiki::cfg{ScriptSuffix};
    my $result = TWiki::Func::getScriptUrl ( "Main", "WebHome", 'wibble' );
    $this->assert_matches(qr!/$ss/Main/WebHome!, $result );

    $result = TWiki::Func::getScriptUrl ( "", "WebHome", 'wibble' );
    $this->assert_matches(qr!/$ss/Main/WebHome!, $result );

    my $q = new CGI( {} );
    $q->path_info( '/Sausages/AndMash' );
    $TWiki::Plugins::SESSION = new TWiki(undef, $q);

    $result = TWiki::Func::getScriptUrl ( "Sausages", "AndMash", 'wibble' );
    $this->assert_matches(qr!/$ss/Sausages/AndMash!, $result );

    $result = TWiki::Func::getScriptUrl ( "", "AndMash", 'wibble' );
    $this->assert_matches(qr!/$ss/Main/AndMash!, $result );
}

sub test_leases {
    my $this = shift;

    my $testtopic = $TWiki::cfg{HomeTopicName};

    my( $oops, $login, $time ) =
      TWiki::Func::checkTopicEditLock($testweb, $testtopic);
    $this->assert(!$oops, $oops);
    $this->assert(!$login);
    $this->assert_equals(0,$time);

    my $locker = $twiki->{user}->login();
    TWiki::Func::setTopicEditLock($testweb, $testtopic, 1);

    # check the lease
    ( $oops, $login, $time ) =
      TWiki::Func::checkTopicEditLock($testweb, $testtopic);
    $this->assert_equals($locker,$login);
    $this->assert($time > 0);
    $this->assert_matches(qr/leaseconflict/,$oops);
    $this->assert_matches(qr/active/,$oops);

    # change user and check the lease again
    $twiki->{user} = $twiki->{users}->findUser('TestUser1');
    ( $oops, $login, $time ) =
      TWiki::Func::checkTopicEditLock($testweb, $testtopic);
    $this->assert_equals($locker,$login);
    $this->assert($time > 0);
    $this->assert_matches(qr/leaseconflict/,$oops);
    $this->assert_matches(qr/active/,$oops);

    # try and clear the lease. This should always succeed, even
    # though the user has changed
    TWiki::Func::setTopicEditLock($testweb, $testtopic, 0);
    ( $oops, $login, $time ) =
      TWiki::Func::checkTopicEditLock($testweb, $testtopic);
    $this->assert(!$oops,$oops);
    $this->assert(!$login);
    $this->assert_equals(0,$time);
}

sub test_attachments {
    my $this = shift;

    my $data = "\0b\1l\2a\3h\4b\5l\6a\7h";
    my $attnm = 'blahblahblah.gif';
    my $tmpfile = '/tmp/tmpity-tmp.gif';
    my $name1 = 'blahblahblah.gif';
    my $name2 = 'bleagh.sniff';
    my $topic = "BlahBlahBlah";

    my $stream;
    $this->assert(open($stream,">$tmpfile"));
    binmode($stream);
    print $stream $data;
    close($stream);

    $this->assert(open($stream, "<$tmpfile"));
    binmode($stream);

    $twiki = new TWiki( );
    $TWiki::Plugins::SESSION = $twiki;

	TWiki::Func::saveTopicText( $testweb, $topic,'' );

    my $e = TWiki::Func::saveAttachment(
        $testweb, $topic, $name1,
        {
            dontlog => 1,
            comment => 'Feasgar Bha',
            stream => $stream,
            filepath => '/local/file',
            filesize => 999,
            filedate => 0,
      } );
    $this->assert(!$e,$e);

    my( $meta, $text ) = TWiki::Func::readTopic( $testweb, $topic );
    my @attachments = $meta->find( 'FILEATTACHMENT' );
    $this->assert_str_equals($name1, $attachments[0]->{name} );

    $e = TWiki::Func::saveAttachment(
        $testweb, $topic, $name2,
        {
            dontlog => 1,
            comment => 'Ciamar a tha u',
            file => $tmpfile,
            filepath => '/local/file',
            filesize => 999,
            filedate => 0,
      } );
    $this->assert(!$e,$e);

    ( $meta, $text ) = TWiki::Func::readTopic( $testweb, $topic );
    @attachments = $meta->find( 'FILEATTACHMENT' );
    $this->assert_str_equals($name1, $attachments[0]->{name} );
    $this->assert_str_equals($name2, $attachments[1]->{name} );
    unlink("$tmpfile");

    my $x = TWiki::Func::readAttachment($testweb, $topic, $name1);
    $this->assert_str_equals($data, $x);
    $x = TWiki::Func::readAttachment($testweb, $topic, $name2);
    $this->assert_str_equals($data, $x);
}

sub test_getrevinfo {
    my $this = shift;
    my $topic = "RevInfo";

    $twiki = new TWiki( );
    $TWiki::Plugins::SESSION = $twiki;

    my $testuser = new TWiki::User( $twiki, "lunch", "PeterRabbit" );
    $twiki->{user} = $testuser;
	TWiki::Func::saveTopicText( $testweb, $topic, 'blah' );

    my( $date, $user, $rev, $comment ) =
      TWiki::Func::getRevisionInfo( $testweb, $topic );
    $this->assert_equals( 1, $rev );
    $this->assert_str_equals( "PeterRabbit", $user );
}

sub test_moveTopic {
    my $this = shift;
    my $twiki = new TWiki();
    $TWiki::Plugins::SESSION = $twiki;
	TWiki::Func::saveTopicText( $testweb, "SourceTopic", "Wibble" );
    $this->assert(TWiki::Func::topicExists( $testweb, "SourceTopic"));
    $this->assert(!TWiki::Func::topicExists( $testweb, "TargetTopic"));
    $this->assert(!TWiki::Func::topicExists( $testextra, "SourceTopic"));
    $this->assert(!TWiki::Func::topicExists( $testextra, "TargetTopic"));

	TWiki::Func::moveTopic( $testweb, "SourceTopic",
                              $testweb, "TargetTopic" );
    $this->assert(!TWiki::Func::topicExists( $testweb, "SourceTopic"));
    $this->assert(TWiki::Func::topicExists( $testweb, "TargetTopic"));

	TWiki::Func::moveTopic( $testweb, "TargetTopic",
                              undef, "SourceTopic" );
    $this->assert(TWiki::Func::topicExists( $testweb, "SourceTopic"));
    $this->assert(!TWiki::Func::topicExists( $testweb, "TargetTopic"));

	TWiki::Func::moveTopic( $testweb, "SourceTopic",
                              $testextra, "SourceTopic" );
    $this->assert(!TWiki::Func::topicExists( $testweb, "SourceTopic"));
    $this->assert(TWiki::Func::topicExists( $testextra, "SourceTopic"));

	TWiki::Func::moveTopic( $testextra, "SourceTopic",
                              $testweb, undef );
    $this->assert(TWiki::Func::topicExists( $testweb, "SourceTopic"));
    $this->assert(!TWiki::Func::topicExists( $testextra, "SourceTopic"));

	TWiki::Func::moveTopic( $testweb, "SourceTopic",
                              $testextra, "TargetTopic" );
    $this->assert(!TWiki::Func::topicExists( $testweb, "SourceTopic"));
    $this->assert(TWiki::Func::topicExists( $testextra, "TargetTopic"));
}

sub test_moveAttachment {
    my $this = shift;

    my $twiki = new TWiki();
    $TWiki::Plugins::SESSION = $twiki;
	TWiki::Func::saveTopicText( $testweb, "SourceTopic", "Wibble" );
    my $stream;
    my $data = "\0b\1l\2a\3h\4b\5l\6a\7h";
    my $tmpfile = "temporary.dat";
    $this->assert(open($stream,">$tmpfile"));
    binmode($stream);
    print $stream $data;
    close($stream);
    TWiki::Func::saveAttachment(
        $testweb, "SourceTopic", "Name1",
        {
            dontlog => 1,
            comment => 'Feasgar Bha',
            file => $tmpfile,
            filepath => '/local/file',
            filesize => 999,
            filedate => 0,
      } );
    unlink($tmpfile);
    $this->assert(TWiki::Func::attachmentExists( $testweb, "SourceTopic",
                                                  "Name1"));

    TWiki::Func::saveTopicText( $testweb, "TargetTopic", "Wibble" );
    TWiki::Func::saveTopicText( $testextra, "TargetTopic", "Wibble" );

	TWiki::Func::moveAttachment( $testweb, "SourceTopic", "Name1",
                              $testweb, "SourceTopic", "Name2" );
    $this->assert(!TWiki::Func::attachmentExists( $testweb, "SourceTopic",
                                                  "Name1"));
    $this->assert(TWiki::Func::attachmentExists( $testweb, "SourceTopic",
                                                 "Name2"));

	TWiki::Func::moveAttachment( $testweb, "SourceTopic", "Name2",
                              $testweb, "TargetTopic", undef );
    $this->assert(!TWiki::Func::attachmentExists( $testweb, "SourceTopic",
                                                  "Name2"));
    $this->assert(TWiki::Func::attachmentExists( $testweb, "TargetTopic",
                                                 "Name2"));

	TWiki::Func::moveAttachment( $testweb, "TargetTopic", "Name2",
                              $testextra, "TargetTopic", "Name1" );
    $this->assert(!TWiki::Func::attachmentExists( $testweb, "TargetTopic",
                                                  "Name2"));
    $this->assert(TWiki::Func::attachmentExists( $testextra, "TargetTopic",
                                                 "Name1"));
}

sub test_workarea {
    my $this = shift;

    my $twiki = new TWiki();
    $TWiki::Plugins::SESSION = $twiki;

    my $dir = TWiki::Func::getWorkArea( 'TestPlugin' );
    $this->assert( -d $dir );
    unlink $dir;
}

1;
