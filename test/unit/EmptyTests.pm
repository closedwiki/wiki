use strict;

# 

package EmptyTests;
use base qw( TWikiTestCase );

use TWiki;
use Error qw( :try );

#================================================================================

my $twiki;
my $topicquery;

#================================================================================

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $topicquery = new CGI( '' );
    $topicquery->path_info( '/TestCases/WebHome' );
    try {
        $twiki = new TWiki( 'AdminUser' || '' );
        my $twikiUserObject = $twiki->{user};

    } catch TWiki::AccessControlException with {
        my $e = shift;
        die "???" unless $e;
        $this->assert( 0, $e->stringify() );
    } catch Error::Simple with {
        $this->assert( 0, shift->stringify() || '' );
    };
}

sub tear_down {
    my $this = shift;

    $this->SUPER::tear_down();
}

sub new {
    my $self = shift()->SUPER::new( @_ );
    return $self;
}

#================================================================================
#================================================================================

sub test_ {
    my $this = shift;
    $twiki = new TWiki();

    $twiki->
}

#================================================================================

1;
