package TWiki::Plugins::SafeWikiPlugin::Parser;
use base 'HTML::Parser';

require TWiki::Plugins::SafeWikiPlugin::Node;
require TWiki::Plugins::SafeWikiPlugin::Leaf;

sub new {
    my ($class) = @_;

    my $this = $class->SUPER::new(
        start_h => [\&_openTag, 'self,tagname,attr' ],
        end_h => [\&_closeTag, 'self,tagname'],
        declaration_h => [\&_ignore, 'self'],
        default_h => [\&_text, 'self,text'],
        comment_h => [\&_comment, 'self,text'] );
    $this->empty_element_tags(1);
    if ($TWiki::cfg{Plugins}{SafeWikiPlugin}{CheckPurity}) {
        $this->strict_end(1);
        $this->strict_names(1);
    }
    return $this;
}

sub parseHTML {
    my $this = $_[0];
    $this->_resetStack();
    $this->parse($_[1]);
    $this->eof();
    $this->_apply(undef);
    return $this->{stackTop};
}

sub _resetStack {
    my $this = shift;

    $this->{stackTop} = undef;
    $this->{stack} = ();
}

# Support autoclose of the tags that are most typically incorrectly
# nested. Autoclose triggers when a second tag of the same type is
# seen without the first tag being closed.
my %autoclose = map { ($_, 1) } qw( li td th tr);

sub _openTag {
    my( $this, $tag, $attrs ) = @_;

    if ($autoclose{$tag} &&
          $this->{stackTop} && $this->{stackTop}->{tag} eq $tag) {
        $this->_apply( $tag );
    }

    push( @{$this->{stack}}, $this->{stackTop} ) if $this->{stackTop};
    $this->{stackTop} =
      new TWiki::Plugins::SafeWikiPlugin::Node($tag, $attrs);
}

sub _closeTag {
    my( $this, $tag ) = @_;

    if ($TWiki::cfg{Plugins}{SafeWikiPlugin}{CheckPurity}) {
        if (!$this->{stackTop} || $this->{stackTop}->{tag} ne $tag) {
            die "Unclosed <$this->{stackTop}->{tag} at </$tag\n".
              $this->{stackTop}->stringify();
        }
    }
    $this->_apply( $tag );
}

sub _text {
    my( $this, $text ) = @_;
    return unless length($text);
    my $l = new TWiki::Plugins::SafeWikiPlugin::Leaf($text);
    if (defined $this->{stackTop}) {
        die "Unexpected leaf" if $this->{stackTop}->isLeaf();
        $this->{stackTop}->addChild( $l );
    } else {
        $this->{stackTop} = $l;
    }
}

sub _comment {
    my( $this, $text ) = @_;
}

sub _ignore {
}

sub _apply {
    my( $this, $tag ) = @_;

    while( $this->{stack} && scalar( @{$this->{stack}} )) {
        my $top = $this->{stackTop};
        $this->{stackTop} = pop( @{$this->{stack}} );
        die unless $this->{stackTop};
        die if $this->{stackTop}->isLeaf();
        $this->{stackTop}->addChild( $top );
        last if( $tag && $top->{tag} eq $tag );
    }
}

1;
