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

# Command handler for changes command
sub changes {
    my $session = shift;

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};
    my $userName = $session->{userName};

    TWiki::UI::checkWebExists( $session, $webName, $topic );

    my $skin = $session->getSkin();

    my $text = $session->{templates}->readTemplate( "changes", $skin );
    my $changes= $session->{store}->readMetaData( $webName, "changes" );

    my @bar = ();
    my $foo = "";
    my %exclude = ();
    my $summary = "";
    my $time = "";
    my $frev = "";

    $text = $session->handleCommonTags( $text, $topic );
    $text = $session->{renderer}->getRenderedVersion( $text );
    $text =~ s/\%META{.*?}\%//go;  # remove %META{"parent"}%

    my $before = "";
    my $after = "";
    ( $before, $text, $after) = split( /%REPEAT%/, $text );

    $before =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;  # remove <nop> and <noautolink> tags

    my $page = $before;

    foreach( reverse split( /\n/, $changes ) ) {
        @bar = split( /\t/ );
        if( ( ! %exclude ) || ( ! $exclude{ $bar[0] } ) ) {
            next unless $session->{store}->topicExists( $webName, $bar[0] );
            $foo = $text;
            $foo =~ s/%TOPICNAME%/$bar[0]/go;
            my $wikiuser = $session->{users}->userToWikiName( $bar[1] );
            $foo =~ s/%AUTHOR%/$wikiuser/go;
            $foo =~ s/%LOCKED%//go;
            $time = &TWiki::formatTime( $bar[2] );
            $frev = "";
            if( $bar[3] ) {
                if( $bar[3] > 1 ) {
                    $frev = $bar[3];
                } else {
                    $frev = "<span class=\"twikiNew\"><b>NEW</b></span>";
                }
            }
            $foo =~ s/%TIME%/$time/go;
            $foo =~ s/%REVISION%/$frev/go;
            $foo = $session->{renderer}->getRenderedVersion( $foo );

            $summary =
              $session->{store}->readTopicRaw($session->{wikiUserName},
                                              $webName,
                                              $bar[0],
                                              undef,
                                              1
                                             );
            $summary = $session->{renderer}->makeTopicSummary( $summary,
                                                               $bar[0],
                                                               $webName );
            $foo =~ s/%TEXTHEAD%/$summary/go;
            $foo =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;   # remove <nop> and <noautolink> tags
            $page .= $foo;
            $exclude{ $bar[0] } = "1";
        }
    }
    if( $TWiki::doLogTopicChanges ) {
        # write log entry
        $session->writeLog( "changes", $webName, "" );
    }
    $after =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;   # remove <nop> and <noautolink> tags
    $page .= $after;

    $session->writeCompletePage( $page );
}

1;
