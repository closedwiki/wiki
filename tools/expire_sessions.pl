#!/usr/bin/perl -w
#
# TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 TWiki Contributors
#
# For licensing info read license.txt file in the TWiki root.
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
# THIS SCRIPT IS DESIGNED TO BE RUN FROM YOUR bin DIRECTORY.
# This is so it can pick up the right TWiki environment from
# setlib.cfg.
#
# It will expire sessions that have not been used for
# |{Sessions}{ExpireAfter}| seconds i.e. if you set {Sessions}{ExpireAfter}
# to -36000 or 36000 it will expire sessions that have not been used for
# more than 100 hours,
#
BEGIN {
    unshift @INC, '.';
    require 'setlib.cfg';
}

use TWiki::Client;

TWiki::Client::expireDeadSessions();

