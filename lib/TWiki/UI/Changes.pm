# TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2004 Peter Thoeny, peter@thoeny.com
#
# Based on parts of Ward Cunninghams original Wiki and JosWiki.
# Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
# Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated
# Copyright (C) 1999-2003 Peter Thoeny, peter@thoeny.com
#
# For licensing info read license.txt file in the TWiki root.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.ai.mit.edu/copyleft/gpl.html 

package TWiki::UI::Changes;

use strict;

use TWiki;
use TWiki::Prefs;
use TWiki::Store;
use TWiki::UI;
use TWiki::Merge;

# Command handler for changes command
sub changes {
    my $session = shift;

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};

    TWiki::UI::checkWebExists( $session, $webName, $topic );

    my $skin = $session->getSkin();

    my $text = $session->{templates}->readTemplate( "changes", $skin );
    my $changes= $session->{store}->readMetaData( $webName, "changes" );

    my $summary = "";

    $text = $session->handleCommonTags( $text, $topic );
    $text = $session->{renderer}->getRenderedVersion( $text );
    $text =~ s/\%META{.*?}\%//go;  # remove %META{"parent"}%

    my( $page, $eachChange, $after) = split( /%REPEAT%/, $text );

    my %done = ();
    foreach my $change ( reverse split( /\r?\n/, $changes ) ) {
        my( $changedTopic, $login, $time, $rev ) = split( /\t/, $change );
        unless( $done{$changedTopic} ) {
            next unless $session->{store}->topicExists( $webName, $changedTopic );
            my $thisChange = $eachChange;
            $thisChange =~ s/%TOPICNAME%/$changedTopic/go;
            my $wikiuser = "";
            my $u = $session->{users}->findUser( $login );
            $wikiuser = $u->webDotWikiName() if $u;
            $thisChange =~ s/%AUTHOR%/$wikiuser/go;
            $time = TWiki::formatTime( $time );
            $rev = 1 unless $rev;
            my $srev = $rev;
            if( $rev == 1 ) {
                $srev = "<span class=\"twikiNew\"><b>NEW</b></span>";
            }
            $thisChange =~ s/%TIME%/$time/go;
            $thisChange =~ s/%REVISION%/$rev/go;
            $thisChange = $session->{renderer}->getRenderedVersion( $thisChange );

            my( $meta, $text ) = $session->{store}->readTopic
              ( $query->{user}, $webName, $changedTopic, undef );
            if( $rev > 1 ) {
                # there was a prior version. Diff it.
                my( $ometa, $otext ) =
                  $session->{store}->readTopic
                    ( $query->{user}, $webName, $changedTopic, $rev - 1 );
                $text = $session->{renderer}->TML2PlainText
                  ( $text, $webName, $changedTopic, "nonop" );
                $otext = $session->{renderer}->TML2PlainText
                  ( $otext, $webName, $changedTopic, "nonop" );
                $summary = TWiki::Merge::merge( $otext, $text, qr/\s+/ );
                if( length( $summary ) > 162 ) {
                    $text = $summary;
                    $summary = "";
                    foreach my $c ( split( /(<\/?(?:ins|del)>)/i, $text )) {
                        if( $c !~ /<\/?(ins|del)>/i ) {
                            $c =~ s/^(.{12}).*(.{12})$/$1...$2/s;
                        }
                        $summary .= $c;
                    }
                }
            } else {
                # only one version, show summary
                $summary = $session->{renderer}->makeTopicSummary
                  ( $text, $changedTopic, $webName );
            }
            $thisChange =~ s/%TEXTHEAD%/$summary/go;

            $page .= $thisChange;
            $done{$changedTopic} = 1;
        }
    }
    if( $TWiki::doLogTopicChanges ) {
        # write log entry
        $session->writeLog( "changes", $webName, "" );
    }
    $page .= $after;

    # remove <nop> and <noautolink> tags
    $page =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;

    $session->writeCompletePage( $page );
}

1;
