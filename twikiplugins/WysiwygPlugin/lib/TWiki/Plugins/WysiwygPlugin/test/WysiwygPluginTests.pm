use strict;

# tests for the two translators, TML to HTML and HTML to TML, that
# support editing using WYSIWYG HTML editors. The tests are designed
# so that the round trip can be verified in as many cases as possible.
# Readers are invited to add more testcases.

package WysiwygPluginTests;

use base qw(Test::Unit::TestCase);

BEGIN {
    unshift(@INC,'../../../..');
    unshift(@INC,'/home/twiki/cairo/lib');
}

use TWiki;
use TWiki::Plugins::WysiwygPlugin;

use Carp;
$SIG{__DIE__} = sub { Carp::confess $_[0] };

sub new {
    my $self = shift()->SUPER::new(@_);
    return $self;
}

sub test_one {
}


1;
