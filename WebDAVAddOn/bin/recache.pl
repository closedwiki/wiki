#!/usr/bin/perl -wT
#
# Copyright (C) 2004 Wind River Systems Inc.
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

BEGIN {
    # Set default current working directory (needed for mod_perl)
    if( $ENV{"SCRIPT_FILENAME"} && $ENV{"SCRIPT_FILENAME"} =~ /^(.+)\/[^\/]+$/ ) {
        chdir $1;
    }
    # Set library paths in @INC, at compile time
    unshift @INC, '.';
    require 'setlib.cfg';
}

# Refresh the content of the TWiki protections cache.
# Deleting the cache first is a valid thing to do.


use strict;
use TWiki;
use TWiki::Plugins::WebDAVPlugin::Permissions;

TWiki::initialize( "/Main", "nobody" );

my $pdb = TWiki::Prefs::getPreferencesValue("WEBDAVPLUGIN_LOCK_DB");
my $permDB = new WebDAVPlugin::Permissions( $pdb );

$permDB->recache();
