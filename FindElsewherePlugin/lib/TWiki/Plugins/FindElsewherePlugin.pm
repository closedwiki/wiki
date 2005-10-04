#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
# Portions Copyright (C) 2002 Mike Barton, Marco Carnut, Peter HErnst
#	(C) 2003 Martin Cleaver, (C) 2004 Matt Wilkie
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
# This is the FindElsewhere TWiki plugin,
# see http://twiki.org/cgi-bin/view/Plugins/FindElsewherePlugin for details.
#

## Changelog
# 29-Jan-2002:	Mike Barton
#		- initial version (cvs rev1.1)
# 15-May-2002:	Marco Carnut
#		- patch to show webname, e.g. Main.WebHome (cvs rev1.2)
# 25-Sep-2002:	PeterHErnst 
#		- modified webname to show as superscript, 
#		- some other changes (chiefly "/o" regex modifiers) (cvs rev1.3)
# 25-May-2003:	Martin Cleaver 
#		- patch to add Codev.WebNameAsWikiName (cvs rev1.4)
# 12-Feb-2004:	Matt Wilkie 
#		- put all of above into twikiplugins cvs, 
#		- removed "/o"'s as there may be issues with modperl (Codev.ModPerl)
# 31-Mar-2005:  SteffenPoulsen
#		- updated plugin to be I18N-aware
# 02-Apr-2005:  SteffenPoulsen
#		- fixed problems with WikiWordAsWebName.WikiWord
# 12-Aug-2005 - Crawford Currie
#       - improved conformance to standards, incremented version #

package TWiki::Plugins::FindElsewherePlugin;

use vars qw(
            $web $topic $user $installWeb $VERSION $debug
            $doPluralToSingular
            $wnre
            $wwre
            $manre
            $abbre
           );

$VERSION = '$Rev$';

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between FindElsewherePlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $debug = TWiki::Func::getPreferencesFlag( "FINDELSEWHEREPLUGIN_DEBUG" );

    $otherWebMulti =  TWiki::Func::getPreferencesValue( "FINDELSEWHEREPLUGIN_LOOKELSEWHERE" ) || "";
    @webList = split( /[\,\s]+/, $otherWebMulti );
    TWiki::Func::writeDebug( "- TWiki::Plugins::FindElsewherePlugin will look in @webList" ) if $debug;

    $doPluralToSingular =  TWiki::Func::getPreferencesFlag( "FINDELSEWHEREPLUGIN_PLURALTOSINGULAR" ) || "";

    $wnre = TWiki::Func::getRegularExpression('webNameRegex');
    $wwre = TWiki::Func::getRegularExpression('wikiWordRegex');
    $manre = TWiki::Func::getRegularExpression('mixedAlphaNum');
    $abbre = TWiki::Func::getRegularExpression('abbrevRegex');

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::FindElsewherePlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

sub preRenderingHandler {
    #my ( $text, \%map ) = @_;

    TWiki::Func::writeDebug( "- FindElsewherePlugin::startRenderingHandler( $_[1].$topic )" ) if $debug;

    # Find instances of WikiWords not in this web, but in the otherWeb(s)
    # If the WikiWord is found in theWeb, put the word back unchanged
    # If the WikiWord is found in the otherWeb, link to it via
    # [[otherWeb.WikiWord]]
    # If it isn't found there either, put the word back unchnaged

    # Match WikiWordAsWebName.WikiWord, WikiWords, [[wiki words]] and
    # WIK IWO RDS
    $_[0] =~ s/([\s\(])($wnre\.$wwre|$wwre|\[\[[$manre\s]+\]\]|$abbre)/_findTopicElsewhere($_[1],$1,$2,$2,"")/geo;
}

sub _makeTopicLink {
    #my($otherWeb, $theTopic) = @_;
    return "[[$_[0].$_[1]][$_[0]]]";
}

sub _findTopicElsewhere {
    # This was copied and pruned from TWiki::internalLink

    my( $theWeb, $thePreamble, $theTopic, $theLinkText, $theAnchor ) = @_;

    # If we got ourselves a WikiWordAsWebName.WikiWord, we're done - return untouched info
    if ($theTopic =~ /$wnre\.$wwre/o) {
        return $thePreamble.$theTopic;
    }

    # preserve link style formatting
    my $oldTheTopic = $theTopic;

    # Turn spaced-out names into WikiWords - upper case first letter of
    # whole link, and first of each word.
    $theTopic =~ s/^(.)/\U$1/o;
    $theTopic =~ s/\s(\w)/\U$1/go;
    $theTopic =~ s/\[\[(\w)(.*)\]\]/\u$1$2/o;

    my $text = $thePreamble;

    # Look in the current web, return when found
    my $exist = TWiki::Func::topicExists( $theWeb, $theTopic );
    if ( ! $exist ) {
        if ( ( $doPluralToSingular ) && ( $theTopic =~ /s$/ ) ) {
            my $theTopicSingular = _makeSingular( $theTopic );
            if( TWiki::Func::topicExists( $theWeb, $theTopicSingular ) ) {
                TWiki::Func::writeDebug( "- $theTopicSingular was found in $theWeb." ) if $debug;
                $text .= "$oldTheTopic"; # leave it as we found it
                return $text;
            }
        }
    } else {
        TWiki::Func::writeDebug( "- $theTopic was found in $theWeb." ) if $debug;
        $text .= "$oldTheTopic"; # leave it as we found it
        return $text;
    }

    # Look in the other webs, return when found
    my @topicLinks;
    foreach ( @webList ) {
        my $otherWeb = $_;

        # For systems running WebNameAsWikiName 
        # If the $theTopic is a reference to a the name of 
        # otherWeb, point at otherWeb.WebHome - MRJC
        if ($otherWeb eq $theTopic) {
            TWiki::Func::writeDebug( "- $theTopic is the name of another web $otherWeb." );# if $debug;
            $text .= "[[$otherWeb.WebHome][$otherWeb]]";
            return $text;
        }

        my $exist = TWiki::Func::topicExists( $otherWeb, $theTopic );
        if ( ! $exist ) {
            if ( ( $doPluralToSingular ) && ( $theTopic =~ /s$/ ) ) {
                my $theTopicSingular = _makeSingular( $theTopic );
                if( TWiki::Func::topicExists( $otherWeb, $theTopicSingular ) ) {
                    TWiki::Func::writeDebug( "- $theTopicSingular was found in $otherWeb." ) if $debug;
                    push(@topicLinks, _makeTopicLink($otherWeb,$theTopic));
                }
            }
        } else  {
            TWiki::Func::writeDebug( "- $theTopic was found in $otherWeb." ) if $debug;
            push(@topicLinks, _makeTopicLink($otherWeb,$theTopic));
        }
    }

    if ($#topicLinks >= 0) { # topic found elsewhere
        # If link text [[was in this form]] <em> it
        $theLinkText =~ s/\[\[(.*)\]\]/<em>$1<\/em>/go;
        # Prepend WikiWords with <nop>, preventing double links
        $theLinkText =~ s/([\s\(])($wwre)/$1<nop>$2/go;
        $text .= "<nop>$theLinkText<sup>(".join(",", @topicLinks ).")</sup>" ;
    } else {
        TWiki::Func::writeDebug( "- $theTopic is not in any of these webs: @webList." ) if $debug;
        $text .= $theLinkText;
    }

    return $text;
}

sub _makeSingular {
    my ($theWord) = @_;

    $theWord =~ s/ies$/y/o;       # plurals like policy / policies
    $theWord =~ s/sses$/ss/o;     # plurals like address / addresses
    $theWord =~ s/([Xx])es$/$1/o; # plurals like box / boxes
    $theWord =~ s/([A-Za-rt-z])s$/$1/o; # others, excluding ending ss like address(es)
    return $theWord;
}

1;
