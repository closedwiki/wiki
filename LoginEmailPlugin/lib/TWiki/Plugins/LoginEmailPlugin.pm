# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
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

# change the package name and $pluginName!!!
package TWiki::Plugins::LoginEmailPlugin;

# Always use strict to enforce variable scoping
use strict;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName );

# This should always be $Rev: 9813$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 9813$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# Name of this Plugin, only used in this module
$pluginName = 'LoginEmailPlugin';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

#    if( $TWiki::Plugins::VERSION < 1.026 ) {
#        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
#        return 0;
#    }

    return 1;
}


sub initializeUserHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $loginName, $url, $pathInfo ) = @_;


	my $email = $_[0];
   # kill spaces and Wikify page name (ManpreetSingh - 15 Sep 2000)
   $email =~ s/^\s*//;
   $email =~ s/\s*$//;
   $email =~ s/^(.)/\U$1/;
   $email =~ s/\s([a-zA-Z0-9])/\U$1/g;
   $email =~ s/-([a-zA-Z0-9])/\U$1/g;
   $email =~ s/@([a-zA-Z0-9])/At\U$1/g;
   $email =~ s/\.([a-zA-Z0-9])/Dot\U$1/g;
    
   TWiki::Func::writeDebug( "- ${pluginName}::initializeUserHandler( $_[0], $email )" ) if $debug;
   
   return $email;
}

1;
