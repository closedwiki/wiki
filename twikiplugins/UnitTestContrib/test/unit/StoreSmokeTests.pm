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

my $testUser1;
my $testUser2;

sub RcsLite {
    my $this = shift;
    $TWiki::cfg{StoreImpl} = 'RcsLite';
    $this->set_up_for_verify();
}

sub RcsWrap {
    my $this = shift;
    $TWiki::cfg{StoreImpl} = 'RcsWrap';
    $this->set_up_for_verify();
}

sub fixture_groups {
    return ( [ 'RcsLite', 'RcsWrap' ] );
}

# Set up the test fixture
sub set_up_for_verify {
    my $this = shift;

    $TWiki::cfg{WarningFileName} = "$TWiki::cfg{TempfileDir}/junk";
    $TWiki::cfg{LogFileName} = "$TWiki::cfg{TempfileDir}/junk";

    $this->{twiki} = new TWiki();

    #TODO: re-do to test other choices
    $TWiki::cfg{Htpasswd}{FileName} = '$TWiki::cfg{TempfileDir}/junkpasswd';
    $TWiki::cfg{PasswordManager} = 'TWiki::Users::HtPasswdUser';
    $TWiki::cfg{UserMappingManager} = 'TWiki::Users::TWikiUserMapping';
    $TWiki::cfg{LoginManager} = 'TWiki::LoginManager::TemplateLogin';  
    $TWiki::cfg{Register}{EnableNewUserRegistration} = 1;
    
    #$this->annotate(" session is running as ".TWiki::Func::getWikiName());
    #$this->annotate("\nusermapper: ".$this->{twiki}->{users}->{mapping_id});
    

    # Use just the wikiname (don't create a complete user) because the
    # store should *only* need the wikiname; no other user details are
    # required.
    $testUser1 = "DummyUserOne";
    $testUser2 = "DummyUserTwo";
    $this->{twiki}->{store}->createWeb( $this->{twiki}->{user}, $testweb);
}

sub tear_down {
    my $this = shift;
    unlink $TWiki::cfg{WarningFileName};
    unlink $TWiki::cfg{LogFileName};
    unlink $TWiki::cfg{Htpasswd}{FileName};
    $this->removeWebFixture($this->{twiki}, $testweb);
    $this->{twiki}->finish() if $this->{twiki};
    $this->SUPER::tear_down();
}

sub verify_notopic {
    my $this = shift;
    my $topic = "UnitTest1";
    my $rev = $this->{twiki}->{store}->getRevisionNumber( $testweb, "UnitTest1" );
    $this->assert(!$this->{twiki}->{store}->topicExists($testweb, $topic));
    $this->assert_num_equals(0, $rev);
}

sub verify_checkin {
    my $this = shift;
    my $topic = "UnitTest1";
    my $text = "hi";
    my $user = $testUser1;

    $this->assert(!$this->{twiki}->{store}->topicExists($testweb,$topic));
    $this->{twiki}->{store}->saveTopic( $user, $testweb, $topic, $text );

    my $rev = $this->{twiki}->{store}->getRevisionNumber( $testweb, $topic );
    $this->assert_num_equals(1, $rev);

    my( $meta, $text1 ) = $this->{twiki}->{store}->readTopic(
        $user, $testweb, $topic, undef, 0 );

    $text1 =~ s/[\s]*$//go;
    $this->assert_str_equals( $text, $text1 );

    # Check revision number from meta data
    my( $dateMeta, $authorMeta, $revMeta ) = $meta->getRevisionInfo();
    $this->assert_num_equals( 1, $revMeta, "Rev from meta data should be 1 when first created $revMeta" );

    $meta = new TWiki::Meta($this->{twiki}, $testweb, $topic);
    my( $dateMeta0, $authorMeta0, $revMeta0 ) = $meta->getRevisionInfo();
    $this->assert_num_equals( $revMeta0, $revMeta );
    # Check-in with different text, under different user (to force change)
    $user = $testUser2;
    $text = "bye";

    $this->{twiki}->{store}->saveTopic($user, $testweb, $topic, $text, $meta );

    $rev = $this->{twiki}->{store}->getRevisionNumber( $testweb, $topic );
    $this->assert_num_equals(2, $rev );
    ( $meta, $text1 ) = $this->{twiki}->{store}->readTopic( $user, $testweb, $topic, undef, 0 );
    ( $dateMeta, $authorMeta, $revMeta ) = $meta->getRevisionInfo();
    $this->assert_num_equals(2, $revMeta, "Rev from meta should be 2 after one change" );
}

sub verify_checkin_attachment {
    my $this = shift;

    # Create topic
    my $topic = "UnitTest2";
    my $text = "hi";
    my $user = $testUser1;

    $this->{twiki}->{store}->saveTopic($user, $testweb, $topic, $text );

    # ensure pub directory for topic exists (SMELL surely not needed?)
    my $dir = $TWiki::cfg{PubDir};
    $dir = "$dir/$testweb/$topic";
    if( ! -e "$dir" ) {
        umask( 0 );
        mkdir( $dir, 0777 );
    }

    my $attachment = "afile.txt";
    open( FILE, ">$TWiki::cfg{TempfileDir}/$attachment" );
    print FILE "Test attachment\n";
    close(FILE);

    my $saveCmd = "";
    my $doNotLogChanges = 0;
    my $doUnlock = 1;

    $this->{twiki}->{store}->saveAttachment($testweb, $topic, $attachment, $user,
                                { file => "$TWiki::cfg{TempfileDir}/$attachment" } );
    unlink "$TWiki::cfg{TempfileDir}/$attachment";

    # Check revision number
    my $rev = $this->{twiki}->{store}->getRevisionNumber($testweb, $topic, $attachment);
    $this->assert_num_equals(1,$rev);

    # Save again and check version number goes up by 1
    open( FILE, ">$TWiki::cfg{TempfileDir}/$attachment" );
    print FILE "Test attachment\nAnd a second line";
    close(FILE);

    $this->{twiki}->{store}->saveAttachment( $testweb, $topic, $attachment, $user,
                                  { file => "$TWiki::cfg{TempfileDir}/$attachment" } );

    unlink "$TWiki::cfg{TempfileDir}/$attachment";

    # Check revision number
    $rev = $this->{twiki}->{store}->getRevisionNumber( $testweb, $topic, $attachment );
    $this->assert_num_equals(2, $rev);
}

sub verify_rename() {
    my $this = shift;

    my $oldWeb = $testweb;
    my $oldTopic = "UnitTest2";
    my $newWeb = $oldWeb;
    my $newTopic = "UnitTest2Moved";
    my $user = $testUser1;

    $this->{twiki}->{store}->saveTopic($user, $oldWeb, $oldTopic, "Elucidate the goose" );
    $this->assert(!$this->{twiki}->{store}->topicExists($newWeb, $newTopic));

    my $attachment = "afile.txt";
    open( FILE, ">$TWiki::cfg{TempfileDir}/$attachment" );
    print FILE "Test her attachment to me\n";
    close(FILE);
    $user = $testUser2;
    $this->{twiki}->{userName} = $user;
    $this->{twiki}->{store}->saveAttachment($oldWeb, $oldTopic, $attachment, $user,
                                { file => "$TWiki::cfg{TempfileDir}/$attachment" } );

    my $oldRevAtt =
      $this->{twiki}->{store}->getRevisionNumber( $oldWeb, $oldTopic, $attachment );
    my $oldRevTop =
      $this->{twiki}->{store}->getRevisionNumber( $oldWeb, $oldTopic );

    $user = $testUser1;
    $this->{twiki}->{user} = $user;

    #$TWiki::Sandbox::_trace = 1;
    $this->{twiki}->{store}->moveTopic($oldWeb, $oldTopic, $newWeb,
                               $newTopic, $user);
    #$TWiki::Sandbox::_trace = 0;

    $this->assert(!$this->{twiki}->{store}->topicExists($oldWeb, $oldTopic));
    $this->assert(!$this->{twiki}->{store}->attachmentExists($oldWeb, $oldTopic,
                                                     $attachment));
    $this->assert($this->{twiki}->{store}->topicExists($newWeb, $newTopic));
    $this->assert($this->{twiki}->{store}->attachmentExists($newWeb, $newTopic,
                                                    $attachment));

    my $newRevAtt =
      $this->{twiki}->{store}->getRevisionNumber($newWeb, $newTopic, $attachment );
    $this->assert_num_equals($oldRevAtt, $newRevAtt);

    # Topic is modified in move, because meta information is updated
    # to indicate move
    # THIS IS NOW DONE IN UI::Manage
#    my $newRevTop =
#      $this->{twiki}->{store}->getRevisionNumber( $newWeb, $newTopic );
#    $this->assert_matches(qr/^\d+$/, $newRevTop);
#    my $revTopShouldBe = $oldRevTop + 1;
#    $this->assert_num_equals($revTopShouldBe, $newRevTop );
}

sub verify_releaselocksonsave {
    my $this = shift;
    my $topic = "MultiEditTopic";
    my $meta = new TWiki::Meta($this->{twiki}, $testweb, $topic);

    # create rev 1 as TestUser1
    my $query = new CGI ({
                          originalrev => [ 0 ],
                          'action' => [ 'save' ],
                          text => [ "Before\nBaseline\nText\nAfter\n" ],
                         });
    $query->path_info( "/$testweb/$topic" );

    $this->{twiki} = new TWiki( $testUser1, $query );
    try {
        $this->capture(\&TWiki::UI::Save::save, $this->{twiki} );
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
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $testUser1, $query );
    try {
        $this->capture( \&TWiki::UI::Save::save,  $this->{twiki} );
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
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $testUser2, $query );
    try {
        $this->capture( \&TWiki::UI::Save::save,  $this->{twiki} );
        $this->annotate("\na merge notice exception should have been thrown for /$testweb/$topic");
        $this->assert(0);
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_equals('attention', $e->{template});
        $this->assert_equals('merge_notice', $e->{def});
    } catch Error::Simple with {
        $this->assert(0,shift->{-text});
    };

    open(F,"<$TWiki::cfg{DataDir}/$testweb/$topic.txt");
    local $/ = undef;
    my $text = <F>;
    close(F);
    $this->assert_matches(qr/version="1.3"/, $text);
    $this->assert_matches(qr/<div\s+class="twikiConflict">.+version\s+2.*<\/div>\s*Changed\nLines[\s.]+<div/, $text);
    $this->assert_matches(qr/<div\s+class="twikiConflict">.+version\s+new.*<\/div>\s*Sausage\nChips[\s.]+<div/, $text);

}

1;
