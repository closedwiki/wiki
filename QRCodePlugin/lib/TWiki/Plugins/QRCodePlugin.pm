# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001-2012 Peter Thoeny, peter[at]thoeny.org
# Copyright (C) 2012 TWiki Contributors. All Rights Reserved.
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
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::QRCodePlugin;

use strict;

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version

#==========================
our $VERSION = '$Rev$';
our $RELEASE = '2012-09-03';

our $SHORTDESCRIPTION = 'Create QR Code (a matrix barcode) in TWiki pages, useful for mobile applications';
our $NO_PREFS_IN_TOPIC = 1;
our $pluginName = 'QRCodePlugin';

#==========================
sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    TWiki::Func::registerTagHandler( 'QRCODE', \&_QRCODE );

    # Plugin correctly initialized
    return 1;
}

#==========================
sub _QRCODE {
#   my ( $session, $params, $theTopic, $theWeb ) = @_;
    # Lazy loading, e.g. compile core module only when required
    require TWiki::Plugins::QRCodePlugin::Core;
    return  TWiki::Plugins::QRCodePlugin::Core::handleQRCODE( @_ );
}

#==========================
1;
