# Smoke tests for TWiki::Store
package StoreSmokeTests;

use base qw(TWikiTestCase);

use strict;
use TWiki;
use TWiki::Meta;
use Error qw( :try );
use CGI;
use TWiki::UI::Save;
use TWiki::OopsException;
use Devel::Symdump;

my $testweb = "TemporaryStoreSmokeTestsTestWeb";

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

my $twiki;

my $testUser1;
my $testUser2;

sub list_tests {
    my $this = shift;
    my @set = $this->SUPER::list_tests();

    my $clz = new Devel::Symdump(qw(StoreSmokeTests));
    for my $i ($clz->functions()) {
        next unless $i =~ /::verify_/;
        foreach my $impl qw(  RcsWrap RcsLite ) {
            my $fn = $i;
            $fn =~ s/\W/_/g;
            my $sfn = 'StoreSmokeTests::test_'.$fn.$impl;
            no strict 'refs';
            *$sfn = sub {
                my $this = shift;
                $TWiki::cfg{StoreImpl} = $impl;
                &$i($this);
            };
            use strict 'refs';
            push(@set, $sfn);
        }
    }
    return @set;
}

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $TWiki::cfg{WarningFileName} = "/tmp/junk";
    $TWiki::cfg{LogFileName} = "/tmp/junk";

    $twiki = new TWiki();

    $testUser1 = $this->createFakeUser($twiki);
    $testUser2 = $this->createFakeUser($twiki);
    $twiki->{store}->createWeb( $twiki->{user}, $testweb);
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    $twiki->{store}->removeWeb($twiki->{user}, $testweb);
}

sub test_noise {
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
    my $user = $twiki->{users}->findUser($testUser1);

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
    $user = $twiki->{users}->findUser($testUser2);
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
    my $user = $twiki->{users}->findUser($testUser1);

    $twiki->{store}->saveTopic($user, $testweb, $topic, $text );

    # ensure pub directory for topic exists (SMELL surely not needed?)
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
    my $user = $twiki->{users}->findUser($testUser1);

    $twiki->{store}->saveTopic($user, $oldWeb, $oldTopic, "Elucidate the goose" );
    $this->assert(!$twiki->{store}->topicExists($newWeb, $newTopic));

    my $attachment = "afile.txt";
    open( FILE, ">/tmp/$attachment" );
    print FILE "Test her attachment to me\n";
    close(FILE);
    $user = $twiki->{users}->findUser( $testUser2 );
    $twiki->{userName} = $user;
    $twiki->{store}->saveAttachment($oldWeb, $oldTopic, $attachment, $user,
                                { file => "/tmp/$attachment" } );

    my $oldRevAtt =
      $twiki->{store}->getRevisionNumber( $oldWeb, $oldTopic, $attachment );
    my $oldRevTop =
      $twiki->{store}->getRevisionNumber( $oldWeb, $oldTopic );

    $user =$twiki->{users}->findUser( $testUser1 );
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
                          originalrev => [ 0 ],
                          'action' => [ 'save' ],
                          text => [ "Before\nBaseline\nText\nAfter\n" ],
                         });
    $query->path_info( "/$testweb/$topic" );

    $twiki = new TWiki( $testUser1, $query );
    try {
        $this->capture(\&TWiki::UI::Save::save, $twiki );
    } catch TWiki::OopsException with {
        my $e = shift;
        print $e->stringify();
    } catch Error::Simple with {
        my $e = shift;
        print $e->stringify();
    };

    # create rev 2 as TestUser1
    $query = new CGI ({
                       originalrev => [ 1 ],
                       'action' => [ 'save' ],
                       text => [ "Before\nChanged\nLines\nAfter\n" ],
                       forcenewrevision => [ 1 ],
                      });
    $query->path_info( "/$testweb/$topic" );
    $twiki = new TWiki( $testUser1, $query );
    try {
        $this->capture( \&TWiki::UI::Save::save,  $twiki );
    } catch TWiki::OopsException with {
        my $e = shift;
        print $e->stringify();
    } catch Error::Simple with {
        my $e = shift;
        print $e->stringify();
    };

    # now TestUser2 has a go, based on rev 1
    $query = new CGI ({
                       originalrev => [ 1 ],
                       'action' => [ 'save' ],
                       text => [ "Before\nSausage\nChips\nAfter\n" ],
                       forcenewrevision => [ 1 ],
                      });

    $query->path_info( "/$testweb/$topic" );
    $twiki = new TWiki( $testUser2, $query );
    try {
        $this->capture( \&TWiki::UI::Save::save,  $twiki );
        $this->assert(0);
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
    $this->assert_matches(qr/<div\s+class="twikiConflict">.+version\s+2.*<\/div>\s*Changed\nLines[\s.]+<div/, $text);
    $this->assert_matches(qr/<div\s+class="twikiConflict">.+version\s+new.*<\/div>\s*Sausage\nChips[\s.]+<div/, $text);
    $this->assert_matches(qr/%META:TOPICINFO{author="$testUser2"/, $text);

}

1;
