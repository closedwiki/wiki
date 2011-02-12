# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001-2011 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2011 TWiki Contributors. All Rights Reserved.
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

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

$VERSION = '$Rev$';
$RELEASE = '2011-02-11';

$SHORTDESCRIPTION = 'Create QR Code (a 2D barcode) in TWiki pages, useful for mobile applications';
$NO_PREFS_IN_TOPIC = 1;

$pluginName = 'QRCodePlugin';

#==========================
sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    $debug = $TWiki::cfg{Plugins}{QRCodePlugin}{Debug} || 0;

    TWiki::Func::registerTagHandler( 'QRCODE', \&_QRCODE );

    # Plugin correctly initialized
    return 1;
}

#==========================
sub _QRCODE {
    my( $session, $params, $theTopic, $theWeb ) = @_;

    my $text  = $params->{_DEFAULT};
    my $pEcc  = $params->{ecc} || 'M';
    my $pVer  = $params->{version} || '8';
    my $pSize = $params->{size} || '4';

    return "QRCode Plugin Error: QRCode text is missing." unless( $text );

    use GD::Barcode::QRcode;
    $pVer = 0 if( $pVer eq 'auto' );
    my $image;
    eval {
        $image = GD::Barcode::QRcode->new( $text,
            {ECC => $pEcc, Version => $pVer, ModuleSize => $pSize} )->plot->png;
    };
    return "QRCode Plugin Error: $@" if( $@ );

    my( $dir, $fileName ) = _makeFilename( $theWeb, $theTopic, "$text-$pEcc-$pVer-$pSize" );

    open( PNG, "> $dir/$fileName" )
        or return "QRCode Plugin Error: Can't write temporary file $fileName.";
    binmode( PNG );
    print PNG $image;
    close( PNG );

    my $html = '<img src="' . TWiki::Func::getPubUrlPath()
             . "/$theWeb/$theTopic/$fileName\" />";
    return $html;
}

#==========================
sub _makeFilename
{
    my ( $web, $topic, $text ) = @_;

    my $dir = TWiki::Func::getPubDir() . "/$web";
    unless( -e "$dir" ) {
        umask( 002 );
        mkdir( $dir, 0775 );
    }
    $dir .= "/$topic";
    unless( -e "$dir" ) {
        umask( 002 );
        mkdir( $dir, 0775 );
    }

    use Digest::MD5  qw(md5_hex);
    my $md5 = md5_hex( $text );

    my $name = "_QRCodePlugin_$md5.png";

    return( $dir, $name );
}

#==========================
1;
