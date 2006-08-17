# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 Craig Meyer, meyercr@gmail.com
# Copyright (C) 2006 MichaelDaum@WikiRing.com
#
# Based on ImgPlugin
# Copyright (C) 2006 Meredith Lesly, msnomer@spamcop.net
#
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
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::ImagePlugin::Core;

use strict;
use Image::Magick;

use vars qw(
  $debug $frameFormat $linkFormat $simpleFormat 
  $magnifyFormat $captionFormat $floatFormat
  $clearFormat
);

$debug = 0; # toggle me

# SMELL: become plugin preference values
$linkFormat = 
  '<a id="$id" class="imageLink" href="$href" title="$title">$text</a>';

$simpleFormat = 
  '<a href="$href" id="$id" class="imageSimple $class" title="$title" style="$style">'.
    '<image border="0" align="absmiddle" src="$src" alt="$alt" width="$width" height="$height" longdesc="$desc" onmouseover="$mousein" onmouseout="$mouseout" />'.
  '</a>';
  
$frameFormat = 
  '<div id="$id" class="imageFrame imageFloat_$align" style="_width:$framewidthpx;max-width:$framewidthpx;$style">'.
    '<a href="$href" class="imageHref" title="$title">'.
      '<image border="0" align="absmiddle" src="$src" alt="$alt" width="$width" height="$height" longdesc="$desc" onmouseover="$mousein" onmouseout="$mouseout" />'.
    '</a>'.
    '$captionFormat'.
  '</div>';

$floatFormat = 
  '<div id="$id" class="imageFloat imageFloat_$align" style="$style">'.
    '<a href="$href" class="imageHref" title="$title">'.
      '<image border="0" align="absmiddle" src="$src" alt="$alt" width="$width" height="$height" longdesc="$desc" onmouseover="$mousein" onmouseout="$mouseout" />'.
    '</a>'.
    '$captionFormat'.
  '</div>';

$clearFormat =
  '<br id="$id" class="imageClear" clear="all" />';
 
# helper formats
$captionFormat =
  '<div class="imageCaption">$caption</div>';

$magnifyFormat =
  '<div class="imageMagnify">'.
    '<a href="$href" title="Enlarge">'.
      '<image bordeR="0" align="absmiddle" src="$magnifyIcon" width="$magnifyWidth" height="$magnifyHeight" alt="Enlarge" />'.
    '</a>'.
  '</div>';

###############################################################################
# static
sub writeDebug {
  &TWiki::Func::writeDebug("ImagePlugin - $_[0]") if $debug;
  #print STDERR "ImagePlugin - $_[0]\n" if $debug;
}

###############################################################################
# ImageCore constructor
sub new {
  my ($class, $baseWeb, $baseTopic) = @_;
  my $this = bless({}, $class);

  $this->{magnifyIcon} = 
    TWiki::Func::getPluginPreferencesValue('IMAGEPLUGIN_MAGNIFY_ICON') ||
    '%PUBURLPATH%/%TWIKIWEB%/ImagePlugin/magnify-clip.png';
  $this->{magnifyWidth} = 15; # TODO: make this configurable/autodetected/irgnored
  $this->{magnifyHeight} = 11; # TODO: make this configurable/autodetected/irgnored

  $this->{thumbSize} = 
    TWiki::Func::getPluginPreferencesValue('THUMBNAIL_SIZE') || 180;
  $this->{albumTopic} = TWiki::Func::getPreferencesValue('IMAGEALBUM') || '';
  $this->{baseWeb} = $baseWeb;
  $this->{baseTopic} = $baseTopic;
  $this->{mage} = undef;
  $this->{errorMsg} = ''; # from image mage
  $this->{albumWeb} = '';

  if ($this->{albumTopic}) {
    ($this->{albumWeb}, $this->{albumTopic}) = 
      TWiki::Func::normalizeWebTopicName($baseWeb, $this->{albumTopic});
  }

  #writeDebug("IMAGEALBUM=$this->{albumWeb}.$this->{albumTopic}");

  return $this;
}

###############################################################################
sub handleIMAGE {
  my($this, $session, $params, $theTopic, $theWeb) = @_;

  #writeDebug("called handleIMAGE(params, $theTopic, $theWeb)");

  if($params->{_DEFAULT} =~ m/clr|clear/i ){ # SMELL: non-documented feature
    return $clearFormat;
  }

  # read parameters
  my $argsStr = $params->{_DEFAULT} || '';
  $argsStr =~ s/^\[\[//o;
  $argsStr =~ s/\]\]$//o;
  $params->{type} ||= '';
  $this->parseWikipediaParams($params, $argsStr);

  # default and fix parameters
  $params->{size} ||= '';
  $params->{width} ||= '';
  $params->{height} ||= '';
  if ($params->{size} =~ /^(\d+)(px)?x?(\d+)?(px)?$/) {
    $params->{size} = $3?"$1x$3":$1;
  }

  my $origFile = $params->{file} || $params->{_DEFAULT};
  my $imgWeb = $params->{web} || $this->{albumWeb} || $theWeb;
  my $imgTopic = $params->{topic} || $this->{albumTopic} || $theTopic;
  ($imgWeb, $imgTopic) = TWiki::Func::normalizeWebTopicName($imgWeb, $imgTopic);

  #writeDebug("origFile=$origFile, imgWeb=$imgWeb, imgTopic=$imgTopic");

  $params->{caption} ||= '';
  $params->{align} ||= 'right';
  my $pubUrlPath = TWiki::Func::getPubUrlPath();
  my $origFileUrl = $pubUrlPath.'/'.$imgWeb.'/'.$imgTopic.'/'.$origFile;
  $params->{alt} ||= $origFile;
  $params->{class} ||= '';
  $params->{title} ||= $params->{caption} || $origFile;
  $params->{desc} ||= $params->{title};
  $params->{footer} ||= '';
  $params->{header} ||= '';
  $params->{href} ||= $origFileUrl;
  $params->{id} ||= '';
  $params->{mousein} ||= '';
  $params->{mouseout} ||= '';
  $params->{style} ||= '';
  $params->{type} = 'thumb' if $params->{type} eq 'thumbnail';

  #writeDebug("type=$params->{type}, align=$params->{align}");
  #writeDebug("size=$params->{size}, width=$params->{width}, height=$params->{height}");

  # compute image
  my $imgInfo = 
    $this->getImageInfo($imgWeb, $imgTopic, $origFile, 
      $params->{size}, $params->{width}, $params->{height});

  unless ($imgInfo) {
    return "<span class=\"twikiAlert\">$this->{errorMsg}</span>";
  }
  my $thumbFileUrl = $pubUrlPath.'/'.$imgWeb.'/'.$imgTopic.'/'.$imgInfo->{file};

  # format result
  my $result = $params->{format} || '';
  if (!$result) {
    if ($params->{type} eq 'simple') {
      $result = $simpleFormat;
    } elsif ($params->{type} eq 'link') {
      $result = $linkFormat;
    } elsif ($params->{type} eq 'frame') {
      $result = $frameFormat;
      $result =~ s/\$captionFormat/$captionFormat/g 
	if $params->{caption};
    } elsif ($params->{type} eq 'thumb') {
      $result = $frameFormat; 
      my $thumbCaption = $params->{caption}.$magnifyFormat;
      $result =~ s/\$captionFormat/$captionFormat/g;
      $result =~ s/\$caption/$thumbCaption/g;
    } else {
      $result = $floatFormat;
      $result =~ s/\$captionFormat/$captionFormat/g 
	if $params->{caption};
    }
  }

  $result =  $params->{header}.$result.$params->{footer};
  $result =~ s/\$captionFormat//g;

  $result =~ s/\$caption/$params->{caption}/g;
  $result =~ s/\$magnifyFormat/$magnifyFormat/g;
  $result =~ s/\$magnifyIcon/$this->{magnifyIcon}/g;
  $result =~ s/\$magnifyWidth/$this->{magnifyWidth}/g;
  $result =~ s/\$magnifyHeight/$this->{magnifyHeight}/g;

  $result =~ s/\$mousein/$params->{mousein}/g;
  $result =~ s/\$mouseout/$params->{mouseout}/g;
  $result =~ s/\$href/$params->{href}/g;
  $result =~ s/\$src/$thumbFileUrl/g;
  $result =~ s/\$height/$imgInfo->{height}/g;
  $result =~ s/\$width/$imgInfo->{width}/g;
  $result =~ s/\$origsrc/$origFileUrl/g;
  $result =~ s/\$origheight/$imgInfo->{origHeight}/g;
  $result =~ s/\$origwidth/$imgInfo->{origWidth}/g;
  $result =~ s/\$framewidth/($imgInfo->{width}+2)/ge;
  $result =~ s/\$text/$origFile/g;
  $result =~ s/\$class/$params->{class}/g;
  $result =~ s/\$id/$params->{id}/g;
  $result =~ s/\$style/$params->{style}/g;
  $result =~ s/\$align/$params->{align}/g;
  $result =~ s/\$alt/$params->{alt}/g;
  $result =~ s/\$title/$params->{title}/g;
  $result =~ s/\$desc/$params->{desc}/g;

  $result =~ s/\$dollar/\$/go;
  $result =~ s/\$percnt/\%/go;
  $result =~ s/\$n/\n/go;
  $result =~ s/\$nop//go;

  # recursive call for delayed TML expansion
  $result = &TWiki::Func::expandCommonVariables($result, $theTopic, $theWeb);
  return $result; 
} 

###############################################################################
# get info about the image and its thumbnail cousin, resize source image if
# a $size was specified, returns a pointer to a hash with the following entries:
#    * file: the name of the source file or its thumbnail 
#    * width: width of the imgInfo{file}
#    * heith: heith of the imgInfo{file}
#    * origFile: the name of the source image
#    * origWidth: width of the source image
#    * origHeight: height of the source image
# returns undef on error
sub getImageInfo {
  my ($this, $imgWeb, $imgTopic, $imgFile, $size, $width, $height) = @_;

  #writeDebug("called getImageInfo($imgWeb, $imgTopic, $imgFile, $size, $width, $height)");

  unless ($this->{mage}) {
    $this->{mage} = new Image::Magick;
  }
  
  $this->{errorMsg} = '';

  my %imgInfo;
  $imgInfo{file} = $imgFile;
  $imgInfo{origFile} = $imgFile;

  my $imgPath = TWiki::Func::getPubDir().'/'.$imgWeb.'/'.$imgTopic;
  ($imgInfo{origWidth}, $imgInfo{origHeight}) = $this->{mage}->Ping($imgPath.'/'.$imgFile);

  if ($size || $width || $height) {
    my $newImgFile = "_${size}_${width}_${height}_$imgFile";

    if (-f $imgPath.'/'.$newImgFile) { # cached
      ($imgInfo{width}, $imgInfo{height}) = $this->{mage}->Ping($imgPath.'/'.$newImgFile);
    } else { 
      
      # read
      my $error = $this->{mage}->Read($imgPath.'/'.$imgFile);
      if ($error =~ /(\d+)/) {
	$this->{errorMsg} = $error;
	return undef if $1 >= 400;
      }
      
      # scale
      my %args;
      $args{geometry} = $size if $size;
      $args{width} = $width if $width;
      $args{height} = $height if $height;
      $error = $this->{mage}->Scale(%args);
      if ($error =~ /(\d+)/) {
	$this->{errorMsg} = $error;
	return undef if $1 >= 400;
      }
      
      # write
      $error = $this->{mage}->Write($imgPath.'/'.$newImgFile);
      if ($error =~ /(\d+)/) {
	$this->{errorMsg} .= " $error";
	return undef if $1 >= 400;
      }
      ($imgInfo{width}, $imgInfo{height}) = $this->{mage}->Get('width', 'height');

      # forget
      my $mage = $this->{mage};
      @$mage = (); 
    }
    $imgInfo{file} = $newImgFile;
  } else {
    $imgInfo{width} = $imgInfo{origWidth};
    $imgInfo{height} = $imgInfo{origHeight};
  }
  
  return \%imgInfo;
} 

###############################################################################
# sets type (link,frame,thumb), file, width, height, size, caption
sub parseWikipediaParams {
  my ($this, $params, $argStr) = @_;

  my ($file, @args) = split(/\|/, $argStr);
  $params->{type} = 'link' if $file =~ s/^://o;
  $params->{file} = $file;

  foreach my $arg (@args) {
    $arg =~ s/^\s+//o;
    $arg =~ s/\s+$//o;
    if ($arg =~ /^(right|left|center|none)$/i ) {
      $params->{align} = $1 unless $params->{align};
    } elsif ($arg =~ /^frame$/i) {
      $params->{type} = 'frame';
    } elsif ($arg =~ m/^thumb(nail)?$/i) {
      $params->{type}= 'thumb' unless $params->{type};
    } elsif ($arg =~ /^(\d+)px$/i) {
      $params->{size} = $1 unless $params->{size};
    } elsif ($arg =~ /^w(\d+)px$/i) {
      $params->{width} = $1 unless $params->{width};
    } elsif ($arg =~ /^h(\d+)px$/i) {
      $params->{height} = $1 unless $params->{height};
    } else {
      $params->{caption} = $arg unless $params->{caption};
    }
  }
  $params->{type} = 'simple' if !$params->{align} && !$params->{type};
  $params->{size} = $this->{thumbSize}
    if $params->{type} eq 'thumb' && !$params->{size};
}


###############################################################################
1;
