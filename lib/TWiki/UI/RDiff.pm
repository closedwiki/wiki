# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
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
# As per the GPL, removal of this notice is prohibited.

=begin twiki

---+ package TWiki::UI::RDiff

UI functions for diffing.

=cut

package TWiki::UI::RDiff;

use strict;
use TWiki;
use TWiki::Store;
use TWiki::Prefs;
use TWiki::UI;
use TWiki::Time;

use Error qw( :try );
use TWiki::UI::OopsException;

#TODO: this needs to be exposed to plugins and whoever might want to over-ride the rendering of diffs
#Hash, indexed by diffType (+,-,c,u,l.....)
#contains {colour, CssClassName}
my %format =
  (
   '+' => [ '#ccccff', 'twikiDiffAddedMarker'],
   '-' => [ '#ff9999', 'twikiDiffDeletedMarker'],
   'c' => [ '#99ff99', 'twikiDiffChangedText'],
   'u' => [ '#ffffff', 'twikiDiffUnchangedText'],
   'l' => [ '#eeeeee', 'twikiDiffLineNumberHeader']
  );

#SVEN - new design.
#main gets the info (NO MAJOR CHANGES NEEDED)
#parseDiffs reads the diffs and interprets the information into types {"+", "-", "u", "c", "l"} (add, remove, unchanged, changed, lineNumber} where line number is for diffs that skip unchanged lines (diff -u etc)
#so renderDiffs would get an array of [changeType, $oldstring, $newstring] 
#		corresponding to Algorithm::Diff's output
#renderDiffs iterates through the interpreted info and makes it into TML / HTML? (mmm)
#and can be over-ridden :)
#(now can we do this in a way that automagically can cope eith word / letter based diffs?)
#NOTE: if we do our own diffs in perl we can go straight to renderDiffs
#TODO: I'm starting to think that we should have a variable number of lines of context. more context if you are doing a 1.13 tp 1.14 diff, less when you do a show page history.
#TODO: ***URGENT*** the diff rendering dies badly when you have table cell changes and context
#TODO: ?type={history|diff} so that you can do a normal diff between r1.3 and r1.32 (rather than a history) (and when doing a history, we maybe should not expand %SEARCH...


#| Description: | twiki render a cell of data from a Diff |
#| Parameter: =$data= |  |
#| Parameter: =$topic= |  |
#| Return: =$text= | Formatted html text |
#| TODO: | this should move to Render.pm |
sub _renderCellData {
    my( $session, $data, $web, $topic ) = @_;
    if ( $data ){
        $data =~ s(^%META:TOPICPARENT.*="([^"]+).*$)
          (|*META TOPICPARENT*|$1 ||)gm;
        $data =~ s(^%META:FIELD.name="(.*?)".title="(.*?)".value="(.*?)".*$)
          (|*META FIELD $2*|$1 |$3 |)gm;
        $data =~ s(^%META:([A-Z]+).\w+="([^"]+)"(.*).%$)
          (|*META $1*|$2 |$3 |)gm;

        $data = $session->handleCommonTags( $data, $web, $topic );
        $data = $session->{renderer}->getRenderedVersion( $data, $web, $topic );
        # Match up table tags, remove comments
        if( $data =~ m/<\/?(th|td|table)\b/i ) {
            # data has <th> or <td>, need to fix ables
            my $bTable = ( $data =~ s/(<table)/$1/gois ) || 0;
            my $eTable = ( $data =~ s/(<\/table)/$1/gois ) || 0;
            while( $eTable < $bTable ) {
                $data .= CGI::end_table();
                $eTable++;
            }
            while( $bTable < $eTable ) {
                $data = CGI::start_table().$data;
                $bTable++;
            }
            unless( $bTable ) {
                $data = CGI::start_table().$data.CGI::end_table();
            }
        }
        #remove the <!--- type tag (i don't know how you would find the matching >)
        #$data =~ s/<!/&lt!/go;
    }
    return $data;
}

sub _sideBySideRow {
    my( $left, $right, $lc, $rc ) = @_;

    my $d1 = CGI::td({ bgcolor=>$format{$lc}[0],
                       class=>$format{$lc}[1],
                       valign=>'top'}, $left.'&nbsp;' );
    my $d2 = CGI::td({ bgcolor=>$format{$rc}[0],
                       class=>$format{$rc}[1],
                       valign=>'top'}, $right.'&nbsp;' );
    return CGI::Tr( $d1 . $d2 );
}

#| Description: | render the Diff entry using side by side |
#| Parameter: =$diffType= | {+,-,u,c,l} denotes the patch operation |
#| Parameter: =$left= | the text blob before the opteration |
#| Parameter: =$right= | the text after the operation |
#| Return: =$result= | Formatted html text |
#| TODO: | this should move to Render.pm |
sub _renderSideBySide
{
    my ( $session, $web, $topic, $diffType, $left, $right ) = @_;
    my $result = '';

    $left = _renderCellData( $session, $left, $web, $topic );
    $right = _renderCellData( $session, $right, $web, $topic );

    if ( $diffType eq '-') {
        $result .= _sideBySideRow( $left, $right, '-', 'u' )
    } elsif ( $diffType eq "+") {
        $result .= _sideBySideRow( $left, $right, 'u', '+' )
    } elsif ( $diffType eq "u") {
        $result .= _sideBySideRow( $left, $right, 'u', 'u' )
    } elsif ( $diffType eq "c") {
        $result .= _sideBySideRow( $left, $right, 'c', 'c' )
    } elsif ( $diffType eq "l" && $left ne '' && $right ne '' ) {
        $result .= CGI::Tr({
                            bgcolor=>$format{l}[0],
                            class=>$format{l}[1],
                           },
                           CGI::th({align=>'center'},
                                   'Line: '.$left).
                           CGI::th({align=>'center'},
                                   'Line: '.$right));
    }
    return $result;
}

#| Description: | render the Diff array (no TML conversion) |
#| Parameter: =$diffType= | {+,-,u,c,l} denotes the patch operation |
#| Parameter: =$left= | the text blob before the opteration |
#| Parameter: =$right= | the text after the operation |
#| Return: =$result= | Formatted html text |
#| TODO: | this should move to Render.pm |
sub _renderDebug
{
    my ( $diffType, $left, $right ) = @_;
    my $result = '';

    #de-html-ize
    $left =~ s/&/&amp;/go;
    $left =~ s/</&lt;/go;
    $left =~ s/>/&gt;/go;
    $right =~ s/&/&amp;/go;
    $right =~ s/</&lt;/go;
    $right =~ s/>/&gt;/go;

    $result = CGI::hr().'type: '.$diffType;
    $result .= CGI::div({style=>'border: 1px dotted;'}, $left);
    $result .= CGI::div({style=>'border: 1px dotted;'}, $right);

    return $result;
}

sub _sequentialRow {
    my( $bg, $hdrcls, $bodycls, $data, $code, $char ) = @_;
    my $row = '';
    if( $char ) {
        $row = CGI::td({bgcolor=>$format{$code}[0],
                        class=>$format{$code}[1],
                        valign=>'top',
                        width=>"1%"},
                       $char.CGI::br().$char);
    }
    $row .= CGI::td({class=>"twikiDiff${bodycls}Text"}, $data);
    $row = CGI::Tr( $row );
    if( $bg ) {
        return CGI::Tr(CGI::td({bgcolor=>$bg,
                                class=>"twikiDiff${hdrcls}Header",
                                colspan=>9},
                               CGI::b( " $hdrcls: "))).$row;
    } else {
        return $row;
    }
}

#| Description: | render the Diff using old style sequential blocks |
#| Parameter: =$diffType= | {+,-,u,c,l} denotes the patch operation |
#| Parameter: =$left= | the text blob before the opteration |
#| Parameter: =$right= | the text after the operation |
#| Return: =$result= | Formatted html text |
#| TODO: | this should move to Render.pm |
sub _renderSequential
{
    my ( $session, $web, $topic, $diffType, $left, $right ) = @_;
    my $result = '';

    #note: I have made the colspan 9 to make sure that it spans all columns (thought there are only 2 now)
    if ( $diffType eq '-') {
        $result .=
          _sequentialRow( '#FFD7D7',
                          'Deleted', 'Deleted',
                          _renderCellData( $session, $left, $web, $topic ),
                          '-', '&lt;');
    } elsif ( $diffType eq '+') {
        $result .=
          _sequentialRow( '#D0FFD0',
                          'Added', 'Added',
                          _renderCellData( $session, $right, $web, $topic ),
                          '+', '&gt;' );
    } elsif ( $diffType eq 'u') {
        $result .=
          _sequentialRow( undef,
                          'Unchanged', 'Unchanged',
                          _renderCellData( $session, $right, $web, $topic ),
                          'u', '' );
    } elsif ( $diffType eq 'c') {
        $result .=
          _sequentialRow( '#D0FFD0',
                          'Changed', 'Added',
                          _renderCellData( $session, $left, $web, $topic ),
                          '-', '&lt;' );
        $result .=
          _sequentialRow( undef,
                          'Changed', 'Added',
                          _renderCellData( $session, $right, $web, $topic ),
                          '+', '&gt;' );
    } elsif ( $diffType eq 'l' && $left ne '' && $right ne '' ) {
        $result .= CGI::Tr({bgcolor=>$format{l}[0],
                            class=>'twikiDiffLineNumberHeader'},
                           CGI::th({align=>'left',
                                    colspan=>9}, 'Line: '.
                                   "$left to $right"));
    }

    return $result;
}

#| Description: | uses renderStyle to choose the rendering function to use |
#| Parameter: =$diffArray= | array generated by parseRevisionDiff |
#| Parameter: =$renderStyle= | style of rendering { debug, sequential, sidebyside} |
#| Return: =$text= | output html for one renderes revision diff |
#| TODO: | move into Render.pm |
sub _renderRevisionDiff
{
    my( $session, $web, $topic, $sdiffArray_ref, $renderStyle ) = @_;

#combine sequential array elements that are the same diffType
    my @diffArray = ();
	foreach my $ele ( @$sdiffArray_ref ) {
		if( ( @$ele[1] =~ /^\%META\:TOPICINFO/ ) || ( @$ele[2] =~ /^\%META\:TOPICINFO/ ) ) {
			# do nothing, ignore redundant topic info
			# FIXME: Intelligently remove followup lines in case META:TOPICINFO is the only change
		} elsif( ( @diffArray ) && ( @{$diffArray[$#diffArray]}[0] eq @$ele[0] ) ) {
			@{$diffArray[$#diffArray]}[1] .= "\n".@$ele[1];
			@{$diffArray[$#diffArray]}[2] .= "\n".@$ele[2];
		} else {
			push @diffArray, $ele;
		}
	}
	my $diffArray_ref = \@diffArray;


    my $result = "";
    my $data = '';
    my $diff_ref = undef;
    for my $next_ref ( @$diffArray_ref ) {
    	if (( @$next_ref[0] eq 'l' ) && ( @$next_ref[1] eq 0 ) && (@$next_ref[2] eq 0)) {
            next;
		}
		if (! $diff_ref ) {
            $diff_ref = $next_ref;
            next;
		}
		if (( @$diff_ref[0] eq '-' ) && ( @$next_ref[0] eq '+' )) {
		    $diff_ref = ['c', @$diff_ref[1], @$next_ref[2]];
            $next_ref = undef;
		}
		if ( $renderStyle eq 'sequential' ) {
		    $result .= _renderSequential( $session, $web, $topic, @$diff_ref );
		} elsif ( $renderStyle eq 'sidebyside' ) {
            $result .= CGI::Tr(CGI::td({ width=>'50%'}, ''),
                               CGI::td({ width=>'50%'}, ''));
		    $result .= _renderSideBySide( $session, $web, $topic, @$diff_ref );
		} elsif ( $renderStyle eq 'debug' ) {
		    $result .= _renderDebug( @$diff_ref );
		}
		$diff_ref = $next_ref;
	}
    #don't forget the last one ;)
    if ( $diff_ref ) {
        if ( $renderStyle eq 'sequential' ) {
            $result .= _renderSequential ( $session, $web, $topic, @$diff_ref );
        } elsif ( $renderStyle eq 'sidebyside' ) {
            $result .= CGI::Tr(CGI::td({ width=>'50%'}, ''),
                               CGI::td({ width=>'50%'}, ''));
            $result .= _renderSideBySide( $session, $web, $topic, @$diff_ref );
        } elsif ( $renderStyle eq 'debug' ) {
            $result .= _renderDebug( @$diff_ref );
        }
    }
    return CGI::table( { class => 'twikiDiffTable',
                         width => '100%',
                         cellspacing => 0 }, $result );
}

=pod

---++ StaticMethod diff( $session, $web, $topic, $query )
=diff= command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.

Renders the differences between version of a TwikiTopic
| topic | topic that we are showing the differences of |
| rev1 | the higher revision |
| rev2 | the lower revision |
| render | the rendering style {sequential, sidebyside, raw, debug} |
| type | history, diff, last} history diff, version to version, last version to previous |
| context | number of lines of context |
| skin | the skin to use to display the diff |
TODO:
   * add a {word} render style
   * move the common CGI param handling to one place
   * move defaults somewhere

=cut

sub diff {
    my $session = shift;

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};

    my $renderStyle = $query->param('render') || $session->{prefs}->getPreferencesValue( 'DIFFRENDERSTYLE' ) || 'sequential';
    my $diffType = $query->param('type') || 'diff';
    my $contextLines = $query->param('context') || $session->{prefs}->getPreferencesValue( 'DIFFCONTEXTLINES' );
    $contextLines = 3 unless defined $contextLines;
    my $skin = $session->getSkin();
    my $rev1 = $query->param( 'rev1' );
    my $rev2 = $query->param( 'rev2' );

    TWiki::UI::checkWebExists( $session, $webName, $topic );

    my $tmpl = '';
    my $diff = '';
    my $maxrev= 1;
    my $i = $maxrev;
    my $j = $maxrev;
    my $revTitle1 = '';
    my $revTitle2 = '';
    my $revInfo = '';
    my $isMultipleDiff = 0;
    my( $before, $difftmpl, $after, $tail);
    my $topicExists;

    $tmpl = $session->{templates}->readTemplate( 'rdiff', $skin );
    $tmpl =~ s/\%META{.*?}\%//go;  # remove %META{'parent'}%

    ( $before, $difftmpl, $after, $tail) = split( /%REPEAT%/, $tmpl);

    $topicExists = $session->{store}->topicExists( $webName, $topic );
    if( $topicExists ) {
        $maxrev = $session->{store}->getRevisionNumber( $webName, $topic );
        $maxrev =~ s/r?1\.//go;  # cut 'r' and major

        $rev1 = $session->{store}->cleanUpRevID( $rev1 );
        if( $rev1 < 1 )       { $rev1 = $maxrev; }
        if( $rev1 > $maxrev ) { $rev1 = $maxrev; }

        $rev2 = $session->{store}->cleanUpRevID( $rev2 );
        if( $rev2 < 1 )       { $rev2 = 1; }
        if( $rev2 > $maxrev ) { $rev2 = $maxrev; }
        if ( $diffType eq 'last' ) {
            $rev1 = $maxrev;
            $rev2 = $maxrev-1;
        }
        $revTitle1 = $rev1;
        if( $rev1 != $rev2 ) {
            $revTitle2 = $rev2;
        }
    } else {
        $rev1 = 1;
        $rev2 = 1;
    }

    # format 'before' part
    $before =~ s/%REVTITLE1%/$revTitle1/go;
    $before =~ s/%REVTITLE2%/$revTitle2/go;
    $before = $session->handleCommonTags( $before, $webName, $topic );
    $before = $session->{renderer}->getRenderedVersion( $before, $webName, $topic );
    $before =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;   # remove <nop> and <noautolink> tags
    my $page = $before;

    # do one or more diffs
    $difftmpl = $session->handleCommonTags( $difftmpl, $webName, $topic );
    if( $topicExists ) {
        my $r1 = $rev1;
        my $r2 = $rev2;
        my $rInfo = '';
        if (( $diffType eq 'history' ) && ( $r1 > $r2 + 1)) {
            $r2 = $r1 - 1;
            $isMultipleDiff = 1;
        }
        do {
            $diff = $difftmpl;
            $diff =~ s/%REVTITLE1%/$r1/go;
            $rInfo = $session->{renderer}->renderRevisionInfo( $webName, $topic, $r1, "\$date - \$wikiusername" );
            # eliminate white space to prevent wrap around in HR table:
            $rInfo =~ s/\s+/&nbsp;/g;
            $diff =~ s/%REVINFO1%/$rInfo/go;
            my $diffArrayRef = $session->{store}->getRevisionDiff( $webName, $topic, $r2, $r1, $contextLines );
            # $text = $session->{store}->getRevisionDiff( $webName, $topic, $r2, $r1, $contextLines );
            # if ( $renderStyle eq "raw" ) {
            #     $text = CGI::code($text);
            # } else {
            #    my $diffArray = parseRevisionDiff( $text );
            my $text = _renderRevisionDiff( $session, $webName, $topic, $diffArrayRef, $renderStyle );
            #            }
            $diff =~ s/%TEXT%/$text/go;
            $diff =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;   # remove <nop> and <noautolink> tags
            $page .= $diff;
            $r1 = $r1 - 1;
            $r2 = $r2 - 1;
            if( $r2 < 1 ) { $r2 = 1; }
        } while( ( $diffType eq 'history') && (( $r1 > $rev2 ) || ( $r1 == 1 )) );

    } else {
        $diff = $difftmpl;
        $diff =~ s/%REVTITLE1%/$revTitle1/go;
        $diff =~ s/%REVTITLE2%/$revTitle2/go;
        $diff =~ s/%TEXT%//go;
        $diff =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;   # remove <nop> and <noautolink> tags
        $page .= $diff;
    }

    if( $TWiki::cfg{Log}{rdiff} ) {
        # write log entry
        $session->writeLog( 'rdiff', $webName.'.'.$topic, "$rev1 $rev2" );
    }

    # format 'after' part
    $i = $maxrev;
    $j = $maxrev;
    my $revisions = '';
    my $breakRev = 0;
    if( ( $TWiki::cfg{NumberOfRevisions} > 0 ) && ( $TWiki::cfg{NumberOfRevisions} < $maxrev ) ) {
        $breakRev = $maxrev - $TWiki::cfg{NumberOfRevisions} + 1;
    }

    while( $i > 0 ) {
        $revisions .= ' | '.
          CGI::a( { href=>$session->getScriptUrl($webName, $topic,'view',
                                                 rev => $i ),
                    rel => 'nofollow' }, $i);
        if( $i != 1 ) {
            if( $i == $breakRev ) {
                $i = 1;
            } else {
                if( ( $i == $rev1 ) && ( !$isMultipleDiff ) ) {
                    $revisions .= ' | &gt;';
                } else {
                    $j = $i - 1;
                    $revisions .= ' | '.
                      CGI::a( { href=>$session->getScriptUrl( $webName, $topic,
                                                              'rdiff',
                                                              rev1 => $i,
                                                              rev2 => $j ),
                                rel => 'nofollow' },
                              '&gt;');
                }
            }
        }
        $i--;
    }

    $i = $rev1;
    my $tailResult = '';
    my $revTitle   = '';
    while( $i >= $rev2) {
        $revTitle = CGI::a( { href=>$session->getScriptUrl($webName, $topic,
                                                           'view',
                                                           rev => $i ),
                              rel => 'nofollow' },
                            $i);
        $revInfo = $session->{renderer}->renderRevisionInfo( $webName, $topic, $i, undef );
        $tailResult .= $tail;
        $tailResult =~ s/%REVTITLE%/$revTitle/go;
        $tailResult =~ s/%REVINFO%/$revInfo/go;
        $i--;
    }
    $after =~ s/%TAIL%/$tailResult/go;
    $after =~ s/%REVISIONS%/$revisions/go;
    $after =~ s/%CURRREV%/$rev1/go;
    $after =~ s/%MAXREV%/$maxrev/go;

    $after = $session->handleCommonTags( $after, $webName, $topic );
    $after = $session->{renderer}->getRenderedVersion( $after, $webName, $topic );
    $page .= $after;

    $session->writeCompletePage( $page );
}

1;
