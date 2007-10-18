#package TWiki::Plugins::WysiwygPlugin::Constants;
# Use s simpler-named namespace for constants to improve code readability
package WC;

use strict;

use vars qw(%ALWAYS_BLOCK $ALWAYS_BLOCK_S $STARTWW $ENDWW $PROTOCOL);

# HTML elements that are strictly block type, as defined by
# http://www.htmlhelp.com/reference/html40/block.html.
# Block type elements do not require
# <br /> to be generated for newlines on the boundary - see WC::isInline.
%ALWAYS_BLOCK = map { $_ => 1 }
  qw( ADDRESS BLOCKQUOTE CENTER DIR DIV DL FIELDSET FORM H1 H2 H3 H4 H5 H6
      HR ISINDEX MENU NOFRAMES NOSCRIPT OL P PRE TABLE UL );
$ALWAYS_BLOCK_S = join('|', keys %ALWAYS_BLOCK);

$STARTWW  = qr/^|(?<=[ \t\n\(\!])/om;
$ENDWW    = qr/$|(?=[ \t\n\,\.\;\:\!\?\)])/om;
$PROTOCOL = qr/^(file|ftp|gopher|http|https|irc|news|nntp|telnet|mailto):/;

1;
