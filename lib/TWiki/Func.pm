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
# Note: Use the PerlDocPlugin to extract the documentation

=begin twiki
---+ NAME

TWiki::Func - Official TWiki library functions for Plugins

---+ DESCRIPTION

This module defines official funtions that Plugins and add-on scripts
can use to interact with TWiki content.

Plugins should ONLY use functions published in this module. If you use
functions in other TWiki libraries you might impose a security hole and 
you will likely need to change your plugin when you upgrade TWiki.

=cut

package TWiki::Func;

use strict;


# =========================
=pod

---+ FUNCTIONS: CGI Environment

---++ getSessionValue( $key ) ==> $value

| Description: | Get a session value from the Session Plugin (if installed) |
| Parameter: =$key= | Session key |
| Return: =$value= | Value associated with key; empty string if not set; undef if session plugin is not installed |

=cut
# -------------------------
sub getSessionValue
{
#   my( $theKey ) = @_;
    return &TWiki::getSessionValue( @_ );
}


# =========================
=pod

---++ setSessionValue( $key, $value ) ==> $result

| Description: | Set a session value via the Session Plugin (if installed) |
| Parameter: =$key= | Session key |
| Parameter: =$value= | Value associated with key |
| Return: =$result= | ="1"= if success; undef if session plugin is not installed |

=cut
# -------------------------
sub setSessionValue
{
#   my( $theKey, $theValue ) = @_;
    &TWiki::setSessionValue( @_ );
}

# =========================
=pod

---++ getSkin( ) ==> $skin

| Description: | Get the name of the skin, set by the =SKIN= preferences variable or the =skin= CGI parameter |
| Return: =$skin= | Name of skin, e.g. ="gnu"=. Empty string if none |

=cut
# -------------------------
sub getSkin
{
    return &TWiki::getSkin();
}

# =========================
=pod

---++ getUrlHost( ) ==> $host

| Description: | Get protocol, domain and optional port of script URL |
| Return: =$host= | URL host, e.g. ="http://example.com:80"= |

=cut
# -------------------------
sub getUrlHost
{
    return $TWiki::urlHost;
}

# =========================
=pod

---++ getScriptUrl( $web, $topic, $script ) ==> $url

| Description: | Compose fully qualified URL |
| Parameter: =$web= | Web name, e.g. ="Main"= |
| Parameter: =$topic= | Topic name, e.g. ="WebNotify"= |
| Parameter: =$script= | Script name, e.g. ="view"= |
| Return: =$url= | URL, e.g. ="http://example.com:80/cgi-bin/view.pl/Main/WebNotify"= |

=cut
# -------------------------
sub getScriptUrl
{
#   my( $web, $topic, $script ) = @_;
    return &TWiki::getScriptUrl( @_ ); 
}

# =========================
=pod

---++ getScriptUrlPath( ) ==> $path

| Description: | Get script URL path |
| Return: =$path= | URL path of TWiki scripts, e.g. ="/cgi-bin"= |

=cut
# -------------------------
sub getScriptUrlPath
{
    return $TWiki::scriptUrlPath;
}

# =========================
=pod

---++ getViewUrl( $web, $topic ) ==> $url

| Description: | Compose fully qualified view URL |
| Parameter: =$web= | Web name, e.g. ="Main"=. The current web is taken if empty |
| Parameter: =$topic= | Topic name, e.g. ="WebNotify"= |
| Return: =$url= | URL, e.g. ="http://example.com:80/cgi-bin/view.pl/Main/WebNotify"= |

=cut
# -------------------------
sub getViewUrl
{
#   my( $web, $topic ) = @_;
    return &TWiki::getViewUrl( @_ );
}

# =========================
=pod

---++ getOopsUrl( $web, $topic, $template, $param1, $param2, $param3, $param4 ) ==> $url

| Description: | Compose fully qualified "oops" dialog URL |
| Parameter: =$web= | Web name, e.g. ="Main"=. The current web is taken if empty |
| Parameter: =$topic= | Topic name, e.g. ="WebNotify"= |
| Parameter: =$template= | Oops template name, e.g. ="oopslocked"= |
| Parameter: =$param1= ... =$param4= | Parameter values for %<nop>PARAM1% ... %<nop>PARAM4% variables in template, optional |
| Return: =$url= | URL, e.g. ="http://example.com:80/cgi-bin/oops.pl/ Main/WebNotify?template=oopslocked&amp;param1=joe"= |

=cut
# -------------------------
sub getOopsUrl
{
#   my( $web, $topic, $template, @params ) = @_;
    # up to 4 parameters in @theParams
    return &TWiki::getOopsUrl( @_ );
}

# =========================
=pod

---++ getPubUrlPath( ) ==> $path

| Description: | Get pub URL path |
| Return: =$path= | URL path of pub directory, e.g. ="/pub"= |

=cut
# -------------------------
sub getPubUrlPath
{
    return &TWiki::getPubUrlPath();
}

# =========================
=pod

---++ getCgiQuery( ) ==> $query

| Description: | Get CGI query object. Important: Plugins cannot assume that scripts run under CGI, Plugins must always test if the CGI query object is set |
| Return: =$query= | CGI query object; or 0 if script is called as a shell script |

=cut
# -------------------------
sub getCgiQuery
{
    return &TWiki::getCgiQuery();
}

# =========================
=pod

---++ writeHeader( $query )

| Description: | Prints a basic content-type HTML header for text/html to standard out |
| Parameter: =$query= | CGI query object |
| Return: | none |

=cut
# -------------------------
sub writeHeader
{
#   my( $theQuery ) = @_;
    return &TWiki::writeHeader( @_ );
}

# =========================
=pod

---++ redirectCgiQuery( $query, $url )

| Description: | Redirect to URL |
| Parameter: =$query= | CGI query object |
| Parameter: =$url= | URL to redirect to |
| Return: | none, never returns |

=cut
# -------------------------
sub redirectCgiQuery
{
#   my( $theQuery, $theUrl ) = @_;
    return &TWiki::redirect( @_ );
}

# =========================
=pod

---+ FUNCTIONS: Preferences

---++ extractNameValuePair( $attr, $name ) ==> $value

| Description: | Extract a named or unnamed value from a variable parameter string |
| Parameter: =$attr= | Attribute string |
| Parameter: =$name= | Name, optional |
| Return: =$value= | Extracted value |

   * Example:
      * Variable: =%<nop>TEST{ "nameless" name1="val1" name2="val2" }%=
      * First extract text between ={...}= to get: ="nameless" name1="val1" name2="val2"=
      * Then call this on the text: <br />
        =my $noname = TWiki::Func::extractNameValuePair( $text );= <br />
        =my $name1  = TWiki::Func::extractNameValuePair( $text, "name1" );= <br />
        =my $name2  = TWiki::Func::extractNameValuePair( $text, "name2" );=

=cut
# -------------------------
sub extractNameValuePair
{
#   my( $theAttr, $theName ) = @_;
    return &TWiki::extractNameValuePair( @_ );
}

# =========================
=pod

---++ getPreferencesValue( $key, $web ) ==> $value

| Description: | Get a preferences value from TWiki or from a Plugin |
| Parameter: =$key= | Preferences key |
| Parameter: =$web= | Name of web, optional. Current web if not specified; does not apply to settings of Plugin topics |
| Return: =$value= | Preferences value; empty string if not set |

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
    return &TWiki::Prefs::getPreferencesValue( @_ );
}

# =========================
=pod

---++ getPreferencesFlag( $key, $web ) ==> $value

| Description: | Get a preferences flag from TWiki or from a Plugin |
| Parameter: =$key= | Preferences key |
| Parameter: =$web= | Name of web, optional. Current web if not specified; does not apply to settings of Plugin topics |
| Return: =$value= | Preferences flag ="1"= (if set), or ="0"= (for preferences values ="off"=, ="no"= and ="0"=) |

   * Example for Plugin setting:
      * MyPlugin topic has: =* Set SHOWHELP = off=
      * Use ="MYPLUGIN_SHOWHELP"= for =$key=
      * =my $showHelp = TWiki::Func::getPreferencesFlag( "MYPLUGIN_SHOWHELP" );=

=cut
# -------------------------
sub getPreferencesFlag
{
#   my( $theKey, $theWeb ) = @_;
    return &TWiki::Prefs::getPreferencesFlag( @_ );
}

# =========================
=pod

---++ getWikiToolName( ) ==> $name

| Description: | Get toolname as defined in TWiki.cfg |
| Return: =$name= | Name of tool, e.g. ="TWiki"= |

=cut
# -------------------------
sub getWikiToolName
{
    return $TWiki::wikiToolName;
}

# =========================
=pod

---++ getMainWebname( ) ==> $name

| Description: | Get name of Main web as defined in TWiki.cfg |
| Return: =$name= | Name, e.g. ="Main"= |

=cut
# -------------------------
sub getMainWebname
{
    return $TWiki::mainWebname;
}

# =========================
=pod

---++ getTwikiWebname( ) ==> $name

| Description: | Get name of TWiki documentation web as defined in TWiki.cfg |
| Return: =$name= | Name, e.g. ="TWiki"= |

=cut
# -------------------------
sub getTwikiWebname
{
    return $TWiki::twikiWebname;
}

# =========================
=pod

---+ FUNCTIONS: User Handling and Access Control

---++ getDefaultUserName( ) ==> $user

| Description: | Get default user name as defined in TWiki.cfg's =$defaultUserName= |
| Return: =$user= | Default user name, e.g. ="guest"= |

=cut
# -------------------------
sub getDefaultUserName
{
    return $TWiki::defaultUserName;
}

# =========================
=pod

---++ getWikiName( ) ==> $wikiName

| Description: | Get Wiki name of logged in user |
| Return: =$wikiName= | Wiki Name, e.g. ="JohnDoe"= |

=cut
# -------------------------
sub getWikiName
{
    return $TWiki::wikiName;
}

# =========================
=pod

---++ getWikiUserName( $text ) ==> $wikiName

| Description: | Get Wiki name of logged in user with web prefix |
| Return: =$wikiName= | Wiki Name, e.g. ="Main.JohnDoe"= |

=cut
# -------------------------
sub getWikiUserName
{
    return $TWiki::wikiUserName;
}

# =========================
=pod

---++ wikiToUserName( $wikiName ) ==> $loginName

| Description: | Translate a Wiki name to a login name based on [[%MAINWEB%.TWikiUsers]] topic |
| Parameter: =$wikiName= | Wiki name, e.g. ="Main.JohnDoe"= or ="JohnDoe"= |
| Return: =$loginName= | Login name of user, e.g. ="jdoe"= |

=cut
# -------------------------
sub wikiToUserName
{
#   my( $wiki ) = @_;
    return &TWiki::wikiToUserName( @_ );
}

# =========================
=pod

---++ userToWikiName( $loginName, $dontAddWeb ) ==> $wikiName

| Description: | Translate a login name to a Wiki name based on [[%MAINWEB%.TWikiUsers]] topic |
| Parameter: =$loginName= | Login name, e.g. ="jdoe"= |
| Parameter: =$dontAddWeb= | Do not add web prefix if ="1"= |
| Return: =$wikiName= | Wiki name of user, e.g. ="Main.JohnDoe"= or ="JohnDoe"= |

=cut
# -------------------------
sub userToWikiName
{
#   my( $loginName, $dontAddWeb ) = @_;
    return &TWiki::userToWikiName( @_ );
}

# =========================
=pod

---++ isGuest( ) ==> $flag

| Description: | Test if logged in user is a guest |
| Return: =$flag= | ="1"= if yes, ="0"= if not |

=cut
# -------------------------
sub isGuest
{
    return &TWiki::isGuest();
}

# =========================
=pod

---++ permissionsSet( $web ) ==> $flag

| Description: | Test if any access restrictions are set for this web, ignoring settings on individual pages |
| Parameter: =$web= | Web name, required, e.g. ="Sandbox"= |
| Return: =$flag= | ="1"= if yes, ="0"= if no |

=cut
# -------------------------
sub permissionsSet
{
#   my( $web ) = @_;
    return &TWiki::Access::permissionsSet( @_ );
}

# =========================
=pod

---++ checkAccessPermission( $type, $user, $text, $topic, $web ) ==> $flag

| Description: | Check access permission for a topic based on the [[TWikiAccessControl]] rules |
| Parameter: =$type= | Access type, e.g. ="VIEW"=, ="CHANGE"=, ="CREATE=" |
| Parameter: =$user= | WikiName of remote user, i.e. ="Main.PeterThoeny"= |
| Parameter: =$text= | Topic text, optional. If empty, topic =$web.$topic= is consulted |
| Parameter: =$topic= | Topic name, required, e.g. ="PrivateStuff"= |
| Parameter: =$web= | Web name, required, e.g. ="Sandbox"= |
| Return: =$flag= | ="1"= if access may be granted, ="0"= if not |

=cut
# -------------------------
sub checkAccessPermission
{
#   my( $type, $user, $text, $topic, $web ) = @_;
    return &TWiki::Access::checkAccessPermission( @_ );
}

# =========================
=pod

---+ FUNCTIONS: Content Handling

---++ webExists( $web ) ==> $flag

| Description: | Test if web exists |
| Parameter: =$web= | Web name, required, e.g. ="Sandbox"= |
| Return: =$flag= | ="1"= if web exists, ="0"= if not |

=cut
# -------------------------
sub webExists
{
#   my( $theWeb ) = @_;
    return &TWiki::Store::webExists( @_ );
}

# =========================
=pod

---++ topicExists( $web, $topic ) ==> $flag

| Description: | Test if topic exists |
| Parameter: =$web= | Web name, optional, e.g. ="Main"= |
| Parameter: =$topic= | Topic name, required, e.g. ="TokyoOffice"=, or ="Main.TokyoOffice"= |
| Return: =$flag= | ="1"= if topic exists, ="0"= if not |

=cut
# -------------------------
sub topicExists
{
#   my( $web, $topic ) = @_;
    return &TWiki::Store::topicExists( @_ );
}

# =========================
=pod

---++ getRevisionInfo( $web, $topic ) ==> ( $date, $user, $rev )

| Description: | Get revision info of a topic |
| Parameter: =$web= | Web name, optional, e.g. ="Main"= |
| Parameter: =$topic= | Topic name, required, e.g. ="TokyoOffice"= |
| Return: =( $date, $user, $rev )= | List with: ( last update date, WikiName of last user, minor part of top revision number ), e.g. =( "01 Jan 2003", "PeterThoeny", "5" )= |

=cut
# -------------------------
sub getRevisionInfo
{
#   my( $web, $topic );
    return &TWiki::Store::getRevisionInfoFromMeta( @_ );
}

# =========================
=pod

---++ getPublicWebList( ) ==> @webs

| Description: | Get list of all public webs, e.g. all webs that do not have the =NOSEARCHALL= flag set in the WebPreferences |
| Return: =@webs= | List of all public webs, e.g. =( "Main",  "Know", "TWiki" )= |

=cut
# -------------------------
sub getPublicWebList
{
    return &TWiki::getPublicWebList();
}

# =========================
=pod

---++ getTopicList( $web ) ==> @topics

| Description: | Get list of all topics in a web |
| Parameter: =$web= | Web name, required, e.g. ="Sandbox"= |
| Return: =@topics= | Topic list, e.g. =( "WebChanges",  "WebHome", "WebIndex", "WebNotify" )= |

=cut
# -------------------------
sub getTopicList
{
#   my( $web ) = @_;
    return &TWiki::Store::getTopicNames ( @_ );
}

# =========================
=pod

---+ FUNCTIONS: Rendering

---++ expandCommonVariables( $text, $topic, $web ) ==> $text

| Description: | Expand all common =%<nop>VARIABLES%= |
| Parameter: =$text= | Text with variables to expand, e.g. ="Current user is %<nop>WIKIUSER%"= |
| Parameter: =$topic= | Current topic name, e.g. ="WebNotify"= |
| Parameter: =$web= | Web name, optional, e.g. ="Main"=. The current web is taken if missing |
| Return: =$text= | Expanded text, e.g. ="Current user is <nop>TWikiGuest"= |

=cut
# -------------------------
sub expandCommonVariables
{
#   my( $text, $topic, $web ) = @_;
    return &TWiki::handleCommonTags( @_ );
}

# =========================
=pod

---++ renderText( $text, $web ) ==> $text

| Description: | Render text from TWiki markup into XHTML as defined in [[TextFormattingRules]] |
| Parameter: =$text= | Text to render, e.g. ="*bold* text and =fixed font="= |
| Parameter: =$web= | Web name, optional, e.g. ="Main"=. The current web is taken if missing |
| Return: =$text= | XHTML text, e.g. ="&lt;b>bold&lt;/b> and &lt;code>fixed font&lt;/code>"= |

=cut
# -------------------------
sub renderText
{
#   my( $text, $web ) = @_;
    return &TWiki::getRenderedVersion( @_ );
}

# =========================
=pod

---++ internalLink( $pre, $web, $topic, $label, $anchor, $createLink ) ==> $text

| Description: | Render topic name and link label into an XHTML link. Normally you do not need to call this funtion, it is called internally by =renderText()= |
| Parameter: =$pre= | Text occuring before the TWiki link syntax, optional |
| Parameter: =$web= | Web name, required, e.g. ="Main"= |
| Parameter: =$topic= | Topic name to link to, required, e.g. ="WebNotify"= |
| Parameter: =$label= | Link label, required. Usually the same as =$topic=, e.g. ="notify"= |
| Parameter: =$anchor= | Anchor, optional, e.g. ="#Jump"= |
| Parameter: =$createLink= | Set to ="1"= to add question linked mark after topic name if topic does not exist;<br /> set to ="0"= to suppress link for non-existing topics |
| Return: =$text= | XHTML anchor, e.g. ="&lt;a href="/cgi-bin/view/Main/WebNotify#Jump">notify&lt;/a>"= |

=cut
# -------------------------
sub internalLink
{
#   my( $pre, $web, $topic, $label, $anchor, $anchor, $createLink ) = @_;
    return &TWiki::internalLink( @_ );
}

# =========================
=pod

---++ search text( $text ) ==> $text

| Description: | This is not a function, just a how-to note. Use: =expandCommonVariables("%<nop>SEARCH{...}%" );= |
| Parameter: =$text= | Search variable |
| Return: ="$text"= | Search result in [[FormattedSearch]] format |

=cut

# =========================
=pod

---++ formatGmTime( $time, $format ) ==> $text

| Description: | Format the time to GM time |
| Parameter: =$time= | Time in epoc seconds |
| Parameter: =$format= | Format type, optional. Default e.g. ="31 Dec 2002 - 19:30"=, can be ="iso"= (e.g. ="2002-12-31T19:30Z"=), ="rcs"= (e.g. ="2001/12/31 23:59:59"=, ="http"= for HTTP header format (e.g. ="Thu, 23 Jul 1998 07:21:56 GMT"=) |
| Return: =$text= | Formatted time string |

=cut
# -------------------------
sub formatGmTime
{
#   my $epSecs = @_;
    return &TWiki::formatGmTime( @_ );
}

# =========================
=pod

---+ FUNCTIONS: File I/O

---++ getDataDir( ) ==> $dir

| Description: | Get data directory (topic file root) |
| Return: =$dir= | Data directory, e.g. ="/twiki/data"= |

=cut
# -------------------------
sub getDataDir
{
    return &TWiki::getDataDir();
}

# =========================
=pod

---++ getPubDir( ) ==> $dir

| Description: | Get pub directory (file attachment root). Attachments are in =$dir/Web/TopicName= |
| Return: =$dir= | Pub directory, e.g. ="/htdocs/twiki/pub"= |

=cut
# -------------------------
sub getPubDir
{
    return &TWiki::getPubDir();
}

# =========================
=pod

---++ readTopic( $web, $opic ) ==> ( $meta, $text )

| Description: | Read topic text and meta data, regardless of access permissions. NOTE: This function will be deprecated in a future release when meta data handling is changed |
| Parameter: =$web= | Web name, required, e.g. ="Main"= |
| Parameter: =$topic= | Topic name, required, e.g. ="TokyoOffice"= |
| Return: =( $meta, $text )= | Meta data object and topic text |

=cut
# -------------------------
sub readTopic
{
#   my( $web, $topic ) = @_;
    return &TWiki::Store::readTopic( @_ );
}

# =========================
=pod

---++ readTemplate( $name, $skin ) ==> $text

| Description: | Read a template or skin file. Embedded [[TWikiTemplates]] directives get expanded |
| Parameter: =$name= | Template name, e.g. ="view"= |
| Parameter: =$skin= | Skin name, optional, e.g. ="print"= |
| Return: =$text= | Template text |

=cut
# -------------------------
sub readTemplate
{
#   my( $name, $skin ) = @_;
    return &TWiki::Store::readTemplate( @_ );
}

# =========================
=pod

---++ readFile( $filename ) ==> $text

| Description: | Read text file, low level |
| Parameter: =$filename= | Full path name of file |
| Return: =$text= | Content of file |

=cut
# -------------------------
sub readFile
{
#   my( $filename ) = @_;
    return &TWiki::Store::readFile( @_ );
}

# =========================
=pod

---++ saveFile( $filename, $text )

| Description: | Save text file, low level |
| Parameter: =$filename= | Full path name of file |
| Parameter: =$text= | Text to save |
| Return: | none |

=cut
# -------------------------
sub saveFile
{
#   my( $filename, $text ) = @_;
    return &TWiki::Store::saveFile( @_ );
}

# =========================
=pod

---++ writeWarning( $text )

| Description: | Log Warning that may require admin intervention to data/warning.txt |
| Parameter: =$text= | Text to write; timestamp gets added |
| Return: | none |

=cut
# -------------------------
sub writeWarning
{
#   my( $theText ) = @_;
    return &TWiki::writeWarning( @_ );
}

# =========================
=pod

---++ writeDebug( $text ) ==> $result

| Description: | Log debug message to data/debug.txt |
| Parameter: =$text= | Text to write; timestamp gets added |
| Return: | none |

=cut
# -------------------------
sub writeDebug
{
#   my( $theText ) = @_;
    return &TWiki::writeDebug( @_ );
}

# =========================
=pod

---+ COPYRIGHT AND LICENSE

Copyright (C) 2000 Peter Thoeny, Peter@Thoeny.com

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
