#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2002-2003 Will Norris. All Rights Reserved. (wbniv@saneasylumstudios.com)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# =========================


# =========================
package TWiki::Plugins::ImageGalleryPlugin;

use Data::Dumper;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $debug
        $IMAGE_MAGICK $CONVERT $IDENTIFY $CONVERT_OPTIONS
    );

$VERSION = '1.1';

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between ImageGalleryPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin preferences, the variable defined by:          * Set CONVERT = ...
    $IMAGE_MAGICK = &TWiki::Prefs::getPreferencesValue( "IMAGEGALLERYPLUGIN_IMAGE_MAGICK" ) || "/usr";
    $CONVERT = &TWiki::Prefs::getPreferencesValue( "IMAGEGALLERYPLUGIN_CONVERT" ) || "$IMAGE_MAGICK/bin/convert";
    $IDENTIFY = &TWiki::Prefs::getPreferencesValue( "IMAGEGALLERYPLUGIN_IDENTIFY" ) || "$IMAGE_MAGICK/bin/identify";
    $CONVERT_OPTIONS = &TWiki::Prefs::getPreferencesValue('IMAGEGALLERYPLUGIN_CONVERT_OPTIONS');

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "IMAGEGALLERYPLUGIN_DEBUG" );

    if ( $debug ) {
	&TWiki::Func::writeDebug( "image_magick=[$IMAGE_MAGICK]" );
	&TWiki::Func::writeDebug( "convert=[$CONVERT]: " . ((-x $CONVERT) ? 'found executable' : 'missing') );
	&TWiki::Func::writeDebug( "identify=[$IDENTIFY]: " . ((-x $IDENTIFY) ? 'found executable' : 'missing'));
	# Plugin correctly initialized
	&TWiki::Func::writeDebug( "- TWiki::Plugins::ImageGalleryPlugin::initPlugin( $web.$topic ) is OK" );
    }

    return 1;
}

# =========================
sub handleImageGallery
{
    my( $attributes ) = @_;

    my $size = scalar &TWiki::extractNameValuePair( $attributes, "size" ) || 'medium';
    my $topic = scalar &TWiki::extractNameValuePair( $attributes, "topic" ) || $TWiki::topicName;
    my $web = scalar &TWiki::extractNameValuePair( $attributes, "web" ) || $TWiki::webName;
    my $columns = scalar &TWiki::extractNameValuePair( $attributes, "columns" ) || '0';
    my $rowstart = scalar &TWiki::extractNameValuePair( $attributes, "rowstart" ) || '';
    my $rowinside = scalar &TWiki::extractNameValuePair( $attributes, "rowinside" ) || '';
    my $rowend = scalar &TWiki::extractNameValuePair( $attributes, "rowend" ) || '';
    my $rowinsideempty = scalar &TWiki::extractNameValuePair( $attributes, "rowinsideempty" ) || '';
    my $rowendempty = scalar &TWiki::extractNameValuePair( $attributes, "rowendempty" ) || '';
    my $options = scalar &TWiki::extractNameValuePair( $attributes, "options" ) || $CONVERT_OPTIONS;
    my $format = scalar &TWiki::extractNameValuePair( $attributes, "format")
	|| q(<span class="imgGallery"><a href="$imageurl"><img src="$thumburl" title="$sizeK: $comment"/></a></span>$n);

    my ( $meta, $page ) = &TWiki::Func::readTopic( $web, $topic );
    my @text = $meta->find( 'FILEATTACHMENT' );

    my $resize = &TWiki::Prefs::getPreferencesValue( uc "IMAGEGALLERYPLUGIN_$size" ) || $size;

    &TWiki::Func::writeDebug( "- web=[$web] topic=[$topic] size=[$size] resize=[$resize]" ) if $debug;

    my $t = "";
    my $inr = 0;
    foreach my $i ( @text )
    {
	$i->{humanReadableSize} = sprintf( "%dk", $i->{size}/1024 );
	my $fn = &TWiki::Func::getPubDir() . "/$web/$topic/$i->{name}";
	my $thumb = &TWiki::Func::getPubDir() . "/$web/$topic/thumbs/$resize/$i->{name}";

	next unless ($fn =~ m/jpg$|gif$|png$/);

	&TWiki::Func::writeDebug( Dumper( $i ) ) if $debug;

	next unless (my $dimensions = `"$IDENTIFY" "$fn"`) =~
	    m/(\d+)x(\d+)/; # fix, else don't work for jpg, png ...!
	    #m/(\d+)x(\d+)\+(\d+)\+(\d+)/;

	$inr++;
	my ( $width, $height ) = ( $1, $2 );

	if($columns && (($inr-1)%$columns==0 || $inr==1)){ # row start
	    $t .= &_replaceVars($rowstart, $i, $web, $topic, $resize, $width, $height, $inr);
	}else{	# inside row
	    $t .= &_replaceVars($rowinside, $i, $web, $topic, $resize, $width, $height, $inr);
	}
	$t .= &_replaceVars($format, $i, $web, $topic, $resize, $width, $height, $inr);
	# row end
	$t .= &_replaceVars($rowend, $i, $web, $topic, $resize, $width, $height, $inr) if $columns && ($inr%$columns==0);

	unless ( ( -M $thumb ) && ( -M $fn > -M $thumb ) )
	{   # only update the thumbnail if (1) it doesn't exist or (2) the thumbnail is older than the source image
	    my $thumbDir = &TWiki::Func::getPubDir() . "/$web/$topic/thumbs";
	    mkdir $thumbDir unless -d $thumbDir;
	    $thumbDir .= "/$resize";
	    mkdir $thumbDir unless -d $thumbDir;

	    &TWiki::Func::writeDebug( "- running CONVERT" ) if $debug;
	    system( qq{$CONVERT -sample $resize $options "$fn" "$thumb"} );
	}
    }

    # complete incomplete last row, needed for tables!!
    if($columns && $inr>0 && ($inr%$columns!=0)){
 	do{
 	    $t .= &_replaceVars($rowinsideempty, undef, $web, $topic, $resize, '', '', $inr);
 	    $inr++;
 	}while($inr%$columns!=0);
	# row end
	$t .= &_replaceVars($rowendempty, undef, $web, $topic, $resize, '', '', $inr);
    }

    return $t;
}


# =========================
sub _replaceVars
{
    my( $format, $img, $web, $topic, $resize, $width, $height, $imgnr) = @_;

    $format =~ s/\$web/$web/gos;
    $format =~ s/\$topic/$topic/gos;
    if($img){			# make sure no access for ***empty formats
	$format =~ s/\$width/$width/gos;
	$format =~ s/\$height/$height/gos;
	$format =~ s/\$date(\{([^\}]*)\})?/&_formatTime($img->{date}, $2)/goes;
	$format =~ s/\$version/$img->{version}/gos;
	$format =~ s/\$name/$img->{name}/gos;
	$format =~ s/\$sizeK/$img->{humanReadableSize}/gos;
	$format =~ s/\$size/$img->{size}/gos;
	$format =~ s/\$comment/$img->{comment}/geos;
	$format =~ s/\$wikiusername/$img->{user}/gos;
	$format =~ s/\$username/&TWiki::wikiToUserName($img->{user})/geos;
	$format =~ s,\$thumburl,%PUBURL%/$web/$topic/thumbs/$resize/$img->{name},gos;
	$format =~ s,\$imageurl,%PUBURL%/$web/$topic/$img->{name},gos;
    }
    $format =~ s/\$imgnr/$imgnr/gos;
    $format =~ s/\$n((\([^\)]*\))|(\{[^\}]*\}))?/\n/gos; # $n or $n(....) or $n{...}

    return $format;
}

# =========================
# stolen form TWiki::handleTime() which implements formatting of %GMTIME{...}%
sub _formatTime
{
    my ( $time, $format ) = @_;
    my $value = "";
    my( $sec, $min, $hour, $day, $mon, $year ) = localtime( $time );

    if( $format && $format ne '' ) {
        $value = $format;
        $value =~ s/\$sec[o]?[n]?[d]?[s]?/sprintf("%.2u",$sec)/geoi;
        $value =~ s/\$min[u]?[t]?[e]?[s]?/sprintf("%.2u",$min)/geoi;
        $value =~ s/\$hou[r]?[s]?/sprintf("%.2u",$hour)/geoi;
        $value =~ s/\$day/sprintf("%.2u",$day)/geoi;
        $value =~ s/\$mon[t]?[h]?/$isoMonth[$mon]/goi;
        $value =~ s/\$mo/sprintf("%.2u",$mon+1)/geoi;
        $value =~ s/\$yea[r]?/sprintf("%.4u",$year+1900)/geoi;
        $value =~ s/\$ye/sprintf("%.2u",$year%100)/geoi;
    }else{
	# Default format, e.g. "31 Dec 2002 - 19:30"
	my( $tmon ) = $TWiki::isoMonth[$mon];
	$year = sprintf( "%.4u", $year + 1900 );  # Y2K fix
	$value = sprintf( "%.2u ${tmon} %.2u - %.2u:%.2u", $day, $year, $hour, $min );
    }

    return $value;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    $_[0] =~ s/%IMAGEGALLERY%/&handleImageGallery()/geo;
    $_[0] =~ s/%IMAGEGALLERY{(.*?)}%/&handleImageGallery($1)/geo;
}

# =========================

1;
