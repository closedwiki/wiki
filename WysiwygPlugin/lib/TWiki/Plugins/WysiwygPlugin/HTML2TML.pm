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

use strict;

use TWiki::Plugins::WysiwygPlugin::HTML2TML::Node;
use TWiki::Plugins::WysiwygPlugin::HTML2TML::Leaf;
use HTML::Parser;

@TWiki::Plugins::WysiwygPlugin::HTML2TML::ISA = ( 'HTML::Parser' );

=pod

---++ ClassMethod new()

Constructs a new HTML to TML convertor.

=cut

sub new {
    my( $class, $options ) = @_;

    my $this = new HTML::Parser( start_h => [\&_openTag, 'self,tagname,attr' ],
                                 end_h => [\&_closeTag, 'self,tagname'],
                                 declaration_h => [\&_ignore, 'self'],
                                 default_h => [\&_text, 'self,text']);

    $this->{stackTop} =
      new TWiki::Plugins::WysiwygPlugin::HTML2TML::Node( $this, '' );
    $this->{stack} = ();
    $this->xml_mode( 1 );
    $this->unbroken_text( 1 );

    map { $this->{$_} = $options->{$_} } keys %$options;

    return bless( $this, $class );
}

=pod

---++ ObjectMethod convert( $html ) -> $tml

Convert a block of HTML text into TML.

=cut

sub convert {
    my( $this, $text ) = @_;

    # SMELL: ought to convert to site charset

    # get rid of nasties
    $text =~ s/\r//g;
    $text =~ s/\t/ /g;

    $this->parse( $text );
    $this->eof();
    $this->_apply( undef );
    return $this->{stackTop}->rootGenerate();
}

sub _openTag {
    my( $this, $tag, $attrs ) = @_;
    push( @{$this->{stack}}, $this->{stackTop} ) if $this->{stackTop};
    $this->{stackTop} =
      new TWiki::Plugins::WysiwygPlugin::HTML2TML::Node( $this, $tag, $attrs );
}

sub _closeTag {
    my( $this, $tag ) = @_;

    $this->_apply( $tag );
}

sub _text {
    my( $this, $text ) = @_;

    # special hack for handling %, which is pre-escaped to avoid
    # expansion as a variable during TML -> HTML conversion
    $text =~ s/&#37;/%/g;

    my $l = new TWiki::Plugins::WysiwygPlugin::HTML2TML::Leaf( $text );
    $this->{stackTop}->addChild( $l );
}

sub _ignore {
}

sub _apply {
    my( $this, $tag ) = @_;

    while( $this->{stack} && scalar( @{$this->{stack}} )) {
        my $top = $this->{stackTop};
        $this->{stackTop} = pop( @{$this->{stack}} );
        die unless $this->{stackTop};
        $this->{stackTop}->addChild( $top );
        last if( $tag && $top->{tag} eq $tag );
    }
}

=pod

---++ convertUtf8toSiteCharset( $text )
Based on parts of the TWiki KupuEditorAddOn add-on
Copyright (C) 2004 Damien Mandrioli and Romain Raugi

Generic encoding subroutine. Require TWiki init.

=cut

sub convertUtf8toSiteCharset {
    my ( $text, $siteCharset ) = @_;
    my $charEncoding;

    # Convert into ISO-8859-1 if it is the site charset
    if ( $siteCharset =~ /^iso-?8859-?1$/i ) {
        # ISO-8859-1 maps onto first 256 codepoints of Unicode
        # (conversion from 'perldoc perluniintro')
        $text =~ s/ ([\xC2\xC3]) ([\x80-\xBF]) / chr( ord($1) << 6 & 0xC0 | ord($2)& 0x3F ) /egx;
        return $text;
    } elsif ( $siteCharset eq 'utf-8' ) {
        # Convert into internal Unicode characters if on Perl 5.8 or higher.
        if( $] >= 5.008 ) {
            require Encode;                   # Perl 5.8 or higher only
            $text = Encode::decode('utf8', $text);    # 'decode' into UTF-8
        } else {
            die 'UTF-8 not supported on Perl $] - use Perl 5.8 or higher';
        }
    } else {
        # Convert from UTF-8 into some other site charset
        # Use conversion modules depending on Perl version
        if( $] >= 5.008 ) {
            require Encode;                   # Perl 5.8 or higher only
            import Encode qw(:fallbacks);
            # Map $siteCharset into real encoding name
            $charEncoding = Encode::resolve_alias( $siteCharset );
            if( not $charEncoding ) {
                die 'Conversion to '.$siteCharset.
                  ' not supported, or name not recognised';
            } else {
                # Convert text using Encode:
                # - first, convert from UTF8 bytes into internal (UTF-8)
                # characters
                $text = Encode::decode('utf8', $text);
                # - then convert into site charset from internal UTF-8,
                # inserting \x{NNNN} for characters that can't be converted
                $text = Encode::encode( $charEncoding, $text, &FB_PERLQQ );
                ##writeDebug 'Encode result is $fullTopicName';
            }
        } else {
            require Unicode::MapUTF8; # Pre-5.8 Perl versions
            # SMELL: cairo specific
            $charEncoding = $siteCharset;
            if( not Unicode::MapUTF8::utf8_supported_charset($charEncoding) ) {
                die 'Conversion to '.$siteCharset.
                  ' not supported, or name not recognised';

            } else {
                # Convert text
                $text = Unicode::MapUTF8::from_utf8
                  ({ -string => $text, -charset => $charEncoding });
                # FIXME: Check for failed conversion?
            }
        }
    }
    return $text;
}

1;
