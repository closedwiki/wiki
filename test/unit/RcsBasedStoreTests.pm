# Smoke tests for TWiki::Store

# SMELL: there is nothing specific to RCS about these tests; they
# are general version-controlled store tests

require 5.006;

use strict;

package RcsBasedStoreTests;

use base qw(Test::Unit::TestCase);

BEGIN {
    unshift @INC, '../../bin';
    require 'setlib.cfg';
};
use strict;
use TWiki;
use TWiki::Meta;
use Error qw( :try );
use CGI;
use TWiki::UI::Save;
use TWiki::OopsException;
use Devel::Symdump;

my $testweb = "StoreTestsTestWeb";

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

my $twiki;

my $saveWF;
my $saveLF;
my $saveIMPL;

sub list_tests {
    my $this = shift;
    my @set = $this->SUPER::list_tests();

    my $clz = new Devel::Symdump(qw(RcsBasedStoreTests));
    for my $i ($clz->functions()) {
        next unless $i =~ /::verify_/;
        foreach my $impl qw(  RcsWrap ) {
            my $fn = $i;
            $fn =~ s/\W/_/g;
            my $sfn = 'RcsBasedStoreTests::test_'.$fn.$impl;
            no strict 'refs';
            *$sfn = sub {
                my $this = shift;
                $saveIMPL = $TWiki::cfg{StoreImpl};
                $TWiki::cfg{StoreImpl} = $impl;
                $this->my_set_up();
                &$i($this);
                $TWiki::cfg{StoreImpl} = $saveIMPL;
            };
            use strict 'refs';
            push(@set, $sfn);
        }
    }
    return @set;
}

# Set up the test fixture
sub my_set_up {
    my $this = shift;

    $saveWF = $TWiki::cfg{WarningFileName};
    $TWiki::cfg{WarningFileName} = "/tmp/junk";
    $saveLF = $TWiki::cfg{LogFileName};
    $TWiki::cfg{LogFileName} = "/tmp/junk";

    my $topic = "";
    my $user = "TestUser1";
    my $thePathInfo = "/$testweb/$topic";
    my $theUrl = "/save/$testweb/$topic";

    $twiki = new TWiki( $thePathInfo, $user, $topic, $theUrl );

    $twiki->{store}->createWeb( $twiki->{user}, $testweb);

    # Make sure we have a TestUser1 and TestUser1 topic
    unless( $twiki->{store}->topicExists($TWiki::cfg{UsersWebName}, "TestUser1")) {
        $twiki->{store}->saveTopic
          ($twiki->{user},
           $TWiki::cfg{UsersWebName}, "TestUser1",
           "silly user page!!!");
    }
    unless( $twiki->{store}->topicExists($TWiki::cfg{UsersWebName}, "TestUser2")) {
        $twiki->{store}->saveTopic
          ($twiki->{user},
           $TWiki::cfg{UsersWebName}, "TestUser2",
           "silly user page!!!");
    }
}

sub tear_down {
    $twiki->{store}->removeWeb(undef, $testweb);
    $TWiki::cfg{WarningFileName} = $saveWF;
    $TWiki::cfg{LogFileName} = $saveLF;
    $TWiki::cfg{StoreImpl} = $saveIMPL;
}

sub verify_notopic {
    my $this = shift;
    my $topic = "UnitTest1";
    my $rev = $twiki->{store}->getRevisionNumber( $testweb, "UnitTest1" );
    $this->assert(!$twiki->{store}->topicExists($testweb, $topic));
    $this->assert_num_equals(0, $rev);
}

sub verify_checkin {
    my $this = shift;
    my $topic = "UnitTest1";
    my $text = "hi";
    my $user = $twiki->{users}->findUser("TestUser1");

    $this->assert(!$twiki->{store}->topicExists($testweb,$topic));
    $twiki->{store}->saveTopic( $user, $testweb, $topic, $text );

    my $rev = $twiki->{store}->getRevisionNumber( $testweb, $topic );
    $this->assert_num_equals(1, $rev);

    my( $meta, $text1 ) = $twiki->{store}->readTopic(
        $user, $testweb, $topic, undef, 0 );

    $text1 =~ s/[\s]*$//go;
    $this->assert_str_equals( $text, $text1 );

    # Check revision number from meta data
    my( $dateMeta, $authorMeta, $revMeta ) = $meta->getRevisionInfo();
    $this->assert_num_equals( 1, $revMeta, "Rev from meta data should be 1 when first created $revMeta" );

    $meta = new TWiki::Meta($twiki, $testweb, $topic);
    my( $dateMeta0, $authorMeta0, $revMeta0 ) = $meta->getRevisionInfo();
    $this->assert_num_equals( $revMeta0, $revMeta );
    # Check-in with different text, under different user (to force change)
    $user = $twiki->{users}->findUser("TestUser2");
    $text = "bye";

    $twiki->{store}->saveTopic($user, $testweb, $topic, $text, $meta );

    $rev = $twiki->{store}->getRevisionNumber( $testweb, $topic );
    $this->assert_num_equals(2, $rev );
    ( $meta, $text1 ) = $twiki->{store}->readTopic( $user, $testweb, $topic, undef, 0 );
    ( $dateMeta, $authorMeta, $revMeta ) = $meta->getRevisionInfo();
    $this->assert_num_equals(2, $revMeta, "Rev from meta should be 2 after one change" );
}

sub verify_checkin_attachment {
    my $this = shift;

    # Create topic
    my $topic = "UnitTest2";
    my $text = "hi";
    my $user = $twiki->{users}->findUser("TestUser1");

    $twiki->{store}->saveTopic($user, $testweb, $topic, $text );

    # directly put file in pub directory (where attachments go)
    my $dir = $TWiki::cfg{PubDir};
    $dir = "$dir/$testweb/$topic";
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

    $twiki->{store}->saveAttachment($testweb, $topic, $attachment, $user,
                                { file => "/tmp/$attachment" } );

    # Check revision number
    my $rev = $twiki->{store}->getRevisionNumber($testweb, $topic, $attachment);
    $this->assert_num_equals(1,$rev);

    # Save again and check version number goes up by 1
    open( FILE, ">/tmp/$attachment" );
    print FILE "Test attachment\nAnd a second line";
    close(FILE);

    $twiki->{store}->saveAttachment( $testweb, $topic, $attachment, $user,
                                  { file => "/tmp/$attachment" } );
    # Check revision number
    $rev = $twiki->{store}->getRevisionNumber( $testweb, $topic, $attachment );
    $this->assert_num_equals(2, $rev);
}

sub verify_rename() {
    my $this = shift;

    my $oldWeb = $testweb;
    my $oldTopic = "UnitTest2";
    my $newWeb = $oldWeb;
    my $newTopic = "UnitTest2Moved";
    my $user = $twiki->{users}->findUser("TestUser1");

    $twiki->{store}->saveTopic($user, $oldWeb, $oldTopic, "Elucidate the goose" );
    $this->assert(!$twiki->{store}->topicExists($newWeb, $newTopic));

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

    $this->assert(!$twiki->{store}->topicExists($oldWeb, $oldTopic));
    $this->assert(!$twiki->{store}->attachmentExists($oldWeb, $oldTopic,
                                                     $attachment));
    $this->assert($twiki->{store}->topicExists($newWeb, $newTopic));
    $this->assert($twiki->{store}->attachmentExists($newWeb, $newTopic,
                                                    $attachment));

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

sub verify_releaselocksonsave {
    my $this = shift;
    my $topic = "MultiEditTopic";
    my $meta = new TWiki::Meta($twiki, $testweb, $topic);

    # create rev 1 as TestUser1
    my $query = new CGI ({
                          '.path_info' => "/$testweb/$topic",
                          originalrev => [ 0 ],
                          'action' => [ 'save' ],
                          text => [ "Baseline\nText\n" ],
                         });
    my $thePathInfo = "/$testweb/$topic";
    my $theUrl = "/save/$testweb/$topic";

    $twiki = new TWiki( $thePathInfo, "TestUser1", $topic, $theUrl, $query );
    try {
        TWiki::UI::Save::save( $twiki );
    } catch TWiki::OopsException with {
        my $e = shift;
        print $e->stringify();
    } catch Error::Simple with {
        my $e = shift;
        print $e->stringify();
    };

    # create rev 2 as TestUser1
    $query = new CGI ({
                       '.path_info' => "/$testweb/$topic",
                       originalrev => [ 1 ],
                       'action' => [ 'save' ],
                       text => [ "Changed\nLines\n" ],
                       forcenewrevision => [ 1 ],
                      });
    $twiki = new TWiki( $thePathInfo, "TestUser1", $topic, $theUrl, $query );
    try {
        TWiki::UI::Save::save( $twiki );
    } catch TWiki::OopsException with {
        my $e = shift;
        print $e->stringify();
    } catch Error::Simple with {
        my $e = shift;
        print $e->stringify();
    };

    # now TestUser2 has a go, based on rev 1
    $query = new CGI ({
                       '.path_info' => "/$testweb/$topic",
                       originalrev => [ 1 ],
                       'action' => [ 'save' ],
                       text => [ "Sausage\nChips\n" ],
                       forcenewrevision => [ 1 ],
                      });

    $twiki = new TWiki( $thePathInfo, "TestUser2", $topic, $theUrl, $query );
    try {
        TWiki::UI::Save::save( $twiki );
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_equals('attention', $e->{template});
        $this->assert_equals('merge_notice', $e->{def});
    } catch Error::Simple with {
        $this->assert(0,shift->{-text});
    };

    open(F,"<$TWiki::cfg{DataDir}/$testweb/$topic.txt");
    undef $/;
    my $text = <F>;
    close(F);
    $this->assert_matches(qr/version="1.3"/, $text);
    $this->assert_matches(qr/<del>Changed<\/del><ins>Sausage<\/ins>/, $text);
    $this->assert_matches(qr/<del>Lines<\/del><ins>Chips<\/ins>/, $text);
    $this->assert_matches(qr/%META:TOPICINFO{author="TestUser2"/, $text);

}

1;
