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

Base class of Node and Leaf

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

=cut

use vars qw( $NO_TML $NO_BLOCK_TML $NOP_ALL $BLOCK_TML );

$NO_TML = 1 << 0;
$NO_BLOCK_TML = 1 << 1;
$NOP_ALL = 1 << 2;
$BLOCK_TML = $NO_BLOCK_TML;

=pod

---++ Assertions
The generator works by expanding to "decorated" text, where the decorators
are non-printable characters. These characters act express format
requirements - for example, the need to have a newline before some text,
or the need for a space. Whitespace is collapsed down to the minimum that
satisfies the format requirements.

| $CHECKn | Marker that gets inserted in text in spaces where there must be an adjacent newline |
| $CHECKs | Marker that gets inserted in text in spaces where there must be a adjacent whitespace |
| $NBSP | Non-breaking space, never gets deleted |
| $NBBR | Non-breaking linebreak; never gets deleted |

=cut

use vars qw( $CHECKn $CHECKw $CHECKs $NBSP $NBBR );
$CHECKn = "\001"; # require adjacent newline (\n or $NBBR)
$CHECKs = "\002"; # require adjacent space character (' ' or $NBSP)
$CHECKw = "\003"; # require adjacent whitespace (\s|$NBBR|$NBSP)
$NBSP   = "\004"; # unbreakable space
$NBBR   = "\005"; # unbreakable newline
$CHECK1 = "\006"; # start of wiki-word
$CHECK2 = "\007"; # end of wiki-word

=pod

---++ REs
REs for matching delimiters of wikiwords
must be consistent with TML2HTML.pm (and Render.pm of course)

| $STARTWW | Zero-width match for the start of a wikiword |
| $ENDWW | Zero-width match for the end of a wikiword |
| $PROTOCOL | match for a valid URL protocol e.g. http, mailto etc |

=cut

use vars qw( $STARTWW $ENDWW $PROTOCOL );

$STARTWW = qr/^|(?<=[ \t\n\(\!])/om;
$ENDWW = qr/$|(?=[ \t\n\,\.\;\:\!\?\)])/om;
$PROTOCOL = qr/^(file|ftp|gopher|http|https|irc|news|nntp|telnet|mailto):/;

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

sub cleanParseTree {
    my $this = shift;

    $this->cleanNode();

    # thread siblings within a node
    my $prev;
    foreach my $kid (@{$this->{children}}) {
        $kid->{parent} = $this;
        $kid->{prev} = $prev;
        $prev->{next} = $kid if $prev;
        $kid->cleanParseTree($this);
        $prev = $kid;
    }
}

sub stringify {
    return '';
}

1;
