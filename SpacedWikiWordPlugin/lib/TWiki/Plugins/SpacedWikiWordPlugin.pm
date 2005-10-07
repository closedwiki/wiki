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
# =========================
#
#
# Each plugin is a package that contains the subs:
#
#   initPlugin           ( $topic, $web, $user, $installWeb )
#   commonTagsHandler    ( $text, $topic, $web )
#   startRenderingHandler( $text, $web )
#   outsidePREHandler    ( $text )
#   insidePREHandler     ( $text )
#   endRenderingHandler  ( $text )
#
# initPlugin is required, all other are optional. 
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name.
# 



# =========================
package TWiki::Plugins::SpacedWikiWordPlugin; 

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $debug
        $exampleCfgVar
    );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';


# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between SpacedWikiWordPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin preferences, the variable defined by:         
    #$exampleCfgVar = &TWiki::Func::getPreferencesValue( "SPACEDWIKIWORDPLUGIN" ) || "default";

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "SPACEDWIKIWORDPLUGIN_DEBUG" );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::SpacedWikiWord::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}


sub spacedWikiWord
{
    my ( $word ) =  @_;
#    $word =~ s/([a-z0-9])([A-Z])/$1&nbsp;$2/g; #lower alphanum followed by upper
#    $word =~ s/([a-zA-Z])([0-9])/$1&nbsp;$2/g; #letter followed by number

# Stolen from http://twiki.org/cgi-bin/view/Codev/SpacedOutTWikiWords

   # Make BSFLeaders into BSF Leaders, but don't make
   #  InterfacingTCL into Interfacing TC L
   $word =~ s!([A-Z\s]+)([A-Z][^A-Z\s]+)!$1 $2!g;

   # make DogWalkers into Dog Walkers
   $word =~ s!([a-z])([A-Z])!$1 $2!g;

   # make Lotus123 into Lotus 123
   $word =~ s!([A-Z])([^A-Z\s])!$1 $2!gi;

   # Make 1999Corvette into 1999 Corvette
   $word =~ s!([^A-Z\s])([A-Z])!$1 $2!gi;

   return $word;
}



sub renderWikiWordHandler 
{
    TWiki::Func::writeDebug( "@_" ) if $debug;
    return spacedWikiWord(@_);
}

1;
