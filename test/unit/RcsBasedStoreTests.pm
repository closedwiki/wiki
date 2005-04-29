# Smoke tests for TWiki::Store

require 5.006;

use strict;

package RcsBasedStoreTests;

use base qw(Test::Unit::TestCase);

BEGIN {
    unshift @INC, '../../bin';
    require 'setlib.cfg';
};

use TWiki;
use TWiki::Meta;
use Error qw( :try );
use CGI;
use TWiki::UI::Save;
use TWiki::OopsException;
use File::Path;

my $testweb = "StoreTestsTestWeb";

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

my $twiki;

my $saveWF;
my $saveLF;

# Set up the test fixture
sub set_up {
    my $this = shift;
    File::Path::mkpath("$TWiki::cfg{DataDir}/$testweb");
    File::Path::mkpath("$TWiki::cfg{PubDir}/$testweb");
    $saveWF = $TWiki::cfg{WarningFileName};
    $TWiki::cfg{WarningFileName} = "/tmp/junk";
    $saveLF = $TWiki::cfg{LogFileName};
    $TWiki::cfg{LogFileName} = "/tmp/junk";

    my $web = $testweb;
    my $topic = "";
    my $user = "TestUser1";
    my $thePathInfo = "/$web/$topic";
    my $theUrl = "/save/$web/$topic";

    $twiki = new TWiki( $thePathInfo, $user, $topic, $theUrl );

    $this->assert($TWiki::cfg{StoreImpl});

    # Make sure we have a TestUser1 and TestUser1 topic
    unless( $twiki->{store}->topicExists($TWiki::cfg{UsersWebName}, "TestUser1")) {
        saveTopic1($TWiki::cfg{UsersWebName}, "TestUser1",
                   "silly user page!!!", "" );
    }
    unless( $twiki->{store}->topicExists($TWiki::cfg{UsersWebName}, "TestUser2")) {
        saveTopic1($TWiki::cfg{UsersWebName}, "TestUser2",
                   "silly user page!!!", "");
    }
}

sub tear_down {
    File::Path::rmtree("$TWiki::cfg{DataDir}/$testweb");
    File::Path::rmtree("$TWiki::cfg{PubDir}/$testweb");
    $TWiki::cfg{WarningFileName} = $saveWF;
    $TWiki::cfg{LogFileName} = $saveLF;
}

sub test_notopic {
    my $this = shift;
    my $web = $testweb;
    my $topic = "UnitTest1";
    my $rev = $twiki->{store}->getRevisionNumber( $testweb, "UnitTest1" );
    $this->assert(!$twiki->{store}->topicExists($web, $topic));
    # Would be better if there was a different result !!!
    $this->assert_num_equals(0, $rev);
}

sub saveTopic1 {
   my ($web, $topic, $text, $user, $meta ) = @_;

   my $saveCmd = "";
   my $doNotLogChanges = 0;
   my $doUnlock = 1;

   unless (ref($user) eq "TWiki::User") {
       if( $user ) {
           $user = $twiki->{users}->findUser($user);
           $twiki->{user} = $user;
       } else {
           $user = $twiki->{user};
       }
   }

   $meta = new TWiki::Meta($twiki, $web, $topic) unless $meta;
   my $error =
     $twiki->{store}->saveTopic( $user, $web, $topic, $text,
                                 $meta,
                                 { savecmd => $saveCmd,
                                   dontlog => $doNotLogChanges,
                                   unlock => $doUnlock } );

   die $error if $error;
}

sub test_checkin
{
    my $this = shift;
    my $topic = "UnitTest1";
    my $text = "hi";
    my $web = $testweb;
    my $user = $twiki->{users}->findUser("TestUser1");

    saveTopic1( $web, $topic, $text, $user );

    my $rev = $twiki->{store}->getRevisionNumber( $web, $topic );
    $this->assert_num_equals(1, $rev);

    my ( $meta, $text1 ) = $twiki->{store}->readTopic( $user, $web, $topic, undef, 0 );

    $text1 =~ s/[\s]*$//go;
    $this->assert_str_equals( $text, $text1 );

    # Check revision number from meta data
    my( $dateMeta, $authorMeta, $revMeta ) = $meta->getRevisionInfo( $web, $topic );
    $this->assert_num_equals( 1, $revMeta, "Rev from meta data should be 1 when first created" );
    $meta = new TWiki::Meta($twiki, $web, $topic);
    my( $dateMeta0, $authorMeta0, $revMeta0 ) =
      $meta->getRevisionInfo( $web, $topic );
    $this->assert_num_equals( $revMeta0, $revMeta );
    # Check-in with different text, under different user (to force change)
    $user = $twiki->{users}->findUser("TestUser2");
    $text = "bye";

    saveTopic1($web, $topic, $text, $user, $meta );

    $rev = $twiki->{store}->getRevisionNumber( $web, $topic );
    $this->assert_num_equals(2, $rev );
    ( $meta, $text1 ) = $twiki->{store}->readTopic( $user, $web, $topic, undef, 0 );
    ( $dateMeta, $authorMeta, $revMeta ) =
      $meta->getRevisionInfo( $web, $topic );
    $this->assert_num_equals(2, $revMeta, "Rev from meta should be 2 after one change" );
}

sub test_checkin_attachment {
    my $this = shift;

    # Create topic
    my $topic = "UnitTest2";
    my $text = "hi";
    my $web = $testweb;
    my $user = $twiki->{users}->findUser("TestUser1");

    saveTopic1($web, $topic, $text, $user );

    # directly put file in pub directory (where attachments go)
    my $dir = $TWiki::cfg{PubDir};
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

    $twiki->{store}->saveAttachment($web, $topic, $attachment, $user,
                                { file => "/tmp/$attachment" } );

    # Check revision number
    my $rev = $twiki->{store}->getRevisionNumber($web, $topic, $attachment);
    $this->assert_num_equals(1,$rev);

    # Save again and check version number goes up by 1
    open( FILE, ">/tmp/$attachment" );
    print FILE "Test attachment\nAnd a second line";
    close(FILE);

    $twiki->{store}->saveAttachment( $web, $topic, $attachment, $user,
                                  { file => "/tmp/$attachment" } );
    # Check revision number
    $rev = $twiki->{store}->getRevisionNumber( $web, $topic, $attachment );
    $this->assert_num_equals(2, $rev);
}

sub test_rename() {
    my $this = shift;

    my $oldWeb = $testweb;
    my $oldTopic = "UnitTest2";
    my $newWeb = $oldWeb;
    my $newTopic = "UnitTest2Moved";
    my $user = $twiki->{users}->findUser("TestUser1");

    saveTopic1($oldWeb, $oldTopic, "Elucidate the goose", $user );
    my $attachment = "afile.txt";
    open( FILE, ">/tmp/$attachment" );
    print FILE "Test her attachment to me\n";
    close(FILE);
    $user = $twiki->{users}->findUser( "TestUser2" );
    $twiki->{userName} = $user;
    $twiki->{store}->saveAttachment($oldWeb, $oldTopic, $attachment, $user,
                                { file => "/tmp/$attachment" } );

    my $oldRevAtt =
      $twiki->{store}->getRevisionNumber( $oldWeb, $oldTopic, $attachment );
    my $oldRevTop =
      $twiki->{store}->getRevisionNumber( $oldWeb, $oldTopic );

    $user =$twiki->{users}->findUser( "TestUser1" );
    $twiki->{user} = $user;

    #$TWiki::Sandbox::_trace = 1;
    $twiki->{store}->moveTopic($oldWeb, $oldTopic, $newWeb,
                               $newTopic, $user);
    #$TWiki::Sandbox::_trace = 0;

    my $newRevAtt =
      $twiki->{store}->getRevisionNumber($newWeb, $newTopic, $attachment );
    $this->assert_num_equals($oldRevAtt, $newRevAtt);

    # Topic is modified in move, because meta information is updated
    # to indicate move
    # THIS IS NOW DONE IN UI::Manage
#    my $newRevTop =
#      $twiki->{store}->getRevisionNumber( $newWeb, $newTopic );
#    $this->assert_matches(qr/^\d+$/, $newRevTop);
#    my $revTopShouldBe = $oldRevTop + 1;
#    $this->assert_num_equals($revTopShouldBe, $newRevTop );
}

sub test_releaselocksonsave {
    my $this = shift;
    my $web = $testweb;
    my $topic = "MultiEditTopic";
    my $meta = new TWiki::Meta($twiki, $web, $topic);

    # create rev 1
    my $query = new CGI ({
                          '.path_info' => "/$web/$topic",
                          originalrev => [ 0 ],
                          'action' => [ 'save' ],
                          text => [ "Baseline\nText\n" ],
                         });
    my $user = "TestUser1";
    my $thePathInfo = "/$web/$topic";
    my $theUrl = "/save/$web/$topic";

    $twiki = new TWiki( $thePathInfo, $user, $topic, $theUrl, $query );
    try {
        TWiki::UI::Save::save( $twiki );
    } catch TWiki::OopsException with {
        my $e = shift;
        print $e->stringify();
    } catch Error::Simple with {
        my $e = shift;
        print $e->stringify();
    };

    # create rev 2
    $query = new CGI ({
                       '.path_info' => "/$web/$topic",
                       originalrev => [ 1 ],
                       'action' => [ 'save' ],
                       text => [ "Changed\nLines\n" ],
                       forcenewrevision => [ 1 ],
                      });
    $twiki = new TWiki( $thePathInfo, $user, $topic, $theUrl, $query );
    try {
        TWiki::UI::Save::save( $twiki );
    } catch TWiki::OopsException with {
        my $e = shift;
        print $e->stringify();
    } catch Error::Simple with {
        my $e = shift;
        print $e->stringify();
    };

    # now testuser2 has a go, based on rev 1
    $query = new CGI ({
                       '.path_info' => "/$web/$topic",
                       originalrev => [ 1 ],
                       'action' => [ 'save' ],
                       text => [ "Sausage\nChips\n" ],
                       forcenewrevision => [ 1 ],
                      });
    $user = "TestUser2";
    $twiki = new TWiki( $thePathInfo, $user, $topic, $theUrl, $query );
    try {
        TWiki::UI::Save::save( $twiki );
    } catch TWiki::OopsException with {
    } catch Error::Simple with {
    };

    open(F,"<$TWiki::cfg{DataDir}/$web/$topic.txt");
    undef $/;
    my $text = <F>;
    close(F);
    $this->assert_matches(qr/%META:TOPICINFO{author="TestUser2"/, $text);
    $this->assert_matches(qr/version="1.3"/, $text);
    $this->assert_matches(qr/<del>Changed<\/del><ins>Sausage<\/ins>/, $text);
    $this->assert_matches(qr/<del>Lines<\/del><ins>Chips<\/ins>/, $text);

}

1;
