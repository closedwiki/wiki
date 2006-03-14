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
# 15-Dec-2005 - SteffenPoulsen
#       - improved handling of the special case [[Main.ABBR][Some desc with a found ABBRTWO]]
#       - is now ignored correctly, instead of breaking the link
# 14-Mar-2006 - MichaeDaum
#       - repsects <noautolink> ... </noautolink> blocks as well as the
#         NOAUTOLINK preference flag

package TWiki::Plugins::FindElsewherePlugin;

use vars qw(
            $web $topic $user $installWeb $VERSION $RELEASE
            $plural2SingularEnabled
            $wnre
            $wwre
            $manre
            $abbre
	    $noAutolink
           );
use vars qw( %TWikiCompatibility );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between FindElsewherePlugin and Plugins.pm" );
        return 0;
    }

    my $pp = 'FINDELSEWHEREPLUGIN_';
    $lookElsewhereDisabled =
      TWiki::Func::getPreferencesFlag( 'DISABLELOOKELSEWHERE' ) ||
          TWiki::Func::getPreferencesFlag( $pp.'DISABLELOOKELSEWHERE' );

    $otherWebs =
      TWiki::Func::getPreferencesValue( $pp.'LOOKELSEWHEREWEBS' ) || '';
    @webList = split( /[\,\s]+/, $otherWebs );

    $plural2SingularEnabled =
      !TWiki::Func::getPreferencesFlag( 'DISABLEPLURALTOSINGULAR' ) &&
        !TWiki::Func::getPreferencesFlag( $pp.'DISABLEPLURALTOSINGULAR' );

    $wnre = TWiki::Func::getRegularExpression('webNameRegex');
    $wwre = TWiki::Func::getRegularExpression('wikiWordRegex');
    $manre = TWiki::Func::getRegularExpression('mixedAlphaNum');
    $abbre = TWiki::Func::getRegularExpression('abbrevRegex');

    $noAutolink = TWiki::Func::getPreferencesFlag('NOAUTOLINK');
    # Plugin correctly initialized
    return 1;
}

sub preRenderingHandler {
    #my ( $text, \%map ) = @_;
    # SMELL: skips PRE blocks
    _handle( @_ );
}

$TWikiCompatibility{startRenderingHandler} = 1.1;
sub startRenderingHandler {
    #my ( $text, \%map ) = @_;
    # SMELL: why is there another call th _handle() here
    _handle( @_ );
}

sub _handle {
    return if $lookElsewhereDisabled && $noAutolink;

    # Find instances of WikiWords not in this web, but in the otherWeb(s)
    # If the WikiWord is found in theWeb, put the word back unchanged
    # If the WikiWord is found in the otherWeb, link to it via
    # [[otherWeb.WikiWord]]
    # If it isn't found there either, put the word back unchnaged

    my $text = $_[0];
    my $removed = {};

    # SMELL: taking out blocks should be in Func.pm
    my $renderer = $TWiki::Plugins::SESSION->{renderer};
    $text = $renderer->takeOutBlocks( $text, 'noautolink', $removed );

    # Match WikiWordAsWebName.WikiWord, WikiWords, [[wiki words]] and
    # WIK IWO RDS
    $text =~ s/(^|[\s\(])(\[\[$wnre\.($wwre|$abbre)\]\[[$manre\s]+\]\]|\[\[[$manre\s]+\]\[[$manre\s]+\]\]|$wnre\.$wwre|$wwre|\[\[[$manre\s]+\]\]|$abbre)/$1._findTopicElsewhere($2)/geo;

    $renderer->putBackBlocks( \$text, $removed, 'noautolink' );
    $_[0] = $text;
}

sub _makeTopicLink {
    #my($otherWeb, $theTopic) = @_;
    return "";
}

sub _findTopicElsewhere {
    my $link = shift;

    # If we got ourselves a WikiWordAsWebName.WikiWord, we're done - return untouched info
    if ($link =~ /$wnre\.$wwre/o) {
        return $link;
    }

    # If we got ourselves an explicit [[SOMETHING][SOMETHING]] link, let's leave it untouched
    if ($link =~ /\[\[[$manre\s]+\]\[[$manre\s]+\]\]/o) {
        return $link;
    }

    # preserve link style formatting
    my $original = $link;

    # Turn spaced-out names into WikiWords - upper case first letter of
    # whole link, and first of each word.
    $link =~ s/^(.)/\U$1/o;
    $link =~ s/\s(\w)/\U$1/go;
    $link =~ s/\[\[(\w)(.*)\]\]/\u$1$2/o;

    my $text = '';

    my @topicLinks;

    # Look in the current web
    my $exist = TWiki::Func::topicExists( $web, $link );
    return $original if $exist;

    if( $plural2SingularEnabled && $link =~ /s$/ ) {
        my $linkSingular = _makeSingular( $link );
        if( TWiki::Func::topicExists( $web, $linkSingular ) ) {
            # $linkSingular was found in $web.
            return $original; # leave it as we found it
        }
    }

    # Look in the other webs, return when found
    foreach my $otherWeb ( @webList ) {

        # If the $link is a reference to a the name of
        # otherWeb, point at otherWeb.WebHome
        if( $otherWeb eq $link ) {
            return "[[$otherWeb.WebHome][$otherWeb]]";
        }

        my $exist = TWiki::Func::topicExists( $otherWeb, $link );
        if( $exist ) {
            # $link was found in $otherWeb.
            push(@topicLinks, [ $otherWeb, $link ]);
        } elsif ( ( $plural2SingularEnabled ) && ( $link =~ /s$/ ) ) {
            my $linkSingular = _makeSingular( $link );
            if( TWiki::Func::topicExists( $otherWeb, $linkSingular )) {
                # $linkSingular was found in $otherWeb.
                push(@topicLinks, [ $otherWeb, $link ]);
            }
        }
    }

    if( scalar @topicLinks > 0 ) {
        # If link text [[was in this form]] then <em> it
        $original =~ s/\[\[(.*)\]\]/<em>$1<\/em>/g;
        # Prepend WikiWords with <nop>, preventing double links
        $original =~ s/([\s\(])($wwre)/$1<nop>$2/go;
        if( scalar(@topicLinks) > 1 ) {
            return "<nop>$original<sup>(".
              join( ',', map { "[[$_->[0].$_->[1]][$_->[0]]]" }
                      @topicLinks ).")</sup>" ;
        } else {
            my $l = $topicLinks[0];
            return "[[$l->[0].$l->[1]][$l->[1]]]";
        }
    #} else {
    #    print STDERR "OK $link (",join(',',@webList),"\n";
    }
    # $link is not in any of these webs
    return $original;
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
