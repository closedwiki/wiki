# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2004 Peter Thoeny, Peter@Thoeny.com
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
#
# Note: Use the TWiki:Plugins/PerlDocPlugin to extract the documentation
#       Unlike in other modules, do not use a ---+ level one heading

=begin twiki

---++ Description

This module defines official funtions that [[%TWIKIWEB%.TWikiPlugins][Plugins]] 
and add-on scripts can use to interact with the TWiki engine and content.

Plugins should *only* use functions published in this module. If you use
functions in other TWiki libraries you might impose a security hole and 
you will likely need to change your Plugin when you upgrade TWiki.

The version of the TWiki::Func module is defined by the VERSION number of the 
TWiki::Plugins module, currently %PLUGINVERSION{}%. This can be shown by the 
=%<nop>PLUGINVERSION{}%= variable. The "Since" field in the function documentation 
refers to the VERSION number and the date that the function was addded.

*Note* Contrib authors beware! These methods should only ever be called
from the context of a TWiki plugin. They require a session context to be
established before they are called, and will not work if simply called from
another TWiki module unless the session object is defined first.

=cut

package TWiki::Func;

use strict;

# =========================
=pod

---++ Functions: CGI Environment

---+++ getSessionValue( $key ) ==> $value

| Description:      | Get a session value from the Session Plugin (if installed) |
| Parameter: =$key= | Session key |
| Return: =$value=  | Value associated with key; empty string if not set; undef if session plugin is not installed |
| Since:            | TWiki::Plugins::VERSION 1.000 (27 Feb 2001) |

=cut
# -------------------------
sub getSessionValue
{
#   my( $theKey ) = @_;

    return TWiki::Plugins::getSessionValueHandler( @_ );
}


# =========================
=pod

---+++ setSessionValue( $key, $value ) ==> $result

| Description:        | Set a session value via the Session Plugin (if installed) |
| Parameter: =$key=   | Session key |
| Parameter: =$value= | Value associated with key |
| Return: =$result=   | ="1"= if success; undef if session plugin is not installed |
| Since:              | TWiki::Plugins::VERSION 1.000 (17 Aug 2001) |

=cut
# -------------------------
sub setSessionValue
{
#   my( $theKey, $theValue ) = @_;
    TWiki::Plugins::setSessionValueHandler( @_ );
}

# =========================
=pod

---+++ getSkin( ) ==> $skin

| Description:    | Get the name of the skin, set by the =SKIN= preferences variable or the =skin= CGI parameter |
| Return: =$skin= | Name of skin, e.g. ="gnu"=. Empty string if none |
| Since:          | TWiki::Plugins::VERSION 1.000 (29 Jul 2001) |

=cut
# -------------------------
sub getSkin
{
    return $TWiki::Plugins::SESSION->getSkin();
}

# =========================
=pod

---+++ getUrlHost( ) ==> $host

| Description:    | Get protocol, domain and optional port of script URL |
| Return: =$host= | URL host, e.g. ="http://example.com:80"= |
| Since:          | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

=cut
# -------------------------
sub getUrlHost
{
    return $TWiki::Plugins::SESSION->{urlHost};
}

# =========================
=pod

---+++ getScriptUrl( $web, $topic, $script ) ==> $url

| Description:         | Compose fully qualified URL |
| Parameter: =$web=    | Web name, e.g. ="Main"= |
| Parameter: =$topic=  | Topic name, e.g. ="WebNotify"= |
| Parameter: =$script= | Script name, e.g. ="view"= |
| Return: =$url=       | URL, e.g. ="http://example.com:80/cgi-bin/view.pl/Main/WebNotify"= |
| Since:               | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

=cut
# -------------------------
sub getScriptUrl
{
#   my( $web, $topic, $script ) = @_;
    return $TWiki::Plugins::SESSION->getScriptUrl( @_ ); 
}

# =========================
=pod

---+++ getScriptUrlPath( ) ==> $path

| Description:    | Get script URL path |
| Return: =$path= | URL path of TWiki scripts, e.g. ="/cgi-bin"= |
| Since:          | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

=cut
# -------------------------
sub getScriptUrlPath
{
    return $TWiki::Plugins::SESSION->{scriptUrlPath};
}

# =========================
=pod

---+++ getViewUrl( $web, $topic ) ==> $url

| Description:        | Compose fully qualified view URL |
| Parameter: =$web=   | Web name, e.g. ="Main"=. The current web is taken if empty |
| Parameter: =$topic= | Topic name, e.g. ="WebNotify"= |
| Return: =$url=      | URL, e.g. ="http://example.com:80/cgi-bin/view.pl/Main/WebNotify"= |
| Since:              | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

=cut
# -------------------------
sub getViewUrl
{
    my( $web, $topic ) = @_;
    return $TWiki::Plugins::SESSION->getScriptUrl( $web, $topic, "view" );
}

# =========================
=pod

---+++ getOopsUrl( $web, $topic, $template, $param1, $param2, $param3, $param4 ) ==> $url

| Description:                       | Compose fully qualified "oops" dialog URL |
| Parameter: =$web=                  | Web name, e.g. ="Main"=. The current web is taken if empty |
| Parameter: =$topic=                | Topic name, e.g. ="WebNotify"= |
| Parameter: =$template=             | Oops template name, e.g. ="oopslocked"= |
| Parameter: =$param1= ... =$param4= | Parameter values for %<nop>PARAM1% ... %<nop>PARAMn% variables in template, optional |
| Return: =$url=                     | URL, e.g. ="http://example.com:80/cgi-bin/oops.pl/ Main/WebNotify?template=oopslocked&amp;param1=joe"= |
| Since:                             | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

=cut
# -------------------------
sub getOopsUrl
{
#   my( $web, $topic, $template, @params ) = @_;
    return $TWiki::Plugins::SESSION->getOopsUrl( @_ );
}

# =========================
=pod

---+++ getPubUrlPath( ) ==> $path

| Description:    | Get pub URL path |
| Return: =$path= | URL path of pub directory, e.g. ="/pub"= |
| Since:          | TWiki::Plugins::VERSION 1.000 (14 Jul 2001) |

=cut
# -------------------------
sub getPubUrlPath
{
    return $TWiki::pubUrlPath;
}

# =========================
=pod

---+++ getCgiQuery( ) ==> $query

| Description:     | Get CGI query object. Important: Plugins cannot assume that scripts run under CGI, Plugins must always test if the CGI query object is set |
| Return: =$query= | CGI query object; or 0 if script is called as a shell script |
| Since:           | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

=cut
# -------------------------
sub getCgiQuery
{
    return $TWiki::Plugins::SESSION->{cgiQuery};
}

# =========================
=pod

---+++ writeHeader( $query, $contentLength )

| Description:        | Prints a basic content-type HTML header for text/html to standard out |
| Parameter: =$query= | CGI query object. If not given, the default CGI query will be used. In most cases you should _not_ pass this parameter. |
| Parameter: =$contentLength= | Length of content |
| Return:             | none |
| Since:              | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

=cut
# -------------------------
sub writeHeader
{
    my( $theQuery ) = @_;
    return $TWiki::Plugins::SESSION->writePageHeader( $theQuery );
}

# =========================
=pod

---+++ redirectCgiQuery( $query, $url )

| Description:        | Redirect to URL |
| Parameter: =$query= | CGI query object. Ignored, only there for compatibility. The session CGI query object is used instead. |
| Parameter: =$url=   | URL to redirect to |
| Return:             | none, never returns |
| Since:              | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

=cut
# -------------------------
sub redirectCgiQuery
{
    my( $theQuery, $theUrl ) = @_;
    return $TWiki::Plugins::SESSION->redirect( $theUrl );
}

# =========================
=pod

---++ Functions: Preferences

---+++ extractParameters( $attr ) ==> %params

| Description:       | Extract all parameters from a variable string and returns a hash of parameters |
| Parameter: =$attr= | Attribute string |
| Return: =%params=  | Hash containing all parameters. The nameless parameter is stored in key =_DEFAULT= |
| Since:             | TWiki::Plugins::VERSION 1.025 (26 Aug 2004) |

   * Example:
      * Variable: =%<nop>TEST{ "nameless" name1="val1" name2="val2" }%=
      * First extract text between ={...}= to get: ="nameless" name1="val1" name2="val2"=
      * Then call this on the text: <br />
        =my %params = TWiki::Func::extractParameters( $text );=
      * The =%params= hash contains now: <br />
        =_DEFAULT => "nameless"= <br />
        =name1 => "val1"= <br />
        =name2 => "val2"=

=cut
# -------------------------
sub extractParameters
{
#   my( $theAttr ) = @_;
    my $params = TWiki::extractParameters( @_ );
    return %$params;
}

# =========================
=pod

---+++ extractNameValuePair( $attr, $name ) ==> $value

| Description:       | Extract a named or unnamed value from a variable parameter string |
| Note:              | Function TWiki::Func::extractParameters is more efficient for extracting several parameters |
| Parameter: =$attr= | Attribute string |
| Parameter: =$name= | Name, optional |
| Return: =$value=   | Extracted value |
| Since:             | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

   * Example:
      * Variable: =%<nop>TEST{ "nameless" name1="val1" name2="val2" }%=
      * First extract text between ={...}= to get: ="nameless" name1="val1" name2="val2"=
      * Then call this on the text: <br />
        =my $noname = TWiki::Func::extractNameValuePair( $text );= <br />
        =my $val1  = TWiki::Func::extractNameValuePair( $text, "name1" );= <br />
        =my $val2  = TWiki::Func::extractNameValuePair( $text, "name2" );=

=cut
# -------------------------
sub extractNameValuePair
{
#   my( $theAttr, $theName ) = @_;
    return &TWiki::extractNameValuePair( @_ );
}

# =========================
=pod

---+++ getPreferencesValue( $key, $web ) ==> $value

| Description:      | Get a preferences value from TWiki or from a Plugin |
| Parameter: =$key= | Preferences key |
| Parameter: =$web= | Name of web, optional. Current web if not specified; does not apply to settings of Plugin topics |
| Return: =$value=  | Preferences value; empty string if not set |
| Since:            | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

   * Example for Plugin setting:
      * MyPlugin topic has: =* Set COLOR = red=
      * Use ="MYPLUGIN_COLOR"= for =$key=
      * =my $color = TWiki::Func::getPreferencesValue( "MYPLUGIN_COLOR" );=

   * Example for preferences setting:
      * WebPreferences topic has: =* Set WEBBGCOLOR = #FFFFC0=
      * =my $webColor = TWiki::Func::getPreferencesValue( "WEBBGCOLOR", "Sandbox" );=

=cut
# -------------------------
sub getPreferencesValue
{
#   my( $theKey, $theWeb ) = @_;
    return $TWiki::Plugins::SESSION->{prefs}->getPreferencesValue( @_ );
}

=pod

---+++ getPluginPreferencesValue( $key ) ==> $value

| Description:      | Get a preferences value from your Plugin |
| Parameter: =$key= | Plugin Preferences key w/o PLUGINNAME_ prefix. |
| Return: =$value=  | Preferences value; empty string if not set |
| Since:            | TWiki::Plugins::VERSION 1.021 (27 Mar 2004) |

=cut

sub getPluginPreferencesValue
{
    my( $theKey ) = @_;
    my $package = caller;
    $package =~ s/.*:://; # strip off TWiki::Plugins:: prefix
    return $TWiki::Plugins::SESSION->{prefs}->getPreferencesValue( "\U$package\E_$theKey" );
}

# =========================
=pod

---+++ getPreferencesFlag( $key, $web ) ==> $value

| Description:      | Get a preferences flag from TWiki or from a Plugin |
| Parameter: =$key= | Preferences key |
| Parameter: =$web= | Name of web, optional. Current web if not specified; does not apply to settings of Plugin topics |
| Return: =$value=  | Preferences flag ="1"= (if set), or ="0"= (for preferences values ="off"=, ="no"= and ="0"=) |
| Since:            | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

   * Example for Plugin setting:
      * MyPlugin topic has: =* Set SHOWHELP = off=
      * Use ="MYPLUGIN_SHOWHELP"= for =$key=
      * =my $showHelp = TWiki::Func::getPreferencesFlag( "MYPLUGIN_SHOWHELP" );=

=cut
# -------------------------
sub getPreferencesFlag
{
#   my( $theKey, $theWeb ) = @_;
    return $TWiki::Plugins::SESSION->{prefs}->getPreferencesFlag( @_ );
}

=pod

---+++ getPluginPreferencesFlag( $key ) ==> $flag

| Description:      | Get a preferences flag from your Plugin |
| Parameter: =$key= | Plugin Preferences key w/o PLUGINNAME_ prefix. |
| Return: =$flag=   | Preferences flag ="1"= (if set), or ="0"= (for preferences values ="off"=, ="no"= and ="0"=, or values not set at all) |
| Since:            | TWiki::Plugins::VERSION 1.021 (27 Mar 2004) |

=cut

sub getPluginPreferencesFlag
{
    my( $theKey ) = @_;
    my $package = caller;
    $package =~ s/.*:://; # strip off TWiki::Plugins:: prefix
    return $TWiki::Plugins::SESSION->{prefs}->getPreferencesFlag( "\U$package\E_$theKey" );
}

# =========================
=pod

---+++ getWikiToolName( ) ==> $name

| Description:    | Get toolname as defined in TWiki.cfg |
| Return: =$name= | Name of tool, e.g. ="TWiki"= |
| Since:          | TWiki::Plugins::VERSION 1.000 (27 Feb 2001) |

=cut
# -------------------------
sub getWikiToolName
{
    return $TWiki::wikiToolName;
}

# =========================
=pod

---+++ getMainWebname( ) ==> $name

| Description:    | Get name of Main web as defined in TWiki.cfg |
| Return: =$name= | Name, e.g. ="Main"= |
| Since:          | TWiki::Plugins::VERSION 1.000 (27 Feb 2001) |

=cut
# -------------------------
sub getMainWebname
{
    return $TWiki::mainWebname;
}

# =========================
=pod

---+++ getTwikiWebname( ) ==> $name

| Description:    | Get name of TWiki documentation web as defined in TWiki.cfg |
| Return: =$name= | Name, e.g. ="TWiki"= |
| Since:          | TWiki::Plugins::VERSION 1.000 (27 Feb 2001) |

=cut
# -------------------------
sub getTwikiWebname
{
    return $TWiki::twikiWebname;
}

# =========================
=pod

---++ Functions: User Handling and Access Control

---+++ getDefaultUserName( ) ==> $loginName

| Description:         | Get default user name as defined in TWiki.cfg's =$defaultUserName= |
| Return: =$loginName= | Default user name, e.g. ="guest"= |
| Since:               | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

=cut
# -------------------------
sub getDefaultUserName
{
    return $TWiki::defaultUserName;
}

# =========================
=pod

---+++ getWikiName( ) ==> $wikiName

| Description:        | Get Wiki name of logged in user |
| Return: =$wikiName= | Wiki Name, e.g. ="JohnDoe"= |
| Since:              | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

=cut
# -------------------------
sub getWikiName
{
    return $TWiki::Plugins::SESSION->{users}->userToWikiName( $TWiki::Plugins::SESSION->{userName}, 1 );
}

# =========================
=pod

---+++ getWikiUserName( $text ) ==> $wikiName

| Description:        | Get Wiki name of logged in user with web prefix |
| Return: =$wikiName= | Wiki Name, e.g. ="Main.JohnDoe"= |
| Since:              | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

=cut
# -------------------------
sub getWikiUserName
{
    return $TWiki::Plugins::SESSION->{users}->userToWikiName( $TWiki::Plugins::SESSION->{userName} );
}

# =========================
=pod

---+++ wikiToUserName( $wikiName ) ==> $loginName

| Description:           | Translate a Wiki name to a login name based on [[%MAINWEB%.TWikiUsers]] topic |
| Parameter: =$wikiName= | Wiki name, e.g. ="Main.JohnDoe"= or ="JohnDoe"= |
| Return: =$loginName=   | Login name of user, e.g. ="jdoe"= |
| Since:                 | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

=cut
# -------------------------
sub wikiToUserName
{
#   my( $wiki ) = @_;
    return $TWiki::Plugins::SESSION->{users}->wikiToUserName( @_ );
}

# =========================
=pod

---+++ userToWikiName( $loginName, $dontAddWeb ) ==> $wikiName

| Description:             | Translate a login name to a Wiki name based on [[%MAINWEB%.TWikiUsers]] topic |
| Parameter: =$loginName=  | Login name, e.g. ="jdoe"= |
| Parameter: =$dontAddWeb= | Do not add web prefix if ="1"= |
| Return: =$wikiName=      | Wiki name of user, e.g. ="Main.JohnDoe"= or ="JohnDoe"= |
| Since:                   | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

=cut
# -------------------------
sub userToWikiName
{
#   my( $loginName, $dontAddWeb ) = @_;
    return $TWiki::Plugins::SESSION->{users}->userToWikiName( @_ );
}

# =========================
=pod

---+++ isGuest( ) ==> $flag

| Description:    | Test if logged in user is a guest |
| Return: =$flag= | ="1"= if yes, ="0"= if not |
| Since:          | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

=cut
# -------------------------
sub isGuest
{
    return ( $TWiki::Plugins::SESSION->{userName} eq $TWiki::defaultUserName );
}

# =========================
=pod

---+++ permissionsSet( $web ) ==> $flag

| Description:      | Test if any access restrictions are set for this web, ignoring settings on individual pages |
| Parameter: =$web= | Web name, required, e.g. ="Sandbox"= |
| Return: =$flag=   | ="1"= if yes, ="0"= if no |
| Since:            | TWiki::Plugins::VERSION 1.000 (27 Feb 2001) |

=cut
# -------------------------
sub permissionsSet
{
#   my( $web ) = @_;
    return $TWiki::Plugins::SESSION->{security}->permissionsSet( @_ );
}

# =========================
=pod

---+++ checkAccessPermission( $type, $wikiName, $text, $topic, $web ) ==> $flag

| Description:           | Check access permission for a topic based on the [[%TWIKIWEB%.TWikiAccessControl]] rules |
| Parameter: =$type=     | Access type, e.g. ="VIEW"=, ="CHANGE"=, ="CREATE"= |
| Parameter: =$wikiName= | WikiName of remote user, i.e. ="Main.PeterThoeny"= |
| Parameter: =$text=     | Topic text, optional. If empty, topic =$web.$topic= is consulted |
| Parameter: =$topic=    | Topic name, required, e.g. ="PrivateStuff"= |
| Parameter: =$web=      | Web name, required, e.g. ="Sandbox"= |
| Return: =$flag=        | ="1"= if access may be granted, ="0"= if not |
| Since:                 | TWiki::Plugins::VERSION 1.000 (27 Feb 2001) |

=cut
# -------------------------
sub checkAccessPermission
{
#   my( $type, $user, $text, $topic, $web ) = @_;
    return $TWiki::Plugins::SESSION->{security}->checkAccessPermission( @_ );
}

# =========================
=pod

---++ Functions: Content Handling

---+++ webExists( $web ) ==> $flag

| Description:      | Test if web exists |
| Parameter: =$web= | Web name, required, e.g. ="Sandbox"= |
| Return: =$flag=   | ="1"= if web exists, ="0"= if not |
| Since:            | TWiki::Plugins::VERSION 1.000 (14 Jul 2001) |

=cut
# -------------------------
sub webExists
{
#   my( $theWeb ) = @_;
    return $TWiki::Plugins::SESSION->{store}->webExists( @_ );
}

# =========================
=pod

---+++ topicExists( $web, $topic ) ==> $flag

| Description:        | Test if topic exists |
| Parameter: =$web=   | Web name, optional, e.g. ="Main"= |
| Parameter: =$topic= | Topic name, required, e.g. ="TokyoOffice"=, or ="Main.TokyoOffice"= |
| Return: =$flag=     | ="1"= if topic exists, ="0"= if not |
| Since:              | TWiki::Plugins::VERSION 1.000 (14 Jul 2001) |

=cut
# -------------------------
sub topicExists
{
#   my( $web, $topic ) = @_;
    return $TWiki::Plugins::SESSION->{store}->topicExists( @_ );
}

# =========================
=pod

---+++ getRevisionInfo($theWebName, $theTopic, $theRev, $attachment ) ==> ( $date, $user, $rev, $comment ) 
| Description:           | Get revision info of a topic |
| Parameter: =$theWebName= | Web name, optional, e.g. ="Main"= |
| Parameter: =$theTopic=   | Topic name, required, e.g. ="TokyoOffice"= |
| Parameter: =$theRev=     | revsion number, or tag name (can be in the format 1.2, or just the minor number) |
| Parameter: =$attachment=                 |attachment filename |
| Return: =( $date, $user, $rev, $comment )= | List with: ( last update date, login name of last user, minor part of top revision number ), e.g. =( 1234561, "phoeny", "5" )= |
| $date | in epochSec |
| $user | |
| $rev |  |
| $comment | WHAT COMMENT? |
| Since:                                | TWiki::Plugins::VERSION 1.000 (29 Jul 2001) |

=cut
# -------------------------
sub getRevisionInfo
{
    return $TWiki::Plugins::SESSION->{store}->getRevisionInfo( @_ );
}

# =========================
=pod

---+++ checkTopicEditLock( $web, $topic ) ==> ( $oopsUrl, $loginName, $unlockTime )

*DOES NOTHING* - deprecated by ReleaseEditLocksOnSave since
TWiki::Plugins::VERSION 1.026

=cut
# -------------------------
sub checkTopicEditLock
{
    return( "", "", 0 );
}

# =========================
=pod

---+++ setTopicEditLock( $web, $topic, $lock ) ==> $oopsUrl

*DOES NOTHING* - deprecated by ReleaseEditLocksOnSave since
TWiki::Plugins::VERSION 1.026

=cut
# -------------------------
sub setTopicEditLock
{
    return "";
}

# =========================
=pod

---+++ readTopicText( $web, $topic, $rev, $ignorePermissions ) ==> $text

| Description:                     | Read topic text, including meta data |
| Parameter: =$web=                | Web name, e.g. ="Main"=, or empty |
| Parameter: =$topic=              | Topic name, e.g. ="MyTopic"=, or ="Main.MyTopic"= |
| Parameter: =$rev=                | Topic revision to read, optional. Specify the minor part of the revision, e.g. ="5"=, not ="1.5"=; the top revision is returned if omitted or empty. |
| Parameter: =$ignorePermissions=  | Set to ="1"= if checkAccessPermission() is already performed and OK; an oops URL is returned if user has no permission |
| Return: =$text=                  | Topic text with embedded meta data; an oops URL for calling redirectCgiQuery() is returned in case of an error |
| Since:                           | TWiki::Plugins::VERSION 1.010 (31 Dec 2002) |

=cut
# -------------------------
sub readTopicText
{
    my( $web, $topic, $rev, $ignorePermissions ) = @_;

    $ignorePermissions = 0 unless defined( $ignorePermissions );

    my $text =
      $TWiki::Plugins::SESSION->{store}->readTopicRaw( $TWiki::Plugins::SESSION->{wikiUserName}, $web, $topic, $rev,
                                  $ignorePermissions );

    # FIXME: The following breaks if spec of readTopicRaw() changes
    if( $text =~ /^No permission to read topic/ ) {
        $text = $TWiki::Plugins::SESSION->getOopsUrl( $web, $topic, "oopsaccessview" );
    }
    return $text;
}

# =========================
=pod

---+++ saveTopicText( $web, $topic, $text, $ignorePermissions, $dontNotify ) ==> $oopsUrl

| Description:                     | Save topic text, typically obtained by readTopicText(). Topic data usually includes meta data; the file attachment meta data is replaced by the meta data from the topic file if it exists. |
| Parameter: =$web=                | Web name, e.g. ="Main"=, or empty |
| Parameter: =$topic=              | Topic name, e.g. ="MyTopic"=, or ="Main.MyTopic"= |
| Parameter: =$text=               | Topic text to save, assumed to include meta data |
| Parameter: =$ignorePermissions=  | Set to ="1"= if checkAccessPermission() is already performed and OK |
| Parameter: =$dontNotify=         | Set to ="1"= if not to notify users of the change |
| Return: =$oopsUrl=               | Empty string if OK; the =$oopsUrl= for calling redirectCgiQuery() in case of error |
| Since:                           | TWiki::Plugins::VERSION 1.010 (31 Dec 2002) |

   * Example: <br />
     =my $text = TWiki::Func::readTopicText( $web, $topic );        # read topic text= <br />
     =# check for oops URL in case of error:= <br />
     =if( $text =~ /^http.*?\/oops/ ) {= <br />
     =&nbsp;   TWiki::Func::redirectCgiQuery( $query, $text );= <br />
     =&nbsp;   return;= <br />
     =}= <br />
     =# do topic text manipulation like:= <br />
     =$text =~ s/old/new/g;= <br />
     =# do meta data manipulation like:= <br />
     =$text =~ s/(META\:FIELD.*?name\=\"TopicClassification\".*?value\=\")[^\"]*/$1BugResolved/;= <br />
     =$oopsUrl = TWiki::Func::saveTopicText( $web, $topic, $text ); # save topic text= <br />

=cut

# -------------------------
sub saveTopicText
{
    my( $web, $topic, $text, $ignorePermissions, $dontNotify ) = @_;

    my( $mirrorSite, $mirrorViewURL ) = $TWiki::Plugins::SESSION->readOnlyMirrorWeb( $web );
    return $TWiki::Plugins::SESSION->getOopsUrl( $web, $topic, "oopsmirror", $mirrorSite, $mirrorViewURL ) if( $mirrorSite );

    # check access permission
    unless( $ignorePermissions ||
            $TWiki::Plugins::SESSION->{security}->checkAccessPermission( "change",
                                                     $TWiki::Plugins::SESSION->{wikiUserName}, "",
                                                     $topic, $web )
          ) {
        return $TWiki::Plugins::SESSION->getOopsUrl( $web, $topic, "oopsaccesschange" );
    }

    return $TWiki::Plugins::SESSION->getOopsUrl( $web, $topic, "oopssave" )  unless( defined $text );
    return $TWiki::Plugins::SESSION->getOopsUrl( $web, $topic, "oopsempty" ) unless( $text ); # empty topic not allowed

    # extract meta data and merge old attachment meta data
    my $meta = $TWiki::Plugins::SESSION->{store}->extractMetaData( $web, $topic, \$text );
    my( $oldMeta, $oldText ) =
      $TWiki::Plugins::SESSION->{store}->readTopic( $TWiki::Plugins::SESSION->{wikiUserName}, $web, $topic, undef, 1 );
    $meta->copyFrom( $oldMeta, "FILEATTACHMENT" );

    # save topic
    my $error =
      $TWiki::Plugins::SESSION->{store}->saveTopic
        ( $TWiki::Plugins::SESSION->{userName}, $web, $topic, $text, $meta,
          { notify => $dontNotify } );
    return $TWiki::Plugins::SESSION->getOopsUrl( $web, $topic, "oopssaveerr", $error ) if( $error );
    return "";
}

# =========================
=pod

---+++ getPublicWebList( ) ==> @webs

| Description:    | Get list of all public webs, e.g. all webs that do not have the =NOSEARCHALL= flag set in the WebPreferences |
| Return: =@webs= | List of all public webs, e.g. =( "Main",  "Know", "TWiki" )= |
| Since:          | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

=cut
# -------------------------
sub getPublicWebList
{
    return $TWiki::Plugins::SESSION->getPublicWebList();
}

# =========================
=pod

---+++ getTopicList( $web ) ==> @topics

| Description:      | Get list of all topics in a web |
| Parameter: =$web= | Web name, required, e.g. ="Sandbox"= |
| Return: =@topics= | Topic list, e.g. =( "WebChanges",  "WebHome", "WebIndex", "WebNotify" )= |
| Since:            | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

=cut
# -------------------------
sub getTopicList
{
#   my( $web ) = @_;
    return $TWiki::Plugins::SESSION->{store}->getTopicNames ( @_ );
}

=pod

---++ Functions: Rendering

---+++ expandCommonVariables( $text, $topic, $web ) ==> $text

| Description:        | Expand all common =%<nop>VARIABLES%= |
| Parameter: =$text=  | Text with variables to expand, e.g. ="Current user is %<nop>WIKIUSER%"= |
| Parameter: =$topic= | Current topic name, e.g. ="WebNotify"= |
| Parameter: =$web=   | Web name, optional, e.g. ="Main"=. The current web is taken if missing |
| Return: =$text=     | Expanded text, e.g. ="Current user is <nop>TWikiGuest"= |
| Since:              | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

=cut
# -------------------------
sub expandCommonVariables
{
#   my( $text, $topic, $web ) = @_;
    return $TWiki::Plugins::SESSION->handleCommonTags( @_ );
}

# =========================
=pod

---+++ renderText( $text, $web ) ==> $text

| Description:       | Render text from TWiki markup into XHTML as defined in [[%TWIKIWEB%.TextFormattingRules]] |
| Parameter: =$text= | Text to render, e.g. ="*bold* text and =fixed font="= |
| Parameter: =$web=  | Web name, optional, e.g. ="Main"=. The current web is taken if missing |
| Return: =$text=    | XHTML text, e.g. ="&lt;b>bold&lt;/b> and &lt;code>fixed font&lt;/code>"= |
| Since:             | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

=cut
# -------------------------
sub renderText
{
#   my( $text, $web ) = @_;
    return $TWiki::Plugins::SESSION->{renderer}->getRenderedVersion( @_ );
}

# =========================
=pod

---+++ internalLink( $pre, $web, $topic, $label, $anchor, $createLink ) ==> $text

| Description:             | Render topic name and link label into an XHTML link. Normally you do not need to call this funtion, it is called internally by =renderText()= |
| Parameter: =$pre=        | Text occuring before the TWiki link syntax, optional |
| Parameter: =$web=        | Web name, required, e.g. ="Main"= |
| Parameter: =$topic=      | Topic name to link to, required, e.g. ="WebNotify"= |
| Parameter: =$label=      | Link label, required. Usually the same as =$topic=, e.g. ="notify"= |
| Parameter: =$anchor=     | Anchor, optional, e.g. ="#Jump"= |
| Parameter: =$createLink= | Set to ="1"= to add question linked mark after topic name if topic does not exist;<br /> set to ="0"= to suppress link for non-existing topics |
| Return: =$text=          | XHTML anchor, e.g. ="&lt;a href="/cgi-bin/view/Main/WebNotify#Jump">notify&lt;/a>"= |
| Since:                   | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

=cut
# -------------------------
sub internalLink
{
    my $pre = shift;
#   my( $web, $topic, $label, $anchor, $anchor, $createLink ) = @_;
    return $pre . $TWiki::Plugins::SESSION->{renderer}->internalLink( @_ );
}

# =========================
=pod

---+++ search text( $text ) ==> $text

| Description:       | This is not a function, just a how-to note. Use: =expandCommonVariables("%<nop>SEARCH{...}%" );= |
| Parameter: =$text= | Search variable |
| Return: =$text=  | Search result in [[%TWIKIWEB%.FormattedSearch]] format |

=cut

# =========================
=pod

---+++ formatTime( $time, $format, $timezone ) ==> $text

| Description:            | Format the time in seconds into the desired time string |
| Parameter: =$time=     | Time in epoc seconds |
| Parameter: =$format=   | Format type, optional. Default e.g. ="31 Dec 2002 - 19:30"=. Can be ='$iso'= (e.g. ="2002-12-31T19:30Z"=), ='$rcs'= (e.g. ="2001/12/31 23:59:59"=, ='$http'= for HTTP header format (e.g. ="Thu, 23 Jul 1998 07:21:56 GMT"=), or any string with tokens ='$seconds, $minutes, $hours, $day, $wday, $month, $mo, $year, $ye, $tz'= for seconds, minutes, hours, day of month, day of week, 3 letter month, 2 digit month, 4 digit year, 2 digit year, timezone string, respectively |
| Parameter: =$timezone= | either not defined (uses the displaytime setting), "gmtime", or "servertime" |
| Return: =$text=        | Formatted time string |
| Note:                  | if you used the removed formatGmTime, add a third parameter "gmtime" |
| Since:                 | TWiki::Plugins::VERSION 1.020 (26 Feb 2004) |

=cut
# -------------------------
sub formatTime
{
#   my ( $epSecs, $format, $timezone ) = @_;
    return &TWiki::formatTime( @_ );
}

# =========================
=pod

---+++ formatGmTime( $time, $format ) ==> $text

| NOTE:                | <b>This function is deprecated and should not be used. Use formatTime() instead</b> |
| Description:         | Format the time to GM time |
| Parameter: =$time=   | Time in epoc seconds |
| Parameter: =$format= | Format type, optional. Default e.g. ="31 Dec 2002 - 19:30"=, can be ="iso"= (e.g. ="2002-12-31T19:30Z"=), ="rcs"= (e.g. ="2001/12/31 23:59:59"=, ="http"= for HTTP header format (e.g. ="Thu, 23 Jul 1998 07:21:56 GMT"=) |
| Return: =$text=      | Formatted time string |
| Since:               | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

=cut
# -------------------------
sub formatGmTime
{
#   my ( $epSecs, $format ) = @_;

    # FIXME: Write warning based on flag (disabled for now); indicate who is calling this function
    ## writeWarning( "deprecated use of Func::formatGmTime" );

    return &formatTime( @_, "gmtime" );
}


# =========================
=pod

---++ Functions: File I/O

---+++ getDataDir( ) ==> $dir

| Description:   | Get data directory (topic file root) |
| Return: =$dir= | Data directory, e.g. ="/twiki/data"= |
| Since:         | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

SMELL: this function violates store encapsulation and should be avoided
wherever possible!

=cut
# -------------------------
sub getDataDir
{
    return $TWiki::dataDir;
}

# =========================
=pod

---+++ getPubDir( ) ==> $dir

| Description:   | Get pub directory (file attachment root). Attachments are in =$dir/Web/TopicName= |
| Return: =$dir= | Pub directory, e.g. ="/htdocs/twiki/pub"= |
| Since:         | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

SMELL: this function violates store encapsulation and should be avoided
wherever possible!

=cut
# -------------------------
sub getPubDir
{
    return $TWiki::pubDir;
}

# =========================
=pod

---+++ readTopic( $web, $topic ) ==> ( $meta, $text )

| NOTE:                      | <b>The following function is deprecated and should not be used. Use readTopicText() instead</b> |
| Description:               | Read topic text and meta data, regardless of access permissions. |
| Parameter: =$web=          | Web name, required, e.g. ="Main"= |
| Parameter: =$topic=        | Topic name, required, e.g. ="TokyoOffice"= |
| Return: =( $meta, $text )= | Meta data object and topic text |
| Since:                     | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

=cut
# -------------------------
sub readTopic
{
    my( $web, $topic ) = @_;

    return $TWiki::Plugins::SESSION->{store}->readTopic( $TWiki::Plugins::SESSION->{wikiUserName}, $web, $topic, undef, 0 );
}

# =========================
=pod

---+++ readTemplate( $name, $skin ) ==> $text

| Description:       | Read a template or skin file. Embedded [[%TWIKIWEB%.TWikiTemplates][template directives]] get expanded |
| Parameter: =$name= | Template name, e.g. ="view"= |
| Parameter: =$skin= | Skin name, optional, e.g. ="print"= |
| Return: =$text=    | Template text |
| Since:             | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

=cut
# -------------------------
sub readTemplate
{
#   my( $name, $skin ) = @_;
    return &TWiki::Store::readTemplate( @_ );
}

# =========================
=pod

---+++ readFile( $filename ) ==> $text

| Description:           | Read text file, low level. NOTE: For topics use readTopicText() |
| Parameter: =$filename= | Full path name of file |
| Return: =$text=        | Content of file |
| Since:                 | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |

=cut
# -------------------------
sub readFile
{
#   my( $filename ) = @_;
    return $TWiki::Plugins::SESSION->{store}->readFile( @_ );
}

# =========================
=pod

---+++ saveFile( $filename, $text )

| Description:           | Save text file, low level. NOTE: For topics use saveTopicText() |
| Parameter: =$filename= | Full path name of file |
| Parameter: =$text=     | Text to save |
| Return:                | none |
| Since:                 | TWiki::Plugins::VERSION 1.000 (7 Dec 2002) |
| TODO:                  | This should return an error for the different failure modes. |

=cut
# -------------------------
sub saveFile
{
#   my( $filename, $text ) = @_;
    return $TWiki::Plugins::SESSION->{store}->saveFile( @_ );
}

# =========================
=pod

---+++ writeWarning( $text )

| Description:       | Log Warning that may require admin intervention to data/warning.txt |
| Parameter: =$text= | Text to write; timestamp gets added |
| Return:            | none |
| Since:             | TWiki::Plugins::VERSION 1.020 (16 Feb 2004) |

=cut
# -------------------------
sub writeWarning
{
#   my( $theText ) = @_;
    return $TWiki::Plugins::SESSION->writeWarning( @_ );
}

# =========================
=pod

---+++ writeDebug( $text )

| Description:       | Log debug message to data/debug.txt |
| Parameter: =$text= | Text to write; timestamp gets added |
| Return:            | none |
| Since:             | TWiki::Plugins::VERSION 1.020 (16 Feb 2004) |

=cut
# -------------------------
sub writeDebug
{
#   my( $theText ) = @_;
    return $TWiki::Plugins::SESSION->writeDebug( @_ );
}

# =========================
=pod

---++ Functions: System and I18N related

---+++ getRegularExpression( $regexName ) ==> $pattern

| Description:            | Retrieves a TWiki predefined regular expression |
| Parameter: =$regexName= | Name of the regular expression to retrieve.  See notes below |
| Return:                 | String or precompiled regular expression matching as described below |
| Since:                  | TWiki::Plugins::VERSION 1.020 (9 Feb 2004) |

__Notes:__ TWiki internally precompiles several regular expressions to represent various string entities
in an I18N-compatible manner.  Plugins are encouraged to use these in matching where appropriate.
The following are guaranteed to be present; others may exist, but their use is unsupported and
they may be removed in future TWiki versions.  Those which are marked "CC" are for use within
character classes and may not produce the desired results outside of them.

| *Name* | *Matches* | *CC* |
| upperAlpha | Upper case characters | Y |
| lowerAlpha | Lower case characters | Y |
| mixedAlpha | Alphabetic characters | Y |
| mixedAlphaNum | Alphanumeric charactecs | Y |
| wikiWordRegex | WikiWords | N |

Example:
<pre>
   my $upper = TWiki::Func::getRegularExpression("upperAlpha");
   my $alpha = TWiki::Func::getRegularExpression("mixedAlpha");
   my $capitalized = qr/[$upper][$alpha]+/;
</pre>

=cut

sub getRegularExpression
{
    my ( $regexName ) = @_;
    return $TWiki::regex{$regexName};
}

=pod

---+++ checkDependencies( $moduleName, $dependenciesRef ) ==> $error

| Description: | Checks a list of Perl dependencies at runtime |
| Parameter: =$moduleName= | Context description e.g. name of the module being checked |
| Parameter: =$dependenciesRef= | Reference of list of hashes containing dependency information; see notes below |
| Return: =$error= | undef if dependencies are OK, an error message otherwise |
| Since: | TWiki::Plugins::VERSION 1.025 (01 Aug 2004) |

The dependencies are expressed as a list of hashes. Each hash contains
the name of a package and (optionally) a boolean constraint on the VERSION
variable in that package. It is usually used from the =initPlugin= method
like this:
<verbatim>
    if( $TWiki::Plugins::VERSION >= 1.025 ) {
        my @deps = (
            { package => 'TWiki::Plugins::CalendarPlugin', constraint => '>= 5.030' },
            { package => 'Time::ParseDate' },
            { package => 'Apache::VMonitor' }
        );
        my $err = TWiki::Func::checkDependencies( $pluginName, \@deps );
        if( $err ) {
            TWiki::Func::writeWarning( $err );
            print STDERR $err; # print to webserver log file
            return 0; # plugin initialisation failed
        }
    }
</verbatim>

=cut

sub checkDependencies {
  my ( $context, $deps ) = @_;
  my $report = "";
  my $depsOK = 1;
  foreach my $dep ( @$deps ) {
    my ( $ok, $ver ) = ( 1, 0 );
    my $msg = "";
    my $const = "";

    eval "use $dep->{package}";
    if ( $@ ) {
        $msg .= "it could not be found: $@";
        $ok = 0;
    } else {
        if ( defined( $dep->{constraint} ) ) {
            $const = $dep->{constraint};
            eval "\$ver = \$$dep->{package}::VERSION;";
            if ( $@ ) {
                $msg .= "the VERSION of the package could not be found: $@";
                $ok = 0;
            } else {
                eval "\$ok = ( \$ver $const )";
                if ( $@ || ! $ok ) {
                    $msg .= " $ver is currently installed: $@";
                    $ok = 0;
                }
            }
        }
    }
    unless ( $ok ) {
        $report .= "WARNING: $dep->{package}$const is required for $context, but $msg\n";
        $depsOK = 0;
    }
  }
  return undef if( $depsOK );

  return $report;
}

# =========================
=pod

---++ Copyright and License

Copyright (C) 2000-2004 Peter Thoeny, Peter@Thoeny.com

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at 
http://www.gnu.org/copyleft/gpl.html

=cut

1;

# EOF
