# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2009-2013 Peter Thoeny, peter[at]thoeny.org
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

package TWiki::Configure::Checkers::SmimeKeyFile;

use strict;

use base 'TWiki::Configure::Checkers::Certificate::KeyChecker';

use TWiki::Configure::Checker;

sub check {
    my $this = shift;

    return $this->SUPER::check( @_, '{SmimeKeyPassword}' );
}

1;
