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

require TWiki::Plugins::WysiwygPlugin::HTML2TML::Node;
require TWiki::Plugins::WysiwygPlugin::HTML2TML::Leaf;
require HTML::Parser;

# Entities that are safe to convert back to 8-bit characters without
# tripping over Perl's crappy UTF-8 support.
my %safe_entities = (
    iexcl  => 161, cent   => 162, pound  => 163,
    curren => 164, yen    => 165, brvbar => 166, sect   => 167,
    uml    => 168, copy   => 169, ordf   => 170, laquo  => 171,
    not    => 172, shy    => 173, reg    => 174, macr   => 175,
    deg    => 176, plusmn => 177, sup2   => 178, sup3   => 179,
    acute  => 180, micro  => 181, para   => 182, middot => 183,
    cedil  => 184, sup1   => 185, ordm   => 186, raquo  => 187,
    frac14 => 188, frac12 => 189, frac34 => 190, iquest => 191,
    Agrave => 192, Aacute => 193, Acirc  => 194, Atilde => 195,
    Auml   => 196, Aring  => 197, AElig  => 198, Ccedil => 199,
    Egrave => 200, Eacute => 201, Ecirc  => 202, Euml   => 203,
    Igrave => 204, Iacute => 205, Icirc  => 206, Iuml   => 207,
    ETH    => 208, Ntilde => 209, Ograve => 210, Oacute => 211,
    Ocirc  => 212, Otilde => 213, Ouml   => 214, times  => 215,
    Oslash => 216, Ugrave => 217, Uacute => 218, Ucirc  => 219,
    Uuml   => 220, Yacute => 221, THORN  => 222, szlig  => 223,
    agrave => 224, aacute => 225, acirc  => 226, atilde => 227,
    auml   => 228, aring  => 229, aelig  => 230, ccedil => 231,
    egrave => 232, eacute => 233, ecirc  => 234, uml    => 235,
    igrave => 236, iacute => 237, icirc  => 238, iuml   => 239,
    eth    => 240, ntilde => 241, ograve => 242, oacute => 243,
    ocirc  => 244, otilde => 245, ouml   => 246, divide => 247,
    oslash => 248, ugrave => 249, uacute => 250, ucirc  => 251,
    uuml   => 252, yacute => 253, thorn  => 254, yuml   => 255,
);

my $safe_entities_re = join('|', keys %safe_entities);

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

    # Item5138: Convert 8-bit entities back into characters
    $text =~ s/&($safe_entities_re);/chr($safe_entities{$1})/ego;
    $text =~ s/(&#(\d+);)/$2 > 127 && $2 <= 255 ? chr($2) : $1/eg;
    $text =~ s/(&#x([\dA-Fa-f]+);)/(hex($2) > 127 && hex($2)) <= 255 ? chr(hex($2)) : $1/eg;

    # get rid of nasties
    $text =~ s/\r//g;
    $this->_resetStack();
    $this->parse( $text );
    $this->eof();
    #print STDERR "Finished\n";
    $this->_apply( undef );
    return $this->{stackTop}->rootGenerate( $opts );
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
