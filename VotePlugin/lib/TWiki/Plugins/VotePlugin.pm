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
use strict;

###############################################################################
use vars qw(
  $isInitialized
  $VERSION $RELEASE $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION
);

$VERSION = '$Rev$';
$RELEASE = '1.32';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Simple way to count votes';

###############################################################################
sub initPlugin {
    $isInitialized = 0;
    TWiki::Func::registerTagHandler('VOTE', \&handleVote);
    return 1;
}

###############################################################################
sub handleVote {
    #my ($session, $params, $topic, $web) = @_;

    unless ($isInitialized) {
        eval 'use TWiki::Plugins::VotePlugin::Core;';
        die $@ if $@;
        $isInitialized = 1;
    }

    return TWiki::Plugins::VotePlugin::Core::handleVote(@_);
}

1;
