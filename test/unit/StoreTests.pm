# Smoke tests for TWiki::Store

use strict;

package StoreTests;

use base qw(Test::Unit::TestCase);

BEGIN {
    unshift @INC, '../../lib';
    unshift @INC, '.';
}

use TWiki;
use TWiki::Store;
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
    unless( TWiki::Store::topicExists($TWiki::mainWebname, "TestUser1")) {
        saveTopic1($TWiki::mainWebname, "TestUser1",
                   "silly user page!!!", "" );
    }
    unless( TWiki::Store::topicExists($TWiki::mainWebname, "TestUser2")) {
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
    my $rev = TWiki::Store::getRevisionNumber( $zanyweb, "UnitTest1" );
    $this->assert(!TWiki::Store::topicExists($web, $topic));
    # Would be better if there was a different result !!!
    $this->assert_str_equals("1.1", $rev);
}

sub saveTopic1 {
   my ($web, $topic, $text, $user, $meta ) = @_;

   my $saveCmd = "";
   my $doNotLogChanges = 0;
   my $doUnlock = 1;

   $meta = new TWiki::Meta($web, $topic) unless $meta;
   my $error = TWiki::Store::saveTopic( $web, $topic, $text, $meta, $saveCmd,
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

    my $rev = TWiki::Store::getRevisionNumber( $web, $topic );
    $this->assert_str_equals("1.1", $rev);

    my ( $meta, $text1 ) = TWiki::Store::readTopic( $web, $topic );

    # FIXME ?
    # Temporarily remove \n
    $text1 =~ s/[\s]*$//go;

    $this->assert_str_equals( $text, $text1 );

    # Check revision number from meta data
    my( $dateMeta, $authorMeta, $revMeta ) = $meta->getRevisionInfo( $web, $topic );
    $this->assert_str_equals( "1", $revMeta, "Rev from meta data should be 1 when first created" );

    $meta = new TWiki::Meta($web, $topic);
    my( $dateMeta0, $authorMeta0, $revMeta0 ) = $meta->getRevisionInfo( $web, $topic );
    $this->assert_str_equals( $revMeta0, $revMeta );

    # Check-in with different text, under different user (to force change)
    $user = "TestUser2";
    $text = "bye";
    saveTopic1($web, $topic, $text, $user, $meta );
    $rev = TWiki::Store::getRevisionNumber( $web, $topic );

    $this->assert_str_equals("1.2", $rev );
    ($text1, $meta ) = TWiki::Store::readTopic( $web, $topic );
    ( $dateMeta, $authorMeta, $revMeta ) = $meta->getRevisionInfo( $web, $topic );
    $this->assert_str_equals("2", $revMeta, "Rev from meta should be 2 after one change" );
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
    my $filename = "$dir/$attachment";
    open( FILE, ">$filename" );
    print FILE "Test attachment";
    close(FILE);

    my $saveCmd = "";
    my $doNotLogChanges = 0;
    my $doUnlock = 1;

    TWiki::Store::saveAttachment($web, $topic, $attachment,
                                { file => $filename } );

    # Check revision number
    my $rev = TWiki::Store::getRevisionNumber($web, $topic, $attachment);
    $this->assert_str_equals("1.1",$rev);

    # Save again and check version number goes up by 1
    open( FILE, ">$filename" );
    print FILE "Test attachment\nAnd a second line";
    close(FILE);

    TWiki::Store::saveAttachment( $web, $topic, $attachment,
                                  { file => $filename } );
    # Check revision number
    $rev = TWiki::Store::getRevisionNumber( $web, $topic, $attachment );
    $this->assert_str_equals("1.2", $rev);
}

# Assumes topic with attachment already exists
sub test_rename() {
    my $this = shift;

    my $oldWeb = $zanyweb;
    my $oldTopic = "UnitTest2";
    my $newWeb = $oldWeb;
    my $newTopic = "UnitTest2Moved";
    my $attachment = "afile.txt";

    my $doNotLogChanges = 0;
    my $doUnlock = 1;
    my $oldRevAtt = TWiki::Store::getRevisionNumber( $oldWeb, $oldTopic, $attachment, $doNotLogChanges, $doUnlock );
    my $oldRevTop = TWiki::Store::getRevisionNumber( $oldWeb, $oldTopic );

    TWiki::Store::renameTopic($oldWeb, $oldTopic, $newWeb, $newTopic);

    my $newRevAtt = TWiki::Store::getRevisionNumber($newWeb, $newTopic, $attachment );
    my $newRevTop = TWiki::Store::getRevisionNumber( $newWeb, $newTopic );

    $oldRevTop =~ /1\.(.*)/;
    my $revTopShouldBe = $1 + 1;
    $revTopShouldBe = "1.$revTopShouldBe";

    $this->assert_str_equals($oldRevAtt, $newRevAtt);
    # Topic is modified in move, because meta information is updated
    # to indicate move
    $this->assert_str_equals($revTopShouldBe, $newRevTop );
}

1;


