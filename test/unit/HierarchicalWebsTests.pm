use strict;

package HierarchicalWebsTests;
use base qw( TWikiTestCase );

use TWiki;
use Error qw( :try );

#================================================================================

my $twiki;
my $topicquery;

my $webSubWeb = 'TestCases/HierarchicalWebs';
my $testTopic = 'Topic';

#================================================================================

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

#================================================================================
#================================================================================

sub test_createSubWeb {
    my $this = shift;
    $twiki = new TWiki();
    my $twikiUserObject = $twiki->{user};

    { my $webTest = 'Item0';
    $twiki->{store}->createWeb( $twikiUserObject, "$webSubWeb/$webTest" );
    $this->assert( $twiki->{store}->webExists( "$webSubWeb/$webTest" ) );
    }

    { my $webTest = 'Item0_';
    $twiki->{store}->createWeb( $twikiUserObject, "$webSubWeb/$webTest" );
    $this->assert( $twiki->{store}->webExists( "$webSubWeb/$webTest" ) );
    }
}

#================================================================================

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

#================================================================================

sub test_include_subweb_non_wikiword_topic {
    my $this = shift;
    $twiki = new TWiki();
    my $twikiUserObject = $twiki->{user};

    my $baseTopic = 'IncludeSubWebNonWikiWordTopic';
    my $includeTopic = 'Topic';
    my $testText = 'TEXT';

    # create the (including) page
    $twiki->{store}->saveTopic( $twiki->{user}, $webSubWeb, $baseTopic, <<__TOPIC__ );
%INCLUDE{ "$webSubWeb/$includeTopic" }%
__TOPIC__
    $this->assert( $twiki->{store}->topicExists( $webSubWeb, $baseTopic ) );

    # create the (included) page
    $twiki->{store}->saveTopic( $twiki->{user}, $webSubWeb, $includeTopic, $testText );
    $this->assert( $twiki->{store}->topicExists( $webSubWeb, $includeTopic ) );

    # verify included page's text
    { my ( undef, $text ) = $twiki->{store}->readTopic( $twikiUserObject, $webSubWeb, $includeTopic );
    $this->assert_matches( qr/$testText\s*$/, $text );
    }

    # base page should evaluate (more or less) to the included page's text
    { my ( undef, $text ) = $twiki->{store}->readTopic( $twikiUserObject, $webSubWeb, $baseTopic );
    $text = $twiki->handleCommonTags( $text, $webSubWeb, $baseTopic );
    $this->assert_matches( qr/$testText\s*$/, $text );
    }
}

#================================================================================

sub test_create_subweb_with_same_name_as_a_topic {
    my $this = shift;
    $twiki = new TWiki();
    my $twikiUserObject = $twiki->{user};

    my $testTopic = 'SubWeb';
    my $testText = 'TOPIC';

    # create the page
    $twiki->{store}->saveTopic( $twiki->{user}, $webSubWeb, $testTopic, $testText );
    $this->assert( $twiki->{store}->topicExists( $webSubWeb, $testTopic ) );

    { my ( undef, $text ) = $twiki->{store}->readTopic( 
	$twikiUserObject, $webSubWeb, $testTopic );
    $this->assert_matches( qr/$testText\s*$/, $text );
    }

    # create the subweb with the same name as the page
    $twiki->{store}->createWeb( $twikiUserObject, "$webSubWeb/$testTopic" );
    $this->assert( $twiki->{store}->webExists( "$webSubWeb/$testTopic" ) );
    
    { my ( undef, $text ) = $twiki->{store}->readTopic( $twikiUserObject, $webSubWeb, $testTopic );
    $this->assert_matches( qr/$testText\s*$/, $text );
    }

#    $twiki->{store}->removePage( $twikiUserObject, 
#    $this->assert( ! $twiki->{store}->topicExists( $webSubWeb, $testTopic ) );

    $twiki->{store}->removeWeb( $twikiUserObject, "$webSubWeb/$testTopic" );
    $this->assert( ! $twiki->{store}->webExists( "$webSubWeb/$testTopic" ) );
}

#================================================================================

sub test_url_parameters {
    my $this = shift;
    $twiki = new TWiki();
    my $twikiUserObject = $twiki->{user};

    my $topicquery = new CGI( { 
	action => 'view',
	topic => "$webSubWeb/$testTopic",
	} );

    $twiki = new TWiki( 'AdminUser', $topicquery );
}

#================================================================================

1;
