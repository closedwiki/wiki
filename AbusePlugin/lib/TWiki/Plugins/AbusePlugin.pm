# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
# Copyright (C) 2003 TWiki:Main.RahulMundke 
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

package TWiki::Plugins::AbusePlugin;

# =========================
our $VERSION = '$Rev$';
our $RELEASE = '2011-07-10';

my $debug;
my $abuseWordsRE;

# =========================
sub initPlugin
{
    my ( $topic, $web ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.024 ) {
        TWiki::Func::writeWarning( "Version mismatch between AbusePlugin and Plugins.pm" );
        return 0;
    }

    # Get preferences settings
    $debug = TWiki::Func::getPreferencesValue( "ABUSEPLUGIN_DEBUG" ) || 0;
    $abuseWordsRE = TWiki::Func::getPreferencesValue( "ABUSEPLUGIN_ABUSEWORDS" ) || 'fuck, fucking';
    $abuseWordsRE =~ s/, */|/go;
    $abuseWordsRE = "\\b($abuseWordsRE)\\b";
    TWiki::Func::writeDebug( "- TWiki::Plugins::AbusePlugin, abuseWordsRE: $abuseWordsRE" ) if $debug;

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::AbusePlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
    $_[0] =~ s/$abuseWordsRE/_obscureWord( $1 )/geim;
}

# =========================
sub _obscureWord
{
    my( $word ) = @_;
    TWiki::Func::writeDebug( "- TWiki::Plugins::AbusePlugin::_obscureWord( $word )" ) if $debug;
    $word =~ s/^(.)(.*)$/$1 . '*' x length($2)/e;
    return $word;
}

# =========================
1;
