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

---+ package WC

Constants, and base class of Node and Leaf

_generate
_cleanAttrs
addChild
stringify

=cut

package WC;

=pod

---++ Generator flags
| $NO_TML | Flag that gets passed _down_ into generator functions. Constrains output to HTML only. |
| $NO_BLOCK_TML | Flag that gets passed _down_ into generator functions. Don't generate block TML e.g. tables, lists |
| $NOP_ALL | Flag that gets passed _down_ into generator functions. NOP all variables and WikiWords. |
| $BLOCK_TML | Flag passed up from generator functions; set if expansion includes block TML |
| $VERY_CLEAN | Flag passed to indicate that HTML must be aggressively cleaned (unrecognised or unuseful tags stripped out) |
| $BR2NL | Flag set to force BR tags to be converted to newlines. |
| $KEEP_WS | Set to force the generator to keep all whitespace. Otherwise whitespace gets collapsed (as it is when HTML is rendered) |
| $PROTECTED | In a block marked as PROTECTED |
| $KEEP_ENTITIES | Don't decode HTML entities |

=cut

use vars qw( $NO_TML $NO_BLOCK_TML $NOP_ALL $BLOCK_TML $BR2NL );
use vars qw( $CHECKn $CHECKw $CHECKs $NBSP $NBBR $TAB $PON $POFF );

$NO_HTML       = 1 << 0;
$NO_TML        = 1 << 1;
$NO_BLOCK_TML  = 1 << 2;
$NOP_ALL       = 1 << 3;
$VERY_CLEAN    = 1 << 4;
$BR2NL         = 1 << 5;
$KEEP_WS       = 1 << 6;
$PROTECTED     = 1 << 7;
$KEEP_ENTITIES = 1 << 8;

$BLOCK_TML    = $NO_BLOCK_TML;

my %cc = (
    'NBSP'   => 14, # unbreakable space
    'NBBR'   => 15, # para break required
    'CHECKn' => 16, # require adjacent newline (\n or $NBBR)
    'CHECKs' => 17, # require adjacent space character (' ' or $NBSP)
    'CHECKw' => 18, # require adjacent whitespace (\s|$NBBR|$NBSP)
    'CHECK1' => 19, # start of wiki-word
    'CHECK2' => 20, # end of wiki-word
    'TAB'    => 21, # list indent
    'PON'    => 22, # protect on
    'POFF'   => 23, # protect off
);

sub debugEncode {
    my $string = shift;
    while (my ($k, $v) = each %cc) {
        my $c = chr($v);
        $string =~ s/$c/\%$k/g;
    }
    return $string;
}

=pod

---++ Forced whitespace
These single-character shortcuts are used to assert the presence of
non-breaking whitespace.

| $NBSP | Non-breaking space |
| $NBBR | Non-breaking linebreak |

=cut

$NBSP   = chr($cc{NBSP});
$NBBR   = chr($cc{NBBR});

=pod

---++ Inline Assertions
The generator works by expanding to "decorated" text, where the decorators
are characters below ' '. These characters act to express format
requirements - for example, the need to have a newline before some text,
or the need for a space. The generator sticks this format requirements into
the text stream, and they are then optimised down to the minimum in a post-
process.

| $CHECKn | there must be an adjacent newline (\n or $NBBR) |
| $CHECKs | there must be an adjacent space (' ' or $NBSP) |
| $CHECKw | There must be adjacent whitespace (\s or $NBBR or $NBSP) |
| $CHECK1 | Marks the start of an inline wikiword. |
| $CHECK2 | Marks the end of an inline wikiword. |
| $TAB    | Shorthand for an indent level in a list |

=cut

$CHECKn = chr($cc{CHECKn});
$CHECKs = chr($cc{CHECKs});
$CHECKw = chr($cc{CHECKw});
$CHECK1 = chr($cc{CHECK1});
$CHECK2 = chr($cc{CHECK2});
$TAB    = chr($cc{TAB});
$PON    = chr($cc{PON});
$POFF   = chr($cc{POFF});

=pod

---++ REs
REs for matching delimiters of wikiwords, must be consistent with TML2HTML.pm

| $STARTWW | Zero-width match for the start of a wikiword |
| $ENDWW | Zero-width match for the end of a wikiword |
| $PROTOCOL | match for a valid URL protocol e.g. http, mailto etc |

=cut

use vars qw( $STARTWW $ENDWW $PROTOCOL );

$STARTWW = qr/^|(?<=[ \t\n\(\!])/om;
$ENDWW = qr/$|(?=[ \t\n\,\.\;\:\!\?\)])/om;
$PROTOCOL = qr/^(file|ftp|gopher|http|https|irc|news|nntp|telnet|mailto):/;

# HTML elements that are strictly block type, as defined by
# http://www.htmlhelp.com/reference/html40/block.html.
# Block type elements do not require
# <br /> to be generated for newlines on the boundary - see WC::isInline.
my %isOnlyBlockType = map { $_ => 1 }
  qw( ADDRESS BLOCKQUOTE CENTER DIR DIV DL FIELDSET FORM H1 H2 H3 H4 H5 H6
      HR ISINDEX MENU NOFRAMES NOSCRIPT OL P PRE TABLE UL );

# pure virtual
sub generate {
    die "coding error";
}

# pure virtual
sub addChild {
    die "coding error";
}

sub cleanNode {
}

sub hasClass {
    return 0;
}

sub cleanParseTree {
    my( $this, $opts ) = @_;

    my @jobs = ( $this );

    while (scalar(@jobs)) {
        my $node = shift(@jobs);
        $node->cleanNode($opts);

        my $prev;
        my $kid = $node->{head};
        while ($kid) {
            push(@jobs, $kid);
            $kid = $kid->{next};
        }
    }
    return ($this->{head}, $this->{head});
}

sub stringify {
    return '';
}

sub _remove {
    my ($this) = @_;
    if ($this->{prev}) {
        $this->{prev}->{next} = $this->{next};
    } else {
        $this->{parent}->{head} = $this->{next};
    }
    if ($this->{next}) {
        $this->{next}->{prev} = $this->{prev};
    } else {
        $this->{parent}->{tail} = $this->{prev};
    }
    $this->{parent} = $this->{prev} = $this->{next} = undef;
}

# Determine if the node - and all it's child nodes - satisfy the criteria
# for an HTML inline element.
sub isInline {
    # This impl is actually for Nodes; Leaf overrides it
    my $this = shift;
    return 0 if $isOnlyBlockType{uc($this->{tag})};
    my $kid = $this->{head};
    while ($kid) {
        return 0 unless $kid->isInline();
        $kid = $kid->{next};
    }
    return 1;
}

sub isLeftInline {
    # This impl is actually for Nodes; Leaf overrides it
    my $this = shift;
    return 0 if $isOnlyBlockType{uc($this->{tag})};
    return 1 unless ($this->{head});
    return 0 unless $this->{head}->isInline();
    return 1;
}

sub isRightInline {
    my $this = shift;
    return 0 if $isOnlyBlockType{uc($this->{tag})};
    return 1 unless $this->{tail};
    return 0 unless $this->{tail}->isInline();
    return 1;
}

# Determine if the previous node qualifies as an inline node
sub prevIsInline {
    my $this = shift;
    if ($this->{prev}) {
        return $this->{prev}->isRightInline();
    } elsif ($this->{parent}) {
        return $this->{parent}->prevIsInline();
    }
    return 0;
}

# Determine if the next node qualifies as an inline node
sub nextIsInline {
    my $this = shift;
    if ($this->{next}) {
        return $this->{next}->isLeftInline();
    } elsif ($this->{parent}) {
        return $this->{parent}->nextIsInline();
    }
    return 0;
}

1;
