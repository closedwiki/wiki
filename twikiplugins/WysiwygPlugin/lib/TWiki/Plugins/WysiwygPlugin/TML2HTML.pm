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

# HTML elements that are palatable to editors. Other HTM tags will be
# rendered in 'protected' regions to prevent the WYSIWYG editor mussing
# them up. Note that as well as the HTML tags we also consider NOAUTOLINK
# palatable, even though it isn't HTML, because it will be used later in
# the rendering process to generate a span.
my $PALATABLE_HTML = qr/(A|ABBR|ACRONYM|ADDRESS|B|BDO|BIG|BLOCKQUOTE|BR|CAPTION|CENTER|CITE|CODE|COL|COLGROUP|DD|DEL|DFN|DIR|DIV|DL|DT|EM|FONT|H1|H2|H3|H4|H5|H6|HR|HTML|I|IMG|INS|ISINDEX|KBD|LABEL|LEGEND|LI|OL|P|PRE|Q|S|SAMP|SMALL|SPAN|STRONG|SUB|SUP|TABLE|TBODY|TD|TFOOT|TH|THEAD|TITLE|TR|TT|U|UL|NOAUTOLINK)/i;

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

    # DEBUG
    #print STDERR "TML2HTML = '$content'\n";

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
                         $stackTop !~ /^%([A-Z0-9_:]+){.*}$/os ) {
                    $stackTop = pop( @stack ) . $stackTop;
                }
            }
            if( $stackTop =~ m/^%([A-Z0-9_:]+)({.*})?$/os ) {
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
    return $this->{opts}->{expandVarsInURL}->( $url, $this->{opts} );
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

    $text = $this->_takeOutBlocks( $text, 'literal' );

    $text = $this->_takeOutSets( $text );

    # Remove PRE to prevent TML interpretation of text inside it
    $text = $this->_takeOutBlocks( $text, 'pre' );

    # change '!%XXX' to '%<nop>XXX' (but not if preceded by !)
    $text =~ s/(?<!\+!)!%(?=[A-Z][A-Z0-9_]*[{%])/%<nop>/g;

    # Change ' !AnyWord' to ' <nop>AnyWord',
    $text =~ s/$STARTWW!(?=[$TWiki::regex{mixedAlphaNum}\*\=])/<nop>/gm;

    # Change ' ![[...' to ' [<nop>[...'
    $text =~ s/(^|\s)!\[\[/$1\[<nop>\[/gm;

    # Protect comments
    $text =~ s/(<!--.*?-->)/$this->_liftOut($1, 'PROTECTED')/ges;

    # Handle inline IMG tags specially
    $text =~ s/(<img [^>]*>)/$this->_takeOutIMGTag($1)/gei;
    $text =~ s/<\/img>//gi;

    # Convert TWiki tags to spans outside protected text
    $text = $this->_processTags( $text );

    # protect some HTML tags.
    $text =~ s/(<\/?(?!($PALATABLE_HTML)\b)[A-Z]+(\s[^>]*)?>)/
      $this->_liftOut($1, 'PROTECTED')/gei;

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
    $text =~ s/&([$TWiki::regex{mixedAlphaNum}]+;)/$TT0$1/g;      # "&abc;"
    $text =~ s/&(#[0-9]+;)/$TT0$1/g;  # "&#123;"
    #$text =~ s/&/&amp;/g;             # escape standalone "&"
    $text =~ s/$TT0(#[0-9]+;)/&$1/go;
    $text =~ s/$TT0([$TWiki::regex{mixedAlphaNum}]+;)/&$1/go;

    # Horizontal rule
    my $hr = CGI::hr({class => 'TMLhr'});
    $text =~ s/^---+$/$hr/gm;

    # Now we really _do_ need a line loop, to process TML
    # line-oriented stuff.
    my $inList = 0;		 # True when within a list type
    my $inTable = 0;     # True when within a table type
    my $inParagraph = 1; # True when within a P
    my @result = ( '<p>' );

    foreach my $line ( split( /\n/, $text )) {
        # Table: | cell | cell |
        # allow trailing white space after the last |
        if( $line =~ m/^(\s*\|.*\|\s*)$/ ) {
            push(@result, '</p>') if $inParagraph;
            $inParagraph = 0;
            $this->_addListItem( \@result, '', '', '' ) if $inList;
            $inList = 0;
            unless( $inTable ) {
                push( @result, CGI::start_table(
                    { border=>1, cellpadding=>0, cellspacing=>1 } ));
            }
            push( @result, _emitTR($1) );
            $inTable = 1;
            next;
        }

        if( $inTable ) {
            push( @result, CGI::end_table() );
            $inTable = 0;
        }

        if ($line =~ /$TWiki::regex{headerPatternDa}/o) {
            # Running head
            $this->_addListItem( \@result, '', '', '' ) if $inList;
            $inList = 0;
            push(@result, '</p>') if $inParagraph;
            $inParagraph = 0;
            $line = _makeHeading($2, length($1));

        } elsif ($line =~ /^\s*$/) {
            # Blank line
            push(@result, '</p>') if $inParagraph;
            $inParagraph = 0;
            $line = '<p>';
            $this->_addListItem( \@result, '', '', '' ) if $inList;
            $inList = 0;
            $inParagraph = 1;

        } elsif ( $line =~ s/^((\t|   )+)\$\s(([^:]+|:[^\s]+)+?):\s/<dt> $3 <\/dt><dd> /o ) {
            # Definition list
            push(@result, '</p>') if $inParagraph;
            $inParagraph = 0;
            $this->_addListItem( \@result, 'dl', 'dd', $1, '' );
            $inList = 1;

        } elsif ( $line =~ s/^((\t|   )+)(\S+?):\s/<dt> $3<\/dt><dd> /o ) {
            # Definition list
            push(@result, '</p>') if $inParagraph;
            $inParagraph = 0;
            $this->_addListItem( \@result, 'dl', 'dd', $1, '' );
            $inList = 1;

        } elsif ( $line =~ s/^((\t|   )+)\*(\s|$)/<li> /o ) {
            # Unnumbered list
            push(@result, '</p>') if $inParagraph;
            $inParagraph = 0;
            $this->_addListItem( \@result, 'ul', 'li', $1, '' );
            $inList = 1;

        } elsif ( $line =~ m/^((\t|   )+)([1AaIi]\.|\d+\.?) ?/ ) {
            # Numbered list
            push(@result, '</p>') if $inParagraph;
            $inParagraph = 0;
            my $ot = $3;
            $ot =~ s/^(.).*/$1/;
            if( $ot !~ /^\d$/ ) {
                $ot = ' type="'.$ot.'"';
            } else {
                $ot = '';
            }
            $line =~ s/^((\t|   )+)([1AaIi]\.|\d+\.?) ?/<li$ot> /;
            $this->_addListItem( \@result, 'ol', 'li', $1, $ot );
            $inList = 1;

        } else {
            # Other line
            $this->_addListItem( \@result, '', '', '' ) if $inList;
            $inList = 0;
        }

        push( @result, $line );
    }

    if( $inTable ) {
        push( @result, '</table>' );
    } elsif ($inList) {
        $this->_addListItem( \@result, '', '', '' );
    } elsif ($inParagraph) {
        push(@result, '</p>');
    }

    $text = join("\n", @result );

    # Trim any extra Ps from the top and bottom.
    $text =~ s#^(\s*<p>\s*</p>)+##s;
    $text =~ s#(<p>\s*</p>\s*)+$##s;

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
        if( $placeholder =~ /^noautolink/i ) {
            _addClass( $val->{params}->{class}, 'WYSIWYG_NOAUTOLINK' );
        } elsif( $placeholder =~ /^verbatim/i ) {
            _addClass( $val->{params}->{class}, 'TMLverbatim');
        } elsif( $placeholder =~ /^literal/i ) {
            _addClass( $val->{params}->{class}, 'WYSIWYG_LITERAL');
        }
    }

    $this->_putBackBlocks( $text, 'noautolink', 'span' );

    $this->_putBackBlocks( $text, 'pre' );

    $this->_putBackBlocks( $text, 'literal', 'span' );

    # replace verbatim with pre in the final output, with encoded entities
    $this->_putBackBlocks( $text, 'verbatim', 'pre', \&_encodeEntities );

    $text =~ s/(<nop>)/$this->_liftOut($1, 'PROTECTED')/ge;

    return $text;
}

sub _addClass {
    if( $_[0] ) {
        $_[0] = join(' ', ( split( /\s+/, $_[0] ), $_[1] ));
    } else {
        $_[0] = $_[1];
    }
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
    $text =~ s/(<img [^>]*\bsrc=)(["'])(.*?)\2/$1.$2.$this->_expandURL($3).$2/gie;
    # Take out mce_src - it just causes problems.
    $text =~ s/(<img [^>]*)\bmce_src=(["'])(.*?)\2/$1/gie;

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

sub _takeOutBlocks {
    my( $this, $intext, $tag ) = @_;
    die unless $tag;
    return '' unless $intext;
    return $intext unless ( $intext =~ m/<$tag\b/ );

    my $open = qr/<$tag\b[^>]*>/i;
    my $close = qr/<\/$tag>/i;
    my $out = '';
    my $depth = 0;
    my $scoop;
    my $tagParams;
    my $n = 0;

    foreach my $chunk (split/($open|$close)/, $intext) {
        next unless defined($chunk);
        if( $chunk =~ m/<$tag\b([^>]*)>/ ) {
            unless( $depth++ ) {
                $tagParams = $1;
                $scoop = '';
                next;
            }
        }
        elsif( $depth && $chunk =~ m/$close/ ) {
            unless( --$depth ) {
                my $placeholder = $tag.$n;
                $this->{removed}->{$placeholder} = {
                    params => _parseParams( $tagParams ),
                    text => $scoop,
                };
                $chunk = $TT0.$placeholder.$TT0;
                $n++;
            }
        }
        if( $depth ) {
            $scoop .= $chunk;
        } else {
            $out .= $chunk;
        }
    }

    if( $depth ) {
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

    # Filter spurious tags without matching open/close
    $out =~ s/$open/&lt;$tag$1&gt;/g;
    $out =~ s/$close/&lt;\/$tag&gt;/g;
    $out =~ s/<($tag\s+\/)>/&lt;$1&gt;/g;

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
    while( $p =~ s/^\s*([$TWiki::regex{mixedAlphaNum}]+)=(".*?"|'.*?')// ) {
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

    $row =~ s/\t/   /g;   # change tabs to space
    $row =~ s/^(\s*)\|//; # Remove leading junk
    my $pre = $1;

    my @tr;
    while( $row =~ s/^(.*?)\|// ) {
        my $cell = $1;
        my $attr = {};

        # make sure there's something there in empty cells. Otherwise
        # the editor may compress it to (visual) nothing.
        $cell =~ s/^\s+$/&nbsp;/g;

        my( $left, $right ) = ( 0, 0 );
        if( $cell =~ /^(\s*)(.*?)(\s*)$/ ) {
            $left = length( $1 );
            $right = length( $3 );
            $cell = $2;
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

        my $fn = "CGI::td";
        if ($cell =~ s/^\*(.+)\*$/$1/) {
            $fn = "CGI::th";
        }

        push(@tr, { fn => $fn, attr => $attr, text => $cell });
    }
    # Work out colspans
    my $colspan = 0;
    my @row;
    for (my $i = $#tr; $i >= 0; $i--) {
        if ($i && length($tr[$i]->{text}) == 0) {
            $colspan++;
            next;
        } elsif ($colspan) {
            $tr[$i]->{attr}->{colspan} = $colspan + 1;
            $colspan = 0;
        }
        unshift(@row, $tr[$i]);
    }
    no strict 'refs';
    return $pre.CGI::Tr(join('', map { &{$_->{fn}}($_->{attr}, $_->{text}) }
                               @row));
    use strict 'refs';
}

1;
