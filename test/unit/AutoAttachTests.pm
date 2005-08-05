use strict;

# Test cases:
# 1) Autoattach = off. Save a topic referring to an attachmentMissing that does not exist.
# 2) Add attachmentAdded into the attachment area for that topic, circumventing TWiki
# 3) Turn autoattach = on. Ask for the list of attachments. attachmentAdded should appear. attachmentMissing should not.


package AutoAttachTests;

use base qw(TWikiTestCase);


use TWiki;
use TWiki::Meta;
use Error qw( :try );
use CGI;
use TWiki::UI::Save;
use TWiki::OopsException;
use Devel::Symdump;

my $testweb = "TemporaryStoreAutoAttachTestWeb";

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

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


sub saveTopicWithMissingAttachment {
	my $this = shift;
	my $topic = shift;
	my $file = 'bogusAttachment.txt';
	
	$this->assert($session->{store}->topicExists($testWeb, $topic));
	
    my ($text, $meta) = $session->{store}->readTopic( 
    				$session->{user}, $testWeb, $topic );
	
	$meta->putKeyed( 'FILEATTACHMENT',
                       {
                             name    => $file,
                             version => '',
                             path    => $file,
                             size    => 2000000,
                             date    => 2000000, 
                             user    => "TWikiContributor",
                             comment => "I am a figment of TWiki's imagination",
                             attr    => ''
                        }
                       );
	$twiki->{store}->saveTopic(
					 $session->{user}, $testWeb, $topic, $text, $meta );
}

sub sneakAttachmentsAddedToTopic {
	my $this = shift;
	my ($topic) = @_;
    my $dir = $TWiki::cfg{PubDir};
    $dir = "$dir/$testweb/$topic";
 
    my $attachment = "afile.txt";
    open( FILE, ">$dir/$attachment" );
    print FILE "Test attachment\n";
    close(FILE); 
    
    my $hiddenAttachment = "_afile.txt";
    open( FILE, ">$dir/$hiddenAttachment" );
    print FILE "Test hidden attachment\n";
    close(FILE); 
    
    mkdir $dir.'/_hiddenDirectoryForPlugins';    
}

sub test_no_autoattach {


}

sub test_autoattach {
	my $this = shift; 
	my $topic = "UnitTest1";	
	$this->verify_normal_attachment($topic);
    $this->saveTopicWithMissingAttachment($topic);
    $this->sneakAttachmentsAddedToTopic($topic);
   
    my ($readMeta, $readText) = $session->{store}->readTopic($session->{user}, $testWeb, $topic);
    my @attachments = $meta->find( 'FILEATTACHMENT' );
    
    foreach $attachment (@attachments) {
    	print "Attachment found: ".$attachment."\n";
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
                                { file => "/tmp/$attachment" } );

    # Check revision number
    my $rev = $session->{store}->getRevisionNumber($testweb, $topic, $attachment);
    $this->assert_num_equals(1,$rev);

    # Save again and check version number goes up by 1
    open( FILE, ">/tmp/$attachment" );
    print FILE "Test attachment\nAnd a second line";
    close(FILE);

    $session->{store}->saveAttachment( $testweb, $topic, $attachment, $user,
                                  { file => "/tmp/$attachment" } );
    # Check revision number
    $rev = $session->{store}->getRevisionNumber( $testweb, $topic, $attachment );
    $this->assert_num_equals(2, $rev);
}
