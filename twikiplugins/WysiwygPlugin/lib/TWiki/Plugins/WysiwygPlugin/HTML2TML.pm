# Copyright (C) 2005 ILOG http://www.ilog.fr
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of the TWiki distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package TWiki::Plugins::WysiwygPlugin::HTML2TML;

Convertor for translating HTML into TML (TWiki Meta Language)

The conversion is done by parsing the HTML and generating a parse
tree, and then converting that parse treeinto TML.

The class is a subclass of HTML::Parser, run in XML mode, so it
should be tolerant to many syntax errors, and will also handle
XHTML syntax.

The translator tries hard to make good use of newlines in the
HTML, in order to maintain text level formating that isn't
reflected in the HTML. So the parser retains newlines and
spaces, rather than throwing them away, and uses various
heuristics to determine which to keep when generating
the final TML.

=cut

package TWiki::Plugins::WysiwygPlugin::HTML2TML;
use base 'HTML::Parser';

use strict;

require Encode;
require HTML::Parser;
require HTML::Entities;

require TWiki::Plugins::WysiwygPlugin::HTML2TML::Node;
require TWiki::Plugins::WysiwygPlugin::HTML2TML::Leaf;

# Entities that we want to convert back to characters, rather
# than leaving them as HTML entities.
our @safeEntities = qw(
    euro   iexcl  cent   pound  curren yen    brvbar sect
    uml    copy   ordf   laquo  not    shy    reg    macr
    deg    plusmn sup2   sup3   acute  micro  para   middot
    cedil  sup1   ordm   raquo  frac14 frac12 frac34 iquest
    Agrave Aacute Acirc  Atilde Auml   Aring  AElig  Ccedil
    Egrave Eacute Ecirc  Euml   Igrave Iacute Icirc  Iuml
    ETH    Ntilde Ograve Oacute Ocirc  Otilde Ouml   times
    Oslash Ugrave Uacute Ucirc  Uuml   Yacute THORN  szlig
    agrave aacute acirc  atilde auml   aring  aelig  ccedil
    egrave eacute ecirc  uml    igrave iacute icirc  iuml
    eth    ntilde ograve oacute ocirc  otilde ouml   divide
    oslash ugrave uacute ucirc  uuml   yacute thorn  yuml
);

our $safe_entities;

# Convert the safe entities values to characters in the site charset.
sub _prepSafeEntities {
    return if $safe_entities;
    my $encoding = Encode::resolve_alias(
        $TWiki::cfg{Site}{CharSet} || 'iso-8859-15');
    foreach my $entity (@safeEntities) {
        $safe_entities->{$entity} =
          Encode::encode(
              $encoding,
              HTML::Entities::decode_entities("&$entity;"));
    }
    # Special handling for euro symbol. The unicode
    # entity is not mapped to the correct iso-18859-15
    # codepoint by Encode::encode
    if ($encoding =~ /iso-?8859-?15/i) {
        $safe_entities->{euro} = chr(128);
    }
}

=pod

---++ ClassMethod new()

Constructs a new HTML to TML convertor.

You *must* provide parseWikiUrl and convertImage if you want URLs
translated back to wikinames. See WysiwygPlugin.pm for an example
of how to call it.

=cut

sub new {
    my( $class ) = @_;

    my $this = new HTML::Parser( start_h => [\&_openTag, 'self,tagname,attr' ],
                                 end_h => [\&_closeTag, 'self,tagname'],
                                 declaration_h => [\&_ignore, 'self'],
                                 default_h => [\&_text, 'self,text'],
                                 comment_h => [\&_comment, 'self,text'] );

    $this = bless( $this, $class );

    $this->xml_mode( 1 );
    if ($this->can('empty_element_tags')) {
        # protected because not there in some HTML::Parser versions
        $this->empty_element_tags( 1 );
    };
    $this->unbroken_text( 1 );

    return $this;
}

sub _resetStack {
    my $this = shift;

    $this->{stackTop} =
      new TWiki::Plugins::WysiwygPlugin::HTML2TML::Node( $this->{opts}, '' );
    $this->{stack} = ();
}

=pod

---++ ObjectMethod convert( $html ) -> $tml

Convert a block of HTML text into TML.

=cut

sub convert {
    my( $this, $text, $options ) = @_;

    $this->{opts} = $options;

    my $opts = 0;
    $opts = $WC::VERY_CLEAN
      if ( $options->{very_clean} );

    # If the site charset is UTF8, then there may be wide chars in the data
    # (though it's not clear why CGI doesn't decode them). Anyway, if there
    # are undecoded octets, the HTML parser will barf, so we have to decode
    # them.
    if( $TWiki::cfg{Site}{CharSet} =~ /^utf-?8$/i ) {
        $text = Encode::decode_utf8( $text );
    }

    # get rid of nasties
    $text =~ s/\r//g;
    $this->_resetStack();

    $this->parse( $text );
    $this->eof();
    #print STDERR "Finished\n";
    $this->_apply( undef );
    $text = $this->{stackTop}->rootGenerate( $opts );

    # Encode utf8 as octets to stop TWiki from barfing
    # with Wide character in print. We have to do this
    # before converting high-bit entities to characters.
    $text = Encode::encode_utf8( $text );

    # Convert entities that represent "safe" high-bit characters
    # to byte characters if we are using an 8859 charset.
    _prepSafeEntities();
    HTML::Entities::_decode_entities($text, $safe_entities);

    return $text;
}

# Autoclose tags without waiting for a /tag
my %autoClose = map { $_ => 1 } qw( area base basefont br col embed frame hr input link meta param );

# Support auto-close of the tags that are most typically incorrectly
# nested. Autoclose triggers when a second tag of the same type is
# seen without the first tag being closed.
my %closeOnRepeat = map { $_ => 1 } qw( li td th tr );

sub _openTag {
    my( $this, $tag, $attrs ) = @_;

    $tag = lc($tag);

    if ($closeOnRepeat{$tag} &&
          $this->{stackTop} &&
            $this->{stackTop}->{tag} eq $tag) {
        #print STDERR "Close on repeat $tag\n";
        $this->_apply($tag);
    }

    push( @{$this->{stack}}, $this->{stackTop} ) if $this->{stackTop};
    $this->{stackTop} =
      new TWiki::Plugins::WysiwygPlugin::HTML2TML::Node(
          $this->{opts}, $tag, $attrs );

    if ($autoClose{$tag}) {
        #print STDERR "Autoclose $tag\n";
        $this->_apply($tag);
    }
}

sub _closeTag {
    my( $this, $tag ) = @_;

    $tag = lc($tag);

    while ($this->{stackTop} &&
             $this->{stackTop}->{tag} ne $tag &&
               $autoClose{$this->{stackTop}->{tag}}) {
        #print STDERR "Close mismatched $this->{stackTop}->{tag}\n";
        $this->_apply($this->{stackTop}->{tag});
    }
    if ($this->{stackTop} &&
          $this->{stackTop}->{tag} eq $tag) {
        #print STDERR "Closing $tag\n";
        $this->_apply($tag);
    }
}

sub _text {
    my( $this, $text ) = @_;
    my $l = new TWiki::Plugins::WysiwygPlugin::HTML2TML::Leaf( $text );
    $this->{stackTop}->addChild( $l );
}

sub _comment {
    my( $this, $text ) = @_;
    my $l = new TWiki::Plugins::WysiwygPlugin::HTML2TML::Leaf( $text );
    $this->{stackTop}->addChild( $l );
}

sub _ignore {
}

sub _apply {
    my( $this, $tag ) = @_;

    while( $this->{stack} && scalar( @{$this->{stack}} )) {
        my $top = $this->{stackTop};
        #print STDERR "Pop $top->{tag}\n";
        $this->{stackTop} = pop( @{$this->{stack}} );
        die unless $this->{stackTop};
        $this->{stackTop}->addChild( $top );
        last if( $tag && $top->{tag} eq $tag );
    }
}

1;
