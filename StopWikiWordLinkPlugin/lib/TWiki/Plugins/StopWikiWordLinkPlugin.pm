# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006-2012 Peter Thoeny, peter[at]thoeny.org
# Copyright (C) 2006-2012 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::StopWikiWordLinkPlugin;

use strict;

#===========================================================================
our $VERSION = '$Rev$';
our $RELEASE = '2012-09-08';

my $debug;
my $stopWordsRE;
my $pluginName = 'StopWikiWordLinkPlugin';

#===========================================================================
sub initPlugin {
    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # get debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    # Get plugin preferences variable:
    my $stopWords = TWiki::Func::getPreferencesValue( "STOPWIKIWORDLINK" )
                 || TWiki::Func::getPreferencesValue( "\U$pluginName\E_STOPWIKIWORDLINK" )
                 || 'UndefinedStopWikiWordLink';

    # build regex:
    $stopWords =~ s/\, */\|/go;
    $stopWords =~ s/^ *//o;
    $stopWords =~ s/ *$//o;
    $stopWords =~ s/[^A-Za-z0-9\|]//go;
    $stopWordsRE = "(^|[\( \n\r\t\|])($stopWords)"; # WikiWord preceeded by space or parens
    TWiki::Func::writeDebug( "- $pluginName stopWordsRE: $stopWordsRE" ) if $debug;

    # Plugin correctly initialized
    return 1;
}

#===========================================================================
sub preRenderingHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    #my( $text, $pMap ) = @_;

    $_[0] =~ s/$stopWordsRE/$1<nop>$2/g;
}

1;
