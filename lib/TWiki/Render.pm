# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
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
#
# Notes:
# - Latest version at http://twiki.org/
# - Installation instructions in $dataDir/Main/TWikiDocumentation.txt
# - Customize variables in TWiki.cfg when installing TWiki.
# - Optionally change TWiki.pm for custom extensions of rendering rules.
# - Upgrading TWiki is easy as long as you do not customize TWiki.pm.
# - Check web server error logs for errors, i.e. % tail /var/log/httpd/error_log
#
# Jun 2001 - written by John Talintyre, jet@cheerful.com

=begin twiki

---+ TWiki::Render Module

This module provides most of the actual HTML rendering code in TWiki.

=cut

package TWiki::Render;

use strict;

use vars qw($noAutoLink $linkToolTipInfo);

use TWiki qw(:renderflags %regex $TranslationToken);

# Global initialization
$noAutoLink = 0;
$linkToolTipInfo = "";

=pod

---++ sub new ()

Not yet documented.

=cut

sub new
{
   my $self = {};
   bless $self;

   $self->{listTypes} = [];
   $self->{listElements} = [];
   $noAutoLink = TWiki::Prefs::getPreferencesValue("NOAUTOLINK") || 0;
   $linkToolTipInfo = TWiki::Prefs::getPreferencesValue("LINKTOOLTIPINFO") || "";
   return $self;
}

=pod

---++ sub emitList ( $theType, $theElement, $theDepth, $theOlType  )

Render bulleted and numbered lists, including nesting.
Called from several places.

=cut

sub emitList {
    my( $self, $theType, $theElement, $theDepth, $theOlType ) = @_;

    my $result = "";
    $self->{isList} = 1;

    my $types = $self->{listTypes};
    my $elements = $self->{listElements};

    # Ordered list type
    $theOlType = "" unless( $theOlType );
    $theOlType =~ s/^(.).*/$1/;
    $theOlType = "" if( $theOlType eq "1" );

    if( @$types < $theDepth ) {
        my $firstTime = 1;
        while( @$types < $theDepth ) {
            push( @$types, $theType );
            push( @$types, $theElement );
            $result .= "<$theElement>\n" unless( $firstTime );
            if( $theOlType ) {
                $result .= "<$theType type=\"$theOlType\">\n";
            } else {
                $result .= "<$theType>\n";
            }
            $firstTime = 0;
        }

    } elsif( @$types > $theDepth ) {
        while( @$types > $theDepth ) {
            local($_) = pop @$types;
            $result .= "</$_>\n";
            local($_) = pop @$types;
            $result .= "</$_>\n";
        }
        $result .= "</$$types[$#{$elements}]>\n" if( @$elements );

    } elsif( @$elements ) {
        $result = "</$$elements[$#{$elements}]>\n";
    }

    my $lastIndex = $#{$types};
    if( ( @$types ) && ( $types->[$lastIndex] ne $theType ) ) {
        $result .= "</$types->[$lastIndex]>\n<$theType>\n";
        $types->[$lastIndex] = $theType;
        $elements->[$lastIndex] = $theElement;
    }

    return $result;
}

# ========================
=pod

---++ sub emitTR (  $thePre, $theRow, $insideTABLE  )

Not yet documented.

=cut

sub emitTR {
    my ( $self, $thePre, $theRow, $insideTABLE ) = @_;

    my $text = "";
    my $attr = "";
    my $l1 = 0;
    my $l2 = 0;
    if( $insideTABLE ) {
        $text = "$thePre<tr>";
    } else {
        $text = "$thePre<table border=\"1\" cellspacing=\"0\" cellpadding=\"1\"> <tr>";
    }
    $theRow =~ s/\t/   /g;  # change tabs to space
    $theRow =~ s/\s*$//;    # remove trailing spaces
    $theRow =~ s/(\|\|+)/$TranslationToken . length($1) . "\|"/ge;  # calc COLSPAN

    foreach( split( /\|/, $theRow ) ) {
        $attr = "";
        #AS 25-5-01 Fix to avoid matching also single columns
        if ( s/$TranslationToken([0-9]+)//o ) { 
            $attr = " colspan=\"$1\"" ;
        }
        s/^\s+$/ &nbsp; /;
        /^(\s*).*?(\s*)$/;
        $l1 = length( $1 || "" );
        $l2 = length( $2 || "" );
        if( $l1 >= 2 ) {
            if( $l2 <= 1 ) {
                $attr .= ' align="right"';
            } else {
                $attr .= ' align="center"';
            }
        }
        if( /^\s*(\*.*\*)\s*$/ ) {
            $text .= "<th$attr bgcolor=\"#99CCCC\"> $1 </th>";
        } else {
            $text .= "<td$attr> $_ </td>";
        }
    }
    $text .= "</tr>";
    return $text;
}

=pod

---++ sub internalLink (  $thePreamble, $theWeb, $theTopic, $theLinkText, $theAnchor, $doLink  )

Not yet documented.

=cut

sub internalLink {
    my( $self, $thePreamble, $theWeb, $theTopic, $theLinkText, $theAnchor, $doLink ) = @_;
    # $thePreamble is text used before the TWiki link syntax
    # $doLink is boolean: false means suppress link for non-existing pages

    # Get rid of leading/trailing spaces in topic name
    $theTopic =~ s/^\s*//;
    $theTopic =~ s/\s*$//;

    # Turn spaced-out names into WikiWords - upper case first letter of
    # whole link, and first of each word. TODO: Try to turn this off,
    # avoiding spaces being stripped elsewhere - e.g. $doPreserveSpacedOutWords 
    $theTopic =~ s/^(.)/\U$1/;
    $theTopic =~ s/\s($regex{singleMixedAlphaNumRegex})/\U$1/go;	

    # Add <nop> before WikiWord inside link text to prevent double links
    $theLinkText =~ s/([\s\(])($regex{singleUpperAlphaRegex})/$1<nop>$2/go;

    my $exist = &TWiki::Store::topicExists( $theWeb, $theTopic );
    # I18N - Only apply plural processing if site language is English, or
    # if a built-in English-language web (Main, TWiki or Plugins).  Plurals
    # apply to names ending in 's', where topic doesn't exist with plural
    # name.
    if(  ( $doPluralToSingular ) and ( $siteLang eq 'en' 
					or $theWeb eq $mainWebname
					or $theWeb eq $twikiWebname
					or $theWeb eq 'Plugins' 
				     ) 
	    and ( $theTopic =~ /s$/ ) and not ( $exist ) ) {
        # Topic name is plural in form and doesn't exist as written
        my $tmp = $theTopic;
        $tmp =~ s/ies$/y/;       # plurals like policy / policies
        $tmp =~ s/sses$/ss/;     # plurals like address / addresses
        $tmp =~ s/([Xx])es$/$1/; # plurals like box / boxes
        $tmp =~ s/([A-Za-rt-z])s$/$1/; # others, excluding ending ss like address(es)
        if( &TWiki::Store::topicExists( $theWeb, $tmp ) ) {
            $theTopic = $tmp;
            $exist = 1;
        }
    }

    my $text = $thePreamble;
    if( $exist) {
        if( $theAnchor ) {
            my $anchor = TWiki::makeAnchorName( $theAnchor );
            $text .= "<a href=\"$dispScriptUrlPath$dispViewPath"
		  .  "$scriptSuffix/$theWeb/$theTopic\#$anchor\""
                  .  &linkToolTipInfo( $theWeb, $theTopic )
                  .  ">$theLinkText<\/a>";
            return $text;
        } else {
            $text .= "<a href=\"$dispScriptUrlPath$dispViewPath"
		  .  "$scriptSuffix/$theWeb/$theTopic\""
                  .  &linkToolTipInfo( $theWeb, $theTopic )
                  .  ">$theLinkText<\/a>";
            return $text;
        }

    } elsif( $doLink ) {
        $text .= "<span style='background : $newTopicBgColor;'>"
              .  "<font color=\"$newTopicFontColor\">$theLinkText</font></span>"
              .  "<a href=\"$dispScriptUrlPath/edit$scriptSuffix/$theWeb/$theTopic?topicparent=$TWiki::webName.$TWiki::topicName\">?</a>";
        return $text;

    } else {
        $text .= $theLinkText;
        return $text;
    }
}

=pod

---++ sub linkToolTipInfo ( $theWeb, $theTopic )

Returns =title="..."= tooltip info in case LINKTOOLTIPINFO perferences variable is set. 
Warning: Slower performance if enabled.

=cut

sub linkToolTipInfo
{
    my( $theWeb, $theTopic ) = @_;
    return "" unless( $linkToolTipInfo );

    # FIXME: This is slow, it can be improved by caching topic rev info and summary
    my( $date, $user, $rev ) = TWiki::Store::getRevisionInfo( $theWeb, $theTopic );
    my $text = $linkToolTipInfo;
    $text =~ s/\$web/<nop>$theWeb/g;
    $text =~ s/\$topic/<nop>$theTopic/g;
    $text =~ s/\$rev/1.$rev/g;
    $text =~ s/\$date/&TWiki::formatTime( $date )/ge;
    $text =~ s/\$username/<nop>$user/g;                                     # "jsmith"
    $text =~ s/\$wikiname/"<nop>" . &TWiki::userToWikiName( $user, 1 )/ge;  # "JohnSmith"
    $text =~ s/\$wikiusername/"<nop>" . &TWiki::userToWikiName( $user )/ge; # "Main.JohnSmith"
    if( $text =~ /\$summary/ ) {
        my $summary = &TWiki::Store::readFileHead( "$TWiki::dataDir\/$theWeb\/$theTopic.txt", 16 );
        $summary = &TWiki::makeTopicSummary( $summary, $theTopic, $theWeb );
        $summary =~ s/[\"\']/<nop>/g;       # remove quotes (not allowed in title attribute)
        $text =~ s/\$summary/$summary/g;
    }
    return " title=\"$text\"";
}

=pod

---++ sub getRenderedVersion (  $text, $theWeb, $meta  )

Not yet documented.

=cut

sub getRenderedVersion {
    my( $self, $text, $theWeb, $meta ) = @_;
    my( $head, $result, $extraLines, $insidePRE, $insideTABLE, $insideNoAutoLink, $isList );

    return "" unless $text;  # nothing to do

    # FIXME: Get $theTopic from parameter to handle [[#anchor]] correctly
    # (fails in %INCLUDE%, %SEARCH%)
    my $theTopic = $TWiki::topicName;

    # PTh 22 Jul 2000: added $theWeb for correct handling of %INCLUDE%, %SEARCH%
    if( !$theWeb ) {
        $theWeb = $TWiki::webName;
    }

    $head = "";
    $result = "";
    $insidePRE = 0;
    $insideTABLE = 0;
    $insideNoAutoLink = 0;      # PTh 02 Feb 2001: Added Codev.DisableWikiWordLinks
    $isList = 0;

    # Initial cleanup
    $text =~ s/\r//g;
    $text =~ s/(\n?)$/\n<nop>\n/s; # clutch to enforce correct rendering at end of doc
    # Convert any occurrences of token (very unlikely - details in
    # Codev.NationalCharTokenClash)
    $text =~ s/$TranslationToken/!/go;	

    my @verbatim = ();
    $text = TWiki::takeOutVerbatim( $text, \@verbatim );
    $text =~ s/\\\n//g;  # Join lines ending in "\"

    # do not render HTML head, style sheets and scripts
    if( $text =~ m/<body[\s\>]/i ) {
        my $bodyTag = "";
        my $bodyText = "";
        ( $head, $bodyTag, $bodyText ) = split( /(<body)/i, $text, 3 );
        $text = $bodyTag . $bodyText;
    }
    
    # Wiki Plugin Hook
    &TWiki::Plugins::startRenderingHandler( $text, $theWeb, $meta );

    # $isList is tested and set by this loop and 'emitList' function
    $isList = 0;		# True when within a list

    foreach( split( /\n/, $text ) ) {

        # change state:
        m|<pre>|i  && ( $insidePRE = 1 );
        m|</pre>|i && ( $insidePRE = 0 );
        m|<noautolink>|i   && ( $insideNoAutoLink = 1 );
        m|</noautolink>|i  && ( $insideNoAutoLink = 0 );

        if( $insidePRE ) {
            # inside <PRE>

            # close list tags if any
            if( @{ $self->{listTypes} } ) {
                $result .= $self->emitList( "", "", 0 );
                $isList = 0;
            }

# Wiki Plugin Hook
            &TWiki::Plugins::insidePREHandler( $_ );

            s/(.*)/$1\n/;
            s/\t/   /g;		# Three spaces
            $result .= $_;

        } else {
          # normal state, do Wiki rendering

# Wiki Plugin Hook
          &TWiki::Plugins::outsidePREHandler( $_ );
          $extraLines = undef;   # Plugins might introduce extra lines
          do {                   # Loop over extra lines added by plugins
            $_ = $extraLines if( defined $extraLines );
            s/^(.*?)\n(.*)$/$1/s;
            $extraLines = $2;    # Save extra lines, need to parse each separately

# Blockquoted email (indented with '> ')
            s/^>(.*?)$/> <cite> $1 <\/cite><br \/>/g;

# Embedded HTML
            s/\<(\!\-\-)/$TranslationToken$1/g;  # Allow standalone "<!--"
            s/(\-\-)\>/$1$TranslationToken/g;    # Allow standalone "-->"
	    # FIXME: next 2 lines are redundant since s///g's below do same
	    # thing
            s/(\<\<+)/"&lt\;" x length($1)/ge;
            s/(\>\>+)/"&gt\;" x length($1)/ge;
            s/\<nop\>/nopTOKEN/g;  # defuse <nop> inside HTML tags
            s/\<(\S.*?)\>/$TranslationToken$1$TranslationToken/g;
            s/</&lt\;/g;
            s/>/&gt\;/g;
            s/$TranslationToken(\S.*?)$TranslationToken/\<$1\>/go;
            s/nopTOKEN/\<nop\>/g;
            s/(\-\-)$TranslationToken/$1\>/go;
            s/$TranslationToken(\!\-\-)/\<$1/go;

# Handle embedded URLs
            s!(^|[\-\*\s\(])($regex{linkProtocolPattern}\:([^\s\<\>\"]+[^\s\.\,\!\?\;\:\)\<]))!&TWiki::externalLink($1,$2)!geo;

# Entities
            s/&(\w+?)\;/$TranslationToken$1\;/g;      # "&abc;"
            s/&(\#[0-9]+)\;/$TranslationToken$1\;/g;  # "&#123;"
            s/&/&amp;/g;                              # escape standalone "&"
            s/$TranslationToken/&/go;

# Headings
            # '<h6>...</h6>' HTML rule
            s/$regex{headerPatternHt}/&TWiki::makeAnchorHeading($2,$1)/geoi;
            # '\t+++++++' rule
            s/$regex{headerPatternSp}/&TWiki::makeAnchorHeading($2,(length($1)))/geo;
            # '----+++++++' rule
            s/$regex{headerPatternDa}/&TWiki::makeAnchorHeading($2,(length($1)))/geo;

# Horizontal rule
            s/^---+/<hr \/>/;
            s!^([a-zA-Z0-9]+)----*!<table width=\"100%\"><tr><td valign=\"bottom\"><h2>$1</h2></td><td width=\"98%\" valign=\"middle\"><hr /></td></tr></table>!o;

# Table of format: | cell | cell |
            # PTh 25 Jan 2001: Forgiving syntax, allow trailing white space
            if( $_ =~ /^(\s*)\|.*\|\s*$/ ) {
                s/^(\s*)\|(.*)/$self->emitTR($1,$2,$insideTABLE)/e;
                $insideTABLE = 1;
            } elsif( $insideTABLE ) {
                $result .= "</table>\n";
                $insideTABLE = 0;
            }

# Lists and paragraphs
            s/^\s*$/<p \/>/o                 && ( $isList = 0 );
            m/^(\S+?)/o                      && ( $isList = 0 );
	    # Definition list
            s/^(\t+)\$\s(([^:]+|:[^\s]+)+?):\s/<dt> $2 <\/dt><dd> /o && ( $result .= $self->emitList( "dl", "dd", length $1 ) );
            s/^(\t+)(\S+?):\s/<dt> $2<\/dt><dd> /o && ( $result .= $self->emitList( "dl", "dd", length $1 ) );
	    # Unnumbered list
            s/^(\t+)\* /<li> /o              && ( $result .= $self->emitList( "ul", "li", length $1 ) );
	    # Numbered list
            s/^(\t+)([1AaIi]\.|\d+\.?) ?/<li> /o && ( $result .= $self->emitList( "ol", "li", length $1, $2 ) );
	    # Finish the list
            if( ! $isList ) {
                $result .= $self->emitList( "", "", 0 );
                $isList = 0;
            }

# '#WikiName' anchors
            s/^(\#)($regex{wikiWordRegex})/ '<a name="' . &TWiki::makeAnchorName( $2 ) . '"><\/a>'/ge;

# enclose in white space for the regex that follow
             s/(.*)/\n$1\n/;

# Emphasizing
            # PTh 25 Sep 2000: More relaxed rules, allow leading '(' and trailing ',.;:!?)'
            s/([\s\(])==([^\s]+?|[^\s].*?[^\s])==([\s\,\.\;\:\!\?\)])/$1 . &TWiki::fixedFontText( $2, 1 ) . $3/ge;
            s/([\s\(])__([^\s]+?|[^\s].*?[^\s])__([\s\,\.\;\:\!\?\)])/$1<strong><em>$2<\/em><\/strong>$3/g;
            s/([\s\(])\*([^\s]+?|[^\s].*?[^\s])\*([\s\,\.\;\:\!\?\)])/$1<strong>$2<\/strong>$3/g;
            s/([\s\(])_([^\s]+?|[^\s].*?[^\s])_([\s\,\.\;\:\!\?\)])/$1<em>$2<\/em>$3/g;
            s/([\s\(])=([^\s]+?|[^\s].*?[^\s])=([\s\,\.\;\:\!\?\)])/$1 . &TWiki::fixedFontText( $2, 0 ) . $3/ge;

# Mailto
	    # Email addresses must always be 7-bit, even within I18N sites

	    # RD 27 Mar 02: Mailto improvements - FIXME: check security...
	    # Explicit [[mailto:... ]] link without an '@' - hence no 
	    # anti-spam padding needed.
            # '[[mailto:string display text]]' link (no '@' in 'string'):
            s/\[\[mailto\:([^\s\@]+)\s+(.+?)\]\]/&TWiki::mailtoLinkSimple( $1, $2 )/ge;

	    # Explicit [[mailto:... ]] link including '@', with anti-spam 
	    # padding, so match name@subdom.dom.
            # '[[mailto:string display text]]' link
            s/\[\[mailto\:([a-zA-Z0-9\-\_\.\+]+)\@([a-zA-Z0-9\-\_\.]+)\.(.+?)(\s+|\]\[)(.*?)\]\]/&TWiki::mailtoLinkFull( $1, $2, $3, $5 )/ge;

	    # Normal mailto:foo@example.com ('mailto:' part optional)
	    # FIXME: Should be '?' after the 'mailto:'...
            s/([\s\(])(?:mailto\:)*([a-zA-Z0-9\-\_\.\+]+)\@([a-zA-Z0-9\-\_\.]+)\.([a-zA-Z0-9\-\_]+)(?=[\s\.\,\;\:\!\?\)])/$1 . &TWiki::mailtoLink( $2, $3, $4 )/ge;

# Make internal links
	    # Spaced-out Wiki words with alternative link text
            # '[[Web.odd wiki word#anchor][display text]]' link:
            s/\[\[([^\]]+)\]\[([^\]]+)\]\]/&TWiki::specificLink("",$theWeb,$theTopic,$2,$1)/ge;
            # RD 25 Mar 02: Codev.EasierExternalLinking
            # '[[URL#anchor display text]]' link:
            s/\[\[([a-z]+\:\S+)\s+(.*?)\]\]/&TWiki::specificLink("",$theWeb,$theTopic,$2,$1)/ge;
	    # Spaced-out Wiki words
            # '[[Web.odd wiki word#anchor]]' link:
            s/\[\[([^\]]+)\]\]/&TWiki::specificLink("",$theWeb,$theTopic,$1,$1)/ge;

            # do normal WikiWord link if not disabled by <noautolink> or NOAUTOLINK preferences variable
            unless( $noAutoLink || $insideNoAutoLink ) {

                # 'Web.TopicName#anchor' link:
                s/([\s\(])($regex{webNameRegex})\.($regex{wikiWordRegex})($regex{anchorRegex})/$self->internalLink($1,$2,$3,"$TranslationToken$3$4$TranslationToken",$4,1)/geo;
                # 'Web.TopicName' link:
                s/([\s\(])($regex{webNameRegex})\.($regex{wikiWordRegex})/&TWiki::internalCrosswebLink($1,$2,$3,"$TranslationToken$3$TranslationToken","",1)/geo;

                # 'TopicName#anchor' link:
                s/([\s\(])($regex{wikiWordRegex})($regex{anchorRegex})/$self->internalLink($1,$theWeb,$2,"$TranslationToken$2$3$TranslationToken",$3,1)/geo;

                # 'TopicName' link:
		s/([\s\(])($regex{wikiWordRegex})/$self->internalLink($1,$theWeb,$2,$2,"",1)/geo;

		# Handle acronyms/abbreviations of three or more letters
                # 'Web.ABBREV' link:
                s/([\s\(])($regex{webNameRegex})\.($regex{abbrevRegex})/$self->internalLink($1,$2,$3,$3,"",0)/geo;
                # 'ABBREV' link:
		s/([\s\(])($regex{abbrevRegex})/$self->internalLink($1,$theWeb,$2,$2,"",0)/geo;
                # (deprecated <link> moved to DefaultPlugin)

                s/$TranslationToken(\S.*?)$TranslationToken/$1/go;
            }

            s/^\n//;
            s/\t/   /g;
            $result .= $_;

          } while( defined( $extraLines ) );  # extra lines produced by plugins
        }
    }
    if( $insideTABLE ) {
        $result .= "</table>\n";
    }
    $result .= $self->emitList( "", "", 0 );
    if( $insidePRE ) {
        $result .= "</pre>\n";
    }

    # Wiki Plugin Hook
    &TWiki::Plugins::endRenderingHandler( $result );

    $result = TWiki::putBackVerbatim( $result, "pre", @verbatim );

    $result =~ s|\n?<nop>\n$||o; # clean up clutch
    return "$head$result";
}

=end twiki

=cut

1;

