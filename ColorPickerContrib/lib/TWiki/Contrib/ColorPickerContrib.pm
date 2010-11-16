# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2010 Peter Thoeny, peter[at]thoeny.org
# Copyright (C) 2010 TWiki Contributors. All Rights Reserved.
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

=begin twiki

TBD

=cut

package TWiki::Contrib::ColorPickerContrib;

use strict;

require TWiki::Func;    # The plugins API

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION );

$VERSION = '$Rev$';
$RELEASE = '2010-11-15';
$SHORTDESCRIPTION = "Color picker, packaged for use by plugins, skins and add-ons";

1;
