# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2011 Peter Thoeny, peter[at]thoeny.org
# Copyright (C) 2008-2011 TWiki Contributors
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
package TWiki::Plugins::EmbedPDFPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $linkText $prerendered
    );

$VERSION = '$Rev$';
$RELEASE = '2011-05-10';

$pluginName = 'EmbedPDFPlugin';  # Name of this Plugin

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

    # Get plugin preferences, the variable defined by:      * Set LINKTEXT = ...
    $linkText = TWiki::Func::getPreferencesValue( "EMBEDPDFPLUGIN_LINKTEXT" );

    # Get plugin preferences, the variable defined by:   * Set PRERENDERED = ...
    $prerendered = TWiki::Func::getPreferencesValue( "EMBEDPDFPLUGIN_PRERENDERED" );

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

    $_[0] =~ s+%EMBEDPDF{\s*(.*?)\s*}%+&handleEmbedPDF($1, $_[1], $_[2])+ge;
    $_[0] =~ s+%EMBEDPDFSIZE{\s*([A-Za-z0-9_-]*?)\s*}%+&handleEmbedPDFSize($1, $_[1], $_[2])+ge;
}

sub handleEmbedPDF
{
    my ( $thePDFFile, $theTopic, $theWeb ) = @_;

    if ( $prerendered && -r TWiki::Func::getPubDir() . "/$theWeb/$theTopic/$thePDFFile.$prerendered" ) {
	$result = "<img src=\"\%ATTACHURL%/$thePDFFile.$prerendered\" />";
    } else {
	$result = "<object data=\"\%ATTACHURLPATH%/$thePDFFile.pdf\" \%EMBEDPDFSIZE{$thePDFFile}% type=\"application/pdf\">"
                . "<param name=\"src\" value=\"\%ATTACHURL%/$thePDFFile.pdf\" />"
                . "<a href=\"\%ATTACHURLPATH%/$thePDFFile.pdf\">$thePDFFile.pdf</a>"
                . '</object>';
    }
    if( $linkText ) {
        $result = "<table><tbody><tr><td align=\"center\">$result</td></tr><tr><td align=\"center\">"
                . "<a href=\"\%ATTACHURLPATH%/$thePDFFile.pdf\">$linkText</a></td></tr></tbody></table>";
    }
    return $result;
}

# =========================

sub handleEmbedPDFSize
{
    my ( $thePDFFile, $theTopic, $theWeb ) = @_;

    $pdf = TWiki::Func::readFile
	( TWiki::Func::getPubDir() . "/$theWeb/$theTopic/$thePDFFile.pdf" );
    if ( $pdf =~ /MediaBox\s*\[\s*([0-9]+\s+){2}([0-9]+)\s+([0-9]+)\s*\]/ ) {
	$width = $2;
	$height = $3;
	$query = TWiki::Func::getCgiQuery();
	if ( $query && $query->user_agent("MSIE") ) {
	    $width += 60;
	    if ( $width < 360) {
		$width = 360;
	    }
	    $height += 110;
	}
	return "width=\"$width\" height=\"$height\"";
    }
    return "note=\"size unknown\"";
}

1;
