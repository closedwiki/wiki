# TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2004 Peter Thoeny, peter@thoeny.com
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
# http://www.gnu.org/copyleft/gpl.html
=begin twiki

---+ TWiki::UI::RDiff
UI functions for diffing.

=cut

package TWiki::UI::RDiff;

use strict;
use TWiki;
use TWiki::Store;
use TWiki::Prefs;
use TWiki::UI;
use Error qw( :try );
use TWiki::UI::OopsException;

#TODO: this needs to be exposed to plugins and whoever might want to over-ride the rendering of diffs
#Hash, indexed by diffType (+,-,c,u,l.....)
#contains {colour, CssClassName}
my %diffColours = ( "+" => [ "#ccccff", "twikiDiffAddedMarker"],
                    "-" => [ "#ff9999", "twikiDiffDeletedMarker"],
                    "c" => [ "#99ff99", "twikiDiffChangedText"],
                    "u" => [ "#ffffff", "twikiDiffUnchangedText"],
                    "l" => [ "#eeeeee", "twikiDiffLineNumberHeader"] );

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


# =========================
=pod

---+++ _renderCellData( $data, $topic ) ==> $data

| Description: | twiki render a cell of data from a Diff |
| Parameter: =$data= |  |
| Parameter: =$topic= |  |
| Return: =$text= | Formatted html text |
| TODO: | this should move to Render.pm |
| TODO: | need to fix unmatched <p>, <div> and.... |

=cut
# -------------------------
sub _renderCellData {
    my( $session, $data, $topic ) = @_;
    if (( $data ) && ( $data ne "" )) {
        #improve meta-data diff's - Main.PeterKlausner
        if( $data =~ /%META/ ) {
            $data =~ s(^%META:TOPICPARENT.*="([^"]+).*$)
              (|*META TOPICPARENT*|$1 ||)gm;
            $data =~ s(^%META:FIELD.name="(.*?)".title="(.*?)".value="(.*?)".*$)
              (|*META FIELD $2*|$1 |$3 |)gm;
            $data =~ s(^%META:([A-Z]+).\w+="([^"]+)"(.*).%$)
              (|*META $1*|$2 |$3 |)gm;
        }
        $data = $session->handleCommonTags( $data, $topic );
        $data = $session->{renderer}->getRenderedVersion( $data );
        if( $data =~ m/<\/?(th|td|table)/i ) {
            # data has <th> or <td>, need to fix <table>
            my $bTable = ( $data =~ s/(<table)/$1/gois ) || 0;
            my $eTable = ( $data =~ s/(<\/table)/$1/gois ) || 0;
            my $i = 0;
            if( $bTable > $eTable ) {
                for( $i = $eTable; $i < $bTable; $i++ ) {
                    $data .= "</table>";
                }
            } elsif( $bTable < $eTable ) {
                for( $i = $bTable; $i < $eTable; $i++ ) {
                    $data = "\n<table>$data";
                }
            } elsif( ( $bTable == 0 ) && ( $eTable == 0 ) ) {
                $data = "\n<table>$data\n</table>";
            }
        }
        #remove the <!--- type tag (i don't know how you would find the matching >)
        $data =~ s/<!/&lt!/go;
    }
    return $data;
}

# =========================
=pod

---+++ _renderSideBySide( $session, $topic, $diffType, $left, $right ) ==> $result

| Description: | render the Diff entry using side by side |
| Parameter: =$diffType= | {+,-,u,c,l} denotes the patch operation |
| Parameter: =$left= | the text blob before the opteration |
| Parameter: =$right= | the text after the operation |
| Return: =$result= | Formatted html text |
| TODO: | this should move to Render.pm |

=cut
# -------------------------
sub _renderSideBySide
{
    my ( $session, $topic, $diffType, $left, $right ) = @_;
    my $result = "";

    $left = _renderCellData( $session, $left, $topic );
    $right = _renderCellData( $session, $right, $topic );

    if ( $diffType eq "-") {
        $result .= qq(<tr><td bgcolor="$diffColours{"-"}[0]" class="$diffColours{"-"}[1]" valign="top">$left&nbsp;</td>);
        $result .= qq(<td bgcolor="$diffColours{"u"}[0]" class="$diffColours{"u"}[1]" valign="top">$right&nbsp;</td></tr>\n);
    } elsif ( $diffType eq "+") {
        $result .= qq(<tr><td bgcolor="$diffColours{"u"}[0]" class="$diffColours{"u"}[1]" valign="top">$left&nbsp;</td>);
        $result .= qq(<td bgcolor="$diffColours{"+"}[0]" class="$diffColours{"+"}[1]" valign="top">$right&nbsp;</td></tr>\n);
    } elsif ( $diffType eq "u") {
        $result .= qq(<tr><td bgcolor="$diffColours{"u"}[0]" class="$diffColours{"u"}[1]" valign="top">$left&nbsp;</td>);
        $result .= qq(<td bgcolor="$diffColours{"u"}[0]" class="$diffColours{"u"}[1]" valign="top">$right&nbsp;</td></tr>\n);
    } elsif ( $diffType eq "c") {
        $result .= qq(<tr><td bgcolor="$diffColours{"c"}[0]" class="$diffColours{"c"}[1]" valign="top">$left&nbsp;</td>);
        $result .= qq(<td bgcolor="$diffColours{"c"}[0]" class="$diffColours{"c"}[1]" valign="top">$right&nbsp;</td></tr>\n);
    } elsif ( $diffType eq "l") {
        if (( $left ne "" ) && ($right ne "" )) {
            $result .= qq(<tr bgcolor="$diffColours{"l"}[0]" class="$diffColours{"l"}[1]"><th align="center">Line: $left</th><th align="center">Line: $right</th></tr>\n);
        }
    }
    
    return $result;
}

# =========================
=pod

---+++ renderDebug( $diffType, $left, $right ) ==> $result

| Description: | render the Diff array (no TML conversion) |
| Parameter: =$diffType= | {+,-,u,c,l} denotes the patch operation |
| Parameter: =$left= | the text blob before the opteration |
| Parameter: =$right= | the text after the operation |
| Return: =$result= | Formatted html text |
| TODO: | this should move to Render.pm |

=cut
# -------------------------
sub renderDebug
{
    my ( $diffType, $left, $right ) = @_;
    my $result = "";

    #de-html-ize
    $left =~ s/</&lt;/go;
    $right =~ s/</&lt;/go;
    $left =~ s/>/&gt;/go;
    $right =~ s/>/&gt;/go;

    $result = "<hr>type: $diffType\n";
    $result .= "<div style=\"border: 1px dotted;\">$left</div>\n";
    $result .= "<div style=\"border: 1px dotted;\">$right</div>\n";

    return $result;
}


# =========================
=pod

---+++ _renderSequential( $session, $topic, $diffType, $left, $right ) ==> $result

| Description: | render the Diff using old style sequential blocks |
| Parameter: =$diffType= | {+,-,u,c,l} denotes the patch operation |
| Parameter: =$left= | the text blob before the opteration |
| Parameter: =$right= | the text after the operation |
| Return: =$result= | Formatted html text |
| TODO: | this should move to Render.pm |

=cut
# -------------------------
sub _renderSequential
{
    my ( $session, $topic, $diffType, $left, $right ) = @_;
    my $result = "";

    #note: I have made the colspan 9 to make sure that it spans all columns (thought there are only 2 now)
    if ( $diffType eq "-") {
        $result .= qq(<tr><td bgcolor="#FFD7D7" class="twikiDiffDeletedHeader" colspan ="9"><b> Deleted: </b>\n</td></tr>\n);
        $result .= qq(<tr><td bgcolor="$diffColours{"-"}[0]" class="$diffColours{"-"}[1]" valign="top" width="1%">&lt;<br />&lt;</td>\n);
        $result .= qq(<td class="twikiDiffDeletedText">\n);
        $result .= _renderCellData( $session, $left, $topic );
        $result .= qq(\n</td></tr>\n);
    } elsif ( $diffType eq "+") {
        $result .= qq(<tr><td bgcolor="#D0FFD0" class="twikiDiffAddedHeader" colspan ="9"><b> Added:   </b>\n</td></tr>\n);
        $result .= qq(<tr><td bgcolor="$diffColours{"+"}[0]" class="$diffColours{"+"}[1]" valign="top" width="1%">&gt;<br />&gt;</td>\n);
        $result .= qq(<td class="twikiDiffAddedText">\n);
        $result .= _renderCellData( $session, $right, $topic );
        $result .= qq(\n</td></tr>\n);
    } elsif ( $diffType eq "u") {
        $result .= qq(<tr><td valign="top" bgcolor="$diffColours{"u"}[0]" class="$diffColours{"u"}[1]" width="1%"><br /></td>\n);
        $result .= qq(<td class="twikiDiffUnchangedText">\n);
        $result .= _renderCellData( $session, $right, $topic );
        $result .= qq(\n</td></tr>\n);
    } elsif ( $diffType eq "c") {
        $result .= qq(<tr><td bgcolor="#D0FFD0" class="twikiDiffChangedHeader" colspan ="9"><b> Changed: </b></td></tr>\n);
        $result .= qq(<tr><td bgcolor="$diffColours{"-"}[0]" class="$diffColours{"-"}[1]" valign="top" width="1%">&lt;<br />&lt;</td>\n);
        $result .= qq(<td class="twikiDiffDeletedText">\n);
        $result .= _renderCellData( $session, $left, $topic );
        $result .= qq(\n</td></tr>\n);
        $result .= qq(<tr><td bgcolor="$diffColours{"+"}[0]" class="$diffColours{"+"}[1]" valign="top" width="1%">&gt;<br />&gt;</td>\n);
        $result .= qq(<td class="twikiDiffAddedText">\n);
        $result .= _renderCellData( $session, $right, $topic );
        $result .= qq(\n</td></tr>\n);
    } elsif ( $diffType eq "l") {
        if (( $left ne "" ) && ($right ne "" )) {
            $result .= qq(<tr bgcolor="$diffColours{"l"}[0]" class="twikiDiffLineNumberHeader"><th align="left" colspan="9">Line: $left to $right</th></tr>\n);
        }
    }

    return $result;
}

# =========================
=pod

---+++ _renderRevisionDiff( $session, $topic, $diffArray_ref, $renderStyle ) ==> $text

| Description: | uses renderStyle to choose the rendering function to use |
| Parameter: =$diffArray= | array generated by parseRevisionDiff |
| Parameter: =$renderStyle= | style of rendering { debug, sequential, sidebyside} |
| Return: =$text= | output html for one renderes revision diff |
| TODO: | move into Render.pm |

=cut
# -------------------------
sub _renderRevisionDiff
{
    my( $session, $topic, $sdiffArray_ref, $renderStyle ) = @_;

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

    my $result = "<table class=\"twikiDiffTable\" width=\"100%\" cellspacing=\"0\">\n";
    my $data = "";
    my $diff_ref = undef;
    for my $next_ref ( @$diffArray_ref ) {
    	if (( @$next_ref[0] eq "l" ) && ( @$next_ref[1] eq 0 ) && (@$next_ref[2] eq 0)) {
	    next;
		}
		if (! $diff_ref ) {
		   $diff_ref = $next_ref;
		   next;
		}
		if (( @$diff_ref[0] eq "-" ) && ( @$next_ref[0] eq "+" )) {
		    $diff_ref = ["c", @$diff_ref[1], @$next_ref[2]];
    	        $next_ref = undef;
		}
		if ( $renderStyle eq "sequential" ) {
		    $result .= _renderSequential ( $session, $topic, @$diff_ref );
		} elsif ( $renderStyle eq "sidebyside" ) {
    		    $result .= "<tr><td width=\"50%\"></td><td width=\"50%\"></td></tr>\n";
		    $result .= _renderSideBySide ( $session, $topic, @$diff_ref );
		} elsif ( $renderStyle eq "debug" ) {
		    $result .= renderDebug ( @$diff_ref );
		}
		$diff_ref = $next_ref;
	}
#don't forget the last one ;)
   if ( $diff_ref ) {
	if ( $renderStyle eq "sequential" ) {
	    $result .= _renderSequential ( $session, $topic, @$diff_ref );
	} elsif ( $renderStyle eq "sidebyside" ) {
    	    $result .= "<tr><td width=\"50%\"></td><td width=\"50%\"></td></tr>\n";
	    $result .= _renderSideBySide ( $session, $topic, @$diff_ref );
	} elsif ( $renderStyle eq "debug" ) {
	    $result .= renderDebug ( @$diff_ref );
	}
    }
    return "$result\n<\/table>";
}

# =========================
=pod

---+++ getRevInfo( $session, $web, $rev, $topic, $short ) ==> $revInfo

| Description: | gets a displayable date and user string |
| Parameter: =$web= | topic webname |
| Parameter: =$rev= | revision number of the topic |
| Parameter: =$topic= | topic name |
| Parameter: =$short= | use a shortened version of the date string |
| Return: =$text= | date - user |
| TODO: | move to Render.pm |

=cut
# -------------------------
sub getRevInfo
{
    my( $session, $web, $rev, $topic, $short ) = @_;

    my( $date, $user ) = $session->{store}->getRevisionInfo( $web, $topic, $rev);
    my $wikiname =
      $session->{renderer}->getRenderedVersion( $user->wikiName() );
	
    if ( $short ) {
	    $date = TWiki::formatTime( $date, "\$day \$month \$year" );
        # eliminate white space to prevent wrap around in HR table:
        $date =~ s/ /\&nbsp\;/go;
    } else {
        $date = TWiki::formatTime( $date );
	}

    my $revInfo = "$date - $wikiname";
    $revInfo =~ s/[\n\r]*//go;
    return $revInfo;
}


# =========================
=pod

---++ diff( $web, $topic, $query )

| Description: | CgiScript to render the differences between version of a TwikiTopic |
| Parameter: param("topic") | topic that we are showing the differences of |
| Parameter: param( "rev1" ) | the higher revision |
| Parameter: param( "rev2" ) | the lower revision |
| Parameter: param('render') | the rendering style {sequential, sidebyside, raw, debug} |
| Parameter: param( 'type' ) | {history, diff, last} history diff, version to version, last version to previous |
| Parameter: param( 'context' ) | number of lines of context |
| TODO: | add a {word} render style |
| Parameter: param( "skin" ) | the skin to use to display the diff |
| TODO: | move the common CGI param handling to one place |
| TODO: | move defaults somewhere |
| Return: | none |

=cut

sub diff {
    my $session = shift;

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};

    my $renderStyle = $query->param('render');
    $renderStyle = $session->{prefs}->getPreferencesValue( "DIFFRENDERSTYLE" ) unless ( $renderStyle );
    my $diffType = $query->param('type');
    my $contextLines = $query->param('context');
    $contextLines = $session->{prefs}->getPreferencesValue( "DIFFCONTEXTLINES" ) unless ( $contextLines );
    my $skin = $session->getSkin();
    my $rev1 = $query->param( "rev1" );
    my $rev2 = $query->param( "rev2" );

    $renderStyle = "sequential" if ( ! $renderStyle );
    $diffType = "history" if ( ! $diffType );
    $contextLines = 3 if ( ! $contextLines );

    TWiki::UI::checkWebExists( $session, $webName, $topic );

    my $tmpl = "";
    my $diff = "";
    my $maxrev= 1;
    my $i = $maxrev;
    my $j = $maxrev;
    my $revTitle1 = "";
    my $revTitle2 = "";
    my $revInfo1 = "";
    my $revInfo2 = "";
    my $isMultipleDiff = 0;
    my $scriptUrlPath = $session->{scriptUrlPath};
    my( $before, $difftmpl, $after);
    my $topicExists;

    $tmpl = $session->{templates}->readTemplate( "rdiff", $skin );
    $tmpl =~ s/\%META{.*?}\%//go;  # remove %META{"parent"}%

    ( $before, $difftmpl, $after) = split( /%REPEAT%/, $tmpl);

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
        if ( $diffType eq "last" ) {
            $rev1 = $maxrev;
            $rev2 = $maxrev-1;
        }
        $revTitle1 = $rev1;
        $revInfo1 = getRevInfo( $session, $webName, $rev1, $topic );
        if( $rev1 != $rev2 ) {
            $revTitle2 = $rev2;
            $revInfo2 = getRevInfo( $session, $webName, $rev2, $topic );
        }
    } else {
        $rev1 = 1;
        $rev2 = 1;
    }

    # format "before" part
    $before =~ s/%REVTITLE1%/$revTitle1/go;
    $before =~ s/%REVTITLE2%/$revTitle2/go;
    $before = $session->handleCommonTags( $before, $topic );
    $before = $session->{renderer}->getRenderedVersion( $before );
    $before =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;   # remove <nop> and <noautolink> tags
    my $page = $before;

    # do one or more diffs
    $difftmpl = $session->handleCommonTags( $difftmpl, $topic );
    if( $topicExists ) {
        my $r1 = $rev1;
        my $r2 = $rev2;
        my $rInfo = "";
        if (( $diffType eq "history" ) && ( $r1 > $r2 + 1)) {
            $r2 = $r1 - 1;
            $isMultipleDiff = 1;
        }
        do {
            $diff = $difftmpl;
            $diff =~ s/%REVTITLE1%/r1\.$r1/go;
            $rInfo = getRevInfo( $session, $webName, $r1, $topic, 1 );
            $diff =~ s/%REVINFO1%/$rInfo/go;
            my $diffArrayRef = $session->{store}->getRevisionDiff( $webName, $topic, $r2, $r1, $contextLines );
            # $text = $session->{store}->getRevisionDiff( $webName, $topic, $r2, $r1, $contextLines );
            # if ( $renderStyle eq "raw" ) {
            #     $text = "\n<code>\n$text\n</code>\n";
            # } else {
            #    my $diffArray = parseRevisionDiff( $text );
            my $text = _renderRevisionDiff( $session, $topic, $diffArrayRef, $renderStyle );
            #            }
            $diff =~ s/%TEXT%/$text/go;
            $diff =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;   # remove <nop> and <noautolink> tags
            $page .= $diff;
            $r1 = $r1 - 1;
            $r2 = $r2 - 1;
            if( $r2 < 1 ) { $r2 = 1; }
        } while( ( $diffType eq "history") && (( $r1 > $rev2 ) || ( $r1 == 1 )) );
        
    } else {
        $diff = $difftmpl;
        $diff =~ s/%REVTITLE1%/$revTitle1/go;
        $diff =~ s/%REVTITLE2%/$revTitle2/go;
        $diff =~ s/%TEXT%//go;
        $diff =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;   # remove <nop> and <noautolink> tags
        $page .= $diff;
    }
    
    if( $TWiki::doLogTopicRdiff ) {
        # write log entry
        $session->writeLog( "rdiff", "$webName.$topic", "$rev1 $rev2" );
    }
    
    # format "after" part
    $i = $maxrev;
    $j = $maxrev;
    my $revisions = "";
    my $breakRev = 0;
    if( ( $TWiki::numberOfRevisions > 0 ) && ( $TWiki::numberOfRevisions < $maxrev ) ) {
        $breakRev = $maxrev - $TWiki::numberOfRevisions + 1;
    }
    
    while( $i > 0 ) {
        $revisions .= " | <a href=\"$scriptUrlPath/view%SCRIPTSUFFIX%/%WEB%/%TOPIC%?rev=$i\">$i</a>";
        if( $i != 1 ) {
            if( $i == $breakRev ) {
                # Now obsolete because of 'More' link
                # $revisions = "$revisions | <a href=\"$scriptUrlPath/oops%SCRIPTSUFFIX%/%WEB%/%TOPIC%?template=oopsrev&amp;param1=$maxrev\">&gt;...</a>";
                $i = 1;
                
            } else {
                if( ( $i == $rev1 ) && ( !$isMultipleDiff ) ) {
                    $revisions .= " | &gt;";
                } else {
                    $j = $i - 1;
                    $revisions .= " | <a href=\"$scriptUrlPath/rdiff%SCRIPTSUFFIX%/%WEB%/%TOPIC%?rev1=$i&amp;rev2=$j\">&gt;</a>";
                }
            }
        }
        $i = $i - 1;
    }
    $after =~ s/%REVISIONS%/$revisions/go;
    $after =~ s/%CURRREV%/$rev1/go;
    $after =~ s/%MAXREV%/$maxrev/go;
    $after =~ s/%REVTITLE1%/$revTitle1/go;
    $after =~ s/%REVINFO1%/$revInfo1/go;
    $after =~ s/%REVTITLE2%/$revTitle2/go;
    $after =~ s/%REVINFO2%/$revInfo2/go;

    $after = $session->handleCommonTags( $after, $topic );
    $after = $session->{renderer}->getRenderedVersion( $after );
    $after =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;   # remove <nop> and <noautolink> tags

    $page .= $after;

    $session->writeCompletePage( $page );
}

1;
