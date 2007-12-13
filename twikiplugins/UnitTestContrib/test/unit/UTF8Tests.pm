#
# Currently a mostly empty test package; waiting for someone with an interest
# in UTF-8 to develop some meaningful tests. Specifically, manipulation of
# $TWiki::cfg{Site}{CharSet}
# $TWiki::cfg{UseLocale}
# $TWiki::cfg{Site}{Locale}
# $TWiki::cfg{Site}{Lang}
# $TWiki::cfg{Site}{FullLang}
# $TWiki::cfg{Site}{LocaleRegexes}
# to provide coverage of all the options (bearing in mind that you are going
# to have to work out how to re-initialise TWiki for each test)
#
package UTF8Tests;
use base qw(TWikiTestCase);

use strict;

use TWiki;

sub set_up {
}

sub tear_down {
}

sub test_urlEncodeDecode {
    my $this = shift;
    my $s = '';
    my $t = '';

    for (my $i = 0; $i < 256; $i++) {
        $s .= chr($i);
    }
    $t = TWiki::urlEncode($s);
    $this->assert($s eq TWiki::urlDecode($t));

    $s = TWiki::urlDecode('%u7FFF%uA1EE');
    $this->assert_equals(chr(0x7FFF).chr(0xA1EE), $s);
}

1;
