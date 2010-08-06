# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 TWiki:Main.DeanCording
# Copyright (C) 2005-2010 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution.
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
package TWiki::Plugins::ChildTopicTemplatePlugin;    # change the package name and $pluginName!!!

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $childTopicTemplateFound
    );

$VERSION = '$Rev$';
$RELEASE = '2010-08-05';

$pluginName = 'ChildTopicTemplatePlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );
$debug=1;

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

sub postRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    TWiki::Func::writeDebug( "- ${pluginName}::postRenderingHandler( $web.$topic )" ) if $debug;

    # This handler is called once for each rendered block of text i.e.
    # it may be called several times during the rendering of a topic.

    return unless( $_[0] =~ m/%CHILDTOPICTEMPLATE/ );

    # Clear childTopicTemplate
    my $childTopicTemplate = '';
    my $result ='';

    foreach( split /%CHILDTOPICTEMPLATE/m, $_[0] ) {
        if( s/^ *{[ "']*([^ "'\}]*)[ "']*}%// ) {
            $childTopicTemplate = $1;
        }
        if( $childTopicTemplate ) {
            s/(href=".*?\?topicparent=[^"]+)"(.*?<\/a>)/$1;templatetopic=$childTopicTemplate"$2/g;
        }
        $result .= $_;
    }

    $_[0] = $result;
}

1;
