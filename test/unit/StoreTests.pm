# Smoke tests for TWiki::Store

use strict;

package StoreTests;

use base qw(Test::Unit::TestCase);

BEGIN {
    unshift @INC, '../../lib';
    unshift @INC, '.';
}

use TWiki;
use TWiki::Meta;

my $zanyweb = "ZanyTestZeebleWeb";

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

# Set up the test fixture
sub set_up {
    mkdir "$TWiki::dataDir/$zanyweb";
    chmod 0777, "$TWiki::dataDir/$zanyweb";
    mkdir "$TWiki::pubDir/$zanyweb";
    chmod 0777, "$TWiki::pubDir/$zanyweb";

    my $web = $zanyweb;
    my $topic = "";
    my $user = "TestUser1";
    my $thePathInfo = "/$web/$topic";
    my $theUrl = "/save/$web/$topic";

    TWiki::initialize( $thePathInfo, $user, $topic, $theUrl );

    # Make sure we have a TestUser1 and TestUser1 topic
    unless( $TWiki::T->{store}->topicExists($TWiki::mainWebname, "TestUser1")) {
        saveTopic1($TWiki::mainWebname, "TestUser1",
                   "silly user page!!!", "" );
    }
    unless( $TWiki::T->{store}->topicExists($TWiki::mainWebname, "TestUser2")) {
        saveTopic1($TWiki::mainWebname, "TestUser2",
                   "silly user page!!!", "");
    }
}

sub tear_down {
    `rm -rf $TWiki::dataDir/$zanyweb`;
    die "Could not clean fixture $?" if $!;
    `rm -rf $TWiki::pubDir/$zanyweb`;
    die "Could not clean fixture $?" if $!;
}

sub test_notopic {
    my $this = shift;
    my $web = $zanyweb;
    my $topic = "UnitTest1";
    my $rev = $TWiki::T->{store}->getRevisionNumber( $zanyweb, "UnitTest1" );
    $this->assert(!$TWiki::T->{store}->topicExists($web, $topic));
    # Would be better if there was a different result !!!
    $this->assert_num_equals(0, $rev);
}

sub saveTopic1 {
   my ($web, $topic, $text, $user, $meta ) = @_;

   my $saveCmd = "";
   my $doNotLogChanges = 0;
   my $doUnlock = 1;

   $TWiki::T->{userName} = $user;
   $meta = new TWiki::Meta($web, $topic) unless $meta;
   my $error = $TWiki::T->{store}->saveTopic( $user, $web, $topic, $text,
                                        $meta, $saveCmd,
                                        $doNotLogChanges, $doUnlock );

   die $error if $error;
}

sub test_checkin
{
    my $this = shift;
    my $topic = "UnitTest1";
    my $text = "hi";
    my $web = $zanyweb;
    my $user = "TestUser1";

    saveTopic1( $web, $topic, $text, $user );

    my $rev = $TWiki::T->{store}->getRevisionNumber( $web, $topic );
    $this->assert_num_equals(1, $rev);

    my ( $meta, $text1 ) = $TWiki::T->{store}->readTopic( $user, $web, $topic, undef, 0 );

    $text1 =~ s/[\s]*$//go;
    $this->assert_str_equals( $text, $text1 );

    # Check revision number from meta data
    my( $dateMeta, $authorMeta, $revMeta ) = $meta->getRevisionInfo( $web, $topic );
    $this->assert_num_equals( 1, $revMeta, "Rev from meta data should be 1 when first created" );
    $meta = new TWiki::Meta($web, $topic);
    my( $dateMeta0, $authorMeta0, $revMeta0 ) =
      $meta->getRevisionInfo( $web, $topic );
    $this->assert_num_equals( $revMeta0, $revMeta );
    # Check-in with different text, under different user (to force change)
    $user = "TestUser2";
    $text = "bye";

    saveTopic1($web, $topic, $text, $user, $meta );

    $rev = $TWiki::T->{store}->getRevisionNumber( $web, $topic );
    $this->assert_num_equals(2, $rev );
    ( $meta, $text1 ) = $TWiki::T->{store}->readTopic( $user, $web, $topic, undef, 0 );
    ( $dateMeta, $authorMeta, $revMeta ) =
      $meta->getRevisionInfo( $web, $topic );
    $this->assert_num_equals(2, $revMeta, "Rev from meta should be 2 after one change" );
}

sub test_checkin_attachment {
    my $this = shift;

    # Create topic
    my $topic = "UnitTest2";
    my $text = "hi";
    my $web = $zanyweb;
    my $user = "TestUser1";

    saveTopic1($web, $topic, $text, $user );

    # directly put file in pub directory (where attachments go)
    my $dir = $TWiki::pubDir;
    $dir = "$dir/$web/$topic";
    if( ! -e "$dir" ) {
        umask( 0 );
        mkdir( $dir, 0777 );
    }

    my $attachment = "afile.txt";
    open( FILE, ">/tmp/$attachment" );
    print FILE "Test attachment\n";
    close(FILE);

    my $saveCmd = "";
    my $doNotLogChanges = 0;
    my $doUnlock = 1;

    $TWiki::T->{store}->saveAttachment($web, $topic, $attachment, $user,
                                { file => "/tmp/$attachment" } );

    # Check revision number
    my $rev = $TWiki::T->{store}->getRevisionNumber($web, $topic, $attachment);
    $this->assert_num_equals(1,$rev);

    # Save again and check version number goes up by 1
    open( FILE, ">/tmp/$attachment" );
    print FILE "Test attachment\nAnd a second line";
    close(FILE);

    $TWiki::T->{store}->saveAttachment( $web, $topic, $attachment, $user,
                                  { file => "/tmp/$attachment" } );
    # Check revision number
    $rev = $TWiki::T->{store}->getRevisionNumber( $web, $topic, $attachment );
    $this->assert_num_equals(2, $rev);
}

sub test_rename() {
    my $this = shift;

    my $oldWeb = $zanyweb;
    my $oldTopic = "UnitTest2";
    my $newWeb = $oldWeb;
    my $newTopic = "UnitTest2Moved";
    my $user = "TestUser1";

    saveTopic1($oldWeb, $oldTopic, "Elucidate the goose", $user );
    my $attachment = "afile.txt";
    open( FILE, ">/tmp/$attachment" );
    print FILE "Test her attachment to me\n";
    close(FILE);
    $user = "TestUser2";
    $TWiki::T->{userName} = $user;
    $TWiki::T->{store}->saveAttachment($oldWeb, $oldTopic, $attachment, $user,
                                { file => "/tmp/$attachment" } );

    my $oldRevAtt =
      $TWiki::T->{store}->getRevisionNumber( $oldWeb, $oldTopic, $attachment );
    my $oldRevTop =
      $TWiki::T->{store}->getRevisionNumber( $oldWeb, $oldTopic );

    $user = "TestUser1";
    $TWiki::T->{userName} = $user;

    #$TWiki::Sandbox::_trace = 1;
    $TWiki::T->{store}->renameTopic($oldWeb, $oldTopic, $newWeb, $newTopic, 1, $user);
    #$TWiki::Sandbox::_trace = 0;

    my $newRevAtt =
      $TWiki::T->{store}->getRevisionNumber($newWeb, $newTopic, $attachment );

    $this->assert_num_equals($oldRevAtt, $newRevAtt);

    # Topic is modified in move, because meta information is updated
    # to indicate move
    my $newRevTop =
      $TWiki::T->{store}->getRevisionNumber( $newWeb, $newTopic );
    $this->assert_matches(qr/^\d+$/, $newRevTop);
    my $revTopShouldBe = $oldRevTop + 1;
    $this->assert_num_equals($revTopShouldBe, $newRevTop );
}

1;


