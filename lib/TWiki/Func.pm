#
# TWiki WikiClone (see wiki.pm for $wikiversion and other info)
#
# Copyright (C) 2000 Peter Thoeny, Peter@Thoeny.com
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
# Notes:
# - Latest version at http://twiki.org/
# - Installation instructions in $dataDir/TWiki/TWikiDocumentation.txt
# - Customize variables in TWiki.cfg when installing TWiki.
# - Upgrading TWiki is easy as long as you use Plugins.
# - Check web server error logs for errors, i.e. % tail /var/log/httpd/error_log
#
# This is the module with official funcions. Plugins should
# ONLY use functions published in this module. If you use
# other functions you might impose a security hole and you
# will likely need to change your plugin when you upgrade
# TWiki.

package TWiki::Func;

use strict;

# =========================
# get session value (from session plugin)
# =========================
sub getSessionValue
{
#   my( $key ) = @_;
    return &TWiki::getSessionValue( @_ );
}

# =========================
# get a preferences value
# =========================
sub getPreferencesValue
{
#   my( $theKey, $theWeb ) = @_;
    # $theKey is "MYPLUGIN_COLOR" to get the "Set COLOR" setting in "MyPlugin" topic
    # $theWeb is optional (does not apply to settings of plugin topics)
    return &TWiki::Prefs::getPreferencesValue( @_ );
}

# =========================
# get a preferences flag value (on/off 1/0 etc)
# =========================
sub getPreferencesFlag
{
#   my( $theKey ) = @_;
    # $theKey is "MYPLUGIN_SHOWHELP" to get the "Set SHOWHELP" setting in "MyPlugin" topic
    return &TWiki::Prefs::getPreferencesFlag( @_ );
}

# =========================
# get skin, from query param or preference
# =========================
sub getSkin
{
    return &TWiki::getSkin();
}

# =========================
# extract the value from a name="value" attribute pair
# =========================
sub extractNameValuePair
{
#   my( $theAttr, $theName ) = @_;
    # extract attributes from variables
    # i.e. %TEST{"nameless" name1="val1" name2="val2"}%
    # - first extract text between {...} to get: "nameless" name1="val1" name2="val2"
    # - then call this on the text:
    #     my $noname = &TWiki::Func::extractNameValuePair( $text );
    #     my $name1  = &TWiki::Func::extractNameValuePair( $text, "name1" );
    #     my $name2  = &TWiki::Func::extractNameValuePair( $text, "name2" );

    return &TWiki::extractNameValuePair( @_ );
}

# =========================
# log Warning that may require admin intervention to data/warning.txt
# =========================
sub writeWarning
{
#   my( $theText ) = @_;
    return &TWiki::writeWarning( @_ );
}

# =========================
# log debug message to data/debug.txt
# =========================
sub writeDebug
{
#   my( $theText ) = @_;
    return &TWiki::writeDebug( @_ );
}

# =========================
# get data directory (topic file root)
# =========================
sub getDataDir
{
    return &TWiki::getDataDir();
}

# =========================
# get pub directory (file attachment root)
# =========================
sub getPubDir
{
    return &TWiki::getPubDir();
}

# =========================
# get pub URL path
# =========================
sub getPubUrlPath
{
    return &TWiki::getPubUrlPath();
}

# =========================
# get script URL path
# =========================
sub getScriptUrlPath
{
    return $TWiki::scriptUrlPath;
}

# =========================
# get URL host
# =========================
sub getUrlHost
{
    return $TWiki::urlHost;
}

# =========================
# compose fully qualified URL
# =========================
sub getScriptUrl
{
#   my( $web, $topic, $script ) = @_;
    return &TWiki::getScriptUrl( @_ ); 
}

# =========================
# compose fully qualified view URL
# =========================
sub getViewUrl
{
#   my( $theWeb, $theTopic ) = @_;
    return &TWiki::getViewUrl( @_ );
}

# =========================
# compose fully qualified "oops" dialog URL
# =========================
sub getOopsUrl
{
#   my( $theWeb, $theTopic, $theTemplate, @theParams ) = @_;
    # up to 4 parameters in @theParams
    return &TWiki::getOopsUrl( @_ );
}

# =========================
# get wikiToolName
# =========================
sub getWikiToolName
{
    return $TWiki::wikiToolName;
}

# =========================
# get mainWebname
# =========================
sub getMainWebname
{
    return $TWiki::mainWebname;
}

# =========================
# get twikiWebname
# =========================
sub getTwikiWebname
{
    return $TWiki::twikiWebname;
}

# =========================
# expand all common %VARIABLES%
# =========================
sub expandCommonVariables
{
#   my( $theText, $theTopic, $theWeb ) = @_;
    return &TWiki::handleCommonTags( @_ );
}

# =========================
# render text in Wiki syntax
# =========================
sub renderText
{
#   my( $theText, $theWeb ) = @_;
    return &TWiki::getRenderedVersion( @_ );
}

# =========================
# do internal link
# =========================
sub internalLink
{
#   my( $thePreamble, $theWeb, $theTopic, $theLinkText, $theAnchor, $doLink ) = @_;
    return &TWiki::internalLink( @_ );
}

# =========================
# get list of all public webs
# =========================
sub getPublicWebList
{
    return &TWiki::getPublicWebList();
}

# =========================
# get list of all topics in a web
# =========================
sub getTopicList
{
#   my( $theWeb ) = @_;
    return &TWiki::Store::getTopicNames ( @_ );
}
# =========================
# test if any permissions are set on this web
# =========================
sub permissionsSet
{
#   my( $web ) = @_;
    return &TWiki::Access::permissionsSet( @_ );
}

# =========================
# check access permissions for this topic
# =========================
sub checkAccessPermission
{
#   my( $theAccessType, $theUserName, $theTopicText, $theTopicName, $theWebName ) = @_;
    return &TWiki::Access::checkAccessPermission( @_ );
}

# =========================
# test if web exists
# =========================
sub webExists
{
#   my( $theWeb ) = @_;
    return &TWiki::Store::webExists( @_ );
}

# =========================
# test if topic exists
# =========================
sub topicExists
{
#   my( $theWeb, $theTopic ) = @_;
    return &TWiki::Store::topicExists( @_ );
}

# =========================
# get revision info from meta
# returns ($revdate, $revuser, $maxrev)
# =========================
sub getRevisionInfo
{
#   my( $web, $topic, $meta, $format );
#   format can be  "isoFormat"
    return &TWiki::Store::getRevisionInfoFromMeta( @_ );
}

# =========================
# read a topic "as is" (with embedded meta data)
# =========================
sub readTopic
{
#   my( $theWebName, $theTopic ) = @_;
    return &TWiki::Store::readTopic( @_ );
}

# =========================
# read a template file
# =========================
sub readTemplate
{
#   my( $theName, $theSkin ) = @_;
    return &TWiki::Store::readTemplate( @_ );
}

# =========================
# read text file, low level
# better to use readTopic or readTemplate if possible
# =========================
sub readFile
{
#   my( $theFileName ) = @_;
    return &TWiki::Store::readFile( @_ );
}

# =========================
# save text file, low level
# =========================
sub saveFile
{
#   my( $theFileName, $theText ) = @_;
    return &TWiki::Store::saveFile( @_ );
}

# =========================
# get defaultUserName e.g. guest
# =========================
sub getDefaultUserName
{
    return $TWiki::defaultUserName;
}

# =========================
# get wikiName e.g. JohnDoe
# =========================
sub getWikiName
{
    return $TWiki::wikiName;
}

# =========================
# get wikiUserName e.g. Main.JohnDoe
# =========================
sub getWikiUserName
{
    return $TWiki::wikiUserName;
}

# =========================
# translate wikiUserName to userName, Main web is optional
# e.g Main.JohnDoe to jdoe
#  or Johndoe to jdoe
# =========================
sub wikiToUserName
{
#   my( $wiki ) = @_;
    return &TWiki::wikiToUserName( @_ );
}

# =========================
# translate userName to wikiName
# e.g. jdoe to Main.JohnDoe
#   or jdoe to JohnDoe if $dontAddWeb is true
# =========================
sub userToWikiName
{
#   my( $user, $dontAddWeb ) = @_;
    return &TWiki::userToWikiName( @_ );
}

# =========================
# returns true if user is guest
# =========================
sub isGuest
{
    return &TWiki::isGuest();
}

# =========================
# Write HTML header
# =========================
sub writeHeader
{
#   my( $theQuery ) = @_;
    return &TWiki::writeHeader( @_ );
}

# =========================
# get CGI query object
# =========================
sub getCgiQuery
{
    return &TWiki::getCgiQuery();
}

# =========================
# redirect to URL
# =========================
sub redirectCgiQuery
{
#   my( $theQuery, $theUrl ) = @_;
    return &TWiki::redirect( @_ );
}

# =========================u
# search web
# if you need to do a search then use handleCommonTags( "%SEARCH{...}%" );
# =========================

# =========================
# format the time
# =========================
sub formatGmTime
{
#   my $epSecs = @_;
    return &TWiki::formatGmTime( @_ );
}

1;

# EOF
