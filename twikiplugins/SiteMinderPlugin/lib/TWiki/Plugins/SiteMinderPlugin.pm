#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
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
# This is an SiteMinder TWiki plugin. Use it as a template
# for your own plugins; see TWiki.TWikiPlugins for details.
#
# Each plugin is a package that contains the subs:
#
#   initPlugin           ( $topic, $web, $user, $installWeb )
#   commonTagsHandler    ( $text, $topic, $web )
#   startRenderingHandler( $text, $web )
#   outsidePREHandler    ( $text )
#   insidePREHandler     ( $text )
#   endRenderingHandler  ( $text )
#
# initPlugin is required, all other are optional. 
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name.
# 
# NOTE: To interact with TWiki use the official TWiki functions
# in the &TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::SiteMinderPlugin; 	

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $debug
        $exampleCfgVar $personnelNumber $standardisedFullName
    );

$VERSION = '1.000';

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between SiteMinderPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin preferences, the variable defined by:          
    $exampleCfgVar = &TWiki::Prefs::getPreferencesValue( "SITEMINDERPLUGIN" ) || "5";

    # Get plugin debug flag
    $debug = 1; # &TWiki::Func::getPreferencesFlag( "SITEMINDERPLUGIN_DEBUG" );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::SiteMinderPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    
    ##SiteMinder specific initialisation
    #standardise the name
    $ENV{'HTTP_FULLNAME'} = standardiseFullName($ENV{'HTTP_FULLNAME'});	
    
    $standardisedFullName = $ENV{'HTTP_FULLNAME'};
    #set the personnel number
    $personnelNumber = $ENV{'HTTP_PERSONNELNUMBER'};
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug( "- SiteMinderPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    $_[0] =~ s/%PERSONNELNO%/$personnelNumber/geo;
    $_[0] =~ s/%FULL_NAME%/$standardisedFullName/geo;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/geo;
}

# =========================
sub DISABLE_startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    &TWiki::Func::writeDebug( "- SiteMinderPlugin::startRenderingHandler( $_[1].$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/go;
}

# =========================
sub DISABLE_outsidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

#   &TWiki::Func::writeDebug( "- SiteMinderPlugin::outsidePREHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, in loop outside of <PRE> tag.
    # This is the place to define customized rendering rules.
    # Note: This is an expensive function to comment out.
    # Consider startRenderingHandler instead
}

# =========================
sub DISABLE_insidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

#   &TWiki::Func::writeDebug( "- SiteMinderPlugin::insidePREHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, in loop inside of <PRE> tag.
    # This is the place to define customized rendering rules.
    # Note: This is an expensive function to comment out.
    # Consider startRenderingHandler instead
}

# =========================
sub DISABLE_endRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    &TWiki::Func::writeDebug( "- SiteMinderPlugin::endRenderingHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just after the line loop

}

# =========================

#RJE
sub wikiNameFromSiteMinderName 
{
   return wikiNameFromFullName(&standardiseFullName($ENV{'HTTP_FULLNAME'}));
}

# =========================

# returns "Old X. Macdonald" from "Old X. MacDonald"
sub standardiseFullName
{
    my ($sitemindername) = @_;
    $sitemindername =~ s/([a-zA-z][A-Z])/__/;
    my $lc = $1;
    $lc =~ tr/[A-Z]/[a-z]/; # to lower case
    $sitemindername =~ s/__/$lc/;
    return $sitemindername;
}

# =========================

# returns OldXMacdonald from "Old X. Macdonald"
sub wikiNameFromFullName
{
    my ($wikiName) = @_;
    $wikiName =~ s/ //g; # remove all spaces
    $wikiName =~ s/\.//g; # remove all dots
    return $wikiName;
}

#=============================

#sets up a remote user
sub setUpRemoteUser
{
	my $remoteUser = $ENV{'HTTP_SM_USER'} || "";
        $remoteUser =~ tr/[A-Z]/[a-z]/;  # change to lower case
	return $remoteUser;
}

# ===========================

1;
