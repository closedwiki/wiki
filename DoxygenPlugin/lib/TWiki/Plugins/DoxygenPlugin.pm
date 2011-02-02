# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2003 Leaf Garland.  All Rights Reserved.
# Copyright (C) 2003 Will Norris.  All Rights Reserved.  (wbniv@saneasylumstudios.com)
# Copyright (C) 2007-2011 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
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
#
# =========================
#
# This plugin helps link to doxygen-generated documentation.

# =========================
package TWiki::Plugins::DoxygenPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $debug
    );

$VERSION = '$Rev$';
$RELEASE = '2011-02-01';

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "DOXYGENPLUGIN_DEBUG" );
    
    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between DoxygenPlugin and Plugins.pm" );
        return 0;
    }

    $project = &TWiki::Func::getPreferencesValue( "DOXYGENPLUGIN_PROJECT" );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::DoxygenPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    # &TWiki::Func::writeDebug( "- DoxygenPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    $_[0] =~ s/%DOX{(.*?)}%/&handleDoxygen($1)/geo;
}
# =========================

use Data::Dumper;
sub handleDoxygen
{
    my $text = "";

    my ( $attributes ) = @_;
    $attributes =~ /^\s*
	([^(\[|\s)]+)	# the class name (or filename)
	(
	  \[((.+))\]    # the (optional) diplay name
	 )?		# optional (0 or 1)
	/x;
    my ( $name, $alt ) = ( $1, $3 );
    $alt ||= $name;
    my $classname = $name;
    $classname =~ s/:/_1/g;

    my $thisProject = scalar &TWiki::Func::extractNameValuePair( $attributes, "project" ) || $project;

    # allow a trailing slash so that the location is a valid url in the plugin's settings
    # (sometimes you have to include the trailing / on url's)
    ( $doxygen_docs_base = &TWiki::Func::getPreferencesValue( uc "DOXYGENPLUGIN_DOCS_BASE_$thisProject" ) . '/' ) =~ s|//$|/|;
    ( $doxygen_url_base = &TWiki::Func::getPreferencesValue( uc "DOXYGENPLUGIN_URL_BASE_$thisProject" ) . '/' ) =~ s|//$|/|;

    &TWiki::Func::writeDebug( "project=[$thisProject]\ndocs_base=[$doxygen_docs_base] url_base=[$doxygen_url_base]\nname=[$name] classname=[$classname] alt=[$alt]\nattributes=[$attributes]" ) if $debug;

    # check if we have a file instead of a class
    if ($name =~ /.+html?$/ ) {
        $text .= qq{<a href="${doxygen_url_base}$name">$alt</a>};
    } elsif ( -f "$doxygen_docs_base/class$classname.html" ) {
        $text .= qq{<a href="${doxygen_url_base}class$classname.html">$alt </a>};
    } else {
        $text .= qq{<a href="${doxygen_url_base}class$classname.html">$alt [bad link?]</a>};
    }

    return $text;
}

# =========================

1;
