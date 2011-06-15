+# TWiki Enterprise Collaboration Platform, http://TWiki.org/
# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2009-2011 TWiki Contributors.
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
package TWiki::Configure::Checkers::SmimeCertificateFile;

use strict;

use base 'TWiki::Configure::Checker';

use TWiki::Configure::Checker;
use TWiki::Configure::Load;

sub check {
    my $this = shift;

    my $certFile = $TWiki::cfg{SmimeCertificateFile} || "";
    $certFile =~ s/%DATE%/DATE/;
    TWiki::Configure::Load::expandValue($certFile);
    my $e = !-r ( $certFile ) && "Can\'t read $certFile";
    $e = $this->ERROR($e) if $e;
    return $e;
}

1;
