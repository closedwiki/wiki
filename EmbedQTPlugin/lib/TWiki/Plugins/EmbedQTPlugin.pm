# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
# Copyright (C) 2003 TWiki:Main.DonnyKurniawan
# Copyright (C) 2008-2011 TWiki Contributors. All Rights Reserved.
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
package TWiki::Plugins::EmbedQTPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName $debug
    );

$VERSION = '$Rev$';
$RELEASE = '2011-03-12';

$pluginName = 'EmbedQTPlugin';  # Name of this Plugin

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

    $_[0] =~ s/%EMBEDQT{(.*?)}%/&handleEmbedQT($1)/ge;
}

# =========================
sub handleEmbedQT
{
    my ( $theAttributes ) = @_;
    my $QTFileName =   TWiki::Func::extractNameValuePair($theAttributes, "filename");
    my $QTFileWidth =  TWiki::Func::extractNameValuePair($theAttributes, "width"); 
    my $QTFileHeight = TWiki::Func::extractNameValuePair($theAttributes, "height"); 

    return "<object classid=\"clsid:02BF25D5-8C17-4B23-BC80-D3488ABDDC6B\" width=\"$QTFileWidth\" height=\"$QTFileHeight\" codebase=\"http://www.apple.com/qtactivex/qtplugin.cab\"> <embed src=\"$QTFileName\" autoplay=\"true\" controller=\"false\" pluginspage=\"http://www.apple.com/quicktime/download/\"> </embed> </object>";

}

1;
