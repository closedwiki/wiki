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

The design goal was to support round-trip conversion from well-formed
TML to XHTML1.0 and back to identical TML. Notes that some deprecated
TML syntax is not supported.

=cut

package TWiki::Plugins::WysiwygPlugin::TML2HTML;

use strict;
use TWiki;
use CGI qw( -any );

my $TT0 = chr(0);
my $TT1 = chr(1);
my $TT2 = chr(2);

my $STARTWW = qr/^|(?<=[\s\(])/m;
my $ENDWW = qr/$|(?=[\s\,\.\;\:\!\?\)])/m;

=pod

---++ ClassMethod new()

Construct a new TML to HTML convertor.

=cut

sub new {
    my $class = shift;
    my $this = {};
    return bless( $this, $class );
}

=pod

---++ ObjectMethod convert( $tml, \%options ) -> $tml

Convert a block of TML text into HTML.
Options:
   * getViewUrl is a reference to a method:<br>
     getViewUrl($web,$topic) -> $url (where $topic may include an anchor)
   * markVars is true if we are to expand TWiki variables to spans.
     It should be false otherwise (TWiki variables will be left as text).

=cut

sub convert {
    my( $this, $content, $options ) = @_;

    $this->{opts} = $options;

    return '' unless $content;

    $content =~ s/\\\n/ /g;
    $content =~ s/\t/   /g;

    $content =~ s/[$TT0$TT1$TT2]/!/go;	

    # Render TML constructs to tagged HTML
    $content = $this->_getRenderedVersion( $content );

    # Substitute back in protected elements
    $content = $this->_dropBack( $content );

    # This should really use a template, but what the heck...
    return $content;
}

sub _liftOut {
    my( $this, $text, $type, $encoding ) = @_;
    $text = $this->_unLift($text);
    my $n = scalar( @{$this->{refs}} );
    push( @{$this->{refs}},
          { type => $type,
            encoding => $encoding || 'span',
            text => $text } );
    return $TT1.$n.$TT2;
}

sub _unLift {
    my( $this, $text) = @_;
    # Restore everything that was lifted out
    while( $text =~ s#$TT1([0-9]+)$TT2#$this->{refs}->[$1]->{text}#g ) {
    }
    return $text;
}

sub _dropBack {
    my( $this, $text) = @_;
    # Restore everything that was lifted out
    while($text =~ s#$TT1([0-9]+)$TT2#$this->_dropIn($1)#ge) {
    }
    return $text;
}

sub _dropIn {
    my ($this, $n) = @_;
    my $thing = $this->{refs}->[$n];
    return $thing->{text} if $thing->{encoding} eq 'NONE';
    my $method = 'CGI::'.$thing->{encoding};
    my $text = $thing->{text};
    $text = _encodeEntities($text) if
      $thing->{type} eq 'PROTECTED' || $thing->{type} eq 'VERBATIM';
    no strict 'refs';
    return &$method({class => 'WYSIWYG_'.$thing->{type} }, $text);
    use strict 'refs';
}

# Parse and convert twiki variables. If we are not using span markers
# for variables, we have to change the percent signs into entities
# to prevent internal tags being expanded by TWiki during rendering.
# It's assumed that the editor will have the common sense to convert
# them back to characters when editing.
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
                    $stackTop = pop( @stack ) . $stackTop;
                }
            }
            if( $stackTop =~ m/^%([A-Z0-9_:]+)({.*})?$/o ) {
                my $tag = $1 . ( $2 || '' );
                $tag = '%'.$tag.'%';
                $stackTop = pop( @stack ).
                  $this->_liftOut($tag, 'PROTECTED');
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
        $stackTop = pop( @stack ).$stackTop;
    }

    return $stackTop;
}

sub _expandURL {
    my( $this, $url ) = @_;
    return $url unless ( $this->{opts}->{expandVarsInURL} );
    return &{$this->{opts}->{expandVarsInURL}}( $url, $this->{opts} );
}

# Lifted straight out of DevelopBranch Render.pm
sub _getRenderedVersion {
    my( $this, $text, $refs ) = @_;

    return '' unless $text;  # nothing to do

    @{$this->{LIST}} = ();
    $this->{refs} = [];

    # Initial cleanup
    $text =~ s/\r//g;
    $text =~ s/^\n*//s;
    $text =~ s/\n*$//s;

    $this->{removed} = {}; # Map of placeholders to tag parameters and text

    $text = $this->_takeOutBlocks( $text, 'verbatim' );

    $text = $this->_takeOutSets( $text );

    # Remove PRE to prevent TML interpretation of text inside it
    $text = $this->_takeOutBlocks( $text, 'pre' );

    # change !%XXX to %<nop>XXX
    $text =~ s/!%(?=[A-Z][A-Z0-9_]*[{%])/%<nop>/g;

    # Change ' !AnyWord' to ' <nop>AnyWord',
    $text =~ s/$STARTWW!(?=[\w\*\=])/<nop>/gm;

    # Change ' ![[...' to ' [<nop>[...'
    $text =~ s/(^|\s)\!\[\[/$1\[<nop>\[/gm;

    # Protect comments
    $text =~ s/(<!--.*?-->)/$this->_liftOut($1, 'PROTECTED')/ges;

    # Remove TML pseudo-tags so they don't get protected like HTML tags
    # (verbatim and pre have already been handled, above)
    $text =~ s/<(.?(noautolink|nop).*?)>/$TT1($1)$TT1/gi;

    # Handle inline IMG tags specially
    $text =~ s/(<img [^>]*>)/$this->_takeOutIMGTag($1)/gei;

    # protect HTML tags
    $text =~ s/(<\/?[a-z]+(\s[^>]*)?>)/ $this->_liftOut($1, 'PROTECTED') /gei;

    # Replace TML pseudo-tags
    $text =~ s/$TT1\((.*?)\)$TT1/<$1>/go;

    # Convert TWiki tags to spans outside prtected text
    $text = $this->_processTags( $text );

    $text =~ s/\\\n//gs;  # Join lines ending in '\'

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
    $text =~ s/((^|(?<=[-*\s(]))$TWiki::regex{linkProtocolPattern}:[^\s<>"]+[^\s*.,!?;:)<])/$this->_liftOut($1, 'LINK')/geo;

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
        if( $line =~ m/^(\s*\|.*\|\s*)$/ ) {
            if ($isList) {
                $this->_addListItem( \@result, '', '', '' );
                $isList = 0;
            }
            unless( $insideTABLE ) {
                push( @result, CGI::start_table(
                    { border=>1, cellpadding=>0, cellspacing=>1 } ));
            }
            push( @result, _emitTR($1) );
            $insideTABLE = 1;
            next;
        } elsif( $insideTABLE ) {
            push( @result, CGI::end_table() );
            $insideTABLE = 0;
        }

        # Lists and paragraphs
        if ( $line =~ s/^\s*$/<p \/>/ ) {
            $isList = 0;
        }
        elsif ( $line =~ m/^\S/ ) {
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
            elsif ( $line =~ s/^((\t|   )+)\*(\s|$)/<li> /o ) {
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

    $text =~ s(${STARTWW}==([^\s]+?|[^\s].*?[^\s])==$ENDWW)
      (CGI::b(CGI::code($1)))gem;
    $text =~ s(${STARTWW}__([^\s]+?|[^\s].*?[^\s])__$ENDWW)
      (CGI::b(CGI::i($1)))gem;
    $text =~ s(${STARTWW}\*([^\s]+?|[^\s].*?[^\s])\*$ENDWW)
      (CGI::b($1))gem;
    $text =~ s(${STARTWW}\_([^\s]+?|[^\s].*?[^\s])\_$ENDWW)
      (CGI::i($1))gem;
    $text =~ s(${STARTWW}\=([^\s]+?|[^\s].*?[^\s])\=$ENDWW)
      (CGI::code($1))gem;

    # Handle [[][] and [[]] links

    # We _not_ support [[http://link text]] syntax

    # [[][]]
    $text =~ s/(\[\[[^\]]*\](\[[^\]]*\])?\])/$this->_liftOut($1, 'LINK')/ge;

    # Handle WikiWords
    $text = $this->_takeOutBlocks( $text, 'noautolink' );

    $text =~ s/$STARTWW(($TWiki::regex{webNameRegex}\.)?$TWiki::regex{wikiWordRegex}($TWiki::regex{anchorRegex})?)/$this->_liftOut($1, 'LINK')/geom;

    while (my ($placeholder, $val) = each %{$this->{removed}} ) {
        my $pm = $val->{params}->{class};
        if( $placeholder =~ /^noautolink/i ) {
            if( $pm ) {
                $pm = join(' ', ( split( /\s+/, $pm ), 'WYSIWYG_NOAUTOLINK' ));
            } else {
                $pm = 'WYSIWYG_NOAUTOLINK';
            }
            $val->{params}->{class} = $pm;
        } elsif( $placeholder =~ /^verbatim/i ) {
            if( $pm ) {
                $pm = join(' ', ( split( /\s+/, $pm ), 'WYSIWYG_VERBATIM' ));
            } else {
                $pm = 'WYSIWYG_VERBATIM';
            }
            $val->{params}->{class} = $pm;
        }
    }

    $this->_putBackBlocks( $text, 'noautolink', 'div' );

    $this->_putBackBlocks( $text, 'pre' );

    # replace verbatim with pre in the final output
    $this->_putBackBlocks( $text, 'verbatim', 'pre', \&_encodeEntities );

    $text =~ s/(<nop>)/$this->_liftOut($1, 'PROTECTED')/ge;

    return $text;
}

sub _encodeEntities {
    my $text = shift;
    $text =~ s/([\000-\011\013-\037<&>'"\200-\277])/'&#'.ord($1).';'/ges;
    $text =~ s/ /&nbsp;/g;
    $text =~ s/\n/<br \/>/gs;
    return $text;
}

# Make the html for a heading
sub _makeHeading {
    my( $theHeading, $theLevel ) = @_;
    my $class = 'TML';
    if( $theHeading =~ s/$TWiki::regex{headerPatternNoTOC}//o ) {
        $class .= ' notoc';
    }
    my $attrs = { class => $class };
    my $fn = 'CGI::h'.$theLevel;
    no strict 'refs';
    return &$fn($attrs, " $theHeading ");
    use strict 'refs';
}

sub _takeOutIMGTag {
    my ($this, $text) = @_;
    # Expand selected TWiki variables in IMG tags so that images appear in the
    # editor as images
    $text =~ s/(<img [^>]*src=)(["'])(.*?)\2/$1.$2.$this->_expandURL($3).$2/gie;
    return $this->_liftOut($text, '', 'NONE');
}

# Pull out TWiki Set statements, to prevent unwanted munging
sub _takeOutSets {
    my $this = $_[0];
    my $setRegex =
      qr/^((?:\t|   )+\*\s+(?:Set|Local)\s+(?:$TWiki::regex{tagNameRegex})\s*=)(.*)$/o;

    my $lead;
    my $value;
    my @outtext;
    foreach( split( /\r?\n/, $_[1] ) ) {
        if( m/$setRegex/s ) {
            if( defined $lead ) {
                push(@outtext, $lead.$this->_liftOut($value, 'PROTECTED'));
            }
            $lead = $1;
            $value = defined($2) ? $2 : '';
            next;
        }

        if( defined $lead ) {
            if( /^(   |\t)+ *[^\s]/ && !/$TWiki::regex{bulletRegex}/o ) {
                # follow up line, extending value
                $value .= "\n".$_;
                next;
            }
            push(@outtext, $lead.$this->_liftOut($value, 'PROTECTED'));
            undef $lead;
        }
        push(@outtext, $_);
    }
    if( defined $lead ) {
        push(@outtext, $lead.$this->_liftOut($value, 'PROTECTED'));
    }
    return join("\n", @outtext);
}

# Lifted straight out of DevelopBranch Render.pm
sub _takeOutBlocks {
    my( $this, $intext, $tag ) = @_;
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
        if( $line =~ m/$open/ ) {
            unless( $depth++ ) {
                $out .= $1;
                $tagParams = $2;
                $scoop = '';
                $line = $3;
            }
        }
        if( $depth && $line =~ m/$close/ ) {
            $scoop .= $1;
            my $rest = $2;
            unless ( --$depth ) {
                my $placeholder = $tag.$n;
                $this->{removed}->{$placeholder} = {
                    params => _parseParams( $tagParams ),
                    text => $scoop,
                };

                $line = $TT0.$placeholder.$TT0;
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
        $this->{removed}->{$placeholder} = {
            params => _parseParams( $tagParams ),
            text => $scoop,
        };
        $out .= $TT0.$placeholder.$TT0;
    }

    return $out;
}

sub _putBackBlocks {
    my( $this, $text, $tag, $newtag, $callback ) = @_;
    my $fn = 'CGI::'.($newtag || $tag);
    $newtag ||= $tag;
    while (my ($placeholder, $val) = each %{$this->{removed}}) {
        if( $placeholder =~ /^$tag\d+$/ ) {
            my $params = $val->{params};
            my $val = $val->{text};
            $val = &$callback( $val ) if ( defined( $callback ));
            no strict 'refs';
            $_[1] =~ s/$TT0$placeholder$TT0/&$fn($params, $val)/e;
            use strict 'refs';
            delete( $this->{removed}->{$placeholder} );
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

sub _emitTR {
    my $row = shift;

    $row =~ s/\t/   /g;  # change tabs to space
    $row =~ s/^(\s*)\|//;
    my $pre = $1;

    my @tr;

    while( $row =~ s/^(.*?)\|// ) {
        my $cell = $1;

        if( $cell eq '' ) {
            $cell = '%SPAN%';
        }

        my $attr = {};

        my( $left, $right ) = ( 0, 0 );
        if( $cell =~ /^(\s*).*?(\s*)$/ ) {
            $left = length( $1 );
            $right = length( $2 );
        }

        if( $left > $right ) {
            $attr->{class} = 'align-right';
            $attr->{style} = 'text-align: right';
        } elsif( $left < $right ) {
            $attr->{class} = 'align-left';
            $attr->{style} = 'text-align: left';
        } elsif( $left > 1 ) {
            $attr->{class} = 'align-center';
            $attr->{style} = 'text-align: center';
        }

        # make sure there's something there in empty cells. Otherwise
        # the editor will compress it to (visual) nothing.
        $cell =~ s/^\s*$/&nbsp;/g;

        # Removed TH to avoid problems with handling table headers. TWiki
        # allows TH anywhere, but editors assume top row only, mostly.
        # See Item1185
        push( @tr, CGI::td( $attr, $cell ));
    }
    return $pre.CGI::Tr( join( '', @tr));
}

1;
