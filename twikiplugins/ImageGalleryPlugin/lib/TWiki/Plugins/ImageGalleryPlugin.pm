#! perl -w
use strict; #TODO: check for problems with -w and strict
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
# When %IMAGEGALLERY is seen, it:
#    1 finds the meta data for the current topic
#    2 initialises a buffer $t for the output to be inserted
#    3 for each attachment $i (does it check to ensure Image type?), it:
#       a finds the dimensions of the image (using IMAGEGALLERYPLUGIN_IDENTIFY)
#            (it aborts this attachment in the results if it cannot find the dimension)
#       b adds to $t the image <IMG SRC> pointer; this is subject to formatting into columns and rows
#    4 returns the buffer
sub handleImageGallery
{
    my( $attributes ) = @_;

    $settings = {
       size => scalar &TWiki::extractNameValuePair( $attributes, "size" ) || 'medium',
       topic => scalar &TWiki::extractNameValuePair( $attributes, "topic" ) || $TWiki::topicName,
       web => scalar &TWiki::extractNameValuePair( $attributes, "web" ) || $TWiki::webName,
       columns => scalar &TWiki::extractNameValuePair( $attributes, "columns" ) || '0',
       rowstart => scalar &TWiki::extractNameValuePair( $attributes, "rowstart" ) || '',
       rowinside => scalar &TWiki::extractNameValuePair( $attributes, "rowinside" ) || '',
       rowend => scalar &TWiki::extractNameValuePair( $attributes, "rowend" ) || '',
       rowinsideempty => scalar &TWiki::extractNameValuePair( $attributes, "rowinsideempty" ) || '',
       rowendempty = scalar &TWiki::extractNameValuePair( $attributes, "rowendempty" ) || '',
       options = scalar &TWiki::extractNameValuePair( $attributes, "options" ) || $CONVERT_OPTIONS,
       format = scalar &TWiki::extractNameValuePair( $attributes, "format"),
    	|| q(<span class="imgGallery"><a href="$imageurl"><img src="$thumburl" title="$sizeK: $comment"/></a></span>$n),
       resize = &TWiki::Prefs::getPreferencesValue( uc "IMAGEGALLERYPLUGIN_$size" ) || $size
    };
    
    my @topics = _getTopics($web, $topic);
    my $output = '';
    foreach my $wantedTopic (@topics) {
       my ( $meta, $text ) = &TWiki::Func::readTopic( $web, $wantedTopic ); # SMELL - don't need text
       $output .= _formatTMLforTopic($web, $wantedTopic, $meta, $settings);
    }
    return $output;
}

# Potentially we could provide a topic name/other-attribute(e.g. form) filter...
sub _getTopics {

    return ($topic) unless ($topic eq 'all');
    return TWiki::Func::getTopicList();
}

# DESIGN: I chose to reset the image number with each new topic, but arguably
# you'd want to be able to compile pictures from different topics into the 
# same rows. 
#
# DESIGN: I chose to select all images attached to a page but 
# you might choose to select only the first image from each topic
sub _formatTMLforTopic {
    my ($web, $topic, $meta, $settings) = @_;
    
    my @attachments = $meta->find( 'FILEATTACHMENT' );
    &TWiki::Func::writeDebug( "- web=[$web] topic=[$topic] size=[$settings->{size}] resize=[$settings->{resize}]" ) if $debug;
#TODO: check what's resize vs size
  
    my $t = "";
    my $imageNumber = 0;

    foreach my $attachment (@attachments) {
      $attachment->{humanReadableSize} = sprintf( "%dk", $attachment->{size}/1024 );

	  my $filename = &TWiki::Func::getPubDir() . "/$web/$topic/$attachment->{name}";
      &TWiki::Func::writeDebug( Dumper( $i ) ) if $debug;

	  next unless (my $dimensions = `"$IDENTIFY" "$filename"`) =~
	    m/(\d+)x(\d+)/; # fix, else don't work for jpg, png ...!
	    #m/(\d+)x(\d+)\+(\d+)\+(\d+)/;
      my ( $width, $height ) = ( $1, $2 );
      
	  $imageNumber++;
      $t .= _formatImageSRC($imageNumber, $web, $topic, $attachment, $width, $height, $settings );
      _updateThumb($filename);  # SMELL - might want to do this periodically?
    } 
    
    if ($columns && ($imageNumber>0)) {
      $t .= _completeAnyUnfinishedTables($imageNumber, $web, $topic, $width, $height, $settings);
    }

    return $t;
}

sub _updateThumb {
   my ($fn, $settings) = @_;
   my $resize = $settings->{resize};
   my $options = $settings->{options};
   
   my $thumb = &TWiki::Func::getPubDir() . "/$web/$topic/thumbs/$resize/$i->{name}";
   unless ( ( -M $thumb ) && ( -M $fn > -M $thumb ) )
	{   # only update the thumbnail if (1) it doesn't exist or (2) the thumbnail is older than the source image
	    my $thumbDir = &TWiki::Func::getPubDir() . "/$web/$topic/thumbs";
	    mkdir $thumbDir unless -d $thumbDir;
	    $thumbDir .= "/$resize";
	    mkdir $thumbDir unless -d $thumbDir;

	    &TWiki::Func::writeDebug( "- running CONVERT" ) if $debug;
	    system( qq{$CONVERT -sample $resize $options  "$fn" "$thumb"} );
	}
}


sub _formatImageSRC {
   my ($inr, $web, $topic, $i, $width, $height, $settings) = @_;
   my $ans;
   if($columns && (($inr-1)%$columns==0 || $inr==1)){ # row start
 	    $ans = &_replaceVars($rowstart, $i, $web, $topic, $resize, $width, $height, $inr);
   }else{	# inside row
	    $ans = &_replaceVars($rowinside, $i, $web, $topic, $resize, $width, $height, $inr);
   }
   $ans .= &_replaceVars($format, $i, $web, $topic, $resize, $width, $height, $inr);
	# row end
   if $columns && ($inr%$columns==0) {
	  $ans .= &_replaceVars($rowend, $i, $web, $topic, $resize, $width, $height, $inr) 
   }
   return $ans;
}


=pod
 complete incomplete last row, needed for tables!!
=cut
sub _completeAnyUnfinishedTables {
   my ($inr, $web, $topic, $width, $height, $settings) = @_;
 # finish columns
   while($inr%$columns!=0) {
 	 $t .= &_replaceVars($settings->{rowinsideempty}, undef, $web, $topic, $resize, '', '', $inr);
 	 $inr++;
   } 

 # empty end row 
   $t .= &_replaceVars($settings->{rowendempty}, undef, $web, $topic, $resize, '', '', $inr);
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
