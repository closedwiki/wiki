use strict;

# Test cases:
# 1) Autoattach = off. Save a topic referring to an attachmentMissing that does not exist.
# 2) Add attachmentAdded into the attachment area for that topic, circumventing TWiki
# 3) Turn autoattach = on. Ask for the list of attachments. attachmentAdded should appear. attachmentMissing should not.


# SMELL: this looks very incomplete

package AutoAttachTests;

use base qw(TWikiTestCase);

use strict;
use TWiki;
use TWiki::Meta;
use Error qw( :try );
use CGI;
use TWiki::UI::Save;
use TWiki::OopsException;
use Devel::Symdump;

sub new {
    my $this = shift()->SUPER::new(@_);
    return $this;
}

my $testweb = "TemporaryStoreAutoAttachTestWeb";
my $session;
my $testUser1;
my $testUser2;
my %cfg;

use Data::Dumper;

# Set up the test fixture
sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
    $TWiki::cfg{WarningFileName} = "/tmp/junk";
    $TWiki::cfg{LogFileName} = "/tmp/junk";

    $session = new TWiki();

    $testUser1 = $this->createFakeUser($session);
    $testUser2 = $this->createFakeUser($session);
    $session->{store}->createWeb( $session->{user}, $testweb);
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    $session->{store}->removeWeb($session->{user}, $testweb);
}

# We create a topic with a missing attachment
# This attachment should be now omitted from the resulting output
sub addMissingAttachment {
	my $this = shift;
	my $topic = shift;
	my $file = shift; 
	my $comment = shift; 

	$this->assert($session->{store}->topicExists($testweb, $topic));
	
    my ($meta, $text) = $session->{store}->readTopic( 
    				$session->{user}, $testweb, $topic );
	
	$meta->putKeyed( 'FILEATTACHMENT',
                       {
                             name    => $file,
                             version => '',
                             path    => $file,
                             size    => 2000000,
                             date    => 2000000,
                             user    => "TWikiContributor",
                             comment => $comment,
                             attr    => ''
                        }
                       );
	$session->{store}->saveTopic(
					 $session->{user}, $testweb, $topic, $text, $meta );
}

# We create a 3 more attachment entries:
# one (afile.txt) that should be detected and 
# another two (_afile.txt and _hiddenDirectoryForPlugins) that should not

sub sneakAttachmentsAddedToTopic {
	my $this = shift;
	my ($topic, @filenames) = @_;
	
    my $dir = $TWiki::cfg{PubDir};
    $dir = "$dir/$testweb/$topic";

	foreach my $file (@filenames) {
		touchFile("$dir/$file");
	}

	    
    mkdir $dir.'/_hiddenDirectoryForPlugins';    
}

sub touchFile {
    my $filename = shift;
    open( FILE, ">$filename" );
    print FILE "Test attachment $filename\n";
    close(FILE); 
}

sub test_no_autoattach {
}

sub test_autoattach {
	
	$TWiki::cfg{AutoAttachPubFiles} = 1;
	print "AutoAttachPubFiles = $TWiki::cfg{AutoAttachPubFiles}\n";
	
	my $this = shift; 
	my $topic = "UnitTest1";	
	$this->verify_normal_attachment($topic);
    $this->addMissingAttachment($topic, 'bogusAttachment.txt', "I'm a figment of TWiki's imagination");
    $this->addMissingAttachment($topic, 'ressurectedComment.txt', 'ressurected attachment comment');
    $this->sneakAttachmentsAddedToTopic($topic, 'sneakedfile1.txt','sneakedfile2.txt', 'commavfilesshouldbeignored2.txt,v','_hiddenAttachment.txt', 'ressurectedComment.txt');

    my ($meta, $text) = $session->{store}->readTopic($session->{user}, $testweb, $topic);
    my @attachments = $meta->find( 'FILEATTACHMENT' );
# 	printAttachments(@attachments);

    $this->foundAttachmentsMustBeGettable($meta, @attachments);
    # ASSERT the commavfile should not be found, but should be gettable.

	# Our attachment correctly listed in meta data still exists:
    my $afileAttributes = $meta->get('FILEATTACHMENT', "afile.txt");
  	$this->assert_not_null($afileAttributes);
    
    # Our added files now exist:
    my $sneakedfile1Attributes = $meta->get('FILEATTACHMENT', "sneakedfile1.txt");
    my $sneakedfile2Attributes = $meta->get('FILEATTACHMENT', "sneakedfile2.txt");
	$this->assert_not_null($sneakedfile1Attributes);
	$this->assert_not_null($sneakedfile2Attributes);
	
	# We have deleted the faulty bogus reference:
    my $bogusAttachmentAttributes = $meta->get('FILEATTACHMENT', "bogusAttachment.txt");
    $this->assert_null($bogusAttachmentAttributes);
    
    # And commav files are still gettable (we check earlier that it is not listable).
    my $commavfilesshouldbeignoredAttributes = $meta->get('FILEATTACHMENT', "commavfilesshouldbeignored2.txt,v");
	$this->assert_not_null($commavfilesshouldbeignoredAttributes);

}

sub foundAttachmentsMustBeGettable {
   my ($this, $meta, @attachments) = @_;

	foreach my $attachment (@attachments) {
		my $attachmentName = $attachment->{name};
#		print "Testing file exists ".$attachmentName.": ";
		my $attachmentAttributes = $meta->get('FILEATTACHMENT', $attachmentName);
		$this->assert_not_null($attachmentAttributes);
	    # print Dumper($attachmentAttributes)."\n";
	    
	    if ($attachmentName eq "commavfilesshouldbeignored2.txt,v") {
	    	die "commavfilesshouldbeignored2.txt,v should not be returned in the listing";
	    }
	}
}   


sub printAttachments {
	my (@attachments) = @_; 
    
    foreach my $attachment (@attachments) {
    	print "Attachment found: ".Dumper($attachment)."\n";
    }
}

sub verify_normal_attachment {
    my $this = shift;

    # Create topic
    my $topic = shift;
    my $text = "hi";
    my $user = $session->{users}->findUser($testUser1);

    $session->{store}->saveTopic($user, $testweb, $topic, $text );

    my $attachment = "afile.txt";
    open( FILE, ">/tmp/$attachment" );
    print FILE "Test attachment\n";
    close(FILE);

    my $saveCmd = "";
    my $doNotLogChanges = 0;
    my $doUnlock = 1;

    $session->{store}->saveAttachment($testweb, $topic, $attachment, $user,
                                { file => "/tmp/$attachment", comment => 'comment 1' } );

    # Check revision number
    my $rev = $session->{store}->getRevisionNumber($testweb, $topic, $attachment);
    $this->assert_num_equals(1,$rev);

    # Save again and check version number goes up by 1
    open( FILE, ">/tmp/$attachment" );
    print FILE "Test attachment\nAnd a second line";
    close(FILE);

    $session->{store}->saveAttachment( $testweb, $topic, $attachment, $user,
                                  { file => "/tmp/$attachment", comment => 'comment 2'  } );
    # Check revision number
    $rev = $session->{store}->getRevisionNumber( $testweb, $topic, $attachment );
    $this->assert_num_equals(2, $rev);
}

1;
