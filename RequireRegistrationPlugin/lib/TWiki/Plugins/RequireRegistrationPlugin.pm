# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2012      W. van Engen, wvengen+twiki@nikhef.nl
# Copyright (C) 2001-2012 Peter Thoeny, peter[at]thoeny.org
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

# =========================
our $VERSION = '1.3 - $Rev$';
our $RELEASE = '2011-08-02';

our $VERSION = '1.4';
our $RELEASE = '2012-08-17';
our $NO_PREFS_IN_TOPIC = 1;

my $refresh;
my $debug;
my $pluginName = 'RequireRegistrationPlugin';

# =========================
sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # this doesn't really have any meaning if we aren't being called as a CGI
    my $query = TWiki::Func::getCgiQuery();
    return 0 unless $query;

    # Get refresh
    $refresh = $TWiki::cfg{Plugins}{$pluginName}{Refresh} || 0;

    # Get plugin debug flag
    $debug = $TWiki::cfg{Plugins}{$pluginName}{Debug} || 0;

    my $regPage = 'TWikiRegistration';
    my $twikiWeb = TWiki::Func::getTwikiWebname( );
    my $url = TWiki::Func::getViewUrl( $twikiWeb, $regPage );
    my $action = $query->action();
    my @actionsOnly = split(',', $TWiki::cfg{Plugins}{$pluginName}{Actions} || '');

    if (($action ne 'register') && 
        ($web ne $twikiWeb || $topic ne $regPage) &&
        (scalar(@actionsOnly)>0 && grep(/^$action$/, @actionsOnly)>0) &&
        (! TWiki::Func::isValidWikiWord( TWiki::Func::getWikiName( ) ))) {

      TWiki::Func::writeDebug( "- TWiki::Plugins::$pluginName Sending $user to $url with refresh $refresh" )
        if $debug;

      if( $refresh < 0 ) {
    	# This option here is very strict in that the user never sees the destination page
    	TWiki::Func::redirectCgiQuery( $query, $url );
      } else {
    	# This option is configurable, gives user some time to preview before redirecting to registration
        TWiki::Func::addToHEAD( 'REQUIREREGISTRATION', "<meta http-equiv='refresh' content='$refresh;url=$url' />" );
      }
    }
    return 1;
}

# =========================
1;
