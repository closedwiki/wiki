# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
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
# This program applies in order the installed TWiki plugins.
# Each plugin is a package that contains the subs listed in
# @registrableHandlers.

package TWiki::Plugins;

##use strict;

use vars qw(
        @activePluginWebs @activePluginTopics
        @registrableHandlers %registeredHandlers %onlyOnceHandlers
	$VERSION
    );

$VERSION = '1.010';

@registrableHandlers = (           #                                         VERSION:
        'initPlugin',              # ( $topic, $web, $user, $installWeb )    1.000
        'registrationHandler',     # ( $web, $wikiName, $loginName )         1.010
        'commonTagsHandler',       # ( $text, $topic, $web )                 1.000
        'startRenderingHandler',   # ( $text, $web )                         1.000
        'outsidePREHandler',       # ( $text )                               1.000
        'insidePREHandler',        # ( $text )                               1.000
        'endRenderingHandler',     # ( $text )                               1.000
        'beforeEditHandler',       # ( $text, $topic, $web )                 1.010
        'afterEditHandler',        # ( $text, $topic, $web )                 1.010
        'beforeSaveHandler',       # ( $text, $topic, $web )                 1.010
        'writeHeaderHandler',      # ( $query )                              1.010
        'redirectCgiQueryHandler', # ( $query, $url )                        1.010
        'getSessionValueHandler',  # ( $key )                                1.010
        'setSessionValueHandler'   # ( $key, $value )                        1.010
    );
    
%onlyOnceHandlers = ( 'registrationHandler'     => 1,
                      'writeHeaderHandler'      => 1,
                      'redirectCgiQueryHandler' => 1,
                      'getSessionValueHandler'  => 1,
                      'getSessionValueHandler'  => 1 );

%registeredHandlers = ();


# =========================
sub discoverPluginPerlModules
{
    my $libDir = &TWiki::getTWikiLibDir();
    my @plugins = ();
    my @modules = ();
    if( opendir( DIR, "$libDir/TWiki/Plugins" ) ) {
        @modules = map{ s/^(.*?)\.pm$/$1/oi; $_ }
                   sort
                   grep /.+Plugin\.pm$/i, readdir DIR;
        push( @plugins, @modules );
        closedir( DIR );
    }
    return @plugins;
}

# =========================
sub registerHandler
{
    my ( $handlerName, $theHandler ) = @_;
    push @{$registeredHandlers{$handlerName}}, ( $theHandler );
}

# =========================
sub registerPlugin
{
    #FIXME make all this sub more robust
    # parameters: ( $plugin, $topic, $web, $user )
    my ( $plugin, $topic, $web, $user ) = @_;

    # look for the plugin installation web (needed for attached files)
    # in the order:
    #   1 fully specified web.plugin
    #   2 TWiki.plugin
    #   3 Plugins.plugin
    #   4 thisweb.plugin

    my $installWeb = '';
    # first check for fully specified plugin
    if ( $plugin =~ m/^(.+)\.([^\.]+Plugin)$/ ) {
        $installWeb = $1;
        $plugin = $2;
    } 

    if( grep { /^$plugin$/ } @activePluginTopics ) {
        # Plugin is already registered
        return;
    }

    if( ! $installWeb ) {
        if ( &TWiki::Store::topicExists( $TWiki::twikiWebname, $plugin ) ) {
            # found plugin in TWiki web
            $installWeb = $TWiki::twikiWebname;
        } elsif ( &TWiki::Store::topicExists( "Plugins", $plugin ) ) {
            # found plugin in Plugins web
            $installWeb = "Plugins";
        } elsif ( &TWiki::Store::topicExists( $web, $plugin ) ) {
            # found plugin in current web
            $installWeb = $web;
        } else {
            # not found
            &TWiki::writeWarning( "Plugins: couldn't register $plugin, no plugin topic" );
            return;
        }
    }

    # untaint & clean up the dirty laundry ....
    if ( $plugin =~ m/^([A-Za-z0-9_]+Plugin)$/ ) {
        $plugin = $1; 
    } else {
        # invalid topic name for plugin
        return;
    }

    my $p   = 'TWiki::Plugins::'.$plugin;

    eval "use $p;";
    my $h   = "";
    my $sub = "";
    my $prefix = "";
    $sub = $p.'::initPlugin';
    # we register a plugin ONLY if it defines initPlugin AND it returns true 
    if( ! defined( &$sub ) ) {
        return;
    }
    # read plugin preferences before calling initPlugin
    $prefix = uc( $plugin ) . "_";
    &TWiki::Prefs::getPrefsFromTopic( $installWeb, $plugin, $prefix );

    if( &$sub( $topic, $web, $user, $installWeb ) ) {
        foreach $h ( @registrableHandlers ) {
            $sub = $p.'::'.$h;
            &registerHandler( $h, $sub ) if defined( &$sub );
        }
        $activePluginWebs[@activePluginWebs] = $installWeb;
        $activePluginTopics[@activePluginTopics] = $plugin;
    }
}

# =========================
sub applyHandlers
{
    my $handlerName = shift;
    my $theHandler;
    if( $TWiki::disableAllPlugins ) {
        return;
    }
    my $status;
    
    foreach $theHandler ( @{$registeredHandlers{$handlerName}} ) {
        # apply handler on the remaining list of args
        $status = &$theHandler;
        if( $onlyOnceHandlers{$handlerName} ) {
            if( $status ) {
                return $status;
            }
        }
    }
    
    return undef;
}

# =========================
sub initialize
{
    my( $theTopicName, $theWebName, $theUserName ) = @_;

    # initialize variables, needed when TWiki::initialize called more then once
    %registeredHandlers = ();
    @activePluginTopics = ();
    @activePluginWebs = ();

    # Get INSTALLEDPLUGINS and DISABLEDPLUGINS variables
    my $plugin = &TWiki::Prefs::getPreferencesValue( "INSTALLEDPLUGINS" ) || "";
    $plugin =~ s/[\n\t\s\r]+/ /go;
    my @instPlugins = grep { /^.+Plugin$/ } split( /,?\s+/ , $plugin );
    $plugin = &TWiki::Prefs::getPreferencesValue( "DISABLEDPLUGINS" ) || "";
    $plugin =~ s/[\n\t\s\r]+/ /go;
    my @disabledPlugins = map{ s/^.*\.(.*)$/$1/o; $_ }
                          grep { /^.+Plugin$/ } split( /,?\s+/ , $plugin );

    # append discovered plugin modules to installed plugin list
    push( @instPlugins, discoverPluginPerlModules() );

    # for efficiency we register all possible handlers at once
    my $p = "";
    foreach $plugin ( @instPlugins ) {
        $p = $plugin;
        $p =~ s/^.*\.(.*)$/$1/o; # cut web
        if( ! ( grep { /^$p$/ } @disabledPlugins ) ) {
            &registerPlugin( $plugin, @_, $theWebName, $theUserName );
        }
    }
}

# =========================
sub handlePluginDescription
{
    my $text = "";
    my $line = "";
    my $pref = "";
    for( my $i = 0; $i < @activePluginTopics; $i++ ) {
        $pref = uc( $activePluginTopics[$i] ) . "_SHORTDESCRIPTION";
        $line = &TWiki::Prefs::getPreferencesValue( $pref );
        if( $line ) {
            $text .= "\t\* $activePluginWebs[$i].$activePluginTopics[$i]: $line\n"
        }
    }

    return $text;
}

# =========================
sub handleActivatedPlugins
{
    my $text = "";
    for( my $i = 0; $i < @activePluginTopics; $i++ ) {
        $text .= "$activePluginWebs[$i].$activePluginTopics[$i], "
    }
    $text =~ s/\,\s*$//o;
    return $text;
}

# =========================
# This could be better integrated with the other auto discovery for plugins
sub initializeUser
{
#   my( $theRemoteUser, $theUrl,  $thePathInfo ) = @_;
    my $user;
    my $p = "TWiki::Plugins::SessionPlugin";
    my $sub = $p.'::initializeUserHandler';

    my $libDir = &TWiki::getTWikiLibDir();
    if(  -e "$libDir/TWiki/Plugins/SessionPlugin.pm" ) {
        eval "use $p;";
        if( defined( &$sub ) ) {
            $user = &$sub( @_ );
        }
    }
    if( ! defined( $user ) ) {
        $user = &TWiki::initializeRemoteUser( $_[0] );
    }
    
    return $user;
}

# FIXME: For Beijing release, restored above initializeUser function and
# comment out initializeUserHandler since Codev.InitializeUserHandlerBroken
# =========================
#sub initializeUserHandler
#{
#    # Called by TWiki::initialize
##   my( $theLoginName, $theUrl, $thePathInfo ) = @_;
#
#    unshift @_, ( 'initializeUserHandler' );
#    my $user = &applyHandlers;
#
#    if( ! defined( $user ) ) {
#        $user = &TWiki::initializeRemoteUser( $_[0] );
#    }
#
#    return $user;
#}

# =========================
sub registrationHandler
{
    # Called by the register script
#    my( $web, $wikiName, $loginName ) = @_;
    unshift @_, ( 'registrationHandler' );
    &applyHandlers;
}

# =========================
sub commonTagsHandler
{
    # Called by sub handleCommonTags, after %INCLUDE:"..."%
#    my( $text, $topic, $theWeb ) = @_;
    unshift @_, ( 'commonTagsHandler' );
    &applyHandlers;
    $_[0] =~ s/%PLUGINDESCRIPTIONS%/&handlePluginDescription()/geo;
    $_[0] =~ s/%ACTIVATEDPLUGINS%/&handleActivatedPlugins()/geo;
}

# =========================
sub startRenderingHandler
{
    # Called by getRenderedVersion just before the line loop
#    my ( $text, $web ) = @_;
    unshift @_, ( 'startRenderingHandler' );
    &applyHandlers;
}

# =========================
sub outsidePREHandler
{
    # Called by sub getRenderedVersion, in loop outside of <PRE> tag
#    my( $text ) = @_;
    unshift @_, ( 'outsidePREHandler' );
    &applyHandlers;
}

# =========================
sub insidePREHandler
{
    # Called by sub getRenderedVersion, in loop inside of <PRE> tag
#    my( $text ) = @_;
    unshift @_, ( 'insidePREHandler' );
    &applyHandlers;
}

# =========================
sub endRenderingHandler
{
    # Called by getRenderedVersion just after the line loop
#    my ( $text ) = @_;
    unshift @_, ( 'endRenderingHandler' );
    &applyHandlers;
}

# =========================
sub beforeEditHandler
{
    # Called by edit
#    my( $text, $topic, $web ) = @_;
    unshift @_, ( 'beforeEditHandler' );
    &applyHandlers;
}

# =========================
sub afterEditHandler
{
    # Called by edit
#    my( $text, $topic, $web ) = @_;
    unshift @_, ( 'afterEditHandler' );
    &applyHandlers;
}

# =========================
sub beforeSaveHandler
{
    # Called by TWiki::Store::saveTopic before the save action
#    my ( $theText, $theTopic, $theWeb ) = @_;
    unshift @_, ( 'beforeSaveHandler' );
    &applyHandlers;
}

# =========================
sub writeHeaderHandler
{
    # Called by TWiki::writeHeader
    unshift @_, ( 'writeHeaderHandler' );
    return &applyHandlers;
}

# =========================
sub redirectCgiQueryHandler
{
    # Called by TWiki::redirect
    unshift @_, ( 'redirectCgiQueryHandler' );
    return &applyHandlers;
}

# =========================
sub getSessionValueHandler
{
    # Called by TWiki::getSessionValue
    unshift @_, ( 'getSessionValueHandler' );
    return &applyHandlers;
}

# =========================
sub setSessionValueHandler
{
    # Called by TWiki.setSessionValue
    unshift @_, ( 'setSessionValueHandler' );
    return &applyHandlers;
}

# =========================

1;
