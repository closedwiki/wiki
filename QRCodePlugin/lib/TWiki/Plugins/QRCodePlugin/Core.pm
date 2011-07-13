# Plugin module for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001-2011 Peter Thoeny, peter[at]thoeny.org
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

package TWiki::Plugins::QRCodePlugin::Core;

use strict;

require TWiki::Func;    # The plugins API

#==========================
sub handleQRCODE {
    my( $session, $params, $theTopic, $theWeb ) = @_;

    my $text   = $params->{_DEFAULT};
    my $pEcc   = $params->{ecc} || 'M';
    my $pVer   = $params->{version} || '8';
    my $pSize  = $params->{size} || '4';
    my $format = $params->{format} ||
                 '<img src="$urlpath" width="$width" height="$height" border="0" alt="" />';

    return "QRCode Plugin Error: QRCode text is missing." unless( $text );

    # generate image
    require GD::Barcode::QRcode;
    $pVer = 0 if( $pVer eq 'auto' );
    my $qrcode;
    my $image;
    eval {
        $qrcode = GD::Barcode::QRcode->new( $text, {ECC => $pEcc, Version => $pVer, ModuleSize => $pSize} );
        $image = $qrcode->plot->png;
    };
    return "QRCode Plugin Error: $@" if( $@ );

    # save image file
    my( $dir, $fileName ) = _makeFilename( $theWeb, $theTopic, "$text-$pEcc-$pVer-$pSize" );
    open( PNG, "> $dir/$fileName" )
        or return "QRCode Plugin Error: Can't write temporary file $fileName.";
    binmode( PNG );
    print PNG $image;
    close( PNG );

    # generate and return HTML image tag
    my $maxModules = $qrcode->{MaxModules} || 17 + ( $pVer * 4 ); # use undocumented || hard-code
    my $pixels = ( $maxModules + 8 ) * $pSize;
    my $urlPath = TWiki::Func::getPubUrlPath() . "/$theWeb/$theTopic/$fileName";
    $format =~ s/\$urlpath/$urlPath/;
    $format =~ s/\$width/$pixels/;
    $format =~ s/\$height/$pixels/;
    return $format;
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
