package TWiki::Plugins::SafeWikiPlugin::Leaf;

sub new {
    my( $class, $text ) = @_;

    my $this = {};

    $this->{text} = $text;

    return bless( $this, $class );
}

sub stringify {
    my( $this ) = @_;
    return $this->{text};
}

sub generate {
    my( $this ) = @_;
    return $this->{text};
}

sub isLeaf {
    return 1;
}

1;
