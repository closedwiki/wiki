# TWiki RedirectPlugin
#
# Copyright (C) 2003 Steve Mokris, smokris@softpixel.com
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


# =========================
package TWiki::Plugins::RedirectPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $debug
        $exampleCfgVar
    );

$VERSION = '1.000';

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between RedirectPlugin and Plugins.pm" );
        return 0;
    }

    my $query=&TWiki::Func::getCgiQuery();

    if( ! $query ) # this doesn't really have any meaning if we aren't being called as a CGI
    {
	return 0;
    }


    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
#    $exampleCfgVar = &TWiki::Prefs::getPreferencesValue( "EMPTYPLUGIN_EXAMPLE" ) || "default";

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "REDIRECTPLUGIN_DEBUG" );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::RedirectPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug( "- RedirectPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    my $query=&TWiki::Func::getCgiQuery();

    if( !($ENV{SCRIPT_NAME} =~ /preview/) ) # make sure we don't redirect on preview!
    {
        if( $_[0] =~ /%REDIRECT\{\"([A-Z]+[A-Za-z]+)\.([A-Za-z0-9.-]+)\"\}%/ )
        {
            &TWiki::Func::redirectCgiQuery($query,&TWiki::Func::getViewUrl($1,$2));
        }
        if( $_[0] =~ /%REDIRECT\{\"([A-Za-z0-9.-]+)\"\}%/ )
        {
            &TWiki::Func::redirectCgiQuery($query,&TWiki::Func::getViewUrl($_[2],$1));
        }
        if( $_[0] =~ /%REDIRECT\{\"(.+\:\/\/.+)\"\}%/ )
        {
            &TWiki::Func::redirectCgiQuery($query,$1);
        }
    }
}

# =========================

1;
