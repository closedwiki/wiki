# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
# Copyright (C) 2003 Laurent Bovet
# Copyright (C) 2006-2010 TWiki:TWiki.TWikiContributor
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

# =========================
package TWiki::Plugins::JavaDocPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $exampleCfgVar
    );

$VERSION = '1.1';
$RELEASE = '2010-12-11'
$pluginName = 'JavaDocPlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
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

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;
    $_[0] =~ s/%JAVADOC{(.*?)}%/&handleJavaDoc($1)/geo;
}

sub handleJavaDoc
  {
    TWiki::Func::writeDebug( "- ${pluginName}::handleJavaDoc( $_[0] )" ) if $debug;

    # split the prefix variable and the class
    @args = split( /:/, $_[0] );

    if($#args == 0) {
      @args = ("DEFAULT", $args[0]);
    }
    
    # retrieve the prefix
    $prefix = TWiki::Func::getPreferencesValue("JAVADOCPLUGIN_" . $args[0]);
    # convert the dots of the class to slashes
    $path = $args[1];
    $path =~ s|[.]|/|g;
    @parray = split( /\./, $args[1] );

     return '<A HREF="' . $prefix . $path . '.html">' . $parray[$#parray]
       . "</A>";
#  }
}

# =========================

1;
