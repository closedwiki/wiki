# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2006 Michael Daum <micha@nats.informatik.uni-hamburg.de>
# 
# Adapted from WordPress plugin TimeSince by
# Michael Heilemann (http://binarybonsai.com), 
# Dunstan Orchard (http://www.1976design.com/blog/archive/2004/07/23/redesign-time-presentation/),
# Nataile Downe (http://blog.natbat.co.uk/archive/2003/Jun/14/time_since)
# 
# Thanks to all of you!!!
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

package TWiki::Plugins::TimeSincePlugin;

use strict;
use vars qw( $VERSION $RELEASE $isInitialized);

$VERSION = '$Rev$';
$RELEASE = '1.00';

###############################################################################
sub initPlugin {

  if ($TWiki::Plugins::VERSION < 1.1) {
    return 0;
  }

  TWiki::Func::registerTagHandler('TIMESINCE', \&handleTimeSince);
  return 1;
}

###############################################################################
sub handleTimeSince {

  unless ($isInitialized) {
    eval 'use TWiki::Plugins::TimeSincePlugin::Core;';
    die $@ if $@;
    $isInitialized = 1;
  }

  return TWiki::Plugins::TimeSincePlugin::Core::handleTimeSince(@_);
}

1;
