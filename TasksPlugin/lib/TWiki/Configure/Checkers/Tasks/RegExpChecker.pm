# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.

use strict;
use warnings;

# Work-around for issue in TWiki::Configure::Checker
# As of 5.1.0, still uses qr/$str/ instead of =~ $str, which
# is very bad for matching X509 subjects (and anything else.)
# Use this module instead of TWiki::Configure::Checker for vulnerable fields until
# it's fixed in the distribution.  At that point, this is redundant (but mostly harmless)

package TWiki::Configure::Checkers::Tasks::RegExpChecker;
use base 'TWiki::Configure::Checker';

# Check for a compilable RE
sub checkRE {
    my ($this, $keys) = @_;

    my $str;
    eval '$str = $TWiki::cfg'.$keys;
    return $this->ERROR( "Unable to evaluate $keys: $@\n" ) if( $@ );  # Possible malformed key
    return '' unless defined $str;

    eval "'x' =~ \$str";
    if ($@) {
        return $this->ERROR(<<MESS);
Invalid regular expression: $@ <p />
See <a href="http://www.perl.com/doc/manual/html/pod/perlre.html">perl.com</a> for help with Perl regular expressions.
MESS
    }

    return '';
}

1;
__END__

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 3
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at
http://www.gnu.org/copyleft/gpl.html

This is a patch to code from
  the TWiki Collaboration Platform, http://TWiki.org/

which is Copyright (C) 2000-2011 TWiki Contributors and licensed under GPL.
