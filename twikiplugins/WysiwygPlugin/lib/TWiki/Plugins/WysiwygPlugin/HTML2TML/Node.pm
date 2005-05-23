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

---+ package TWiki::Plugins::WysiwygPlugin::HTML2TML::Node;

Object for storing a parsed HTML tag, and processing it
to generate TML from the parse tree.

See also TWiki::Plugins::WysiwygPlugin::HTML2TML::Leaf

=cut

package TWiki::Plugins::WysiwygPlugin::HTML2TML::Node;

use strict;

use HTML::Entities;

# Constants
use vars qw( $CHECKn $CHECKs $NBSP $NBBR );

# flags that get passed down into generator functions
my $NO_TML = 1;
my $NO_BLOCK_TML = 2;

# Flags that get passed _up_ from generator functions
# The $flags indicate what sort of output is in $text. They
# are a combination of the package constants:
#   * $LIST_TML - indicates that TML syntax spread over more
#     than one line was generated
my $BLOCK_TML = 1;

# The generator works by expanding to "decorated" text, where the decorators
# are non-printable characters. These characters act express format
# requirements - for example, the need to have a newline before some text,
# or the need for a space. Whitespace is collapsed down to the minimum that
# satisfies the format requirements.
BEGIN {
    # Markers that get inserted in text in spaces where there must be
    # whitespace of certain types.
    $CHECKn = "\001"; # Assertion that there must be an adjacent newline
    $CHECKs = "\002"; # Assertion that there must be adjacent whitespace
    $NBSP   = "\003"; # Non-breaking space, never gets deleted
    $NBBR   = "\004"; # Non-breaking linebreak; never gets deleted
}

# REs for matching delimiters of wikiwords
# must be consistent with TML2HTML.pm (and Render.pm of course)
my $STARTWW = qr/^|(?<=[ \t\n\(\!])/om;
my $ENDWW = qr/$|(?=[ \t\n\,\.\;\:\!\?\)])/om;
my $PROTOCOL = qr/^(file|ftp|gopher|http|https|irc|news|nntp|telnet|mailto):/;

=pod

---++ ObjectMethod new( $context, $tag, \%attrs )

Construct a new HTML tag node using the given tag name
and attribute hash.

=cut

sub new {
    my( $class, $context, $tag, $attrs ) = @_;

    my $this = {};

    $this->{context} = $context;
    $this->{tag} = $tag;
    $this->{attrs} = {};
    if( $attrs ) {
        foreach my $attr ( keys %$attrs ) {
            $this->{attrs}->{$attr} = $attrs->{$attr};
        }
    }
    $this->{children} = [];

    return bless( $this, $class );
}

# debug
sub stringify {
    my $this = shift;
    my $r = '';
    if( $this->{tag} ) {
        $r .= '<'.$this->{tag};
        foreach my $attr ( keys %{$this->{attrs}} ) {
            $r .= " ".$attr."='".$this->{attrs}->{$attr}."'";
        }
        $r .= '>';
    }
    foreach my $kid ( @{$this->{children}} ) {
        $r .= $kid->stringify();
    }
    if( $this->{tag} ) {
        $r .= '</'.$this->{tag}.'>';
    }
    return $r;
}

=pod

---++ ObjectMethod addChild( $node )

Add a child node to the ordered list of children of this node

=cut

sub addChild {
    my( $this, $node ) = @_;

    push( @{$this->{children}}, $node );
}

# top and tail a string
sub _trim {
    my $s = shift;

    $s =~ s/^[ \t\n$CHECKn$CHECKs]+//o;
    $s =~ s/[ \t\n$CHECKn$CHECKs]+$//o;
    return $s;
}

=pod

---++ ObjectMethod rootGenerate( ) -> $text

Generates TML from this HTML node. The generation is done
top down and bottom up, so that higher level nodes can make
decisions on whether to allow TML conversion in lower nodes,
and lower level nodes can constrain conversion in higher level
nodes.

=cut

sub rootGenerate {
    my $this = shift;
    my( $f, $tml ) = $this->_generate(0);

   # return $tml;

    # ignore $CHECKn if there is a \n next to it, otherwise insert a
    # \n.
    $tml =~ s/^($CHECKn)+//gom;
    $tml =~ s/($CHECKn)+$//gom;

    $tml =~ s/(?<=$NBBR)($CHECKn)+//gom;
    $tml =~ s/($CHECKn)+(?=$NBBR)//gom;

    $tml =~ s/($CHECKn)+/$NBBR/gos;

    $tml =~ s/$NBBR\n+/$NBBR/gs;
    $tml =~ s/\n+$NBBR\n+/$NBBR/gs;
    $tml =~ s/\n\n+/\n/gs;

    $tml =~ s/$NBBR/\n/go;

    # ignore $CHECKs if there is a \s next to it, otherwise insert a
    # space.
    $tml =~ s/(?<=$STARTWW)($CHECKs)+//gos;
    $tml =~ s/($CHECKs)+(?=$ENDWW)//gos;
    $tml =~ s/(?<=$NBSP)($CHECKs)+//gos;
    $tml =~ s/($CHECKs)+(?=$NBSP)//gos;
    $tml =~ s/($CHECKs)+/ /gos;

    $tml =~ s/$NBSP/ /go;

    return $tml;
}

# the actual generate function. rootGenerate is only applied to the root node.
sub _generate {
    my( $this, $options ) = @_;
    my $fn;
    my $flags;
    my $text;

    if( $options & $NO_TML ) {
        return ( 0, $this->stringify() );
    }

    # make the names of the function versions
    my $tag = $this->{tag};
    $tag =~ s/!//; # DOCTYPE
    my $tmlFn = '_handle'.uc( $this->{tag} );

    # See if we have a TML translation function for this tag
    # the translation functions will work out the rendering
    # of their own children.
    if( $this->{tag} && defined( &$tmlFn ) ) {
        no strict 'refs';
        ( $flags, $text ) = &$tmlFn( $this, $options );
        use strict 'refs';
        # if the function returns undef, drop through
        return ( $flags, $text ) if defined $text;
    }

    # No translation, so we need the text of the children
    ( $flags, $text ) = $this->_flatKids( $options );

    # just return the text if there is no tag name
    return ( $flags, $text ) unless $this->{tag};

    return $this->_defaultTag( $options );
}

# Return the children flattened out subject to the options
sub _flatKids {
    my( $this, $options ) = @_;
    my $text = '';
    my $flags = 0;

    foreach my $kid ( @{$this->{children}} ) {
        my( $f, $t ) = $kid->_generate( $options );
        if( $text && $text =~ /\w$/ && $t =~ /^\w/ ) {
            $text .= ' ';
        }
        $text .= $t;
        $flags |= $f;
    }
    return ( $flags, $text );
}

# $cutClasses is an RE matching class names to cut
sub _htmlParams {
    my ( $attrs, $cutClasses ) = @_;
    my @params;

    foreach my $key ( keys %$attrs ) {
        next unless $key;
        if( $key eq 'class' && $cutClasses ) {
            $attrs->{$key} ||= '';
            # tidy up the list of class names
            my @classes = grep { !/^($cutClasses)$/ }
              split(/\s+/, $attrs->{$key} );
            $attrs->{$key} = join(' ', @classes);
            next unless( $attrs->{$key} =~ /\S/);
        }
        my $q = $attrs->{$key} =~ /"/ ? "'" : '"';
        push( @params, "$key=$q$attrs->{$key}$q" );
    }
    my $p = join( ' ', @params );
    return '' unless $p;
    return ' '.$p;
}

# generate the default representation of an HTML tag
sub _defaultTag {
    my( $this, $options ) = @_;
    my( $flags, $text ) = $this->_flatKids( $options );
    my $tag = lc( $this->{tag} );
    my $p = _htmlParams( $this->{attrs} );
    if( $text =~ /^\s+$/ ) {
        return ( $flags, '<'.$this->{tag}.$p.' />' );
    } else {
        return ( $flags, '<'.$this->{tag}.$p.'>'.$text.'</'.$this->{tag}.'>' );
    }
}

# perform conversion on a list type
sub _convertList {
    my( $this, $indent ) = @_;
    my $basebullet;
    my $isdl = ( lc( $this->{tag} ) eq 'dl' );

    if( $isdl ) {
        $basebullet = '';
    } elsif( lc( $this->{tag} ) eq 'ol' ) {
        $basebullet = '1';
    } else {
        $basebullet = '*';
    }

    my $f;
    my $text = '';
    my $pendingDT = 0;
    foreach my $kid ( @{$this->{children}} ) {
        # be tolerant of dl, ol and ul with no li
        if( $kid->{tag} =~ m/^[dou]l$/i ) {
            $text .= $kid->_convertList( $indent."\t" );
            next;
        }
        next unless $kid->{tag} =~ m/^(dt|dd|li)$/i;
        if( $isdl && ( lc( $kid->{tag} ) eq 'dt' )) {
            # DT, set the bullet type for subsequent DT
            $basebullet = $kid->_flatKids( $NO_BLOCK_TML ).':';
            $basebullet =~ s/$CHECKn/ /g;
            if( $basebullet =~ /[$CHECKs ]/ ) {
                $basebullet = "\$ $basebullet";
            }
            $pendingDT = 1; # remember in case there is no DD
            next;
        }
        my $bullet = $basebullet;
        if( $basebullet eq '1' && $kid->{attrs}->{type} ) {
            $bullet = $kid->{attrs}->{type}.'.';
        }
        my $spawn = '';
        foreach my $grandkid ( @{$kid->{children}} ) {
            my $t;
            if( $grandkid->{tag} =~ /^[dou]l$/i ) {
                $t = $grandkid->_convertList( $indent."\t" );
            } else {
                ( $f, $t ) = $grandkid->_generate( $NO_BLOCK_TML );
                $t =~ s/$CHECKn/ /g;
            }
            $spawn .= $t;
        }
        $text .= $CHECKn.$indent.$bullet.$CHECKs.$spawn.$CHECKn;
        $pendingDT = 0;
        $basebullet = '' if $isdl;
    }
    if( $pendingDT ) {
        # DT with no corresponding DD
        $text .= $CHECKn.$indent.$basebullet.$CHECKn;
    }
    return $text;
}

# probe down into a list type to determine if it
# can be converted to TML.
sub _isConvertableList {
    my( $this, $options ) = @_;
    foreach my $kid ( @{$this->{children}} ) {
        # check for malformed list. We can still handle it,
        # by simply ignoring illegal text.
        # be tolerant of dl, ol and ul with no li
        if( $kid->{tag} =~ m/^[dou]l$/i ) {
            return 0 unless $kid->_isConvertableList( $options );
            next;
        }
        next unless( $kid->{tag} =~ m/^(dt|dd|li)$/i );
        unless( $kid->_isConvertableListItem( $options, $this )) {
            return ( 0, undef );
        }
    }
    return 1;
}

# probe down into a list item to determine if the
# containing list can be converted to TML.
sub _isConvertableListItem {
    my( $this, $options, $parent ) = @_;
    my( $flags, $text );

    if( lc( $parent->{tag} ) eq 'dl' ) {
        return 0 unless( $this->{tag} =~ /^d[td]$/i );
    } else {
        return 0 unless( lc( $this->{tag} ) eq 'li' );
    }

    foreach my $kid ( @{$this->{children}} ) {
        if( $kid->{tag} =~ /^[oud]l$/i ) {
            unless( $kid->_isConvertableList( $options )) {
                return 0;
            }
        } else {
            ( $flags, $text ) = $kid->_generate( $options );
            if( $flags & $BLOCK_TML ) {
                return 0;
            }
        }
    }
    return 1;
}

# probe down into a list type to determine if it
# can be converted to TML.
sub _isConvertableTable {
    my( $this, $options, $table ) = @_;
    my @process = ( @{$this->{children}} );
    foreach my $kid ( @{$this->{children}} ) {
        if( $kid->{tag} =~ /^(colgroup|thead|tbody|tfoot|col)$/ ) {
            return 0 unless( $kid->_isConvertableTable( $options, $table ));
        } elsif( !$kid->{tag} ) {
            next;
        } else {
            return 0 unless( lc( $kid->{tag} ) eq 'tr' );
            my $row = $kid->_isConvertableTableRow( $options );
            return 0 unless $row;
            push( @$table, $row );
        }
    }
    return 1;
}

# probe down into a list item to determine if the
# containing table can be converted to TML.
sub _isConvertableTableRow {
    my( $this, $options ) = @_;
    my( $flags, $text );

    my @row;
    foreach my $kid ( @{$this->{children}} ) {
        if( lc( $kid->{tag} ) eq 'th' ) {
            ( $flags, $text ) = $kid->_flatKids( $options );
            $text = _trim( $text );
            $text = '*'.$text.'*';
        } elsif(lc( $kid->{tag} ) eq 'td' ) {
            ( $flags, $text ) = $kid->_flatKids( $options );
            $text = _trim( $text );
        } elsif( !$kid->{tag} ) {
            next;
        } else {
            # some other sort of (unexpected) tag
            return 0;
        }
        return 0 if( $flags & $BLOCK_TML );
        if( $kid->{attrs} ) {
            if( $kid->{attrs}->{align} ) {
                if( $kid->{attrs}->{align} eq 'left' ) {
                    $text .= '  ';
                } elsif( $kid->{attrs}->{align} eq 'right' ) {
                    $text = '  '.$text;
                } elsif( $kid->{attrs}->{align} eq 'center' ) {
                    $text = '  '.$text.'  ';
                }
            }
            if( $kid->{attrs}->{rowspan} && $kid->{attrs}->{rowspan} > 1 ) {
                return 0;
            }
        }
        push( @row, $text );
    }
    return \@row;
}

# convert a heading tag
sub _H {
    my( $this, $options, $depth ) = @_;
    my( $flags, $contents ) = $this->_flatKids( $options );
    return ( 0, undef ) if( $flags & $BLOCK_TML );
    return ( $flags | $BLOCK_TML,
             $CHECKn.'---'.('+' x $depth).$CHECKs.$contents.$CHECKn );
}

# generate an emphasis
sub _emphasis {
    my( $this, $options, $ch ) = @_;
    my( $flags, $contents ) = $this->_flatKids( $options | $NO_BLOCK_TML );
    return ( 0, undef ) if( !defined( $contents ) || ( $flags & $BLOCK_TML ));
    $contents = _trim( $contents );
    return ( $flags, $CHECKs.$ch.$contents.$ch.$CHECKs );
}

######################################################
# Handlers for different tag types. Each handler returns
# a pair (flags,text) containing the result of the expansion.
# Any of these handlers may return (0,undef) at any point,
# which will cause the tag to be generated as HTML tags.

# synonyms
sub _handleH1 { return _H( @_, 1 ); }
sub _handleH2 { return _H( @_, 2 ); }
sub _handleH3 { return _H( @_, 3 ); }
sub _handleH4 { return _H( @_, 4 ); }
sub _handleH5 { return _H( @_, 5 ); }
sub _handleH6 { return _H( @_, 6 ); }
sub _handleOL { return _handleLIST( @_ ); }
sub _handleDL { return _handleLIST( @_ ); }
sub _handleUL { return _handleLIST( @_ ); }
sub _handleB  { return _handleSTRONG( @_ ); }
sub _handleI  { return _handleEM( @_ ); }
sub _handleTT { return _handleCODE( @_ ); }

# tags where we just expand the content, ignoring the actual tag itself
sub _handleHTML { return _flatKids( @_ ); }
sub _handleBODY { return _flatKids( @_ ); }

# tags we ignore completely (contents as well)
sub _handleDOCTYPE { return ( 0, '' ); }
sub _handleHEAD { return ( 0, '' ); }
sub _handleBASE { return ( 0, '' ); }
sub _handleBASEFONT { return ( 0, '' ); }
sub _handleMETA { return ( 0, '' ); }

sub _handleSTRONG {
    my( $this, $options ) = @_;
    if( scalar( @{$this->{children}} ) == 1 ) {
        if( $this->{children}->[0]->{tag} =~ /^(i|em)$/i ) {
            return _emphasis( $this->{children}->[0], $options, '__' );
        } elsif( $this->{children}->[0]->{tag} =~ /^(code|tt)$/i ) {
            return _emphasis( $this->{children}->[0], $options, '==' );
        }
    }
    return _emphasis( @_, '*' );
}

sub _handleEM {
    my( $this, $options ) = @_;
    if( scalar( @{$this->{children}} ) == 1 &&
        $this->{children}->[0]->{tag} =~ /^(b|strong)$/i ) {
        return _emphasis( $this->{children}->[0], $options, '__' );
    }
    return _emphasis( @_, '_' );
}

sub _handleCODE {
    my( $this, $options ) = @_;
    if( scalar( @{$this->{children}} ) == 1 &&
        $this->{children}->[0]->{tag} =~ /^(b|strong)$/i ) {
        return _emphasis( $this->{children}->[0], $options, '==' );
    }
    return _emphasis( @_, '=' );
}

sub _handleBR {
    my( $this, $options ) = @_;
    my($f, $kids ) = $this->_flatKids( $options );
    return ($f, '<br />'.$kids) if( $options & $NO_BLOCK_TML );
    return ($f | $BLOCK_TML, $NBBR.$kids);
}

sub _handleHR {
    my( $this, $options ) = @_;
    return '<hr />' if( $options & $NO_BLOCK_TML );
    return ( $BLOCK_TML, "$CHECKn---$CHECKn");
}

sub _handleP {
    my( $this, $options ) = @_;

    my( $f, $kids ) = $this->_flatKids( $options );
    return ($f, '<p />'.$kids) if( $options & $NO_BLOCK_TML );
    return ($f | $BLOCK_TML, $NBBR.$NBBR.$kids);
}

sub _handleA {
    my( $this, $options ) = @_;

    my( $flags, $text ) = $this->_flatKids( $options | $NO_BLOCK_TML );
    if( $text ) {
        # text can be flattened; try various wikiword constructs
        my $href = $this->{attrs}->{href};
        my $topic = &{$this->{context}->{parseWikiUrl}}( $href );
        if( $topic ) {
            # the href targets a wiki page
            if ( $text eq $topic || $topic =~ /^\w+\.$text$/ ) {
                # wikiword or web.wikiword
                return (0, $CHECKs.$topic.$CHECKs);
            } else {
                # text and link differ
                return (0, $CHECKs.'[['.$topic.']['.$text.']]'.$CHECKs );
            }
        } elsif ( $href =~ $PROTOCOL ) {
            # normal link
            if( $text eq $href ) {
                return (0, $CHECKs.$text.$CHECKs);
            } else {
                return (0, $CHECKs.'[['.$href.']['.$text.']]'.$CHECKs );
            }
        }
    }
    return (0, undef);
}

sub _handleSPAN {
    my( $this, $options ) = @_;
    if( $this->{attrs}->{class} =~ /\bTMLvariable\b/ ) {
        my( $flags, $text ) = $this->_flatKids( $options | $NO_BLOCK_TML );
        my $var = _trim($text);
        # don't create unnamed variables
        $var = '%'.$var.'%' if( $var );
        return (0, $var);
    } elsif ($this->{attrs}->{class} =~ /\bTMLnop\b/) {
        return ( 0, '<nop>');
    }
    return (0, undef);
}

sub _handlePRE {
    my( $this, $options ) = @_;

    if( $this->{attrs}->{class} &&
        $this->{attrs}->{class} =~ /\bTMLverbatim\b/ ) {
        return $this->_handleVERBATIM( $options );
    }

    # can't use CGI::pre because it wont put the newlines that
    # twiki needs in
    unless( $options & $NO_BLOCK_TML ) {
        my( $flags, $text ) = $this->_flatKids( $options | $NO_BLOCK_TML );
        my $p = _htmlParams( $this->{attrs} );
        return ($BLOCK_TML, "$CHECKn<pre$p>$CHECKn".$text.
                "$CHECKn</pre>$CHECKn");
    }
    return ( 0, undef );
}

sub _handleVERBATIM {
    my( $this, $options ) = @_;
    my( $flags, $text ) = $this->_flatKids( $NO_TML );

    $text =~ s!<br( /)?>!$NBBR!gi;
    $text =~ s!<p( /)?>!$NBBR!gi;
    $text =~ s!</(p|br)>!!gi;
    $text = HTML::Entities::decode_entities( $text );
    $text =~ s/ /$NBSP/g;
    $text =~ s/$CHECKn/$NBBR/g;
    my $p = _htmlParams( $this->{attrs}, 'TMLverbatim' );
    return ( $BLOCK_TML,
             "$CHECKn<verbatim$p>$CHECKn".$text."$CHECKn</verbatim>$CHECKn" );
}

sub _handleDIV {
    my( $this, $options ) = @_;
    if( $this->{attrs}->{class} =~ /\bTMLnoautolink\b/ ) {
        my( $flags, $text ) = $this->_flatKids( $options );
        my $p = _htmlParams( $this->{attrs}, 'TMLnoautolink' );
        return ($BLOCK_TML, "$CHECKn<noautolink$p>$CHECKn".$text.
                "$CHECKn</noautolink>$CHECKn");
    }
    return (0, undef);
}

sub _handleLIST {
    my( $this, $options ) = @_;
    if( ( $options & $NO_BLOCK_TML ) ||
        !$this->_isConvertableList( $options | $NO_BLOCK_TML )) {
        return ( 0, undef );
    }
    return ( $BLOCK_TML, $this->_convertList( "\t" ));
}

sub _handleTABLE {
    my( $this, $options ) = @_;
    return ( 0, undef) if( $options & $NO_BLOCK_TML );

    # Should really look at the table attrs, but to heck with it

    return ( 0, undef ) if( $options & $NO_BLOCK_TML );

    my @table;
    return ( 0, undef ) unless
      $this->_isConvertableTable( $options | $NO_BLOCK_TML, \@table );

    my $maxrow = 0;
    my $row;
    foreach $row ( @table ) {
        my $rw = scalar( @$row );
        $maxrow = $rw if( $rw > $maxrow );
    }
    foreach $row ( @table ) {
        while( scalar( @$row ) < $maxrow) {
            push( @$row, '' );
        }
    }
    my $text = $CHECKn;
    foreach $row ( @table ) {
        # isConvertableTableRow has already formatted the cell
        $text .= $CHECKn.'|'.join('|', @$row).'|'.$CHECKn;
    }

    return ( $BLOCK_TML, $text );
}

sub _handleIMG {
    my( $this, $options ) = @_;
    my $alt = &{$this->{context}->{convertImage}}( $this->{attrs}->{src} );
    if( $alt ) {
        return (0, " $alt ");
    }
    return(0, undef);
}

1;
