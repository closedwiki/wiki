# Copyright (C) 2005 ILOG http://www.ilog.fr
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package TWiki::Plugins::WysiwygPlugin::TML2HTML

Convertor class for translating TML (TWiki Meta Language) into
HTML

The convertor does _not_ use the TWiki rendering, as that is a
lossy conversion, and would make symmetric translation back to TML
an impossibility.

All generated HTML tags are marked with CSS class names for the
TML syntax structure that was used to generate them. The
translation is designed to be as clean as possible (nothing "spurious"
HTML is generated e.g. spaces or newlines). The design goal was
to support round-trip conversion from well-formed TML to HTML and
back to identical HTML. Excepting for certain deprecated syntaxes,
and identical spacing around data in tables, this has been achieved.

=cut

package TWiki::Plugins::WysiwygPlugin::TML2HTML;

use strict;
use TWiki;
use CGI qw( -any );
use HTML::Entities;

my $TT0 = "\a";
my $TT1 = "\b";
my $STARTWW = qr/^|(?<=[\s\(])/m;
my $ENDWW = qr/$|(?=[\s\,\.\;\:\!\?\)])/m;

=pod

---++ ClassMethod new( )

Construct a new TML to HTML convertor.

$getViewUrl is a reference to a method:
   * getViewUrl($web,$topic) -> $url (where $topic may include an anchor)

=cut

sub new {
    my( $class, $getViewUrl ) = @_;
    my $this = {};
    $this->{getViewUrl} = $getViewUrl;
    return bless( $this, $class );
}

=pod

---++ ObjectMethod convert( $tml ) -> $tml

Convert a block of TML text into HTML.

=cut

sub convert {
    my( $this, $content ) = @_;

    return '' unless $content;

    $content =~ s/\\\n/ /g;

    $content =~ s/[$TT0$TT1]/!/go;	

    # Render TML constructs to tagged HTML
    $content = $this->_getRenderedVersion( $content );

    # This should really use a template, but what the heck...
    return $content;
}

sub _liftOut {
    my( $this, $text ) = @_;
    my $n = scalar( @{$this->{refs}} );
    push( @{$this->{refs}}, $text );
    return $TT1.$n.$TT1;
}

sub _dropBack {
    my( $this, $text) = @_;
    # Restore everything that was lifted out
    while( $text =~ s/$TT1([0-9]+)$TT1/$this->{refs}->[$1]/gi ) {
    }
    $this->{refs} = [];
    return $text;
}

# Cribbed wholesale from Render.pm on the DevelopBranch
sub _processTags {
    my( $this, $text ) = @_;

    return '' unless defined( $text );

    my @queue = split( /(%)/, $text );
    my @stack;
    my $stackTop = '';

    while( scalar( @queue )) {
        my $token = shift( @queue );
        if( $token eq '%' ) {
            if( $stackTop =~ /}$/ ) {
                while( scalar( @stack) &&
                        $stackTop !~ /^%([A-Z0-9_:]+){.*}$/o ) {
                    my $top = $stackTop;
                    $stackTop = pop( @stack ) . $top;
                }
            }
            if( $stackTop =~ m/^%([A-Z0-9_:]+)(?:({.*}))?$/o ) {
                my( $tag, $args ) = ( $1, $2 || '' );
                $stackTop = pop( @stack ).
                  CGI::span({class => 'TMLvariable'}, $tag.$args);
            } else {
                push( @stack, $stackTop );
                $stackTop = '%'; # push a new context
            }
        } else {
            $stackTop .= $token;
        }
    }

    # Run out of input. Gather up everything in the stack.
    while ( scalar( @stack )) {
        my $expr = $stackTop;
        $stackTop = pop( @stack );
        $stackTop .= $expr;
    }

    return $stackTop;
}

sub _makeLink {
    my( $this, $url, $text ) = @_;
    $url = $this->_liftOut($url);
    $text ||= $url;
    return CGI::a( { href => $url }, $text );
}

sub _makeWikiWord {
    my( $this, $web, $topic ) = @_;
    my $url = &{$this->{getViewUrl}}( $web, $topic );
    return $this->_makeLink( $url, $topic );
}

sub _makeSquab {
    my( $this, $url, $text ) = @_;
    unless( $url =~ /^$TWiki::regex{linkProtocolPattern}/ ||
          $url =~ /[^\w\s]/ ) {
        $text ||= $url;
        my($web,$topic);
        if( $url =~ /^(?:(\w+)\.)?(\w+)$/ ) {
            ($web,$topic) = ($1,$2);
        } else {
            $web = '';
            $topic = $url;
            $topic =~ s/(^|\W)(\w)/uc($2)/ge
        }
        $url = &{$this->{getViewUrl}}( $web, $topic );
    }
    return $this->_makeLink($url, $text);
}

# Lifted straight out of DevelopBranch Render.pm
sub _getRenderedVersion {
    my( $this, $text, $refs ) = @_;

    return '' unless $text;  # nothing to do

    @{$this->{LIST}} = ();
    $this->{refs} = [];

    # Initial cleanup
    $text =~ s/\r//g;

    my $removed = {}; # Map of placeholders to tag parameters and text
    $text = _takeOutBlocks( $text, 'verbatim', $removed );

    # Remove PRE to prevent TML interpretation of text inside it
    $text = _takeOutBlocks( $text, 'pre', $removed );

    $text =~ s/\\\n//gs;  # Join lines ending in '\'

    # Change ' !AnyWord' to ' <nop>AnyWord',
    $text =~ s/$STARTWW!(?=[\w\*\=])/<nop>/gm;
    # and !%XXX to %<nop>XXX
    $text =~ s/$STARTWW!%(?=[A-Z]+({|%))/%<nop>/gm;

    # Blockquoted email (indented with '> ')
    # Could be used to provide different colours for different numbers of '>'
    $text =~ s/^>(.*?)$/'&gt;'.CGI::cite( { class => 'TMLcite' }, $1 ).CGI::br()/gem;

    # locate isolated < and > and translate to entities
    # Protect isolated <!-- and -->
    $text =~ s/<!--/{$TT0!--/g;
    $text =~ s/-->/--}$TT0/g;
    # SMELL: this next fragment is a frightful hack, to handle the
    # case where simple HTML tags (i.e. without values) are embedded
    # in the values provided to other tags. The only way to do this
    # correctly (i.e. handle HTML tags with values as well) is to
    # parse the HTML (bleagh!)
    $text =~ s/<(\/[A-Za-z]+)>/{$TT0$1}$TT0/g;
    $text =~ s/<([A-Za-z]+(\s+\/)?)>/{$TT0$1}$TT0/g;
    $text =~ s/<(\S.*?)>/{$TT0$1}$TT0/g;
    # entitify lone < and >, praying that we haven't screwed up :-(
    $text =~ s/</&lt\;/g;
    $text =~ s/>/&gt\;/g;
    $text =~ s/{$TT0/</go;
    $text =~ s/}$TT0/>/go;

    # standard URI
    my $x;
    $text =~ s/(?:^|(?<=[-*\s(]))($TWiki::regex{linkProtocolPattern}:([^\s<>"]+[^\s*.,!?;:)<]))/$this->_makeLink($1,$1)/geo;

    # other entities
    $text =~ s/&(\w+);/$TT0$1;/g;      # "&abc;"
    $text =~ s/&(#[0-9]+);/$TT0$1;/g;  # "&#123;"
    #$text =~ s/&/&amp;/g;                         # escape standalone "&"
    $text =~ s/$TT0(#[0-9]+;)/&$1/go;
    $text =~ s/$TT0(\w+;)/&$1/go;

    # Headings
    # '----+++++++' rule
    $text =~ s/$TWiki::regex{headerPatternDa}/_makeHeading($2,length($1))/geom;

    # Horizontal rule
    my $hr = CGI::hr({class => 'TMLhr'});
    $text =~ s/^---+/$hr/gm;

    # Now we really _do_ need a line loop, to process TML
    # line-oriented stuff.
    my $isList = 0;		# True when within a list
    my $insideTABLE = 0;
    my @result = ();
    foreach my $line ( split( /\n/, $text )) {
        # Table: | cell | cell |
        # allow trailing white space after the last |
        if( $line =~ m/^(\s*)\|.*\|\s*$/ ) {
            $line =~ s/^(\s*)\|(.*)/_emitTR($1,$2,$insideTABLE)/e;
            $insideTABLE = 1;
        } elsif( $insideTABLE ) {
            push( @result, '</table>' );
            $insideTABLE = 0;
        }

        # Lists and paragraphs
        if ( $line =~ s/^\s*$/<p \/>/o ) {
            $isList = 0;
        }
        elsif ( $line =~ m/^(\S+?)/o ) {
            $isList = 0;
        }
        elsif ( $line =~ m/^(\t|   )+\S/ ) {
            if ( $line =~ s/^((\t|   )+)\$\s(([^:]+|:[^\s]+)+?):\s/<dt> $3 <\/dt><dd> /o ) {
                # Definition list
                $this->_addListItem( \@result, 'dl', 'dd', $1, '' );
                $isList = 1;
            }
            elsif ( $line =~ s/^((\t|   )+)(\S+?):\s/<dt> $3<\/dt><dd> /o ) {
                # Definition list
                $this->_addListItem( \@result, 'dl', 'dd', $1, '' );
                $isList = 1;
            }
            elsif ( $line =~ s/^((\t|   )+)\* /<li> /o ) {
                # Unnumbered list
                $this->_addListItem( \@result, 'ul', 'li', $1, '' );
                $isList = 1;
            }
            elsif ( $line =~ m/^((\t|   )+)([1AaIi]\.|\d+\.?) ?/ ) {
                # Numbered list
                my $ot = $3;
                $ot =~ s/^(.).*/$1/;
                if( $ot !~ /^\d$/ ) {
                    $ot = ' type="'.$ot.'"';
                } else {
                    $ot = '';
                }
                $line =~ s/^((\t|   )+)([1AaIi]\.|\d+\.?) ?/<li$ot> /;
                $this->_addListItem( \@result, 'ol', 'li', $1, $ot );
                $isList = 1;
            }
        } else {
            $isList = 0;
        }

        # Finish the list
        if( ! $isList ) {
            $this->_addListItem( \@result, '', '', '' );
            $isList = 0;
        }

        push( @result, $line );
    }

    if( $insideTABLE ) {
        push( @result, '</table>' );
    }
    $this->_addListItem( \@result, '', '', '' );

    $text = join("\n", @result );

    $text =~ s/${STARTWW}==([^\s]+?|[^\s].*?[^\s])==$ENDWW/CGI::strong(CGI::code($1))/gem;
    $text =~ s/${STARTWW}__([^\s]+?|[^\s].*?[^\s])__$ENDWW/CGI::strong(CGI::em($1))/gem;
    $text =~ s/${STARTWW}\*([^\s]+?|[^\s].*?[^\s])\*$ENDWW/CGI::strong($1)/gem;
    $text =~ s/${STARTWW}\_([^\s]+?|[^\s].*?[^\s])\_$ENDWW/CGI::em($1)/gem;
    $text =~ s/${STARTWW}\=([^\s]+?|[^\s].*?[^\s])\=$ENDWW/CGI::code($1)/gem;

    # Mailto
    # Email addresses must always be 7-bit, even within I18N sites

    # [[mailto:string display text]]
    $text =~ s/\[\[(mailto:\S+?)\s+(.+?)\]\]/$this->_makeLink($1,$2)/ge;

    # Inline mailto:foo@example.com ('mailto:' part optional)
    $text =~ s/$STARTWW((?:mailto:)?[a-zA-Z0-9\-\_\.\+]+\@[a-zA-Z0-9\-\_\.]+\.[a-zA-Z0-9\-\_]+)$ENDWW/$this->_makeLink($1,$1)/gem;

    # Handle [[][] and [[]] links

    # Escape rendering: Change ' ![[...' to ' [<nop>[...', for final unrendered ' [[...' output
    $text =~ s/(^|\s)\!\[\[/$1\[<nop>\[/gm;

    # We _not_ support [[http://link text]] syntax

    # Spaced-out Wiki words with alternative link text
    # i.e. [[$1][$3]]
    $text =~ s/(?<!!)\[\[([^\]]*)\](?:\[([^\]]+)\])?\]/$this->_makeSquab($1,$2)/ge;

    # Handle WikiWords
    $text = _takeOutBlocks( $text, 'noautolink', $removed );
    $text =~ s/$STARTWW(?:($TWiki::regex{webNameRegex})\.)?($TWiki::regex{wikiWordRegex}($TWiki::regex{anchorRegex})?)$ENDWW/$this->_makeWikiWord($1,$2)/geom;

    foreach my $placeholder ( keys %$removed ) {
        my $pm = $removed->{$placeholder}{params}->{class};
        if( $placeholder =~ /^noautolink/i ) {
            if( $pm ) {
                $pm = join(' ', ( split( /\s+/, $pm ), 'TMLnoautolink' ));
            } else {
                $pm = 'TMLnoautolink';
            }
            $removed->{$placeholder}{params}->{class} = $pm;
        } elsif( $placeholder =~ /^verbatim/i ) {
            if( $pm ) {
                $pm = join(' ', ( split( /\s+/, $pm ), 'TMLverbatim' ));
            } else {
                $pm = 'TMLverbatim';
            }
            $removed->{$placeholder}{params}->{class} = $pm;
        }
    }

    _putBackBlocks( $text, $removed, 'noautolink', 'div' );

    _putBackBlocks( $text, $removed, 'pre' );

    $text = $this->_dropBack( $text );

    # protect HTML parameters by pulling them out
    $text =~ s/(<[a-z]+ )([^>]+)>/$1.$this->_liftOut($2).'>'/gei;

    # Convert TWiki tags to spans outside parameters
    $text = $this->_processTags( $text );

    $text = $this->_dropBack( $text );

    # convert embedded <nop>'s to %NOP%
    $text =~ s/<nop>/CGI::span({class => 'TMLnop'}, 'X')/ge;

    # replace verbatim with pre in the final output
    _putBackBlocks( $text, $removed, 'verbatim', 'pre',
                    \&_encodeEntities );

    # protect % from being used in further variable expansions
    $text =~ s/%/&#37;/g;

    return $text;
}

sub _encodeEntities {
    my $text = shift;

    return HTML::Entities::encode_entities( $text );
}

# Make the html for a heading
sub _makeHeading {
    my( $theHeading, $theLevel ) = @_;
    my $attrs = { class => 'TML' };
    if( $theHeading =~ s/$TWiki::regex{headerPatternNoTOC}//o ) {
        $attrs->{notoc} = 1;
    }
    my $fn = 'CGI::h'.$theLevel;
    no strict 'refs';
    return &$fn($attrs, " $theHeading ");
    use strict 'refs';
}

# Lifted straight out of DevelopBranch Render.pm
sub _takeOutBlocks {
    my( $intext, $tag, $map ) = @_;
    die unless $tag;
    return '' unless $intext;
    return $intext unless ( $intext =~ m/<$tag\b/ );

    my $open = qr/^(.*)<$tag\b([^>]*)>(.*)$/i;
    my $close = qr/^(.*)<\/$tag>(.*)$/i;
    my $out = '';
    my $depth = 0;
    my $scoop;
    my $tagParams;
    my $n = 0;

    foreach my $line ( split/\r?\n/, $intext ) {
        if ( $line =~ m/$open/ ) {
            unless ( $depth++ ) {
                $out .= $1;
                $tagParams = $2;
                $scoop = $3;
                next;
            }
        }
        if ( $depth && $line =~ m/$close/ ) {
            $scoop .= $1;
            my $rest = $2;
            unless ( --$depth ) {
                my $placeholder = $tag.$n;
                $map->{$placeholder}{params} = _parseParams( $tagParams );
                $map->{$placeholder}{text} = $scoop;

                $line = '<!--'.$TT0.$placeholder.
                  $TT0.'-->'.$rest;
                $n++;
            }
        }
        if ( $depth ) {
            $scoop .= $line."\n";
        } else {
            $out .= $line."\n";
        }
    }

    if ( $depth ) {
        # This would generate matching close tags
        # while ( $depth-- ) {
        #     $scoop .= "</$tag>\n";
        # }
        my $placeholder = $tag.$n;
        $map->{$placeholder}{params} = _parseParams( $tagParams );
        $map->{$placeholder}{text} = $scoop;
        $out .= '<!--'.$TT0.$placeholder.$TT0."-->";
    }

    return $out;
}

# Lifted straight out of DevelopBranch Render.pm
sub _putBackBlocks {
    my( $text, $map, $tag, $newtag, $callback ) = @_;
    my $fn = 'CGI::'.($newtag || $tag);
    $newtag ||= $tag;
    my @k = keys %$map;
    foreach my $placeholder ( @k ) {
        if( $placeholder =~ /^$tag\d+$/ ) {
            my $params = $map->{$placeholder}{params};
            my $val = $map->{$placeholder}{text};
            $val = &$callback( $val ) if ( defined( $callback ));
            no strict 'refs';
            $_[0] =~ s/<!--$TT0$placeholder$TT0-->/&$fn($params,$val)/e;
            use strict 'refs';
            delete( $map->{$placeholder} );
        }
    }
}

sub _parseParams {
    my $p = shift;
    my $params = {};
    while( $p =~ s/^\s*(\w+)=(".*?"|'.*?')// ) {
        my $name = $1;
        my $val = $2;
        $val =~ s/['"](.*)['"]/$1/;
        $params->{$name} = $val;
    }
    return $params;
}

# Lifted straight out of DevelopBranch Render.pm
sub _addListItem {
    my( $this, $result, $theType, $theElement, $theIndent, $theOlType ) = @_;

    $theIndent =~ s/   /\t/g;
    my $depth = length( $theIndent );

    my $size = scalar( @{$this->{LIST}} );
    if( $size < $depth ) {
        my $firstTime = 1;
        while( $size < $depth ) {
            push( @{$this->{LIST}}, { type=>$theType, element=>$theElement } );
            push( @$result, "<$theElement>" ) unless( $firstTime );
            push( @$result, "<$theType>" );
            $firstTime = 0;
            $size++;
        }
    } else {
        while( $size > $depth ) {
            my $tags = pop( @{$this->{LIST}} );
            push( @$result, "</$tags->{element}>" );
            push( @$result, "</$tags->{type}>" );
            $size--;
        }
        if ($size) {
            push( @$result, "</$this->{LIST}->[$size-1]->{element}>" );
        }
    }

    if ( $size ) {
        my $oldt = $this->{LIST}->[$size-1];
        if( $oldt->{type} ne $theType ) {
            push( @$result, "</$oldt->{type}>\n<$theType>" );
            pop( @{$this->{LIST}} );
            push( @{$this->{LIST}}, { type=>$theType, element=>$theElement } );
        }
    }
}

# Lifted straight out of DevelopBranch Render.pm
sub _emitTR {
    my ( $thePre, $theRow, $insideTABLE ) = @_;

    unless( $insideTABLE ) {
        $thePre .= CGI::start_table({ cellspacing => 1,
                                      cellpadding => 0,
                                      border => 1 });
    }

    $theRow =~ s/\t/   /g;  # change tabs to space
    $theRow =~ s/\s*$//;    # remove trailing spaces
    $theRow =~ s/(\|\|+)/$TT0.length($1).'|'/ge;  # calc COLSPAN
    my $cells = '';
    foreach( split( /\|/, $theRow ) ) {
        my $attr = {};

        # Avoid matching single columns
        if ( s/$TT0([0-9]+)//o ) {
            $attr->{colspan} = $1;
        }
        s/^\s+$/ &nbsp; /;
        my( $left, $right ) = ( 0, 0 );
        if( /^(\s*).*?(\s*)$/ ) {
            $left = length( $1 );
            $right = length( $2 );
        }
        if( $left > $right ) {
            $attr->{align} = 'right';
        } elsif( $left < $right ) {
            $attr->{align} = 'left';
        } elsif( $left > 1 ) {
            $attr->{align} = 'center';
        }
        if( /^\s*\*(.*)\*\s*$/ ) {
            $cells .= CGI::th( $attr, $1 );
        } else {
            $cells .= CGI::td( $attr, $_ );
        }
    }
    return $thePre.CGI::Tr( $cells );
}

1;
