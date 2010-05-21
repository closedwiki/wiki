# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 20005-2010 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
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
#
# Author: Crawford Currie http://c-dot.co.uk

=begin twiki

---+ package TWiki::Query::OP_lc

=cut

package TWiki::Query::OP_lc;
use base 'TWiki::Query::UnaryOP';

use strict;

sub new {
    my $class = shift;

    return $class->SUPER::new(
        name => 'lc',
        prec => 600,
        casematters => 1);
}

sub evaluate {
    my $this = shift;
    my $node = shift;
    return $this->evalUnary( $node, sub { lc( shift ) }, @_ );
};

1;
