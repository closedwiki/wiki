# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
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
# As per the GPL, removal of this notice is prohibited.

=pod

---+ TWiki::Func Perl Package Documentation

_Official list of stable TWiki functions for Plugin developers_

---++ Description

This module defines official functions that [[%TWIKIWEB%.TWikiPlugins][Plugins]]
can use to interact with the TWiki engine and content.

Refer to lib/TWiki/Plugins/EmptyPlugin.pm for a template Plugin and
documentation on how to write a Plugin.

Plugins should *only* use functions published in this module. If you use
functions in other TWiki libraries you might create a security hole and
you will likely need to change your Plugin when you upgrade TWiki.

Deprecated functions will still work in older code, though they should
_not_ be called in new Plugins and should be replaced in older Plugins
as soon as possible.

The version of the TWiki::Func module is defined by the VERSION number of the
TWiki::Plugins module, currently %PLUGINVERSION{}%. This can be shown
by the =%<nop>PLUGINVERSION{}%= variable. The 'Since' field in the function
documentation refers to the VERSION number and the date that the function
was addded.

__Note:__ Contrib authors beware! These methods should only ever be called
from the context of a TWiki Plugin. They require a session context to be
established before they are called, and will not work if simply called from
another TWiki module unless the session object is defined first.

=cut

package TWiki::Func;

use strict;
use Error qw( :try );
use Assert;

use TWiki::Time;
use TWiki::Plugins;
use TWiki::Attrs;

=pod

---++ Functions: CGI Environment

---+++ getSessionValue( $key ) -> $value

Get a session value from the client session module
   * =$key= - Session key
Return: =$value=  Value associated with key; empty string if not set

*Since:* TWiki::Plugins::VERSION 1.000 (27 Feb 200)

=cut

sub getSessionValue {
#   my( $theKey ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    return $TWiki::Plugins::SESSION->{client}->getSessionValue( @_ );
}


=pod

---+++ setSessionValue( $key, $value ) -> $result

Set a session value via the client session module
   * =$key=   - Session key
   * =$value= - Value associated with key
Return: =$result=   ="1"= if success; undef if session Plugin is not installed

*Since:* TWiki::Plugins::VERSION 1.000 (17 Aug 2001)

=cut

sub setSessionValue {
#   my( $theKey, $theValue ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    $TWiki::Plugins::SESSION->{client}->setSessionValue( @_ );
}

=pod

---+++ clearSessionValue( $key ) -> $result

Clear a session value via the client session module
   * =$key=   - Session key
Return: =$result=   ="1"= if success; undef if session Plugin is not installed

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub clearSessionValue {
#   my( $theKey, $theValue ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    $TWiki::Plugins::SESSION->{client}->clearSessionValue( @_ );
}

=pod

---+++ getSkin( ) -> $skin

Get the skin path, set by the =SKIN= preferences variable or the =skin= CGI parameter

Return: =$skin= Comma-separated list of skins, e.g. ='gnu,tartan'=. Empty string if none

*Since:* TWiki::Plugins::VERSION 1.000 (29 Jul 2001)

=cut

sub getSkin {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    return $TWiki::Plugins::SESSION->getSkin();
}

=pod

---+++ getUrlHost( ) -> $host

Get protocol, domain and optional port of script URL

Return: =$host= URL host, e.g. ="http://example.com:80"=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub getUrlHost {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    return $TWiki::Plugins::SESSION->{urlHost};
}

=pod

---+++ getScriptUrl( $web, $topic, $script, ... ) -> $url

Compose fully qualified URL
   * =$web=    - Web name, e.g. ='Main'=
   * =$topic=  - Topic name, e.g. ='WebNotify'=
   * =$script= - Script name, e.g. ='view'=
Return: =$url=       URL, e.g. ="http://example.com:80/cgi-bin/view.pl/Main/WebNotify"=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub getScriptUrl {
#   my( $web, $topic, $script ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    return $TWiki::Plugins::SESSION->getScriptUrl( @_ ); 
}

=pod

---+++ getScriptUrlPath( ) -> $path

Get script URL path

Return: =$path= URL path of TWiki scripts, e.g. ="/cgi-bin"=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub getScriptUrlPath {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    return $TWiki::Plugins::SESSION->{scriptUrlPath};
}

=pod

---+++ getViewUrl( $web, $topic ) -> $url

Compose fully qualified view URL
   * =$web=   - Web name, e.g. ='Main'=. The current web is taken if empty
   * =$topic= - Topic name, e.g. ='WebNotify'=
Return: =$url=      URL, e.g. ="http://example.com:80/cgi-bin/view.pl/Main/WebNotify"=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub getViewUrl {
    my( $web, $topic ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    $web ||= $TWiki::Plugins::SESSION->{webName} || $TWiki::cfg{UsersWebName};
    return $TWiki::Plugins::SESSION->getScriptUrl( $web, $topic, 'view' );
}

=pod

---+++ getOopsUrl( $web, $topic, $template, $param1, $param2, $param3, $param4 ) -> $url

Compose fully qualified 'oops' dialog URL
   * =$web=                  - Web name, e.g. ='Main'=. The current web is taken if empty
   * =$topic=                - Topic name, e.g. ='WebNotify'=
   * =$template=             - Oops template name, e.g. ='oopsmistake'=. The 'oops' is optional; 'mistake' will translate to 'oopsmistake'.
   * =$param1= ... =$param4= - Parameter values for %<nop>PARAM1% ... %<nop>PARAMn% variables in template, optional
Return: =$url=                     URL, e.g. ="http://example.com:80/cgi-bin/oops.pl/ Main/WebNotify?template=oopslocked&amp;param1=joe"=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub getOopsUrl {
    my( $web, $topic, $template, @params ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    my $res = $TWiki::Plugins::SESSION->getOopsUrl( 'TeMpLaTe', web => $web,
                                                    topic => $topic,
                                                    params => \@params );
    $res =~ s/oopsTeMpLaTe/$template/g;
    return $res;
}

=pod

---+++ getPubUrlPath( ) -> $path

Get pub URL path

Return: =$path= URL path of pub directory, e.g. ="/pub"=

*Since:* TWiki::Plugins::VERSION 1.000 (14 Jul 2001)

=cut

sub getPubUrlPath {
    return $TWiki::cfg{PubUrlPath};
}

=pod

---+++ getCgiQuery( ) -> $query

Get CGI query object. Important: Plugins cannot assume that scripts run under CGI, Plugins must always test if the CGI query object is set

Return: =$query= CGI query object; or 0 if script is called as a shell script

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub getCgiQuery {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{cgiQuery};
}

=pod

---+++ writeHeader( $query, $contentLength )

Prints a basic content-type HTML header for text/html to standard out
   * =$query= - CGI query object. If not given, the default CGI query will be used. In most cases you should _not_ pass this parameter.
   * =$contentLength= - Length of content
Return:             none

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub writeHeader {
    my( $theQuery ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->writePageHeader( $theQuery );
}

=pod

---+++ redirectCgiQuery( $query, $url )

Redirect to URL
   * =$query= - CGI query object. Ignored, only there for compatibility. The session CGI query object is used instead.
   * =$url=   - URL to redirect to
Return:             none, never returns

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub redirectCgiQuery {
    my( $theQuery, $theUrl ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->redirect( $theUrl );
}

=pod

---+++ getContext() -> \%hash
Get a hash of context identifiers representing the currently active
context. The hash *must not* be changed.

The context is a set of identifiers that are set
during specific phases of TWiki processing. For example, each of
the standard scripts in the 'bin' directory each has a context
identifier - the view script has 'view', the edit script has 'edit'
etc. So you can easily tell what 'type' of script your Plugin is
being called within. The core context identifiers are listed
in the %TWIKIWEB%.TWikiTemplates topic. Please be careful not to
overwrite any of these identifiers!

Context identifiers can be used to communicate between Plugins, and between
Plugins and templates. For example, in FirstPlugin.pm, you might write:
<verbatim>
sub initPlugin {
   TWiki::Func::getContext()->{'FirstPlugin'} = 1;
   ...
</verbatim>
and in SecondPlugin.pm:
<verbatim>
sub initPlugin {
   if( TWiki::Func::getContext()->{'FirstPlugin'}) {
      ...
   }
   ...
</verbatim>
or in a template:
<verbatim>
%TMPL:P{context="FirstPlugin", then="first plugin"}%
</verbatim>

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub getContext {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{context};
}


=pod

---++ Functions: Preferences

---+++ extractParameters($attr ) -> %params

Extract all parameters from a variable string and returns a hash of parameters
   * =$attr= - Attribute string
Return: =%params=  Hash containing all parameters. The nameless parameter is stored in key =_DEFAULT=

*Since:* TWiki::Plugins::VERSION 1.025 (26 Aug 2004)

   * Example:
      * Variable: =%<nop>TEST{ 'nameless' name1="val1" name2="val2" }%=
      * First extract text between ={...}= to get: ='nameless' name1="val1" name2="val2"=
      * Then call this on the text: <br />
   * params = TWiki::Func::extractParameters( $text );=
      * The =%params= hash contains now: <br />
        =_DEFAULT => 'nameless'= <br />
        =name1 => "val1"= <br />
        =name2 => "val2"=

=cut

sub extractParameters {
    my( $theAttr ) = @_;
    my $params = new TWiki::Attrs( $theAttr );
    return %$params;
}

=pod

---+++ extractNameValuePair( $attr, $name ) -> $value

Extract a named or unnamed value from a variable parameter string
- Note:              | Function TWiki::Func::extractParameters is more efficient for extracting several parameters
   * =$attr= - Attribute string
   * =$name= - Name, optional
Return: =$value=   Extracted value

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

   * Example:
      * Variable: =%<nop>TEST{ 'nameless' name1="val1" name2="val2" }%=
      * First extract text between ={...}= to get: ='nameless' name1="val1" name2="val2"=
      * Then call this on the text: <br />
        =my $noname = TWiki::Func::extractNameValuePair( $text );= <br />
        =my $val1  = TWiki::Func::extractNameValuePair( $text, "name1" );= <br />
        =my $val2  = TWiki::Func::extractNameValuePair( $text, "name2" );=

=cut

sub extractNameValuePair {
    return TWiki::Attrs::extractValue( @_ );
}

=pod

---+++ getPreferencesValue( $key, $web ) -> $value

Get a preferences value from TWiki or from a Plugin
   * =$key= - Preferences key
   * =$web= - Name of web, optional. Current web if not specified; does not apply to settings of Plugin topics
Return: =$value=  Preferences value; empty string if not set

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

   * Example for Plugin setting:
      * MyPlugin topic has: =* Set COLOR = red=
      * Use ="MYPLUGIN_COLOR"= for =$key=
      * =my $color = TWiki::Func::getPreferencesValue( "MYPLUGIN_COLOR" );=

   * Example for preferences setting:
      * WebPreferences topic has: =* Set WEBBGCOLOR = #FFFFC0=
      * =my $webColor = TWiki::Func::getPreferencesValue( 'WEBBGCOLOR', 'Sandbox' );=

=cut

sub getPreferencesValue {
    my( $key, $web ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    if( $web ) {
        return $TWiki::Plugins::SESSION->{prefs}->getWebPreferencesValue(
            $key, $web );
    } else {
        return $TWiki::Plugins::SESSION->{prefs}->getPreferencesValue( $key );
    }
}

=pod

---+++ getPluginPreferencesValue( $key ) -> $value

Get a preferences value from your Plugin
   * =$key= - Plugin Preferences key w/o PLUGINNAME_ prefix.
Return: =$value=  Preferences value; empty string if not set

NOTE: This sub will retrieve nothing if called from a module in a subpackage of TWiki::Plugins (ie, TWiki::Plugins::MyPlugin::MyModule)

*Since:* TWiki::Plugins::VERSION 1.021 (27 Mar 2004)

=cut

sub getPluginPreferencesValue {
    my( $theKey ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    my $package = caller;
    $package =~ s/.*:://; # strip off TWiki::Plugins:: prefix
    return $TWiki::Plugins::SESSION->{prefs}->getPreferencesValue( "\U$package\E_$theKey" );
}

=pod

---+++ getPreferencesFlag( $key, $web ) -> $value

Get a preferences flag from TWiki or from a Plugin
   * =$key= - Preferences key
   * =$web= - Name of web, optional. Current web if not specified; does not apply to settings of Plugin topics
Return: =$value=  Preferences flag ='1'= (if set), or ="0"= (for preferences values ="off"=, ="no"= and ="0"=)

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

   * Example for Plugin setting:
      * MyPlugin topic has: =* Set SHOWHELP = off=
      * Use ="MYPLUGIN_SHOWHELP"= for =$key=
      * =my $showHelp = TWiki::Func::getPreferencesFlag( "MYPLUGIN_SHOWHELP" );=

=cut

sub getPreferencesFlag {
#   my( $theKey, $theWeb ) = @_;
    my $t = getPreferencesValue( @_ );
    return TWiki::isTrue( $t );
}

=pod

---+++ getPluginPreferencesFlag( $key ) -> $flag

Get a preferences flag from your Plugin
   * =$key= - Plugin Preferences key w/o PLUGINNAME_ prefix.
Return: =$flag=   Preferences flag ='1'= (if set), or ="0"= (for preferences values ="off"=, ="no"= and ="0"=, or values not set at all)

NOTE: This sub will retrieve nothing if called from a module in a subpackage of TWiki::Plugins (ie, TWiki::Plugins::MyPlugin::MyModule)


*Since:* TWiki::Plugins::VERSION 1.021 (27 Mar 2004)

=cut

sub getPluginPreferencesFlag {
    my( $theKey ) = @_;
    my $package = caller;
    $package =~ s/.*:://; # strip off TWiki::Plugins:: prefix
    return getPreferencesFlag( "\U$package\E_$theKey" );
}

=pod

---+++ getWikiToolName( ) -> $name

Get toolname as defined in TWiki.cfg

Return: =$name= Name of tool, e.g. ='TWiki'=

*Since:* TWiki::Plugins::VERSION 1.000 (27 Feb 2001)

=cut

sub getWikiToolName {
    return $TWiki::cfg{WikiToolName};
}

=pod

---+++ getMainWebname( ) -> $name

Get name of Main web as defined in TWiki.cfg

Return: =$name= Name, e.g. ='Main'=

*Since:* TWiki::Plugins::VERSION 1.000 (27 Feb 2001)

=cut

sub getMainWebname {
    return $TWiki::cfg{UsersWebName};
}

=pod

---+++ getTwikiWebname( ) -> $name

Get name of TWiki documentation web as defined in TWiki.cfg

Return: =$name= Name, e.g. ='TWiki'=

*Since:* TWiki::Plugins::VERSION 1.000 (27 Feb 2001)

=cut

sub getTwikiWebname {
    return $TWiki::cfg{SystemWebName};
}

=pod

---++ Functions: User Handling and Access Control

---+++ getDefaultUserName( ) -> $loginName

Get default user name as defined in the configuration as =DefaultUserLogin=

Return: =$loginName= Default user name, e.g. ='guest'=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub getDefaultUserName {
    return $TWiki::cfg{DefaultUserLogin};
}

=pod

---+++ getWikiName( ) -> $wikiName

Get Wiki name of logged in user

Return: =$wikiName= Wiki Name, e.g. ='JohnDoe'=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub getWikiName {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{user}->wikiName();
}

=pod

---+++ getWikiUserName( ) -> $wikiName

Get Wiki name of logged in user with web prefix

Return: =$wikiName= Wiki Name, e.g. ="Main.JohnDoe"=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub getWikiUserName {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{user}->webDotWikiName();
}

=pod

---+++ wikiToUserName( $wikiName ) -> $loginName

Translate a Wiki name to a login name based on [[%MAINWEB%.TWikiUsers]] topic
   * =$wikiName= - Wiki name, e.g. ='Main.JohnDoe'= or ='JohnDoe'=
Return: =$loginName=   Login name of user, e.g. ='jdoe'=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub wikiToUserName {
    my( $wiki ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return '' unless $wiki;
    my $user = $TWiki::Plugins::SESSION->{users}->findUser( $wiki );
    return $wiki unless $user;
    return $user->login();
}

=pod

---+++ userToWikiName( $loginName, $dontAddWeb ) -> $wikiName

Translate a login name to a Wiki name based on [[%MAINWEB%.TWikiUsers]] topic
   * =$loginName=  - Login name, e.g. ='jdoe'=
   * =$dontAddWeb= - Do not add web prefix if ="1"=
Return: =$wikiName=      Wiki name of user, e.g. ='Main.JohnDoe'= or ='JohnDoe'=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub userToWikiName {
    my( $login, $dontAddWeb ) = @_;
    return '' unless $login;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    my $user = $TWiki::Plugins::SESSION->{users}->findUser( $login );
    return '' unless $user;
    return $user->wikiName() if $dontAddWeb;
    return $user->webDotWikiName();
}

=pod

---+++ isGuest( ) -> $flag

Test if logged in user is a guest

Return: =$flag= ="1"= if yes, ="0"= if not

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub isGuest {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{user}->isDefaultUser();
}

=pod

---+++ isValidWikiWord ( $text ) -> $boolean

Check for a valid WikiWord or WikiName
   * =$text= - Word to test 
Return: =$flag=   ="1"= if yes, ="0"= if no

*Since:* TWiki::Plugins::VERSION 1.100 (Dec 2005)

=cut

sub isValidWikiWord {
   return &TWiki::isValidWikiWord(@_);
}

=pod

---+++ permissionsSet( $web ) -> $flag

Test if any access restrictions are set for this web, ignoring settings on individual pages
   * =$web= - Web name, required, e.g. ='Sandbox'=
Return: =$flag=   ="1"= if yes, ="0"= if no

*Since:* TWiki::Plugins::VERSION 1.000 (27 Feb 2001)

=cut

sub permissionsSet {
#   my( $web ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{security}->permissionsSet( @_ );
}

=pod

---+++ checkAccessPermission( $type, $wikiName, $text, $topic, $web ) -> $flag

Check access permission for a topic based on the [[%TWIKIWEB%.TWikiAccessControl]] rules
   * =$type=     - Access type, e.g. ='VIEW'=, ='CHANGE'=, ='CREATE'=
   * =$wikiName= - WikiName of remote user, i.e. ="Main.PeterThoeny"=
   * =$text=     - Topic text, optional. If empty, topic =$web.$topic= is consulted
   * =$topic=    - Topic name, required, e.g. ='PrivateStuff'=
   * =$web=      - Web name, required, e.g. ='Sandbox'=
Return: =$flag=        ="1"= if access may be granted, ="0"= if not

*Since:* TWiki::Plugins::VERSION 1.000 (27 Feb 2001)

=cut

sub checkAccessPermission {
    my( $type, $user, $text, $topic, $web ) = @_;
    return 1 unless ( $user );
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    $user = $TWiki::Plugins::SESSION->{users}->findUser( $user );
    return $TWiki::Plugins::SESSION->{security}->checkAccessPermission
      ( $type, $user, $text, $topic, $web );
}

=pod

---++ Functions: Content Handling

=pod

---+++ getListOfWebs( $filter ) -> @webs
   * =$filter= - spec of web types to recover
Gets a list of webs, filtered according to the spec in the $filter,
which may include one of:
   1 'user' (for only user webs)
   2 'template' (for only template webs i.e. those starting with "_")
=$filter= may also contain the word 'public' which will further filter
out webs that have NOSEARCHALL set on them.
'allowed' filters out webs the current user can't read.

For example, the deprecated getPublicWebList function can be duplicated
as follows:
<verbatim>
   my @webs = TWiki::Func::getListOfWebs( "user,public" );
</verbatim>

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub getListOfWebs {
    my $filter = shift;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{store}->getListOfWebs($filter);
}

=pod

---+++ webExists( $web ) -> $flag

Test if web exists
   * =$web= - Web name, required, e.g. ='Sandbox'=
Return: =$flag=   ="1"= if web exists, ="0"= if not

*Since:* TWiki::Plugins::VERSION 1.000 (14 Jul 2001)

=cut

sub webExists {
#   my( $theWeb ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{store}->webExists( @_ );
}

=pod

---+++ createWeb( $newWeb, $baseWeb, $opts )

$newWeb is the name of the new web.

$baseWeb is the name of an existing web (a template web). If the
base web is a system web, all topics in it
will be copied into the new web. If it is a normal web, only topics starting
with 'Web' will be copied. If no base web is specified, an empty web
(with no topics) will be created. If it is specified but does not exist,
an error will be thrown.

$opts is a ref to a hash that contains settings to be modified in
the web preferences topic in the new web.

<verbatim>
use Error qw( :try );

try {
    TWiki::Func::createWeb( "Newweb" );
} catch Error::Simple with {
    my $e = shift;
    # see documentation on Error::Simple
} catch TWiki::AccessControlException with {
    my $e = shift;
    # see documentation on TWiki::AccessControlException
} otherwise {
    ...
};
</verbatim>

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub createWeb {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    $TWiki::Plugins::SESSION->{store}->createWeb(
        $TWiki::Plugins::SESSION->{user}, @_ );
}

=pod

---+++ moveWeb( $oldName, $newName )

Move (rename) a web.

<verbatim>
use Error qw( :try );

try {
    TWiki::Func::moveWeb( "Oldweb", "Newweb" );
} catch Error::Simple with {
    my $e = shift;
    # see documentation on Error::Simple
} catch TWiki::AccessControlException with {
    my $e = shift;
    # see documentation on TWiki::AccessControlException
} otherwise {
    ...
};
</verbatim>

To delete a web, move it to a subweb of =Trash=
<verbatim>
TWiki::Func::moveWeb( "Deadweb", "Trash.Deadweb" );
</verbatim>

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub moveWeb {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{store}->moveWeb(
        @_, $TWiki::Plugins::SESSION->{user});

}

=pod

---+++ topicExists( $web, $topic ) -> $boolean

Test if topic exists
   * =$web=   - Web name, optional, e.g. ='Main'=.
   * =$topic= - Topic name, required, e.g. ='TokyoOffice'=, or ="Main.TokyoOffice"=
$web and $topic are parsed as described in the documentation for =normalizeWebTopicName=.

*Since:* TWiki::Plugins::VERSION 1.000 (14 Jul 2001)

=cut

sub topicExists {
    my( $web, $topic ) = $TWiki::Plugins::SESSION->normalizeWebTopicName( @_ );
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{store}->topicExists( $web, $topic );
}

=pod

---+++ getRevisionInfo($theWebName, $theTopic, $theRev, $attachment ) -> ( $date, $user, $rev, $comment ) 
Get revision info of a topic
   * =$theWebName= - Web name, optional, e.g. ='Main'=
   * =$theTopic=   - Topic name, required, e.g. ='TokyoOffice'=
   * =$theRev=     - revsion number, or tag name (can be in the format 1.2, or just the minor number)
   * =$attachment=                 -attachment filename
Return: =( $date, $user, $rev, $comment )= List with: ( last update date, login name of last user, minor part of top revision number ), e.g. =( 1234561, 'phoeny', "5" )=
| $date | in epochSec |
| $user | Wiki name of the author (*not* login name) |
| $rev | actual rev number |
| $comment | WHAT COMMENT? |

NOTE: if you are trying to get revision info for a topic, use
$meta->getRevisionInfo instead if you can - it is significantly
more efficient, and returns a user object that contains other user
information.

NOTE: prior versions of TWiki may under some circumstances have returned
the login name of the user rather than the wiki name; the code documentation
was totally unclear, and we have been unable to establish the intent.
However the wikiname is obviously more useful, so that is what is returned.

*Since:* TWiki::Plugins::VERSION 1.000 (29 Jul 2001)

=cut

sub getRevisionInfo {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    my( $date, $user, $rev, $comment ) =
      $TWiki::Plugins::SESSION->{store}->getRevisionInfo( @_ );
    $user = $user->wikiName();
    return ( $date, $user, $rev, $comment );
}

=pod

---+++ getRevisionAtTime( $web, $topic, $time ) -> $rev

Get the revision number of a topic at a specific time.
   * =$web= - web for topic
   * =$topic= - topic
   * =$time= - time (in epoch secs) for the rev
Return: Single-digit revision number, or undef if it couldn't be determined
(either because the topic isn't that old, or there was a problem)

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub getRevisionAtTime {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{store}->getRevisionAtTime( @_ );
}

=pod

---+++ checkTopicEditLock( $web, $topic ) -> ( $oopsUrl, $loginName, $unlockTime )
Check if a lease has been taken by some other user.
   * =$web= Web name, e.g. ="Main"=, or empty
   * =$topic= Topic name, e.g. ="MyTopic"=, or ="Main.MyTopic"=
Return: =( $oopsUrl, $loginName, $unlockTime )= - The =$oopsUrl= for calling redirectCgiQuery(), user's =$loginName=, and estimated =$unlockTime= in minutes, or ( '', '', 0 ) if no lease exists.

*Since:* TWiki::Plugins::VERSION 1.010 (31 Dec 2002)

=cut

sub checkTopicEditLock {
    my( $web, $topic ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    ( $web, $topic ) = normalizeWebTopicName( $web, $topic );

    my $lease = $TWiki::Plugins::SESSION->{store}->getLease( $web, $topic );
    if( $lease ) {
        my $remain = $lease->{expires} - time();
        my $session = $TWiki::Plugins::SESSION;

        if( $remain > 0 ) {
            my $who = $lease->{user}->login();
            my $wn = $lease->{user}->webDotWikiName();
            my $past = TWiki::Time::formatDelta(time()-$lease->{taken},
                                                $TWiki::Plugins::SESSION->{i18n}
                                               );
            my $future = TWiki::Time::formatDelta($lease->{expires}-time(),
                                                  $TWiki::Plugins::SESSION->{i18n}
                                                 );
            return( $session->getOopsUrl( 'leaseconflict',
                                          def => 'active',
                                          web => $web,
                                          topic => $topic,
                                          params => [ $wn, $past, $future ] ),
                                          $who, $remain / 60 );
        }
    }
    return ('', '', 0);
}

=pod

---+++ setTopicEditLock( $web, $topic, $lock )
   * =$web= Web name, e.g. ="Main"=, or empty
   * =$topic= Topic name, e.g. ="MyTopic"=, or ="Main.MyTopic"=
   * =$lock= 1 to lease the topic, 0 to clear the lease=

Takes out a "lease" on the topic. The lease doesn't prevent
anyone from editing and changing the topic, but it does redirect them
to a warning screen, so this provides some protection. The =edit= script
always takes out a lease.

It is *impossible* to fully lock a topic. Concurrent changes will be
merged.

*Since:* TWiki::Plugins::VERSION 1.010 (31 Dec 2002)

=cut

sub setTopicEditLock {
    my( $web, $topic, $lock ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    my $session = $TWiki::Plugins::SESSION;
    my $store = $session->{store};
    if( $lock ) {
        $store->setLease( $web, $topic, $session->{user},
                          $TWiki::cfg{LeaseLength} );
    } else {
        $store->clearLease( $web, $topic );
    }
    return '';
}

=pod

---+++ readTopic( $web, $topic, $rev ) -> ( $meta, $text )

Read topic text and meta data, regardless of access permissions.
   * =$web= - Web name, required, e.g. ='Main'=
   * =$topic= - Topic name, required, e.g. ='TokyoOffice'=
   * =$rev= - revision to read (default latest)
Return: =( $meta, $text )= Meta data object and topic text

=$meta= is a perl 'object' of class =TWiki::Meta=. This class is
fully documented in the source code documentation shipped with the
release, or can be inspected in the =lib/TWiki/Meta.pm= file.

This method *ignores* topic access permissions. You should be careful to use =checkAccessPermissions= to ensure the current user has read access to the topic.

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub readTopic {
    #my( $web, $topic, $rev ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    return $TWiki::Plugins::SESSION->{store}->readTopic( undef, @_ );
}

=pod

---+++ readTopicText( $web, $topic, $rev, $ignorePermissions ) -> $text

Read topic text, including meta data
   * =$web=                - Web name, e.g. ='Main'=, or empty
   * =$topic=              - Topic name, e.g. ='MyTopic'=, or ="Main.MyTopic"=
   * =$rev=                - Topic revision to read, optional. Specify the minor part of the revision, e.g. ="5"=, not ="1.5"=; the top revision is returned if omitted or empty.
   * =$ignorePermissions=  - Set to ="1"= if checkAccessPermission() is already performed and OK; an oops URL is returned if user has no permission
Return: =$text=                  Topic text with embedded meta data; an oops URL for calling redirectCgiQuery() is returned in case of an error

This method is more efficient than =readTopic=, but returns meta-data embedded in the text. Plugins authors must be very careful to avoid damaging meta-data. You are recommended to use readTopic instead, which is a lot safer..

*Since:* TWiki::Plugins::VERSION 1.010 (31 Dec 2002)

=cut

sub readTopicText {
    my( $web, $topic, $rev, $ignorePermissions ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    my $user;
    $user = $TWiki::Plugins::SESSION->{user}
      unless defined( $ignorePermissions );

    my $text;
    try {
        $text =
          $TWiki::Plugins::SESSION->{store}->readTopicRaw
            ( $user, $web, $topic, $rev );
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $text = $TWiki::Plugins::SESSION->getOopsUrl
          ( 'accessdenied', def=>'topic_access', web => $web, topic => $topic,
            params => [ $e->{mode}, $e->{reason} ] );
    };

    return $text;
}

=pod

---+++ saveTopic( $web, $topic, $meta, $text, $options ) -> $error
   * =$web= - web for the topic
   * =$topic= - topic name
   * =$meta= - reference to TWiki::Meta object
   * =$text= - text of the topic (without embedded meta-data!!!
   * =\%options= - ref to hash of save options
     =\%options= may include:
     | =dontlog= | don't log this change in twiki log |
     | =comment= | comment for save |
     | =minor= | True if this is a minor change, and is not to be notified |
Return: error message or undef.

*Since:* TWiki::Plugins::VERSION 1.000 (29 Jul 2001)

For example,
<verbatim>
my( $meta, $text ) = TWiki::Func::readTopic( $web, $topic )
$text =~ s/APPLE/ORANGE/g;
TWiki::Func::saveTopic( $web, $topic, $meta, $text, { comment => 'refruited' } );
</verbatim>

__Note:__ Plugins handlers ( e.g. =beforeSaveHandler= ) will be called as
appropriate.

=cut

sub saveTopic {
    my( $web, $topic, $meta, $text, $options ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    ASSERT($meta) if DEBUG;

    return $TWiki::Plugins::SESSION->{store}->saveTopic
      ( $TWiki::Plugins::SESSION->{user}, $web, $topic, $text, $meta,
        $options );

}

=pod

---+++ saveTopicText( $web, $topic, $text, $ignorePermissions, $dontNotify ) -> $oopsUrl

Save topic text, typically obtained by readTopicText(). Topic data usually includes meta data; the file attachment meta data is replaced by the meta data from the topic file if it exists.
   * =$web=                - Web name, e.g. ='Main'=, or empty
   * =$topic=              - Topic name, e.g. ='MyTopic'=, or ="Main.MyTopic"=
   * =$text=               - Topic text to save, assumed to include meta data
   * =$ignorePermissions=  - Set to ="1"= if checkAccessPermission() is already performed and OK
   * =$dontNotify=         - Set to ="1"= if not to notify users of the change
Return: =$oopsUrl=               Empty string if OK; the =$oopsUrl= for calling redirectCgiQuery() in case of error

This method is a lot less efficient and much more dangerous than =saveTopic=.

*Since:* TWiki::Plugins::VERSION 1.010 (31 Dec 2002)

<verbatim>
my $text = TWiki::Func::readTopicText( $web, $topic );

# check for oops URL in case of error:
if( $text =~ /^http.*?\/oops/ ) {
    TWiki::Func::redirectCgiQuery( $query, $text );
    return;
}
# do topic text manipulation like:
$text =~ s/old/new/g;
# do meta data manipulation like:
$text =~ s/(META\:FIELD.*?name\=\"TopicClassification\".*?value\=\")[^\"]*/$1BugResolved/;
$oopsUrl = TWiki::Func::saveTopicText( $web, $topic, $text ); # save topic text
</verbatim>

=cut

sub saveTopicText {
    my( $web, $topic, $text, $ignorePermissions, $dontNotify ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    my $session = $TWiki::Plugins::SESSION;
    my( $mirrorSite, $mirrorViewURL ) = $session->readOnlyMirrorWeb( $web );
    return $session->getOopsUrl
      ( 'mirror', web => $web, topic => $topic,
        params => [ $mirrorSite, $mirrorViewURL ] ) if( $mirrorSite );

    # check access permission
    unless( $ignorePermissions ||
            $session->{security}->checkAccessPermission( 'change',
                                                     $session->{user}, '',
                                                     $topic, $web )
          ) {
        my @plugin = caller();
        return $session->getOopsUrl( 'accessdenied',
                                     def => 'topic_access',
                                     web => $web,
                                     topic => $topic,
                                     params => [ 'in', $plugin[0] ] );
    }

    return $session->getOopsUrl( 'attention',
                                 def => 'save_error',
                                 web => $web,
                                 topic => $topic )
      unless( defined $text );

    # extract meta data and merge old attachment meta data
    my $meta = new TWiki::Meta( $session, $web, $topic );
    $session->{store}->extractMetaData( $meta, \$text );
    $meta->remove( 'FILEATTACHMENT' );

    my( $oldMeta, $oldText ) =
      $session->{store}->readTopic( undef, $web, $topic, undef );
    $meta->copyFrom( $oldMeta, 'FILEATTACHMENT' );
    # save topic
    my $error =
      $session->{store}->saveTopic
        ( $session->{user}, $web, $topic, $text, $meta,
          { notify => $dontNotify } );
    return $session->getOopsUrl
      ( 'attention', def => 'save_error',
        web => $web, topic => $topic, params => $error ) if( $error );
    return '';
}

=pod

---+++ moveTopic( $web, $topic, $newWeb, $newTopic )
   * =$web= source web - required
   * =$topic= source topic - required
   * =$newWeb= dest web
   * =$newTopic= dest topic
Renames the topic. Throws an exception if something went wrong.
If $newWeb is undef, it defaults to $web. If $newTopic is undef, it defaults
to $topic.

The destination topic must not already exist.

Rename a topic to the $TWiki::cfg{TrashWebName} to delete it.

*Since:* TWiki::Plugins::VERSION 1.1

<verbatim>
use Error qw( :try );

try {
    moveTopic( "Work", "TokyoOffice", "Trash", "ClosedOffice" );
} catch Error::Simple with {
    my $e = shift;
    # see documentation on Error::Simple
} catch TWiki::AccessControlException with {
    my $e = shift;
    # see documentation on TWiki::AccessControlException
} otherwise {
    ...
};
</verbatim>

=cut

sub moveTopic {
    my( $web, $topic, $newWeb, $newTopic ) = @_;
    $newWeb ||= $web;
    $newTopic ||= $topic;

    return if( $newWeb eq $web && $newTopic eq $topic );

    $TWiki::Plugins::SESSION->{store}->moveTopic(
        $web, $topic,
        $newWeb, $newTopic,
        $TWiki::Plugins::SESSION->{user} );
}

=pod

---+++ attachmentExists( $web, $topic, $attachment ) -> $boolean

Test if attachment exists
   * =$web=   - Web name, optional, e.g. =Main=.
   * =$topic= - Topic name, required, e.g. =TokyoOffice=, or =Main.TokyoOffice=
   * =$attachment= - attachment name, e.g.=logo.gif=
$web and $topic are parsed as described in the documentation for =normalizeWebTopicName=.

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub attachmentExists {
    my( $web, $topic, $attachment ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    ( $web, $topic ) =
      $TWiki::Plugins::SESSION->normalizeWebTopicName( $web, $topic );
    return $TWiki::Plugins::SESSION->{store}->attachmentExists(
        $web, $topic, $attachment );
}

=pod

---+++ readAttachment( $web, $topic, $name, $rev ) -> $data
   * =$web= - web for topic
   * =$topic= - topic
   * =$name= - attachment name
   * =$rev= - revision to read (default latest)
Read an attachment from the store for a topic, and return it as a string. The names of attachments on a topic can be recovered from the meta-data returned by =readTopic=. If the attachment does not exist, or cannot be read, undef will be returned.

View permission on the topic is required for the
read to be successful.  Access control violations are flagged by a
TWiki::AccessControlException. Permissions are checked for the user
passed in.

<verbatim>
my( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );
my @attachments = $meta->find( 'FILEATTACHMENT' );
foreach my $a ( @attachments ) {
   try {
       my $data = TWiki::Func::readAttachment( $meta, $a->{name} );
       ...
   } catch TWiki::AccessControlException with {
   };
}
</verbatim>

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub readAttachment {
    my( $meta, $name ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    my $result;

#    try {
        $result = $TWiki::Plugins::SESSION->{store}->readAttachment(
            $TWiki::Plugins::SESSION->{user}, @_ );
#    } catch Error::Simple with {
#    };
    return $result;
}

=pod

---+++ saveAttachment( $web, $topic, $attachment, $opts )
   * =$web= - web for topic
   * =$topic= - topic to atach to
   * =$attachment= - name of the attachment
   * =$opts= - Ref to hash of options
=$opts= may include:
| =dontlog= | don't log this change in twiki log |
| =comment= | comment for save |
| =hide= | if the attachment is to be hidden in normal topic view |
| =stream= | Stream of file to upload |
| =file= | Name of a file to use for the attachment data. ignored if stream is set. Local file on the server. |
| =filepath= | Client path to file |
| =filesize= | Size of uploaded data |
| =filedate= | Date |

Save an attachment to the store for a topic. On success, returns undef. If there is an error, an exception will be thrown.

<verbatim>
    try {
        TWiki::Func::saveAttachment( $web, $topic, 'image.gif',
                                     { file => 'image.gif',
                                       comment => 'Picture of Health',
                                       hide => 1 } );
   } catch Error::Simple with {
      # see documentation on Error
   } otherwise {
      ...
   };
</verbatim>

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub saveAttachment {
    my( $web, $topic, $name, $data ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    my $result = undef;

    try {
        $TWiki::Plugins::SESSION->{store}->saveAttachment(
            $web, $topic, $name,
            $TWiki::Plugins::SESSION->{user},
            $data );
    } catch Error::Simple with {
        $result = shift->{-text};
    };

    return $result;
}

=pod

---+++ moveAttachment( $web, $topic, $attachment, $newWeb, $newTopic, $newAttachment )
   * =$web= source web - required
   * =$topic= source topic - required
   * =$attachment= source attachment - required
   * =$newWeb= dest web
   * =$newTopic= dest topic
   * =$newAttachment= dest attachment
Renames the topic. Throws an exception on error or access violation.
If $newWeb is undef, it defaults to $web. If $newTopic is undef, it defaults
to $topic. If $newAttachment is undef, it defaults to $attachment. If all of $newWeb, $newTopic and $newAttachment are undef, it is an error.

The destination topic must already exist, but the destination attachment must
*not* exist.

Rename an attachment to $TWiki::cfg{TrashWebName}.TrashAttament to delete it.

<verbatim>
use Error qw( :try );

try {
   # move attachment between topics
   moveAttachment( "Countries", "Germany", "AlsaceLorraine.dat",
                     "Countries", "France" );
   # Note destination attachment name is defaulted to the same as source
} catch TWiki::AccessControlException with {
   my $e = shift;
   # see documentation on TWiki::AccessControlException
} catch Error::Simple with {
   my $e = shift;
   # see documentation on Error::Simple
};
</verbatim>

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub moveAttachment {
    my( $web, $topic, $attachment, $newWeb, $newTopic, $newAttachment ) = @_;

    $newWeb ||= $web;
    $newTopic ||= $topic;
    $newAttachment ||= $attachment;

    return if( $newWeb eq $web &&
                 $newTopic eq $topic &&
                   $newAttachment eq $attachment );

    $TWiki::Plugins::SESSION->{store}->moveAttachment(
        $web, $topic, $attachment,
        $newWeb, $newTopic, $newAttachment,
        $TWiki::Plugins::SESSION->{user} );
}

=pod

---+++ getTopicList( $web ) -> @topics

Get list of all topics in a web
   * =$web= - Web name, required, e.g. ='Sandbox'=
Return: =@topics= Topic list, e.g. =( 'WebChanges',  'WebHome', 'WebIndex', 'WebNotify' )=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub getTopicList {
#   my( $web ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{store}->getTopicNames ( @_ );
}

=pod

---++ Functions: Rendering

=cut

=pod=

---+++ registerTagHandler( $var, \&fn, $syntax )
Should only be called from initPlugin.

Register a function to handle a simple variable. Handles both %<nop>VAR% and %<nop>VAR{...}%. Registered variables are treated the same as TWiki internal variables, and are expanded at the same time. This is a _lot_ more efficient than using the =commonTagsHandler=.
   * =$var= - The name of the variable, i.e. the 'MYVAR' part of %<nop>MYVAR%. The variable name *must* match /^[A-Z][A-Z0-9_]*$/ or it won't work.
   * =\&fn= - Reference to the handler function.
   * =$syntax= can be 'classic' (the default) or 'context-free'. 'classic' syntax is appropriate where you want the variable to support classic TWiki syntax i.e. to accept the standard =%<nop>MYVAR{ "unnamed" param1="value1" param2="value2" }%= syntax, as well as an unquoted default parameter, such as =%<nop>MYVAR{unquoted parameter}%=. If your variable will only use named parameters, you can use 'context-free' syntax, which supports a more relaxed syntax. For example, %MYVAR{param1=value1, value 2, param3="value 3", param4='value 5"}%

*Since:* TWiki::Plugins::VERSION 1.1

The variable handler function must be of the form:
<verbatim>
sub handler(\%session, \%params, $theTopic, $theWeb)
</verbatim>
where:
   * =\%session= - a reference to the TWiki session object (may be ignored)
   * =\%params= - a reference to a TWiki::Attrs object containing parameters. This can be used as a simple hash that maps parameter names to values, with _DEFAULT being the name for the default parameter.
   * =$theTopic= - name of the topic in the query
   * =$theWeb= - name of the web in the query
for example, to execute an arbitrary command on the server, you might do this:
<verbatim>
sub initPlugin{
   TWiki::Func::registerTagHandler('EXEC', \&boo);
}

sub boo {
    my( $session, $params, $topic, $web ) = @_;
    my $cmd = $params->{_DEFAULT};

    return "NO COMMAND SPECIFIED" unless $cmd;

    my $result = `$cmd 2>&1`;
    return $params->{silent} ? '' : $result;
}
}
</verbatim>
would let you do this:
=%<nop>EXEC{"ps -Af" silent="on"}%=

=cut

sub registerTagHandler {
    my( $tag, $function, $syntax ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    # Use an anonymous function so it gets inlined at compile time.
    # Make sure we don't mangle the session reference.
    TWiki::registerTagHandler( $tag,
                               sub {
                                   my $record = $TWiki::Plugins::SESSION;
                                   $TWiki::Plugins::SESSION = $_[0];
                                   my $result = &$function( @_ );
                                   $TWiki::Plugins::SESSION = $record;
                                   return $result;
                               },
                               $syntax
                             );
}

=pod

---+++ addToHEAD( $id, $header )
Adds =$header= to the HTML header (the <head> tag).
This is useful for Plugins that want to include some javascript custom css.
   * =$id= - Unique ID to prevent the same HTML from being duplicated. Plugins should use a prefix to prevent name clashes (e.g EDITTABLEPLUGIN_JSCALENDAR)
   * =$header= - the HTML to be added to the <head> section. The HTML must be valid in a HEAD tag - no checks are performed.

All TWiki variables present in =$header= will be expanded before being inserted into the =<head>= section.

Note that this is _not_ the same as the HTTP header, which is modified through the Plugins =modifyHeaderHandler=.

*Since:* TWiki::Plugins::VERSION 1.1

example:
<verbatim>
TWiki::Func::addToHEAD('PATTERN_STYLE','<link id="twikiLayoutCss" rel="stylesheet" type="text/css" href="%PUBURL%/TWiki/PatternSkin/layout.css" media="all" />')
</verbatim>

=cut=	

sub addToHEAD {
	my( $tag, $header ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
	$TWiki::Plugins::SESSION->addToHEAD( $tag, $header );
}

=pod

---+++ expandCommonVariables( $text, $topic, $web ) -> $text

Expand all common =%<nop>VARIABLES%=
   * =$text=  - Text with variables to expand, e.g. ='Current user is %<nop>WIKIUSER%'=
   * =$topic= - Current topic name, e.g. ='WebNotify'=
   * =$web=   - Web name, optional, e.g. ='Main'=. The current web is taken if missing
Return: =$text=     Expanded text, e.g. ='Current user is <nop>TWikiGuest'=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

See also: expandVariablesOnTopicCreation

=cut

sub expandCommonVariables {
    my( $text, $topic, $web ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    $topic ||= $TWiki::Plugins::SESSION->{topicName};
    $web ||= $TWiki::Plugins::SESSION->{webName};
    return $TWiki::Plugins::SESSION->handleCommonTags( $text, $web, $topic );
}

=pod

---+++ renderText( $text, $web ) -> $text

Render text from TWiki markup into XHTML as defined in [[%TWIKIWEB%.TextFormattingRules]]
   * =$text= - Text to render, e.g. ='*bold* text and =fixed font='=
   * =$web=  - Web name, optional, e.g. ='Main'=. The current web is taken if missing
Return: =$text=    XHTML text, e.g. ='&lt;b>bold&lt;/b> and &lt;code>fixed font&lt;/code>'=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub renderText {
#   my( $text, $web ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{renderer}->getRenderedVersion( @_ );
}

=pod

---+++ internalLink( $pre, $web, $topic, $label, $anchor, $createLink ) -> $text

Render topic name and link label into an XHTML link. Normally you do not need to call this funtion, it is called internally by =renderText()=
   * =$pre=        - Text occuring before the TWiki link syntax, optional
   * =$web=        - Web name, required, e.g. ='Main'=
   * =$topic=      - Topic name to link to, required, e.g. ='WebNotify'=
   * =$label=      - Link label, required. Usually the same as =$topic=, e.g. ='notify'=
   * =$anchor=     - Anchor, optional, e.g. ='#Jump'=
   * =$createLink= - Set to ='1'= to add question linked mark after topic name if topic does not exist;<br /> set to ='0'= to suppress link for non-existing topics
Return: =$text=          XHTML anchor, e.g. ='&lt;a href='/cgi-bin/view/Main/WebNotify#Jump'>notify&lt;/a>'=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub internalLink {
    my $pre = shift;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
#   my( $web, $topic, $label, $anchor, $anchor, $createLink ) = @_;
    return $pre . $TWiki::Plugins::SESSION->{renderer}->internalLink( @_ );
}

=pod

---+++ formatTime( $time, $format, $timezone ) -> $text

Format the time in seconds into the desired time string
   * =$time=     - Time in epoc seconds
   * =$format=   - Format type, optional. Default e.g. ='31 Dec 2002 - 19:30'=. Can be ='$iso'= (e.g. ='2002-12-31T19:30Z'=), ='$rcs'= (e.g. ='2001/12/31 23:59:59'=, ='$http'= for HTTP header format (e.g. ='Thu, 23 Jul 1998 07:21:56 GMT'=), or any string with tokens ='$seconds, $minutes, $hours, $day, $wday, $month, $mo, $year, $ye, $tz'= for seconds, minutes, hours, day of month, day of week, 3 letter month, 2 digit month, 4 digit year, 2 digit year, timezone string, respectively
   * =$timezone= - either not defined (uses the displaytime setting), 'gmtime', or 'servertime'
Return: =$text=        Formatted time string
| Note:                  | if you used the removed formatGmTime, add a third parameter 'gmtime' |

*Since:* TWiki::Plugins::VERSION 1.020 (26 Feb 2004)

=cut

sub formatTime {
#   my ( $epSecs, $format, $timezone ) = @_;
    return TWiki::Time::formatTime( @_ );
}

=pod


=pod

---++ Functions: File I/O

=cut

=pod

---+++ getWorkArea( $pluginName ) -> $directorypath

Gets a private directory for Plugin use. The Plugin is entirely responsible
for managing this directory; TWiki will not read from it, or write to it.

The directory is guaranteed to exist, and to be writable by the webserver
user. By default it will *not* be web accessible.

The directory and it's contents are permanent, so Plugins must be careful
to keep their areas tidy.

*Since:* TWiki::Plugins::VERSION 1.1 (Dec 2005)

=cut

sub getWorkArea {
    my( $plugin ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{store}->getWorkArea( $plugin );
}

=pod

---+++ readFile( $filename ) -> $text

Read file, low level. Used for Plugin workarea.
   * =$filename= - Full path name of file
Return: =$text= Content of file, empty if not found

__NOTE:__ Use this function only for the Plugin workarea, *not* for topics and attachments. Use the [[#Functions_Content_Handling][content handling functions]] to manipulate topics and attachments.

*Since:* TWiki::Plugins::VERSION 1.000 (07 Dec 2002)

=cut

sub readFile {
    my $name = shift;
    my $data = '';
    open( IN_FILE, "<$name" ) || return '';
    local $/ = undef; # set to read to EOF
    $data = <IN_FILE>;
    close( IN_FILE );
    $data = '' unless $data; # no undefined
    return $data;
}

=pod

---+++ saveFile( $filename, $text )

Save file, low level. Used for Plugin workarea.
   * =$filename= - Full path name of file
   * =$text=     - Text to save
Return:                none

__NOTE:__ Use this function only for the Plugin workarea, *not* for topics and attachments. Use the [[#Functions_Content_Handling][content handling functions]] to manipulate topics and attachments.

*Since:* TWiki::Plugins::VERSION 1.000 (07 Dec 2002)

=cut

sub saveFile {
    my( $name, $text ) = @_;

    unless ( open( FILE, ">$name" ) )  {
        die "Can't create file $name - $!\n";
    }
    print FILE $text;
    close( FILE);
}

=pod

---+++ readTemplate( $name, $skin ) -> $text

Read a template or skin. Embedded [[%TWIKIWEB%.TWikiTemplates][template directives]] get expanded
   * =$name= - Template name, e.g. ='view'=
   * =$skin= - Comma-separated list of skin names, optional, e.g. ='print'=
Return: =$text=    Template text

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub readTemplate {
#   my( $name, $skin ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{templates}->readTemplate( @_ );
}

=pod

---+++ writeWarning( $text )

Log Warning that may require admin intervention to data/warning.txt
   * =$text= - Text to write; timestamp gets added
Return:            none

*Since:* TWiki::Plugins::VERSION 1.020 (16 Feb 2004)

=cut

sub writeWarning {
#   my( $theText ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    my ($message)=@_;
    return $TWiki::Plugins::SESSION->writeWarning( "(".caller().") ".$message );
}

=pod

---+++ writeDebug( $text )

Log debug message to data/debug.txt
   * =$text= - Text to write; timestamp gets added
Return:            none

*Since:* TWiki::Plugins::VERSION 1.020 (16 Feb 2004)

=cut

sub writeDebug {
#   my( $theText ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->writeDebug( @_ );
}

=pod

---++ Functions: System and I18N related

---+++ getRegularExpression( $name ) -> $expr

Retrieves a TWiki predefined regular expression or character class.
   * =$name= - Name of the expression to retrieve.  See notes below
Return: String or precompiled regular expression matching as described below.

*Since:* TWiki::Plugins::VERSION 1.020 (9 Feb 2004)

__Note:__ TWiki internally precompiles several regular expressions to
represent various string entities in an I18N-compatible manner. Plugins
authors are encouraged to use these in matching where appropriate. The
following are guaranteed to be present. Others may exist, but their use
is unsupported and they may be removed in future TWiki versions.

In the table below, the expression marked type 'String' are intended for
use within character classes (i.e. for use within square brackets inside
a regular expression), for example:
<verbatim>
   my $upper = TWiki::Func::getRegularExpression('upperAlpha');
   my $alpha = TWiki::Func::getRegularExpression('mixedAlpha');
   my $capitalized = qr/[$upper][$alpha]+/;
</verbatim>
Those expressions marked type 'RE' are precompiled regular expressions that can be used outside square brackets. For example:
<verbatim>
   my $webRE = TWiki::Func::getRegularExpression('webNameRegex');
   my $isWebName = ( $s =~ m/$webRE/ );
</verbatim>

| *Name*         | *Matches*                        | *Type* |
| upperAlpha     | Upper case characters            | String |
| upperAlphaNum  | Upper case characters and digits | String |
| lowerAlpha     | Lower case characters            | String |
| lowerAlphaNum  | Lower case characters and digits | String |
| numeric        | Digits                           | String |
| mixedAlpha     | Alphabetic characters            | String |
| mixedAlphaNum  | Alphanumeric characters          | String |
| wikiWordRegex  | WikiWords                        | RE |
| webNameRegex   | User web names                   | RE |
| anchorRegex    | #AnchorNames                     | RE |
| abbrevRegex    | Abbreviations e.g. GOV, IRS      | RE |
| emailAddrRegex | email@address.com                | RE |
| tagNameRegex   | Standard variable names e.g. %<nop>THIS_BIT% (THIS_BIT only) | RE |

=cut

sub getRegularExpression {
    my ( $regexName ) = @_;
    return $TWiki::regex{$regexName};
}

=pod

---++ Functions: Template handling and topic creation

---+++ loadTemplate ( $theName, $theSkin, $theWeb ) -> $text

   * =$theName= - template file name
   * =$theSkin= - comma-separated list of skins to use (default: current skin)
   * =$theWeb= - the web to look in for topics that contain templates (default: current web)
Return: expanded template text (what's left after removal of all %TMPL:DEF% statements)

*Since:* TWiki::Plugins::VERSION 1.1

Reads a template and extracts template definitions, adding them to the
list of loaded templates, overwriting any previous definition.

How TWiki searches for templates is described in TWikiTemplates.

If template text is found, extracts include statements and fully expands them.

=cut

sub loadTemplate {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{templates}->readTemplate( @_ );
}

=pod

---+++ sub expandTemplate( $theDef  ) -> $string
Do a %TMPL:P{$theDef}%, only expanding the template (not expanding any variables other than %TMPL)
   * =$theDef= - template name
Return: the text of the expanded template

*Since:* TWiki::Plugins::VERSION 1.1

A template is defined using a %TMPL:DEF% statement in a template
file. See the documentation on TWiki templates for more information.

=cut

sub expandTemplate {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{templates}->expandTemplate( @_ );
}

=pod

---+++ expandVariablesOnTopicCreation ( $text ) -> $text
Expand the limited set of variables that are always expanded during topic creation
   * =$text= - the text to process
Return: text with variables expanded

*Since:* TWiki::Plugins::VERSION 1.1

Expands only the variables expected in templates that must be statically
expanded in new content.

The expanded variables are:
   * =%<nop>DATE%= Signature-format date
   * =%<nop>SERVERTIME%= See TWikiVariables
   * =%<nop>GMTIME%= See TWikiVariables
   * =%<nop>USERNAME%= Base login name
   * =%<nop>WIKINAME%= Wiki name
   * =%<nop>WIKIUSERNAME%= Wiki name with prepended web
   * =%<nop>URLPARAM{...}%= - Parameters to the current CGI query
   * =%<nop>NOP%= No-op

See also: expandVariables

=cut

sub expandVariablesOnTopicCreation {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->expandVariablesOnTopicCreation( shift, $TWiki::Plugins::SESSION->{user} );
}

=pod

---+++ normalizeWebTopicName($web, $topic) -> ($web, $topic)

Parse a web and topic name, supplying defaults as appropriate.
   * =$web= - Web name, identifying variable, or empty string
   * =$topic= - Topic name, may be a web.topic string, required.
Return: the parsed Web/Topic pai

*Since:* TWiki::Plugins::VERSION 1.1

| *Input* | *Return* |
| <tt>( 'Web',  'Topic' )     </tt> | <tt>( 'Web',  'Topic' ) </tt> |
| <tt>( '',     'Topic' )     </tt> | <tt>( 'Main', 'Topic' ) </tt> |
| <tt>( '',     '' )          </tt> | <tt>( 'Main', 'WebHome' ) </tt> |
| <tt>( '',     'Web/Topic' ) </tt> | <tt>( 'Web',  'Topic' ) </tt> |
| <tt>( '',     'Web.Topic' ) </tt> | <tt>( 'Web',  'Topic' ) </tt> |
| <tt>( 'Web1', 'Web2.Topic' )</tt> | <tt>( 'Web2', 'Topic' ) </tt> |
| <tt>( '%MAINWEB%', 'Topic' )</tt> | <tt>( 'Main', 'Topic' ) </tt> |
| <tt>( '%TWIKIWEB%', 'Topic' )</tt> | <tt>( 'TWiki', 'Topic' ) </tt> |
where =Main= and =TWiki= are the web names set in $cfg{UsersWebName} and $cfg{SystemWebName} respectively.

=cut

sub normalizeWebTopicName {
    #my( $theWeb, $theTopic ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->normalizeWebTopicName( @_ );
}

=pod

---+++ searchInWebContent($searchString, $web, \@topics, \%options ) -> \%map
Search for a string in the content of a web. The search is over all content, including meta-data. Meta-data matches will be returned as formatted lines within the topic content (meta-data matches are returned as lines of the format %META:\w+{.*}%)
   * =$searchString= - the search string, in egrep format
   * =$web= - The web to search in
   * =\@topics= - reference to a list of topics to search
   * =\%option= - reference to an options hash
The =\%options= hash may contain the following options:
   * =type= - if =regex= will perform a egrep-syntax RE search (default '')
   * =casesensitive= - false to ignore case (defaulkt true)
   * =files_without_match= - true to return files only (default false). If =files_without_match= is specified, it will return on the first match in each topic (i.e. it will return only one match per topic, and will not return matching lines).

The return value is a reference to a hash which maps each matching topic
name to a list of the lines in that topic that matched the search,
as would be returned by 'grep'.

To iterate over the returned topics use:
<verbatim>
my $result = TWiki::Func::searchInWebContent( "Slimy Toad", $web, \@topics,
   { casesensitive => 0, files_without_match => 0 } );
foreach my $topic (keys %$result ) {
   foreach my $matching_line ( @{$result->{$topic}} ) {
      ...etc
</verbatim>

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub searchInWebContent {
    #my( $searchString, $web, $topics, $options ) = @_;

    return $TWiki::Plugins::SESSION->{store}->searchInWebContent( @_ );
}

=pod

---++ Functions: Email

---++ sendEmail ( $text, $retries ) -> $error
   * =$text= - text of the mail, including MIME headers
   * =$retries= - number of times to retry the send (default 1)
Send an email specified as MIME format content. To specify MIME
format mails, you create a string that contains a set of header
lines that contain field definitions and a message body such as:
<verbatim>
To: liz@windsor.gov.uk
From: serf@hovel.net
CC: george@whitehouse.gov
Subject: Revolution

Dear Liz,

Please abolish the monarchy (with King George's permission, of course)

Thanks,

A. Peasant
</verbatim>
Leave a blank line between the last header field and the message body.

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub sendEmail {
    #my( $text, $retries ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{net}->sendEmail( @_ );
}

=pod

---+++ wikiToEmail( $wikiName ) -> $email
   * =$wikiName= - wiki name of the user
Get the email address(es) of the named user. If the user has multiple
email addresses (for example, the user is a group), then the list will
be comma-separated.

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub wikiToEmail {
    my( $wiki ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return '' unless $wiki;
    my $user = $TWiki::Plugins::SESSION->{users}->findUser( $wiki );
    return '' unless $user;
    return join( ',', @{$user->emails()} );
}

=pod

---++ Deprecated functions

The following functions are retained for compatibility only. You should
stop using them as soon as possible.

---+++ getPublicWebList( ) -> @webs

*DEPRECATED* since 1.1 - use =getListOfWebs= instead.

Get list of all public webs, e.g. all webs that do not have the =NOSEARCHALL= flag set in the WebPreferences

Return: =@webs= List of all public webs, e.g. =( 'Main',  'Know', 'TWiki' )=

*Since:* TWiki::Plugins::VERSION 1.000 (07 Dec 2002)

=cut

sub getPublicWebList {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{store}->getListOfWebs("user,public");
}

=pod

---+++ formatGmTime( $time, $format ) -> $text

*DEPRECATED* since 1.1 - use =formatTime= instead.

Format the time to GM time
   * =$time=   - Time in epoc seconds
   * =$format= - Format type, optional. Default e.g. ='31 Dec 2002 - 19:30'=, can be ='iso'= (e.g. ='2002-12-31T19:30Z'=), ='rcs'= (e.g. ='2001/12/31 23:59:59'=, ='http'= for HTTP header format (e.g. ='Thu, 23 Jul 1998 07:21:56 GMT'=)
Return: =$text=      Formatted time string

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub formatGmTime {
#   my ( $epSecs, $format ) = @_;

    # FIXME: Write warning based on flag (disabled for now); indicate who is calling this function
    ## writeWarning( 'deprecated use of Func::formatGmTime' );

    return TWiki::Time::formatTime( @_, 'gmtime' );
}

=pod

---+++ getDataDir( ) -> $dir

*DEPRECATED* since 1.1 - use the [[#Functions_Content_Handling][content handling functions]] to manipulate topics instead

Get data directory (topic file root)

Return: =$dir= Data directory, e.g. ='/twiki/data'=

This function violates store encapsulation and is therefore *deprecated*.

*Since:* TWiki::Plugins::VERSION 1.000 (07 Dec 2002)

=cut

sub getDataDir {
    return $TWiki::cfg{DataDir};
}

=pod

---+++ getPubDir( ) -> $dir

*DEPRECATED* since 1.1 - use the [[#Functions_Content_Handling][content handling functions]] to manipulateattachments instead

Get pub directory (file attachment root). Attachments are in =$dir/Web/TopicName=

Return: =$dir= Pub directory, e.g. ='/htdocs/twiki/pub'=

This function violates store encapsulation and is therefore *deprecated*.

Use =readAttachment= and =saveAttachment= instead.

*Since:* TWiki::Plugins::VERSION 1.000 (07 Dec 2002)

=cut

sub getPubDir {
    return $TWiki::cfg{PubDir};
}

=pod

---+++ checkDependencies( $moduleName, $dependenciesRef ) -> $error

*DEPRECATED* since 1.1 - use TWiki:Plugins.BuildContrib and define DEPENDENCIES that can be statically
evaluated at install time instead. It is a lot more efficient.

*Since:* TWiki::Plugins::VERSION 1.025 (01 Aug 2004)

=cut

sub checkDependencies {
    my ( $context, $deps ) = @_;
    my $report = '';
    my $depsOK = 1;
    foreach my $dep ( @$deps ) {
        my ( $ok, $ver ) = ( 1, 0 );
        my $msg = '';
        my $const = '';

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

1;

# EOF
