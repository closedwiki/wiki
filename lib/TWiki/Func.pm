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

---++ package TWiki::Func

This module defines official functions that [[%TWIKIWEB%.TWikiPlugins][Plugins]]
can use to interact with the TWiki engine and content.

Refer to lib/TWiki/Plugins/EmptyPlugin.pm for a template plugin and
documentation on how to write a plugin.

Plugins should *only* use functions published in this module. If you use
functions in other TWiki libraries you might create a security hole and
you will likely need to change your Plugin when you upgrade TWiki.

Deprecated functions will still work in older code, though they should
_not_ be called in new plugins and should be replaced in older plugins
as soon as possible.

The version of the TWiki::Func module is defined by the VERSION number of the
TWiki::Plugins module, currently %PLUGINVERSION{}%. This can be shown
by the =%<nop>PLUGINVERSION{}%= variable. The 'Since' field in the function
documentation refers to the VERSION number and the date that the function
was addded.

*Note* Contrib authors beware! These methods should only ever be called
from the context of a TWiki plugin. They require a session context to be
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
Return: =$result=   ="1"= if success; undef if session plugin is not installed

*Since:* TWiki::Plugins::VERSION 1.000 (17 Aug 2001)

=cut

sub setSessionValue {
#   my( $theKey, $theValue ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    $TWiki::Plugins::SESSION->{client}->setSessionValue( @_ );
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

    $template =~ s/^oops//;
    return $TWiki::Plugins::SESSION->getOopsUrl( $template, web => $web,
                                                 topic => $topic,
                                                 params => \@params );
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
etc. So you can easily tell what 'type' of script your plugin is
being called within. The available context identifiers are listed
in the %TWIKIWEB%.TWikiTemplates topic.

*Since:* TWiki::Plugins::VERSION 1.026

=cut

sub getContext {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{context};
}

=pod

---++ Functions: Preferences

   * $attr ) -> %params

Extract all parameters from a variable string and returns a hash of parameters
- Parameter: =$attr= | Attribute string
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
#   my( $theKey, $theWeb ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{prefs}->getPreferencesValue( @_ );
}

=pod

---+++ getPluginPreferencesValue( $key ) -> $value

Get a preferences value from your Plugin
   * =$key= - Plugin Preferences key w/o PLUGINNAME_ prefix.
Return: =$value=  Preferences value; empty string if not set

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
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{prefs}->getPreferencesFlag( @_ );
}

=pod

---+++ getPluginPreferencesFlag( $key ) -> $flag

Get a preferences flag from your Plugin
   * =$key= - Plugin Preferences key w/o PLUGINNAME_ prefix.
Return: =$flag=   Preferences flag ='1'= (if set), or ="0"= (for preferences values ="off"=, ="no"= and ="0"=, or values not set at all)

*Since:* TWiki::Plugins::VERSION 1.021 (27 Mar 2004)

=cut

sub getPluginPreferencesFlag {
    my( $theKey ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    my $package = caller;
    $package =~ s/.*:://; # strip off TWiki::Plugins:: prefix
    return $TWiki::Plugins::SESSION->{prefs}->getPreferencesFlag( "\U$package\E_$theKey" );
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

---+++ getWikiUserName( $text ) -> $wikiName

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
| $user | |
| $rev |  |
| $comment | WHAT COMMENT? |

NOTE if you are trying to get revision info for a topic, use
$meta->getRevisionInfo instead if you can - it is significantly
more efficient.

*Since:* TWiki::Plugins::VERSION 1.000 (29 Jul 2001)

=cut

sub getRevisionInfo {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{store}->getRevisionInfo( @_ );
}

=pod

---+++ getRevisionAtTime( $web, $topic, $time ) -> $rev
   * =$web= - web for topic
   * =$topic= - topic
   * =$time= - time (in epoch secs) for the rev

Get the revision number of a topic at a specific time.
Returns a single-digit rev number or undef if it couldn't be determined
(either because the topic isn't that old, or there was a problem)

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
Return =( $oopsUrl, $loginName, $unlockTime )= | The =$oopsUrl= for calling redirectCgiQuery(), user's =$loginName=, and estimated =$unlockTime= in minutes, or ( '', '', 0 ) if no lease exists.

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
            my $past = TWiki::Time::formatDelta(time()-$lease->{taken});
            my $future = TWiki::Time::formatDelta($lease->{expires}-time());
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

Takes out a "lease" on the topic. The lease doesn't prevent
anyone from editing and changing the topic, but it does redirect them
to a warning screen, so this provides some protection. The =edit= script
always takes out a lease.

It is *impossible* to fully lock a topic. Concurrent changes will be
merged.

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
    my( $web, $topic ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

    return $TWiki::Plugins::SESSION->{store}->readTopic( undef, $web, $topic, undef, 0 );
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

---+++ saveTopic( $web, $topic, $meta, $text, $options )
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

For example,
<verbatim>
my( $meta, $text ) = TWiki::Func::readTopic( $web, $topic )
$text =~ s/APPLE/ORANGE/g;
TWiki::Func::saveTopic( $web, $topic, $meta, $text, { comment => 'refruited' } );
</verbatim>

*Note* plugins handlers ( e.g. =beforeSaveHandler= ) will be called as
appropriate.

=cut

sub saveTopic {
    my( $web, $topic, $meta, $text, $options ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;

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

This method is inherently less efficient and more dangerous than =saveTopic=.

*Since:* TWiki::Plugins::VERSION 1.010 (31 Dec 2002)

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

=cut

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
   my $data = TWiki::Func::readAttachment( $meta, $a->{name} );
   ...
}
</verbatim>

*Since:* TWiki::Plugins::VERSION 1.026

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

Save an attachment to the store for a topic. On success, returns undef. If there is an error, a report string will be returned.
<verbatim>
    TWiki::Func::saveAttachment( $web, $topic, 'image.gif',
                                 { file => 'image.gif',
                                   comment => 'Picture of Health',
                                   hide => 1 } );
</verbatim>

*Since:* TWiki::Plugins::VERSION 1.026

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

---+++ getPublicWebList( ) -> @webs
*DEPRECATED* since 1.026 - use =getListOfWebs= instead.

Get list of all public webs, e.g. all webs that do not have the =NOSEARCHALL= flag set in the WebPreferences
Return: =@webs= List of all public webs, e.g. =( 'Main',  'Know', 'TWiki' )=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub getPublicWebList {
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{store}->getListOfWebs("user,public");
}

=pod

---+++ getListOfWebs( $filter ) -> @webs
   * =$filter= - spec of web types to recover
Gets a list of webs, filtered according to the spec in the $filter,
which may include one of:
   1 'user' (for only user webs)
   2 'template' (for only template webs i.e. those starting with "_")
=$filter= may also contain the word 'public' which will further filter
out webs that have NOSEARCHALL set on them.

For example, the deprecated getPublicWebList function can be duplicated
as follows:
<verbatim>
   my @webs = TWiki::Func::getListOfWebs( "user,public" );
</verbatim>

*Since:* TWiki::Plugins::VERSION 1.026

=cut

sub getListOfWebs {
    my $filter = shift;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{store}->getListOfWebs($filter);
}

=pod

---+++ getListOfWebs( $filter ) -> @webNames

Gets a list of webs, filtered according to the spec in the $filter,
which may include one of:
   1 'user' (for only user webs)
   2 'template' (for only template webs)
$filter may also contain the word 'public' which will further filter
webs on whether NOSEARCHALL is specified for them or not.

=cut


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

---+++ registerTagHandler( $tag, \&fn )
Should only be called from initPlugin.

Register a function to handle a simple tag. Handles both %<nop>TAG% and %<nop>TAG{...}%. Registered tags are treated the same as TWiki internal tags, and are expanded at the same time. This is a _lot_ more efficient than using the =commonTagsHandler=.
   * =$tag= - The name of the tag i.e. the 'MYTAG' part of %<nop>MYTAG%. The tag name *must* match /^[A-Z][A-Z0-9_]*$/ or it won't work.
   * =\&fn= - Reference to the handler function.

*Since:* TWiki::Plugins::VERSION 1.026

The tag handler function must be of the form:
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
=%EXEC{"ps -Af" silent="on"}%=

=cut

sub registerTagHandler {
    my( $tag, $function ) = @_;
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
                               }
                             );
}

=pod

---+++ addToHEAD( $id, $header )
Adds =$header= to the HTML header (the <head> tag).
This is useful for plugins that want to include some javascript custom css.
   * =$id= - Unique ID to prevent the same HTML from being duplicated. Plugins should use a prefix to prevent name clashes (e.g EDITTABLEPLUGIN_JSCALENDAR)
   * =$header= - the HTML to be added to the <head> section. The HTML must be valid in a HEAD tag - no checks are performed.

All TWiki variables present in =$header= will be expanded before being inserted into the =<head>= section.

Note that this is _not_ the same as the HTTP header, which is modified through the plugins =modifyHeaderHandler=.

*Since:* TWiki::Plugins::VERSION 1.026

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

---+++ formatGmTime( $time, $format ) -> $text
*DEPRECATED* since  TWiki::Plugins::VERSION 1.025 (7 Dec 2002)

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

---++ Functions: File I/O

---+++ getDataDir( ) -> $dir

Get data directory (topic file root)
Return: =$dir= Data directory, e.g. ='/twiki/data'=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

*Deprecated:* TWiki::Plugins::VERSION 1.026

This function violates store encapsulation and is therefore *deprecated*.

=cut

sub getDataDir {
    return $TWiki::cfg{DataDir};
}

=pod

---+++ getPubDir( ) -> $dir

Get pub directory (file attachment root). Attachments are in =$dir/Web/TopicName=
Return: =$dir= Pub directory, e.g. ='/htdocs/twiki/pub'=

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

*Deprecated:* TWiki::Plugins::VERSION 1.026

This function violates store encapsulation and is therefore *deprecated*.

Use =readAttachment= and =writeAttachment= instead.

=cut

sub getPubDir {
    return $TWiki::cfg{PubDir};
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

---+++ readFile( $filename ) -> $text

Read text file, low level. NOTE: For topics use readTopicText()
   * =$filename= - Full path name of file
Return: =$text=        Content of file

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

sub readFile {
#   my( $filename ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{store}->readFile( @_ );
}

=pod

---+++ saveFile( $filename, $text )

Save text file, low level. NOTE: For topics use saveTopicText()
   * =$filename= - Full path name of file
   * =$text=     - Text to save
Return:                none

*Since:* TWiki::Plugins::VERSION 1.000 (7 Dec 2002)

=cut

# TODO: This should return an error for the different failure modes.
sub saveFile {
#   my( $filename, $text ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return $TWiki::Plugins::SESSION->{store}->saveFile( @_ );
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
    return $TWiki::Plugins::SESSION->writeWarning( @_ );
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
| tagNameRegex   | Standard tag names e.g. %<nop>THIS_BIT% (THIS_BIT only) | RE |

=cut

sub getRegularExpression {
    my ( $regexName ) = @_;
    return $TWiki::regex{$regexName};
}

=pod

---+++ checkDependencies( $moduleName, $dependenciesRef ) -> $error

Checks a list of Perl dependencies at runtime
   * =$moduleName= - Context description e.g. name of the module being checked
   * =$dependenciesRef= - Reference of list of hashes containing dependency information; see notes below
Return: =$error= undef if dependencies are OK, an error message otherwise

*Since:* TWiki::Plugins::VERSION 1.025 (01 Aug 2004)

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

=pod

---++ Functions: Template handling and topic creation

---+++ loadTemplate ( $theName, $theSkin, $theWeb ) -> $text

   * =$theName= - template file name
   * =$theSkin= - comma-separated list of skins to use (default: current skin)
   * =$theWeb= - the web to look in for topics that contain templates (default: current web)
Return: expanded template text (what's left after removal of all %TMPL:DEF% statements)

*Since:* TWiki::Plugins::VERSION 1.026

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
Do a %TMPL:P{$theDef}%, only expanding the template (not expanding any tags other than %TMPL tags)
   * =$theDef= - template name
Return: the text of the expanded template

*Since:* TWiki::Plugins::VERSION 1.026

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

*Since:* TWiki::Plugins::VERSION 1.026

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

*Since:* TWiki::Plugins::VERSION 1.026

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

*Since:* TWiki::Plugins::VERSION 1.026

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

*Since:* TWiki::Plugins::VERSION 1.026

=cut

sub wikiToEmail {
    my( $wiki ) = @_;
    ASSERT($TWiki::Plugins::SESSION) if DEBUG;
    return '' unless $wiki;
    my $user = $TWiki::Plugins::SESSION->{users}->findUser( $wiki );
    return '' unless $user;
    return join( ',', @{$user->emails()} );
}

1;

# EOF
