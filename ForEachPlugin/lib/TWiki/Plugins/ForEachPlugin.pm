# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
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
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see TWiki.TWikiPlugins for details.
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   earlyInitPlugin         ( )                                     1.020
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   beforeCommonTagsHandler ( $text, $topic, $web )                 1.024
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   afterCommonTagsHandler  ( $text, $topic, $web )                 1.024
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   afterSaveHandler        ( $text, $topic, $web, $errors )        1.020
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
#
# initPlugin is required, all other are optional.
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::ForEachPlugin;    # change the package name and $pluginName!!!

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName $debug
    );

$VERSION = '1.000';
$pluginName = 'ForEachPlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}


# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    #&TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by TWiki::handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;

    $_[0] =~ s/%FOREACH{\s*"(.+?)"\s+in="(.+?)"\s*}%(.*?)%NEXT{\s*"\1"\s*}%/&handleForEach($1, $2, $3)/ges;

    $_[0] =~ s/%FOR{\s*"(.+?)"\s+start="(.+?)"\s+stop="(.+?)"\s+step="(.+?)"\s*}%(.*?)%NEXT{\s*"\1"\s*}%/&handleFor($1, $2, $3, $4, $5)/ges;
}


# =========================
sub DISABLE_startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    TWiki::Func::writeDebug( "- ${pluginName}::startRenderingHandler( $_[1] )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/g;
}


# =========================
sub DISABLE_endRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::endRenderingHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just after the line loop, that is,
    # after almost all XHTML rendering of a topic. <nop> tags are removed after this.

}


# =========================
sub handleForEach
{
    my ( $var, $list, $body ) = @_;
    my $ldebug = $debug;
    &TWiki::Func::writeDebug( "- ${pluginName}::handleForEach(\n var: $var\n list: $list\n body: $body\n )" ) if $ldebug;
    my $ret = "";

    foreach my $item (split /\s*,\s*/, $list) {
        ($ret .= $body) =~ s/\$$var/$item/gs;
        $ret =~ s/^\n//m;
        $ret =~ s/\n$//m;
    }
    &TWiki::Func::writeDebug( "- ${pluginName}::handleForEach() intermediate:\n$ret" ) if $ldebug;
    $ret =~ s/\$percnt/%/g;
    $ret = &TWiki::Func::expandCommonVariables($ret);
    &TWiki::Func::writeDebug( "- ${pluginName}::handleForEach() returns:\n$ret" ) if $ldebug;
    return $ret;
}

# =========================
sub handleFor
{
    my ( $var, $start, $stop, $step, $body ) = @_;
    unless ( ($start =~ /^-?[0-9]+$/) and
             ($stop =~ /^-?[0-9]+$/) and
             ($step =~ /^-?[0-9]+$/) )
    {
        return qq(%RED% FOR{"$var" start="$start" stop="$stop" step="$step"} : Not a number %ENDCOLOR%);
    }
    if ( ($step == 0) or
         ( ($start > $stop) and ($step > 0) ) or
         ( ($start < $stop) and ($step < 0) ) )
    {
        return "%RED% FOR =$var= : Bad step %ENDCOLOR%";
    }

    my $ldebug = $debug;
    &TWiki::Func::writeDebug( "- ${pluginName}::handleFor(\n var: $var\n start: $start\n stop: $stop\n step: $step\n body: $body\n )" ) if $ldebug;
    my $ret = "";

    for (my $i = $start; ($start < $stop) ? $i <= $stop : $i >= $stop ; $i += $step) {
        ($ret .= $body) =~ s/\$$var/$i/gs;
        $ret =~ s/^\n//m;
        $ret =~ s/\n$//m;
    }

    &TWiki::Func::writeDebug( "- ${pluginName}::handleFor() intermediate:\n$ret" ) if $ldebug;
    $ret =~ s/\$percnt/%/g;
    $ret = &TWiki::Func::expandCommonVariables($ret);
    &TWiki::Func::writeDebug( "- ${pluginName}::handleFor() returns:\n$ret" ) if $ldebug;
    return $ret;
}

1;
