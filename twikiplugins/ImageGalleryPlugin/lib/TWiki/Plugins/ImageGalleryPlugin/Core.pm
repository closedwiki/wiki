#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2002-2003 Will Norris. All Rights Reserved. (wbniv@saneasylumstudios.com)
# Copyright (C) 2005 Michael Daum <micha@nats.informatik.uni-hamurg.de>
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
package TWiki::Plugins::ImageGalleryPlugin::Core;

use strict;

# =========================
# constructor
sub new {
  my ($class, $id, $topic, $web) = @_;
  my $this = bless({}, $class);

  eval 'use Image::Magick;';

  # init
  $this->{id} = $id;
  $this->{query} = &TWiki::Func::getCgiQuery();
  $this->{debug} = 0;
  $this->{mage} = new Image::Magick;
  $this->{isDakar} = defined $TWiki::cfg{MimeTypesFileName};
  $this->{topic} = $topic;
  $this->{web} = $web;
  $this->{doRefresh} = 0;
  $this->{errorMsg} = ''; # from image mage
  
  # get style url
  my $hostUrl = ($this->{isDakar})? $TWiki::cfg{DefaultUrlHost}:$TWiki::defaultUrlHost;
    
  $this->{styleUrl} = TWiki::Func::getPreferencesValue("IMAGEGALLERYPLUGIN_STYLE") ||
    $hostUrl .  &TWiki::Func::getPubUrlPath() . "/" . &TWiki::Func::getTwikiWebname() . 
    "/ImageGalleryPlugin/style.css";

  # get image mimes
  my $mimeTypesFilename = ($this->{isDakar})?
    $TWiki::cfg{MimeTypesFileName}:$TWiki::mimeTypesFilename;
  my $fileContent = &TWiki::Func::readFile($mimeTypesFilename);
  $this->{isImageSuffix} = ();
  foreach my $line (split(/\r?\n/, $fileContent)) {
    next if $line =~ /^#/;
    next if $line =~ /^$/;
    next unless $line =~ /^image/;# only image types
    next unless $line =~ /^\s*[^\s]+\s+(.*)\s*$/;
    foreach my $suffix (split(/ /, $1)) {
      $this->{isImageSuffix}{$suffix} = 1;
    }
  }

  my $topicPubDir = $this->normalizeFileName(&TWiki::Func::getPubDir() . "/$web/$topic");
  mkdir $topicPubDir unless -d $topicPubDir;

  if ($this->{id}) {
    $this->{igpDir} = $this->normalizeFileName("$topicPubDir/igp$this->{id}");
    mkdir $this->{igpDir} unless -d $this->{igpDir};

    $this->{igpPubUrl} = &TWiki::Func::getPubUrlPath() .
      "/$this->{web}/$this->{topic}/igp$this->{id}";
    $this->{infoFile} = $this->normalizeFileName("$this->{igpDir}/info.txt");
  }

  return $this;
}

# =========================
sub debug {
  my $this = shift;

  $this->{debug} = shift if @_;
  return $this->{debug};
}

# =========================
# debug logger
sub writeDebug {
  my $this = shift;
  return unless $this->{debug};
  &TWiki::Func::writeDebug("ImageGallery - $_[0]");
}

# =========================
# test if a file is an image
sub isImage {
  my ($this, $attachment) = @_;

  my $suffix = '';
  if ($attachment->{name} =~ /\.(.+)$/) {
    $suffix = lc($1);
  }

  return defined $this->{isImageSuffix}{$suffix};
}

# =========================
sub init {
  my ($this, $args) = @_;

  $args = '' unless $args;
  $this->writeDebug("init($args) called");
  
  # read attributes
  $this->{size} = &TWiki::Func::extractNameValuePair($args, "size") || 'medium';
  my $thumbsize = TWiki::Func::getPreferencesValue(uc "IMAGEGALLERYPLUGIN_$this->{size}") 
    || $this->{size};
  my $thumbwidth = 95;
  my $thumbheight = 95;
  if ($thumbsize =~ /^(.*)x(.*)$/) {
    $thumbwidth = $1;
    $thumbheight = $2;
  } elsif ($thumbsize =~ /^x(.*)$/) {
    $thumbwidth = $1;
    $thumbheight = $1;
  } elsif ($thumbsize =~ /^(.*)x$/) {
    $thumbwidth = $1;
    $thumbheight = $1;
  }
  $this->{thumbwidth} = $thumbwidth;
  $this->{thumbheight} = $thumbheight;

  $this->writeDebug("size=$this->{size} thumbsize=$thumbsize thumbwidth=$thumbwidth thumbheight=$thumbheight");
  
  my $topics = 
    &TWiki::Func::extractNameValuePair($args) 
    || &TWiki::Func::extractNameValuePair($args, "topic") 
    || &TWiki::Func::extractNameValuePair($args, "topics") 
    || "$this->{web}.$this->{topic}";

  $this->{topics} = undef;
  
  # normalize topic names
  my $topicRegex = &TWiki::Func::getRegularExpression('mixedAlphaNumRegex');
  my $webRegex = &TWiki::Func::getRegularExpression('webNameRegex');
  foreach my $theTopic (split(/,\s*/, $topics)) {
    my $theWeb;
    if ($theTopic =~ /^($webRegex)\.($topicRegex)$/) {
      $theWeb = $1;
      $theTopic = $2;
    } elsif ($theTopic =~ /^($topicRegex)$/) {
      $theWeb = $this->{web};
    } else {
      $this->writeDebug("oops, skipping $theTopic");
      next;
    }
    push @{$this->{topics}}, "$theWeb.$theTopic";
  }

  if (!$this->{topics}) {
    $this->writeDebug("oops, no topics found");
    return 0;
  }
  $this->writeDebug("topics=" . join(", ", @{$this->{topics}}));


  $this->{columns} = &TWiki::Func::extractNameValuePair($args, "columns") || 4;

  $this->{doDocRels} = &TWiki::Func::extractNameValuePair($args, "docrels") || 1;
  $this->{doDocRels} = ($this->{doDocRels} eq "off")?0:1;

  $this->{maxheight} = &TWiki::Func::extractNameValuePair($args, "maxheight") || 480;
  $this->{maxwidth} = &TWiki::Func::extractNameValuePair($args, "maxwidth") || 640;
  
  $this->{minheight} = &TWiki::Func::extractNameValuePair($args, "minheight") || 0;
  $this->{minheight} = $this->{maxheight} if $this->{minheight} > $this->{maxheight};
  
  $this->{minwidth} = &TWiki::Func::extractNameValuePair($args, "minwidth") || 0;
  $this->{minwidth} = $this->{maxwidth} if $this->{minwidth} > $this->{maxwidth};

  $this->{format} = &TWiki::Func::extractNameValuePair($args, "format") || 
      '<a href="$origurl"><img src="$imageurl" title="$comment" width="$width" height="$height"/></a>';

  $this->{title} = &TWiki::Func::extractNameValuePair($args, "title") || '$comment ($imgnr/$nrimgs)&nbsp;$reddot';
  $this->{doTitles} = ($this->{title} eq 'off')?0:1;

  $this->{thumbtitle} = &TWiki::Func::extractNameValuePair($args, "thumbtitle") || '$comment&nbsp;$reddot';
  $this->{doThumbTitles} = ($this->{thumbtitle} eq 'off')?0:1;

  $this->{titles} = &TWiki::Func::extractNameValuePair($args, "titles");
  if ($this->{titles}) {
    $this->{doTitles} = ($this->{titles} eq 'off')?0:1;
    $this->{doThumbTitles} = $this->{doTitles};
  }

  my $refresh = $this->{query}->param("refresh") || '';
  $this->{doRefresh} = ($refresh eq 'on')?1:0;

  return 1;
}

# =========================
# main 
sub render {
  my ($this, $args) = @_;

  if (!$this->init($args)) {
    return &renderError("can't initialize from '$args'");
  }

  $this->getImages();
  $this->readInfo();

  # delete lost images
  foreach my $entry (values %{$this->{info}}) {
    next if $entry->{type} eq 'global';
    my $found = 0;
    foreach my $image (@{$this->{images}}) {
      if ($image->{name} eq $entry->{name}) {
	$found = 1;
	last;
      }
    }
    next if $found;
    my $img = "$this->{igpDir}/$entry->{name}";
    my $thumb = "$this->{igpDir}/thumb_$entry->{name}";

    $img = $this->normalizeFileName($img);
    $thumb = $this->normalizeFileName($thumb);

    unlink $img;
    unlink $thumb;

    delete $this->{info}{$entry->{name}};
  }


  # check for changes
  $this->{infoChanged} = 1
    if !$this->{info}{thumbwidth} || 
      !$this->{info}{thumbheight} || 
      !$this->{info}{topics} ||
      $this->{info}{thumbwidth}{value} ne $this->{thumbwidth} ||
      $this->{info}{thumbheight}{value} ne $this->{thumbheight} ||
      join(', ', $this->{info}{topics}{value}) ne join(', ', @{$this->{topics}});

  my $result = "<div class=\"igp\"><a name=\"igp$this->{id}\"/>";

  # get filename query string
  my $filename = $this->{query}->param("filename");
  my $id = $this->{query}->param("id") || '';

  if ($id eq $this->{id} && $filename) {
    # picture mode
    $result .= $this->renderImage($filename);
  } else {
    # thumbnails mode
    $result .= $this->renderThumbnails();
  }

  # add style
  $result .= "</div><style type=\"text/css\">\@import url(\"$this->{styleUrl}\");</style>\n";

  $this->writeInfo();
  return $result;
}

# =========================
# display one image
sub renderImage {
  my ($this, $filename) = @_;

  $this->writeDebug("renderImage($filename)");

  my $result = '';

  my $firstFile;
  my $lastFile;
  my $nextFile;
  my $thisImage;
  my $prevFile;

  my $state = 0;

  # find the first, prev, this, next and last image in the list
  # relative to the current filename
  foreach my $image (@{$this->{images}}) {
    $state = 3 if $state == 2;
    $state = 2 if $state == 1;
    $state = 1 if $image->{name} eq $filename; 
    
    $firstFile = $image->{name} if ! $firstFile;
    $prevFile = $image->{name} if $state == 0;
    $thisImage = $image if $state == 1;
    $nextFile = $image->{name} if $state == 2;
    $lastFile = $image->{name};
  }
  return &renderError("unknown file $filename") if !$thisImage;

  my $viewUrl = &TWiki::Func::getViewUrl($this->{web}, $this->{topic});

  # document relations
  if ($this->{doDocRels}) {
    $result .=
	"<link rel=\"parent\" href=\"$viewUrl\" title=\"Thumbnails\" />\n";
    if ($firstFile && $firstFile ne $filename) {
      $result .=
	  "<link rel=\"first\" href=\"$viewUrl?id=$this->{id}&filename=$firstFile#igp$this->{id}\" title=\"$firstFile\" />\n";
    }
    if ($lastFile && $lastFile ne $filename) {
      $result .=
	  "<link rel=\"last\" href=\"$viewUrl?id=$this->{id}&filename=$lastFile#igp$this->{id}\" title=\"$lastFile\" />\n";
    }
    if ($nextFile && $lastFile ne $filename) {
      $result .=
	  "<link rel=\"next\" href=\"$viewUrl?id=$this->{id}&filename=$nextFile#igp$this->{id}\" title=\"$nextFile\" />\n";
    }
    if ($prevFile && $firstFile ne $filename) {
      $result .=
	"<link rel=\"previous\" href=\"$viewUrl?id=$this->{id}&filename=$prevFile#igp$this->{id}\" title=\"$prevFile\" />\n";
    }
  }

  # collect image information
  $this->computeImageSize($thisImage);
  if (!$this->createImg($thisImage)) {
    return &renderError($this->{errorMsg});
  }

  # title
  if ($this->{doTitles}) {
    $result .= "<div class=\"igpPictureTitle\"><h2>"
      . $this->replaceVars($this->{title}, $thisImage)
      . "</h2></div>\n";
  }

  # layout img table
  $result .= "<table class=\"igpPictureTable\">\n";

  # navi
  $result .= "<tr><td class=\"igpNavigation\">";
  if ($firstFile && $firstFile ne $filename) {
    $result .= "<a href=\"$viewUrl?id=$this->{id}&filename=$firstFile#igp$this->{id}\">first</a>";
  } else {
    $result .= "first";
  }
  $result .= ' | ';
  if ($prevFile) {
    $result .= "<a href=\"$viewUrl?id=$this->{id}&filename=$prevFile#igp$this->{id}\">prev</a>";
  } else {
    $result .= "prev";
  }
  $result .= " | [[$this->{web}.$this->{topic}][up]] | ";
  if ($nextFile) {
    $result .= "<a href=\"$viewUrl?id=$this->{id}&filename=$nextFile#igp$this->{id}\">next</a>";
  } else {
    $result .= "next";
  }
  $result .= ' | ';
  if ($lastFile && $lastFile ne $filename) {
    $result .= "<a href=\"$viewUrl?id=$this->{id}&filename=$lastFile#igp$this->{id}\">last</a>";
  } else {
    $result .= "last";
  }
  $result .= "</td></tr>\n";

  # img
  $result .= "<tr><td class=\"igpPicture\">" 
    . $this->replaceVars($this->{format}, $thisImage)
    . "</td></tr></table>\n";

  return $result;
}

# =========================
sub renderThumbnails {

  my $this = shift;

  $this->writeDebug("renderThumbnails()");

  if (!@{$this->{images}}) {
    my $msg = "no images found";
    $this->writeDebug($msg);
    return &renderError($msg); 
  }

  my $maxCols = $this->{columns};
  my $result = "<div class=\"igpThumbNails\"><table class=\"igpThumbNailsTable\"><tr>\n";
  my $imageNr = 0;
  my @rowOfImages = ();
  foreach my $image (@{$this->{images}}) {
    $this->computeImageSize($image);

    if ($this->{doThumbTitles}) {
      push @rowOfImages, $image;
    }

    $result .= "<td width=\"" . (100 / $maxCols) . "%\" class=\"igpThumbNail\"><a href=\""
      .  &TWiki::Func::getScriptUrl($this->{web}, $this->{topic}, "view")
      . "?id=$this->{id}&filename=$image->{name}#igp$this->{id}\">"
      . "<img src=\"$this->{igpPubUrl}/thumb_$image->{name}\" "
      . "title=\"$image->{IGP_comment}\" alt=\"$image->{name}\"/></a></td>\n";

    if (!$this->createImg($image, 1)) {
      return &renderError($this->{errorMsg});
    }

    $imageNr++;
    if ($imageNr % $maxCols == 0) {
      $result .= "</tr>\n";
      if ($this->{doThumbTitles}) {
	$result .= $this->renderTitleRow(\@rowOfImages);
	@rowOfImages = ();
      }
    }
  }
  while ($imageNr % $maxCols != 0) {
    $result .= "<td>&nbsp;</td>\n";
    $imageNr++;
  }
  $result .= "</tr>\n";
  if ($this->{doThumbTitles}) {
    $result .= $this->renderTitleRow(\@rowOfImages);
  }
  $result .= "</table></div>\n";

  return $result;
}

# =========================
sub renderTitleRow {

  my ($this, $images) = @_;
  
  my $result = '<tr>';

  my $imageNr = 0;
  foreach my $image (@$images) {
    $result .= 
      "<td class=\"igpThumbNailTitle\">" . 
      $this->replaceVars($this->{thumbtitle}, $image) .
      "</td>\n";
    $imageNr++;
  }
  my $maxCols = $this->{columns};
  while ($imageNr % $maxCols != 0) {
    $result .= "<td>&nbsp;</td>";
    $imageNr++;
  }
  $result .= "</tr>\n";

  return $result;
}

# =========================
sub renderRedDot {
  my ($this, $image) = @_;

  return 
    "<span class=\"igpRedDot\"><a href=\"" 
    . &TWiki::Func::getScriptUrl($image->{IGP_web}, $image->{IGP_topic}, "attach")
    . "?filename=$image->{name}\">.</a></span>";
}

# =========================
sub getImages {
  my $this = shift;

  $this->writeDebug("getImages(" . join(', ', @{$this->{topics}}) . ") called");

  # collect images from all topics
  my $wikiUserName = &TWiki::Func::getWikiUserName();
  my $pubDir = &TWiki::Func::getPubDir();
  my $pubUrl = &TWiki::Func::getPubUrlPath();
  my $topicRegex = &TWiki::Func::getRegularExpression('mixedAlphaNumRegex');
  my $webRegex = &TWiki::Func::getRegularExpression('webNameRegex');
  my @images;
  my $imgnr = 1;
  foreach (@{$this->{topics}}) {
    my $webtopic= $_;
    my $theWeb;
    my $theTopic;
    if ($webtopic =~ /^($webRegex)\.($topicRegex)$/) {
      $theWeb = $1;
      $theTopic = $2;
    } else {
      $this->writeDebug("oops, skipping $webtopic");
      next;
    }
    $this->writeDebug("reading from $theWeb.$theTopic}");

    my $viewAccessOK = &TWiki::Func::checkAccessPermission("view", $wikiUserName, '', 
      $theTopic, $theWeb);

    if (!$viewAccessOK) {
      $this->writeDebug("no view access to ... skipping");
      next;
    }

    my ($meta, undef) = &TWiki::Func::readTopic($theWeb, $theTopic);

    foreach my $attachment ($meta->find('FILEATTACHMENT')) {
      next unless $this->isImage($attachment);
      my $image = $attachment;

      $image->{IGP_comment} = &getImageTitle($image);
      $image->{IGP_sizeK} = sprintf("%dk", $image->{size} / 1024);
      $image->{IGP_natnr} = $imgnr;
      $image->{IGP_topic} = $theTopic;
      $image->{IGP_web} = $theWeb;
      $image->{IGP_filename} = $this->normalizeFileName(
	$pubDir . "/$image->{IGP_web}/$image->{IGP_topic}/$image->{name}");
      $image->{IGP_url} = 
	$pubUrl . "/$image->{IGP_web}/$image->{IGP_topic}/$image->{name}";
      $imgnr++;
      if ($image->{IGP_comment} =~ /^([0-9]+)\s*-\s*(.*)$/) {
	$image->{IGP_imgnr} = $1;
	$image->{IGP_comment} = $2;
      }

      # check for file existence
      if (! -e $image->{IGP_filename}) {
	&TWiki::Func::writeWarning("attachment error in " .
	  "$image->{IGP_web}.$image->{IGP_topic}: " .
	  "no such file '$image->{IGP_filename}'");
	next;
      }
      
      push @images, $image;
    }
  }

  # order images
  my @sortedImages;

  # obey explicite image positioning
  foreach my $image (@images) {
    next unless $image->{IGP_imgnr};
    my $imgnr = $image->{IGP_imgnr};
    while ($sortedImages[$imgnr]) { # first come first serve
      $imgnr++;
    }
    $sortedImages[$imgnr] = $image;
  }

  # merge rest according to natural position
  foreach my $image (@images) {
    next if $image->{IGP_imgnr};
    my $imgnr = $image->{IGP_natnr};
    while ($sortedImages[$imgnr]) { # first come first serve
      $imgnr++;
    }
    $sortedImages[$imgnr] = $image;
  }

  # reconstruct images list and normalize their number
  $imgnr = 1;
  @images = ();
  foreach my $image (@sortedImages) {
    next unless $image;
    push @images, $image;
    $image->{IGP_imgnr} = $imgnr++;
  }

  $this->{images} = \@images;
  return \@images;
}

# =========================
# use the mage to get the image size
# enrich the givem image with the following information
# - IGP_origwidth: the original width of the image
# - IGP_origheight: the original height of the image
# - IGP_width: the max width to be used
# - IGP_height: the max height to be used
# - IGP_thumbwidth: the max thumbnail width to be used for 
# - IGP_thumbheight: the max thumbnail height to be used
sub computeImageSize {
  my ($this, $image) = @_;
  
  $this->writeDebug("computeImageSize($image->{name})");

  my $entry = $this->{info}{$image->{name}};
  if (!$this->{doRefresh} && $entry) {
    
    # look up igp info
    $this->writeDebug("found cached info");
    $image->{IGP_origwidth} = $entry->{origwidth};
    $image->{IGP_origheight} = $entry->{origheight};
    
  } else {
    
    # compute
    $this->writeDebug("consulting image mage on $image->{IGP_filename}");
    ($image->{IGP_origwidth}, $image->{IGP_origheight}, undef, undef) = 
      $this->{mage}->Ping($image->{IGP_filename});

    # forget
    my $mage = $this->{mage};
    @$mage = ();
  }
    
  # compute max image width and height
  my $width = $image->{IGP_origwidth};
  my $height = $image->{IGP_origheight};
  my $aspect = $height / $width;

  if ($width < $this->{minwidth}) {
    $width = $this->{minwidth};
    $height = $width * $aspect;
  } 
  if ($height < $this->{minheight}) {
    $height = $this->{minheight};
    $width = $height / $aspect;
  }
  if ($this->{maxwidth} && $width > $this->{maxwidth}) {
    $width = $this->{maxwidth};
    $height = $width * $aspect;
  } 
  if ($this->{maxheight} && $height > $this->{maxheight}) {
    $height = $this->{maxheight};
    $width = $height / $aspect;
  }
  $image->{IGP_width} = int($width+0.5);
  $image->{IGP_height} = int($height+0.5);

  #$this->writeDebug("minwidth=$this->{minwidth}, minheight=$this->{minheight}, width=$width, height=$height");

  # compute max thumnail width and height
  $width = $image->{IGP_origwidth};
  $height = $image->{IGP_origheight};
  $aspect = $height / $width;

  if ($width > $this->{thumbwidth}) {
    $width = $this->{thumbwidth};
    $height = $width * $aspect;
  } 
  if ($height > $this->{thumbheight}) {
    $height = $this->{thumbheight};
    $width = $height / $aspect;
  }
  $image->{IGP_thumbwidth} = int($width+0.5);
  $image->{IGP_thumbheight} = int($height+0.5);

  # update image info
  my $imgChanged = 0;
  if (!$entry ||
      $entry->{width} ne $image->{IGP_width} ||
      $entry->{height} ne $image->{IGP_height} ||
      $entry->{origwidth} ne $image->{IGP_origwidth} ||
      $entry->{origheight} ne $image->{IGP_origheight} ||
      $entry->{thumbwidth} ne $image->{IGP_thumbwidth} ||
      $entry->{thumbheight} ne $image->{IGP_thumbheight}) {
    $this->{infoChanged} = 1;
    $imgChanged = 1;
  }

  $entry->{name} = $image->{name};
  $entry->{type} = 'image';
  $entry->{width} = $image->{IGP_width};
  $entry->{height} = $image->{IGP_height};
  $entry->{origwidth} = $image->{IGP_origwidth};
  $entry->{origheight} = $image->{IGP_origheight};
  $entry->{thumbwidth} = $image->{IGP_thumbwidth};
  $entry->{thumbheight} = $image->{IGP_thumbheight};
  $entry->{imgChanged} = $imgChanged;
  $this->{info}{$entry->{name}} = $entry;
}

# =========================
sub replaceVars {
  my ($this, $format, $image) = @_;

  if ($image) {

    $format =~ s/\$reddot/$this->renderRedDot($image)/goes;
    $format =~ s/\$width/$image->{IGP_width}/gos;
    $format =~ s/\$height/$image->{IGP_height}/gos;
    $format =~ s/\$thumbwidth/$image->{IGP_thumbwidth}/gos;
    $format =~ s/\$thumbheight/$image->{IGP_thumbheight}/gos;
    $format =~ s/\$origwidth/$image->{IGP_origwidth}/gos;
    $format =~ s/\$origheight/$image->{IGP_origheight}/gos;
    $format =~ s/\$sizeK/$image->{IGP_sizeK}/gos;
    $format =~ s/\$comment/$image->{IGP_comment}/geos;
    $format =~ s/\$imgnr/$image->{IGP_imgnr}/gos;

    $format =~ s/\$date(\{([^\}]*)\})?/&formatTime($image->{date}, $2)/goes;
    $format =~ s/\$version/$image->{version}/gos;
    $format =~ s/\$name/$image->{name}/gos;
    $format =~ s/\$size/$image->{size}/gos;
    $format =~ s/\$wikiusername/$image->{user}/gos;
    $format =~ s/\$username/TWiki::Func::wikiToUserName($image->{user})/geos;
    $format =~ s,\$thumburl,$this->{igpPubUrl}/thumb_$image->{name},gos;
    $format =~ s,\$imageurl,$this->{igpPubUrl}/$image->{name},gos;
    $format =~ s,\$origurl,$image->{IGP_url},gos;
    $format =~ s/\$web/$image->{IGP_web}/gos;
    $format =~ s/\$topic/$image->{IGP_topic}/gos;
  }

  $format =~ s/\$nrimgs/scalar @{$this->{images}}/geos;
  $format =~ s/\$n((\([^\)]*\))|(\{[^\}]*\}))?/\n/gos; # $n or $n(....) or $n{...}
  
  return $format;
}

# =========================
# only update the image if 
# (1) it doesn't exist or 
# (2) the thumbnail is older than the source image
# (3) it should be resized
# returns 1 on success and 0 on an error (see errorMsg)
sub createImg {
  my ($this, $image, $thumbMode) = @_;
  
  #$this->writeDebug("createImg($image->{name}) called");
  
  my $prefix = ($thumbMode)?'thumb_':'';

  my $target = "$this->{igpDir}/$prefix$image->{name}";
  $target = $this->normalizeFileName($target);

  my $entry = $this->{info}{$image->{name}};
  return 1 if !$this->{doRefresh} && -e $target && !$entry->{imgChanged};

  $this->{errorMsg} = '';

  # read
  my $error = $this->{mage}->Read($image->{IGP_filename});
  if ($error =~ /(\d+)/) {
    $this->writeDebug("Read(): error=$error");
    $this->{errorMsg} = " $error";
    return 0 if $1 >= 400;
  }

  # compute
  if ($thumbMode) {
    $error = 
      $this->{mage}->Scale(geometry=>"$image->{IGP_thumbwidth}x$image->{IGP_thumbheight}");
  } else {
    $error = 
      $this->{mage}->Scale(geometry=>"$image->{IGP_width}x$image->{IGP_height}");
  }
  if ($error =~ /(\d+)/) {
    $this->writeDebug("Scale(): error=$error");
    $this->{errorMsg} .= " $error";
    return 0 if $1 >= 400;
  }

  # write
  $error = $this->{mage}->Write($target);
  if ($error =~ /(\d+)/) {
    $this->writeDebug("Write(): error=$error");
    $this->{errorMsg} .= " $error";
    return 0 if $1 >= 400;
  }

  $this->writeDebug("writing target '$target'");

  # forget
  my $mage = $this->{mage};
  @$mage = ();
  return 1;
}

# =========================
# stolen form TWiki::handleTime() 
sub formatTime {
  my ($time, $format) = @_;
  $format ||= '$day $mon $year - $hour:$min';
  my $value = "";

  my ($sec, $min, $hour, $day, $mon, $year) = localtime($time);
  $year = sprintf("%.4u", $year + 1900);
  use constant ISOMONTH => qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
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
# wrapper
sub normalizeFileName {
  my ($this, $fileName) = @_;

  #$this->writeDebug("normalizeFileName($fileName)");

  if (defined &TWiki::Sandbox::normalizeFileName) {
    return &TWiki::Sandbox::normalizeFileName($fileName);
  }

  if (defined &TWiki::normalizeFileName) {
    return &TWiki::normalizeFileName($fileName);
  }
    
  return $fileName;
}

# =========================
sub renderError {
  my $msg = shift;
  return "<span class=\"igpAlert\">Error: $msg</span>" ;
}

# =========================
sub getImageTitle {
  my $image = shift;

  my $title;
  if ($image->{comment}) {
    $title = $image->{comment};
  } else {
    $title =  $image->{name};
    $title =~ s/^(.*)\.[a-zA-Z]*$/$1/;
  }
  $title =~ s/^\s+//;
  $title =~ s/\s+$//;

  return $title;
}

# =========================
sub readInfo {
  my $this = shift;

  $this->writeDebug("readInfo() called");

  $this->{infoChanged} = 1;
  return unless -e $this->{infoFile};

  my $text = &TWiki::Func::readFile($this->{infoFile});
  foreach my $line (split(/\n/, $text)) {
    my $entry;
    if ($line =~ /^name=(.*), origwidth=(.*), origheight=(.*), width=(.*), height=(.*), thumbwidth=(.*), thumbheight=(.*)$/) {
      $entry = {
	name=>$1,
	type=>'image',
	origwidth=>$2,
	origheight=>$3,
	width=>$4,
	height=>$5,
	thumbwidth=>$6,
	thumbheight=>$7,
      };
    } elsif ($line =~ /^(thumbwidth|thumbheight|topics|web)=(.*)$/) {
      $entry = {
	name=>$1,
	type=>'global',
	value=>$2,
      };
    } else {
      next;
    }
    $this->{info}{$entry->{name}} = $entry;
  }

  $this->{infoChanged} = 0;
}

# =========================
sub writeInfo {
  my $this = shift;

  $this->writeDebug("writeInfo() called");

  return unless $this->{infoChanged};

  my $text = "# ImageGalleryPlugin info file: DON'T EDIT BY HAND\n";
  $text .= "thumbwidth=$this->{thumbwidth}\n";
  $text .= "thumbheight=$this->{thumbheight}\n";
  $text .= "topics=" . join (', ', @{$this->{topics}}) . "\n";
  foreach my $entry (values %{$this->{info}}) {
    next if $entry->{type} eq 'global';
    $text .= 
      "name=$entry->{name}, " .
      "origwidth=$entry->{origwidth}, " .
      "origheight=$entry->{origheight}, " .
      "width=$entry->{width}, " .
      "height=$entry->{height}, " .
      "thumbwidth=$entry->{thumbwidth}, " .
      "thumbheight=$entry->{thumbheight}" .
      "\n";
  }

  $this->writeDebug("writing infoFile=$this->{infoFile}");

  &TWiki::Func::saveFile($this->{infoFile}, $text);
}


1;
