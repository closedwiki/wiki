use strict;

package HierarchicalWebsTests;
use base qw( TWikiTestCase );

use TWiki;
use Error qw( :try );

my $twiki;
my $topicquery;

my $webSubWeb = 'TestCases/Item0';
my $testTopic = 'Ads';

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $topicquery = new CGI();
#    $topicquery->path_info("/$webSubWeb/$testTopic");
    try {
        $twiki = new TWiki('AdminUser');
        my $twikiUserObject = $twiki->{user};

	$twiki->{store}->createWeb( $twikiUserObject, $webSubWeb );
	$this->assert( $twiki->{store}->webExists( $webSubWeb ) );

    } catch TWiki::AccessControlException with {
        my $e = shift;
        die "???" unless $e;
        $this->assert(0,$e->stringify());
    } catch Error::Simple with {
        $this->assert(0,shift->stringify()||'');
    };
}

sub tear_down {
    my $this = shift;

    $twiki->{store}->removeWeb( $twiki->{user}, $webSubWeb );

    $this->SUPER::tear_down();
}

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

################################################################################

sub test_createSubWeb {
}

sub test_createSubWebTopic {
    my $this = shift;
    $twiki = new TWiki();
    my $twikiUserObject = $twiki->{user};

    $twiki->{store}->saveTopic(
			       $twiki->{user}, $webSubWeb, $testTopic,
			       "page stuff\n"
			       );
    $this->assert( $twiki->{store}->topicExists( $webSubWeb, $testTopic ) );
}

1;
