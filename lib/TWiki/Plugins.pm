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
    );

@registrableHandlers = (
        'initPlugin',            # ( $topic, $web, $user )
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
    my ( $plug ) = @_;
    eval "use TWiki::Plugins::$plug;" ;
    my $h = "";
    my $sub = "";
    foreach $h ( @registrableHandlers ) {
        $sub = 'TWiki::Plugins::'.$plug.'::'.$h;
        &registerHandler( $h, $sub ) if defined( &$sub );
    }
}

# =========================
sub applyHandlers
{
    my $handlerName = shift;
    my $theHandler;
    foreach $theHandler ( @{$registeredHandlers{$handlerName}} ) {
        # apply handler on the remaining list of args
        &$theHandler;
    }
}

# =========================
sub initialize
{
# FIXME: we should handle multi-line preference values
#        for the moment it seems to work ONLY if the variable is on a single line

    # Get ACTIVEPLUGINS variable, use DefaultPlugin if not defined
    my $active = &TWiki::Prefs::getPreferencesValue( "ACTIVEPLUGINS" )
                 || "$TWiki::twikiWebname.DefaultPlugin";
    $active =~ s/[\n\t\s\r]+/ /go;
    
    # we enforce the schema Plugins.<name>Plugin
    @pluginList = map { s/^[A-Z]+[A-Za-z]*\.(.*Plugin)$/$1/o; $_ }
#		  grep { /^Plugins\.(.*Plugin)$/ }
		  split( /,?\s+/ , $active );

    # for efficiency we register all possible handlers at once
    my $plug = "";
    foreach $plug ( @pluginList ) {
        &registerPlugin( $plug );
    }
    # parameters: ( $topic, $web, $user )
    &applyHandlers( 'initPlugin', @_ );
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
