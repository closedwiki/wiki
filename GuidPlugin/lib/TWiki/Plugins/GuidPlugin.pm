# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
# Copyright (C) 2006-2010 TWiki Contributors 
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
package TWiki::Plugins::GuidPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $exampleCfgVar
    );

use Data::UUID;

$VERSION = '$Rev$';
$RELEASE = '2010-10-31';

$pluginName = 'GUIDPlugin';  # Name of this Plugin

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

    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $exampleCfgVar = &TWiki::Func::getPreferencesValue( "GUIDPLUGIN_EXAMPLE" ) || "default";

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

sub handleGUID {
   my $args = shift;
   my $type = 'str';
   my $result = "";

   $ug = new Data::UUID;

   if ($args) {
      $type = &TWiki::Func::extractNameValuePair( $args, "type" ) || $type;
   }
   if ($type eq 'bin') {
      $result = $ug->create();
   } elsif ($type eq 'str') {
      $result = $ug->create_str();
   } elsif ($type eq 'hex') {
      $result = $ug->create_hex();
   } elsif ($type eq 'b64') {
      $result = $ug->create_b64();
   }

   
   return $result;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    $_[0] =~ s/%GUID_ID%/&handleGUID()/ge;
    $_[0] =~ s/%GUID_ID{(.*)}%/&handleGUID($1)/ge;
}

1;
