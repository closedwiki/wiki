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
#
# This is the ReStructuredText TWiki plugin.
# written by
# Nicolas Tisserand (tisser_n@epita.fr), Nicolas Burrus (burrus_n@epita.fr)
# and Perceval Anichini (anichi_p@epita.fr)
# Modified for reStructuredText by Mark Nodine (nodine@freescale.com).
# 
# It uses trip as HTML renderer for reStructuredText.
#######!!!!!! Need Copyright notice for Freescale wrt trip !!!!!!!
# 
# Use it in your twiki text by writing %RESTSTART{tripopts}% ... %RESTEND%

package TWiki::Plugins::ReStructuredTextPlugin;

use IPC::Open2;

# =========================
use vars qw(
	    $web $topic $user $installWeb $VERSION $pluginName $debug $trip
	    $tripoptions
	    );

$VERSION = '1.000';
$pluginName = 'ReStructuredTextPlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;
    
    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning( "Version mismatch between ReStructuredTextPlugin and Plugins.pm" );
        return 0;
    }
    
    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );

    # Get trip override flag
    $trip = TWiki::Func::getPluginPreferencesValue( "TRIP" )
	|| '/_TOOLS_/dist/fs-trip-twiki-/latest/all/bin/trip';
    
    # Get trip override flag
    $tripoptions = TWiki::Func::getPluginPreferencesValue( "TRIPOPTIONS" )
	|| '-D source_link=0 -D time=0';

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::ReStructuredTextPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub pipeThru
{
    my $out;

    my $pid = open2( \*Reader, \*Writer, $_[0]);

    print Writer $_[1];
    close(Writer);

    while (<Reader>)
    {
	$out .= $_;
    }
    close (Reader);

    return $out;
}
# =========================
sub reST2html
{
    my ($text, $opts) = @_;
    my %opts = $opts =~ /(\w+)="(.*?)"/g;
    # Convert each tab to 3 spaces
    $text =~ s/\t/   /g;
    my $html = pipeThru("tee /tmp/trip.dat | $trip $tripoptions $opts{options} -D trusted=0 -- -", $text);

    if ($html =~ s/.*\<body\>\n(.*?)\n?\<\/body\>.*/$1/ios)
    {
	# Convert <PRE> tags to <VERBATIM> since TWiki does markup with <PRE>
	$html =~ s|<(/?)pre.*?>\b|<$1verbatim>|gi;
	return ($opts{stylesheet} ?
		qq(<link rel="stylesheet" type="text/css" href="$opts{stylesheet}">\n) : '') .
	    $html;
    }	
    else
    {
	return "<font color=\"red\"> ReStructuredTextPlugin: internal error  </font>\n<verbatim>\n$html\n</verbatim>\n";
    }
}

# =========================

sub commonTagsHandler
{
    TWiki::Func::writeDebug( "- ReStructuredTextPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # matches %RESTSTART{options}% ... %RESTEND%
    $_[0] =~ s/^%RESTSTART(?:\s*\{(.*?)\})?%\n(.*?)^%RESTEND%$/reST2html($2,$1)/megis;

}

# =========================

1;
