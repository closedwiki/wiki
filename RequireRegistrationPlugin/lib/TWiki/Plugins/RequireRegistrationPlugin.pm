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

# Initial version by TWiki:Main.ByronIgoe

=pod

---+ package RequireRegistrationPlugin

This plugin will redirect a user to the %TWIKIWEB%.TWikiRegistration
topic if their login name is not a %TWIKIWEB%.WikiWord.

Use this if you have setup single sign-on (SSO) and want to force 
externally authenticated users to register their %TWIKIWEB%.WikiName before 
accessing any wiki content.

The condition for when to redirect can very easily be enhanced to 
only force users to register when they try to:
   * access a protected web
   * edit a page
  
=cut

package TWiki::Plugins::RequireRegistrationPlugin;

use strict;
use vars qw( $VERSION $RELEASE $debug $pluginName );

$VERSION = '$Rev: 9813$';
$RELEASE = 'Dakar';

$pluginName = 'RequireRegistrationPlugin';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # this doesn't really have any meaning if we aren't being called as a CGI
    my $query = &TWiki::Func::getCgiQuery();
    return 0 unless $query;

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");


    my $regPage = 'TWikiRegistration';
    my $twikiWeb = TWiki::Func::getTwikiWebname( );
    my $url = TWiki::Func::getViewUrl( $twikiWeb, $regPage );

    &TWiki::Func::writeDebug( "- TWiki::Plugins::$pluginName Sending $user to $url" )
      if $debug;

    if (($web ne $twikiWeb || $topic ne $regPage) && (! TWiki::Func::isValidWikiWord( TWiki::Func::getWikiName( ) ))) {
    	# The first option here is very strict in that the user never sees the destination page
    	TWiki::Func::redirectCgiQuery( $query, $url );
    	# This second option is more lenient by giving them a 2 second preview before redirecting them to registration
        # TWiki::Func::addToHEAD('REQUIREREGISTRATION','<META HTTP-EQUIV=Refresh CONTENT="2;URL=$url">');
    }
    return 1;
}

1;
