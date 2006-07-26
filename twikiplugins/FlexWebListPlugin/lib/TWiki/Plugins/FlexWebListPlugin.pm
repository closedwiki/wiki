# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 MichaelDaum@WikiRing.com
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

package TWiki::Plugins::FlexWebListPlugin;

use strict;
use vars qw( $VERSION $RELEASE $core);

$VERSION = '$Rev$';
$RELEASE = 'v0.01';

###############################################################################
sub initPlugin {
  $core = undef;
  return 1;
}

###############################################################################
sub commonTagsHandler {
  $_[0] =~ s/%FLEXWEBLIST%/&renderFlexWebList('', $_[2], $_[1])/geo;
  $_[0] =~ s/%FLEXWEBLIST{(.*?)}%/&renderFlexWebList($1, $_[2], $_[1])/geo;
}

###############################################################################
sub newCore {

  return $core if $core;
  eval 'use TWiki::Plugins::FlexWebListPlugin::Core;';
  die $@ if $@;
  $core = new TWiki::Plugins::FlexWebListPlugin::Core;
  return $core;
}

###############################################################################
sub renderFlexWebList {
  return newCore()->handler(@_);
}

###############################################################################
1;
