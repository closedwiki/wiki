#
# Copyright (C) 2005 Garage Games
# Author: Crawford Currie http://c-dot.co.uk
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

=pod

---+ package TWiki::Plugins::AuthPagePlugin

Support for authentication via a logon page. Requires
SessionPlugin.

=cut

package TWiki::Plugins::AuthPagePlugin;

use strict;

# You are required to implement this - see Apache_Validator.pm for an example
use TWiki::Plugins::AuthPagePlugin::Validator;

use vars qw( $VERSION );

$VERSION = 1.000;

=pod

---++ StaticMethod authenticate( $query, $web, $topic )

Handler called from every TWiki script:
<verbatim>
use TWiki::Plugins::AuthPagePlugin;
TWiki::Plugins::AuthPagePlugin::authenticate( $query, $webName, $topic );
</verbatim>
If the user has an existing cookie, the function simply drops though
allowing the calling script to complete. If no cookie is in place it
forces redirection to the "login" script, passing it the original URL,
and does not return.

=cut

sub authenticate {
    my( $query, $web, $topic ) = @_;

    use TWiki::Plugins::SessionPlugin;
    unless( $TWiki::Plugins::SessionPlugin::sessionIsAuthenticated ) {
        my $url = TWiki::getScriptUrl( $web, $topic, "login" );
        $url .= "?origurl=".TWiki::handleNativeUrlEncode( $query->url );
        TWiki::redirect( $query, $url );
        exit 0;
    }
}

=pod

---++ StaticMethod logon( $query )

Handler called from the "logon" script. This script is redirected to
if there is no existing session cookie.
If a login name and password have been passed in the query, it
validates these and if authentic, redirects to the original
script. If there is no username in the query or the username/password is
invalid (validate returns non-zero) then it prompts again.

=cut

sub logon {
    my $query = shift;

    my $origurl = $query->param( 'origurl' );
    my $loginName = $query->param( 'username' );
    my $loginPass = $query->param( 'password' );
    my $banner = "You are not logged in";
    my $note = '';

    if( $TWiki::Plugins::SessionPlugin::session ) {
        my $currUser = $TWiki::Plugins::SessionPlugin::session->param
          ( $TWiki::Plugins::SessionPlugin::authUserSessionVar );
        $banner = $currUser.' is currently logged in';
        $note = "Enter a new username and password to change identity";
    }

    if( $loginName ) {
        my $validation = TWiki::Plugins::AuthPagePlugin::Validator::validate
          ( $loginName, $loginPass );
        if( $validation ) {
            $TWiki::Plugins::SessionPlugin::session->param
              ( $TWiki::Plugins::SessionPlugin::authUserSessionVar,
                $loginName );
            $TWiki::Plugins::SessionPlugin::session->param
              ( 'VALIDATION', $validation );
            if( $origurl && $origurl ne $query->url() ) {
                TWiki::redirect( $query, $origurl );
                return;
            }
            $banner = "$loginName is logged in";
        } else {
            $banner = "Unrecognised user and/or password";
        }
    }

    my $tmpl = TWiki::Func::readTemplate( "login", TWiki::Func::getSkin() );
    # TODO: add JavaScript password encryption in the template
    # to use a template)
    $tmpl =~ s/%ORIGURL%/$origurl/g;
    $tmpl =~ s/%BANNER%/$banner/g;
    $tmpl =~ s/%NOTE%/$note/g;
    $tmpl = TWiki::Func::expandCommonVariables( $tmpl, "", "" );
    $tmpl = TWiki::Func::renderText( $tmpl, "" );
    TWiki::Func::writeHeader( $query );
    print $tmpl;
}

1;
