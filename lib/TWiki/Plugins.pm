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
# This program applies in order the installed TWiki plugins.
# Each plugin is a package that contains the subs:
#
#   initPlugin           ( $topic, $web, $user )
#   commonTagsHandler    ( $text, $topic, $web )
#   startRenderingHandler( $text, $web )
#   outsidePREHandler    ( $text )
#   insidePREHandler     ( $text )
#   endRenderingHandler  ( $text )

package TWiki::Plugins;

##use strict;

use vars qw(
        @pluginList @registrableHandlers %registeredHandlers
	$VERSION
    );

$VERSION = '1.000';

@registrableHandlers = (
        'initPlugin',            # ( $topic, $web, $user, $installWeb )
        'commonTagsHandler',     # ( $text, $topic, $web )
        'startRenderingHandler', # ( $text, $topic, $web )
        'outsidePREHandler',     # ( $text, $web )
        'insidePREHandler',      # ( $text, $web )
        'endRenderingHandler',   # ( $text, $topic, $web )
        'afterEditHandler',      # ( $text, $topic, $web )
        'beforeSaveHandler'      # ( $text, $topic, $web )
    );

%registeredHandlers = ();

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
    # 	1 fully specified web.plugin
    #	2 twiki.plugin
    #   3 thisweb.plugin
    #   4 main.plugin

    my $installWeb = '';
	# first we suppose the plugin is installed in this same web
        # then we check for fully specified plugins
    if ( $plugin =~ m/^(.+)\.([^.]+Plugin)$/ ) {
	$plugin = $2;
	$installWeb = $1;
    } 
    # then, we hope the plugin is in the TWiki web
    elsif ( &TWiki::Store::topicExists( $TWiki::twikiWebname, $topic ) ) {
	$installWeb = $TWiki::twikiWebname;
    }
    # then, we hope the plugin is in the current web
    elsif ( &TWiki::Store::topicExists( $web, $topic ) ) {
	$installWeb = $web;
    }
    # finally, we hope the plugin is in the Main web
    elsif ( &TWiki::Store::topicExists( $TWiki::mainWebname, $topic ) ) {
	$installWeb = $TWiki::mainWebname;
    }
    # else not found ...
    else { return; }

    my $p   = 'TWiki::Plugins::'.$plugin;

    #FIXME: something wrong with an insecure dependency if the plugin
    #       is not <web>.<plugin> ... no idea why !!!
    eval "use $p;";
    my $h   = "";
    my $sub = "";
    $sub = $p.'::initPlugin';
    # we register a plugin ONLY if it defines initPlugin AND it returns true 
    if (defined( &$sub ) 
	&& 
	&$sub($topic, $web, $user, $installWeb)) {
	    foreach $h ( @registrableHandlers ) {
    		$sub = $p.'::'.$h;
    		&registerHandler( $h, $sub ) if defined( &$sub );
		}
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
    foreach $theHandler ( @{$registeredHandlers{$handlerName}} ) {
        # apply handler on the remaining list of args
        &$theHandler;
    }
}

# =========================
sub initialize
{
    # Get ACTIVEPLUGINS variable
    my $active = &TWiki::Prefs::getPreferencesValue( "ACTIVEPLUGINS" ) || "";
    $active =~ s/[\n\t\s\r]+/ /go;

    # FIXME: should we enforce the schema <webname>.<name>Plugin or not?
    @pluginList = grep { /^.+Plugin$/ }
		  split( /,?\s+/ , $active );

    # for efficiency we register all possible handlers at once
    %registeredHandlers = ();  # needed when TWiki::initialize called more then once
    my $plug    = "";
    foreach $plug ( @pluginList ) {
        &registerPlugin( $plug, @_ );
    }
}

# =========================
sub commonTagsHandler
{
    # Called by sub handleCommonTags, after %INCLUDE:"..."%
#    my( $text, $topic, $theWeb ) = @_;
    unshift @_, ( 'commonTagsHandler' );
    &applyHandlers;
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

1;
