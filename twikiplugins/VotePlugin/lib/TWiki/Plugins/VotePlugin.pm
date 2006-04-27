# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2006 Michael Daum <micha@nats.informatik.uni-hamburg.de>
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

###############################################################################
package TWiki::Plugins::VotePlugin; 

###############################################################################
use vars qw($user $VERSION $RELEASE $isInitialized);

$VERSION = '$Rev$';
$RELEASE = '1.30';

###############################################################################
sub initPlugin {
  (undef, undef, $user, undef) = @_;

  $isInitialized = 0;
  return 1;
}

###############################################################################
sub commonTagsHandler {
  $_[0] =~ s/%VOTE{(.*?)}%/&handleVote($_[2], $_[1], $1)/geo;
}

###############################################################################
sub handleVote {

  unless ($isInitialized) {
    eval 'use TWiki::Plugins::VotePlugin::Core;';
    die $@ if $@;
    $isInitialized = 1;
  }

  return TWiki::Plugins::VotePlugin::Core::handleVote(@_);
}

1;
