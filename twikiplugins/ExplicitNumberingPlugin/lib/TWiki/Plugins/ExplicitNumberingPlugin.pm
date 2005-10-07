# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
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
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
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
package TWiki::Plugins::ExplicitNumberingPlugin; 

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug
    );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'ExplicitNumberingPlugin';  # Name of this Plugin


my $maxLevels = 6;		# Maximum number of levels
my %Sequences;			# Numberings, addressed by the numbering name
my $lastLevel = $maxLevels - 1;	# Makes the code more readable
my @alphabet = ('a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z');

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }


    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    # Plugin correctly initialized
    ##TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;

    return 1;
}

# =========================
sub startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    ##TWiki::Func::writeDebug( "- ${pluginName}::startRenderingHandler( $_[1] )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/g;
    %Sequences = ();
}

# =========================
sub outsidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    ##TWiki::Func::writeDebug( "- ${pluginName}::outsidePREHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, once per line, before any changes,
    # for lines outside <pre> and <verbatim> tags. 
    # Use it to define customized rendering rules.
    # Note: This is an expensive function to comment out.
    # Consider startRenderingHandler instead

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/g;
    $_[0] =~ s/\#\#(\w+\#)?(0)?\.(\.*)([a-z]?)/&makeExplicitNumber($1,$2,length($3),$4)/geo;
}

# =========================
# Build the explicit outline number
sub makeExplicitNumber
{

    ##TWiki::Func::writeDebug( "- ${pluginName}::makeExplicitNumber( $_[0], $_[1], $_[2], $_[3] )" ) if $debug;

    my $name = "-default-";
    my $init = "";
    my $level = $_[2];
    my $alist = "";
    if ( defined( $_[0] ) ) { $name = $_[0]; }
    if ( defined( $_[1] ) ) { $init = $_[1]; }
    if ( defined( $_[3] ) ) { $alist = $_[3]; }
    if ( $alist ne "" ) {
        $level++;
    }

    my $text = "";

    #...Truncate the level count to maximum allowed
    if ($level > $lastLevel) { $level = $lastLevel; }

    #...Initialize a new, or get the current, numbering from the Sequences
    my @Numbering = ();
    if ( ! defined( $Sequences{$name} ) ) {
        for $i ( 0 .. $lastLevel ) { $Numbering[$i] = 0; }
    } else {
        @Numbering = split(':', $Sequences{$name} );
	#...Re-initialize the sequence
	if ( $init eq "0" ) {
	    for $i ( 0 .. $lastLevel ) { $Numbering[$i] = 0; }
	}
    }

    #...Increase current level number
    $Numbering[ $level ] += 1;

    #...Reset all higher level counts
    if ( $level < $lastLevel ) {
        for $i ( ($level+1) .. $lastLevel ) { $Numbering[$i] = 0; }
    }

    #...Save the altered numbering
    $Sequences{$name} =  join( ':', @Numbering );

    #...Construct the number
    if ( $alist eq "" ) {
	for $i ( 0 .. $level ) {
	    $text .= "$Numbering[$i]";
	    $text .= "." if ( $i < $level );
	}
    } else {
	#...Level is 1-origin, indexing is 0-origin
	$text .= $alphabet[$Numbering[$level]-1]
    }

    return $text;
}

# =========================

1;
