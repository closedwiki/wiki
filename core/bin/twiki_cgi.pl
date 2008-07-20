#!/usr/bin/perl -wT
#
# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors.
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
# As per the GPL, removal of this notice is prohibited.


use strict;
use warnings;

BEGIN {
    if ( defined $ENV{GATEWAY_INTERFACE} ) {
        $TWiki::cfg{Engine} = 'TWiki::Engine::CGI';
        my $action = (split m!/!, $ENV{SCRIPT_NAME})[-1];
        $ENV{PATH_INFO} = "/$action" . $ENV{PATH_INFO};
        use CGI::Carp qw(fatalsToBrowser);
        $SIG{__DIE__} = \&CGI::Carp::confess;
    }
    else {
        $TWiki::cfg{Engine} = 'TWiki::Engine::CLI';
        require Carp;
        $SIG{__DIE__} = \&Carp::confess;
    }
    @INC = ('.', grep { $_ ne '.' } @INC);
    require 'setlib.cfg';
}

use TWiki;
use TWiki::UI;
$TWiki::engine->run();
