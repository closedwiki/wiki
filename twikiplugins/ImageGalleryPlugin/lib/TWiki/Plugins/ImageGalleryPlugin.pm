#! perl -w
use strict;
#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2002-2005 Will Norris. All Rights Reserved. (wbniv@saneasylumstudios.com)
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

use Data::Dumper qw( Dumper );

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $debug
        $IMAGE_MAGICK $CONVERT $IDENTIFY $CONVERT_OPTIONS 
    );

$VERSION = '1.11';

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
    $IMAGE_MAGICK = TWiki::Func::getPreferencesValue( "IMAGEGALLERYPLUGIN_IMAGE_MAGICK" ) || "/usr";
    $CONVERT = TWiki::Func::getPreferencesValue( "IMAGEGALLERYPLUGIN_CONVERT" ) || "$IMAGE_MAGICK/bin/convert";
    $IDENTIFY = TWiki::Func::getPreferencesValue( "IMAGEGALLERYPLUGIN_IDENTIFY" ) || "$IMAGE_MAGICK/bin/identify";
    $CONVERT_OPTIONS = TWiki::Func::getPreferencesValue('IMAGEGALLERYPLUGIN_CONVERT_OPTIONS');

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "IMAGEGALLERYPLUGIN_DEBUG" ) || 0;

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
#    3 for each attachment _$attachment_ (does it check to ensure Image type?), it:
#       a finds the dimensions of the image (using IMAGEGALLERYPLUGIN_IDENTIFY)
#            (it aborts this attachment in the results if it cannot find the dimension)
#       b adds to $t the image <IMG SRC> pointer; this is subject to formatting into columns and rows
#    4 returns the buffer
sub handleImageGallery
{
    my( $attributes ) = @_;
#    return '<b>IMAGE(' . $settings->{topic} . ")</b>\n";

    my $settings = {
       size => scalar &TWiki::Func::extractNameValuePair( $attributes, "size" ) || 'medium',
       topic => scalar TWiki::Func::extractNameValuePair( $attributes ) || scalar TWiki::Func::extractNameValuePair( $attributes, "topic" ) || $topic,
       web => scalar &TWiki::Func::extractNameValuePair( $attributes, "web" ) || $web,
       columns => scalar &TWiki::Func::extractNameValuePair( $attributes, "columns" ) || '0',
       rowstart => scalar &TWiki::Func::extractNameValuePair( $attributes, "rowstart" ) || '',
       rowinside => scalar &TWiki::Func::extractNameValuePair( $attributes, "rowinside" ) || '',
       rowend => scalar &TWiki::Func::extractNameValuePair( $attributes, "rowend" ) || '',
       rowinsideempty => scalar &TWiki::Func::extractNameValuePair( $attributes, "rowinsideempty" ) || '',
       rowendempty => scalar &TWiki::Func::extractNameValuePair( $attributes, "rowendempty" ) || '',
       options => scalar &TWiki::Func::extractNameValuePair( $attributes, "options" ) || $CONVERT_OPTIONS,
       format => scalar &TWiki::Func::extractNameValuePair( $attributes, "format")
    	|| q(<span class="imgGallery"><a href="$imageurl"><img src="$thumburl" title="$sizeK: $comment"/></a></span>$n),
       max => scalar &TWiki::Func::extractNameValuePair( $attributes, "max") || 0,
    };
       $settings->{resize} = TWiki::Func::getPreferencesValue( uc "IMAGEGALLERYPLUGIN_$settings->{size}" ) || $settings->{size};

    my @topics = $settings->{topic} eq 'all' && TWiki::Func::getTopicList() || ( $settings->{topic} );
    my $output = '';
    foreach my $wantedTopic (@topics) {
	$settings->{topic} = $wantedTopic;
       my ( $meta, undef ) = &TWiki::Func::readTopic( $settings->{web}, $wantedTopic );
       $output .= _formatTMLforTopic( $settings->{web}, $wantedTopic, $meta, $settings );
    }
    return $output;
}

# Potentially we could provide a topic name/other-attribute(e.g. form) filter...
sub _getTopics {
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
    my $max = $settings->{max};

    foreach my $attachment (@attachments) {
    
      last if ($max > 0 and $imageNumber >= $max);

      $attachment->{humanReadableSize} = sprintf( "%dk", $attachment->{size}/1024 );

	  my $filename = &TWiki::Func::getPubDir() . "/$web/$topic/$attachment->{name}";
      &TWiki::Func::writeDebug( Dumper( $attachment ) ) if $debug;

	  next unless (my $dimensions = `"$IDENTIFY" "$filename"`) =~
	    m/(\d+)x(\d+)/; # fix, else don't work for jpg, png ...!
	    #m/(\d+)x(\d+)\+(\d+)\+(\d+)/;
      my ( $width, $height ) = ( $1, $2 );
      
	  $imageNumber++;
      $t .= _formatImageSRC($imageNumber, $web, $topic, $attachment, $width, $height, $settings );
      _updateThumb( $filename, my $thumb = &TWiki::Func::getPubDir() . "/$web/$topic/thumbs/$settings->{resize}/$attachment->{name}", $settings );  # SMELL - might want to do this periodically?
    } 
    
    if ($settings->{columns} && ($imageNumber>0)) {
      $t .= _completeAnyUnfinishedTables($imageNumber, $web, $topic, $settings->{width}, $settings->{height}, $settings);
    }

    return $t;
}

sub _updateThumb {
   my ($fn, $thumb, $settings) = @_;
   my $resize = $settings->{resize};
   my $options = $settings->{options};
   
   TWiki::Func::writeDebug( "thumb=[$thumb] fn=[$fn]" ) if $debug;
   unless ( ( -M $thumb ) && ( -M $fn > -M $thumb ) )
	{   # only update the thumbnail if (1) it doesn't exist or (2) the thumbnail is older than the source image
	    my $thumbDir = &TWiki::Func::getPubDir() . "/$settings->{web}/$settings->{topic}/thumbs";
	    mkdir $thumbDir unless -d $thumbDir;
	    $thumbDir .= "/$resize";
	    mkdir $thumbDir unless -d $thumbDir;

	    my $cmdThumbnail = qq{$CONVERT -sample $resize $options  "$fn" "$thumb"};
	    TWiki::Func::writeDebug( "settings: " . Dumper( $settings ) ) if $debug;

	    &TWiki::Func::writeDebug( "- running CONVERT [$CONVERT] [$cmdThumbnail] - options=[$options]" ) if $debug;
	    system( $cmdThumbnail );
	}
}


sub _formatImageSRC {
   my ($inr, $web, $topic, $i, $width, $height, $settings) = @_;
   my $ans;
   if($settings->{columns} && (($inr-1)%$settings->{columns}==0 || $inr==1)){ # row start
 	    $ans = &_replaceVars($settings->{rowstart}, $i, $web, $topic, $settings->{resize}, $width, $height, $inr);
   }else{	# inside row
	    $ans = &_replaceVars($settings->{rowinside}, $i, $web, $topic, $settings->{resize}, $width, $height, $inr);
   }
   $ans .= &_replaceVars($settings->{format}, $i, $web, $topic, $settings->{resize}, $width, $height, $inr);
	# row end
   if ($settings->{columns} && $inr%$settings->{columns}==0) {
	  $ans .= &_replaceVars($settings->{rowend}, $i, $web, $topic, $settings->{resize}, $width, $height, $inr) 
   }
   return $ans;
}


=pod
 complete incomplete last row, needed for tables!!
=cut
sub _completeAnyUnfinishedTables {
   my ($inr, $web, $topic, $width, $height, $settings) = @_;
 # finish columns
   my $t = '';
   while($inr%$settings->{columns}!=0) {
 	 $t .= &_replaceVars($settings->{rowinsideempty}, undef, $web, $topic, $settings->{resize}, '', '', $inr);
 	 $inr++;
   } 

 # empty end row 
   $t .= &_replaceVars($settings->{rowendempty}, undef, $web, $topic, $settings->{resize}, '', '', $inr);
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
	$format =~ s/\$username/TWiki::Func::wikiToUserName($img->{user})/geos;
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
    $format ||= '$day $mon $year - $hour:$min';		# Default format, e.g. "31 Dec 2002 - 19:30"
    my $value = "";

    my( $sec, $min, $hour, $day, $mon, $year ) = localtime( $time );
    $year = sprintf( "%.4u", $year + 1900 );
    use constant ISOMONTH => qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
    my $tmon = (ISOMONTH)[$mon];

    $value = $format;
    $value =~ s/\$sec[o]?[n]?[d]?[s]?/sprintf("%.2u",$sec)/geoi;
    $value =~ s/\$min[u]?[t]?[e]?[s]?/sprintf("%.2u",$min)/geoi;
    $value =~ s/\$hou[r]?[s]?/sprintf("%.2u",$hour)/geoi;
    $value =~ s/\$day/sprintf("%.2u",$day)/geoi;
    $value =~ s/\$mon[t]?[h]?/$tmon/goi;
    $value =~ s/\$mo/sprintf("%.2u",$mon+1)/geoi;
    $value =~ s/\$yea[r]?/$year/goi;
    $value =~ s/\$ye/sprintf("%.2u",$year%100)/geoi;

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
