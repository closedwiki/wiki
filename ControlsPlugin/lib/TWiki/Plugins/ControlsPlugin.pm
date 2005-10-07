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
#   renderFormFieldForEditHandler( $name, $type, $size, $value, $attributes, $possibleValues)
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
#
# initPlugin is required, all other are optional. 
# For increased performance, unused handlers are disabled. To
# enable a handler remove the leading DISABLE_ from the function
# name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions 
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::ControlsPlugin;

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

$pluginName = 'ControlsPlugin';  # Name of this Plugin

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
    $debug = TWiki::Func::getPluginPreferencesFlag( "CONTROLSPLUGIN_DEBUG" );

    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    #$exampleCfgVar = TWiki::Func::getPluginPreferencesValue( "EXAMPLE" ) || "default";

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
    # Called by TWiki::handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    $_[0] =~ s/%CONTROL{(.*?)}%/handleControls( $_[2], $_[1], $1 )/ge;
}

=pod

---++ sub handleControls ( $web, $topic, $parameterString ) ==> $value
| $web | web and  |
| $topic | topic to display the name for |
| $parameterString | twiki parameter string  |

=cut

sub handleControls
{
    my( $theWeb, $theTopic, $theArgs ) = @_;

    my %params = TWiki::Func::extractParameters( $theArgs );

    my $name   = $params{"_DEFAULT"} || $params{"name"} || "";
    my $web    = $params{"web"}   || $theWeb;
    my $topic  = $params{"topic"} || $theTopic;
    my $size   = $params{"size"} || 1;
    my $type   = $params{"type"} || "select";
    my $url   = $params{"urlparam"} || "off";

    return getListOfFieldValues($web, $topic, $name, $type, $size, $url );
}

# ============================
# Get list of possible field values
# If topic contains Web this overrides webName
=pod

---++ sub getListOfFieldValues (  $webName, $topic, $name, $type, $size  )

Not yet documented.

=cut

sub getListOfFieldValues
{
    my( $webName, $topic, $name, $type, $size ) = @_;
    
    if( $topic =~ /^(.*)\.(.*)$/ ) {
        $webName = $1;
        $topic = $2;
    }
    my @posValues = ();

    if( &TWiki::Func::topicExists( $webName, $topic ) ) {
      my( $meta, $text ) = &TWiki::Func::readTopic( $webName, $topic );
      # Processing of SEARCHES for Lists
      $text =~ s/%SEARCH{(.*?)}%/&TWiki::handleSearchWeb($1)/geo;
      @posValues = &TWiki::Form::getPossibleFieldValues( $text );
    }

    my $value = "";
    $type = $type || "select";
    $size = $size || 1;

    if( $type eq "select" ) {
      my $val = ($url eq "on")?"<option>%URLPARAM{\"$name\"}%</option>":"";
      foreach my $item (@posValues) {
	$item =~ s/<nop/&lt\;nop/go;
	$val .= "   <option>$item</option>";
      }
      $value = "<select name=\"$name\" size=\"$size\">$val</select>";
    } elsif( $type =~ "^checkbox" ) {
      my $val ="<table  cellspacing=\"0\" cellpadding=\"0\"><tr>";
      my $lines = 0;
      foreach my $item ( @posValues ) {
	my $expandedItem = &TWiki::Func::expandCommonVariables( $item, $topic );
	$val .= "\n<td><input class=\"twikiEditFormCheckboxField\" type=\"checkbox\" name=\"$name$item\" />$expandedItem &nbsp;&nbsp;</td>";
	if( $size > 0 && ($lines % $size == $size - 1 ) ) {
	  $val .= "\n</tr><tr>";
	}
	$lines++;
      }
      $val =~ s/\n<\/tr><tr>$//;
      $value = "$val\n</tr></table>\n";
    } elsif( $type eq "radio" ) {
      my $val = "<table  cellspacing=\"0\" cellpadding=\"0\"><tr>";
      my $lines = 0;
      foreach my $item ( @posValues ) {
	my $expandedItem = &TWiki::Func::expandCommonVariables( $item, $topic );
	$val .= "\n<td><input class=\"twikiEditFormRadioField twikiRadioButton\" type=\"radio\" name=\"$name\" value=\"$item\" />$expandedItem &nbsp;&nbsp;</td>";
	if( $size > 0 && ($lines % $size == $size - 1 ) ) {
	  $val .= "\n</tr><tr>";
	}
	$lines++;
      }
      $val =~ s/\n<\/tr><tr>$//;
      $value = "$val\n</tr></table>\n";
    }
    return $value;
}

1;
