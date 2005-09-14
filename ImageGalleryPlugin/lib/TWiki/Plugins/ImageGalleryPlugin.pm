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
package TWiki::Plugins::ImageGalleryPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $isInitialized $igpId
    );

$VERSION = '3.1';

# =========================
sub initPlugin {
  ($topic, $web, $user, $installWeb) = @_;

  if ($TWiki::Plugins::VERSION < 1) {
    &TWiki::Func::writeWarning("Version mismatch between ImageGalleryPlugin and Plugins.pm");
    return 0;
  }
  $isInitialized = 0;
  $igpId = 1;

  return 1;
}

# =========================
sub commonTagsHandler {

  $_[0] =~ s/%IMAGEGALLERY%/&renderImageGallery($igpId++)/geo;
  $_[0] =~ s/%IMAGEGALLERY{(.*?)}%/&renderImageGallery($igpId++, $1)/geo;
  $_[0] =~ s/%NRIMAGES{(.*?)}%/&renderNrImages($1)/geo;
}

# =========================
sub doInit {

  return if $isInitialized;

  if ($TWiki::Plugins::VERSION < 1.020) {
    eval 'use TWiki::Contrib::CairoContrib;';
    return "Error:\%BR\%\n<pre style=\"font-size:9pt\">\n$@</pre>\n"
      if $@;
  }

  eval 'use TWiki::Plugins::ImageGalleryPlugin::Core();';
  return "Error:\%BR\%\n<pre style=\"font-size:9pt\">\n$@</pre>\n"
    if $@;

  $isInitialized = 1;

  return undef;
}

# =========================
sub renderImageGallery {
  my ($id, $args) = @_;

  my $error = &doInit();

  if ($error) {
    &TWiki::Func::writeWarning("ImageGalleryPlugin::doInit() - $error");
    return $error;
  }

  my $igp = TWiki::Plugins::ImageGalleryPlugin::Core->new($id, $topic, $web);
  $igp->debug(0);
  return $igp->render($args);
}

# =========================
sub renderNrImages {
  my ($args) = @_;

  my $error = &doInit();

  if ($error) {
    &TWiki::Func::writeWarning("ImageGalleryPlugin::doInit() - $error");
    return $error;
  }

  my $igp = TWiki::Plugins::ImageGalleryPlugin::Core->new(undef, $topic, $web);
  $igp->debug(0);
  if ($igp->init($args)) {
    return scalar @{$igp->getImages()};
  } else {
    return TWiki::Plugins::ImageGalleryPlugin::Core::renderError("can't initialize using '$args'");
  }
}

1;
