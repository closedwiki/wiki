=pod

---+ package TWiki::Plugins::WysiwygPlugin::TML2HTML::Leaf

Object for a leaf node in an HTML parse tree

A leaf node is text in the document.

=cut

package TWiki::Plugins::WysiwygPlugin::HTML2TML::Leaf;

use strict;

sub new {
    my( $class, $text ) = @_;

    my $this = {};

    $this->{tag} = '';
    $this->{text} = $text;
    return bless( $this, $class );
}

sub _generate {
    my $this = shift;
    my $t = $this->{text};
    $t =~ s/\n/$TWiki::Plugins::WysiwygPlugin::HTML2TML::Node::CHECKn/g;
    return (0, $t);
}

sub addChild {
    die "Illegal";
}

sub stringify {
    my $this = shift;
    return $this->{text};
}

1;
