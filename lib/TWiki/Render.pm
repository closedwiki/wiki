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

=begin twiki

---+ package TWiki::Render

This module provides most of the actual HTML rendering code in TWiki.

=cut

package TWiki::Render;

use strict;
use Assert;
use TWiki::Plurals;
use TWiki::Attach;
use TWiki::Attrs;
use TWiki::Time;

BEGIN {
    # Do a dynamic 'use locale' for this module
    if( $TWiki::cfg{UseLocale} ) {
        eval 'require locale; import locale ();';
    }
}

=pod

---++ ClassMethod new ($session)

Creates a new renderer with initial state from preference values
(NEWTOPICBGCOLOR, NEWTOPICFONTCOLOR NEWTOPICLINKSYMBOL
 LINKTOOLTIPINFO NOAUTOLINK)

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( {}, $class );
    ASSERT(ref($session) eq "TWiki") if DEBUG;
    $this->{session} = $session;

    $this->{NOAUTOLINK} = 0;
    $this->{MODE} = 'html';		# Default is to render as HTML
    $this->{NEWTOPICBGCOLOR} =
      $session->{prefs}->getPreferencesValue("NEWTOPICBGCOLOR")
        || "#FFFFCE";
    $this->{NEWTOPICFONTCOLOR} =
      $session->{prefs}->getPreferencesValue("NEWTOPICFONTCOLOR")
        || "#0000FF";
    $this->{NEWLINKSYMBOL} =
      $session->{prefs}->getPreferencesValue("NEWTOPICLINKSYMBOL")
        || "<sup>?</sup>";
    # tooltip init
    $this->{LINKTOOLTIPINFO} =
      $session->{prefs}->getPreferencesValue("LINKTOOLTIPINFO")
        || "";
    $this->{LINKTOOLTIPINFO} = '$username - $date - r$rev: $summary'
      if( $this->{LINKTOOLTIPINFO} =~ /^on$/ );
    $this->{NOAUTOLINK} =
      $session->{prefs}->getPreferencesValue("NOAUTOLINK")
        || 0;

    return $this;
}

sub users { my $this = shift; return $this->{session}->{users}; }
sub prefs { my $this = shift; return $this->{session}->{prefs}; }
sub store { my $this = shift; return $this->{session}->{store}; }
sub attach { my $this = shift; return $this->{session}->{attach}; }
sub plugins { my $this = shift; return $this->{session}->{plugins}; }

sub _renderParent {
    my( $this, $web, $topic, $meta, $args ) = @_;

    my $ah;

    if( $args ) {
        $ah = new TWiki::Attrs( $args );
    }
    my $dontRecurse = $ah->{dontrecurse} || 0;
    my $noWebHome =   $ah->{nowebhome} || 0;
    my $prefix =      $ah->{prefix} || "";
    my $suffix =      $ah->{suffix} || "";
    my $usesep =      $ah->{separator} || " &gt; ";

    my %visited;
    $visited{"$web.$topic"} = 1;

    my $sep = "";
    my $pWeb = $web;
    my $pTopic;
    my $text = "";
    my $parentMeta = $meta->get( "TOPICPARENT" );
    my $parent;

    $parent = $parentMeta->{name} if $parentMeta;

    my @stack;

    while( $parent ) {
        ( $pWeb, $pTopic ) =
          $this->{session}->normalizeWebTopicName( $pWeb, $parent );
        $parent = "$pWeb.$pTopic";
        last if( $noWebHome &&
                 ( $pTopic eq $TWiki::cfg{HomeTopicName} ) ||
                 $dontRecurse ||
                 $visited{$parent} );
        $visited{$parent} = 1;
        unshift( @stack, "[[$parent][$pTopic]]" );
        $parent = $this->store()->getTopicParent( $pWeb, $pTopic );
    }
    $text = join( $usesep, @stack );

    if( $text) {
        $text = "$prefix$text" if ( $prefix );
        $text .= $suffix if ( $suffix );
    }

    return $text;
}

sub _renderMoved {
    my( $this, $web, $topic, $meta ) = @_;
    my $text = "";
    my $moved = $meta->get( "TOPICMOVED" );

    if( $moved ) {
        my( $fromWeb, $fromTopic ) =
          $this->{session}->normalizeWebTopicName( $web, $moved->{from} );
        my( $toWeb, $toTopic ) =
          $this->{session}->normalizeWebTopicName( $web, $moved->{to} );
        my $by = $moved->{by};
        my $u = $this->users()->findUser( $by );
        $by = $u->webDotWikiName() if $u;
        my $date = TWiki::Time::formatTime( $moved->{date}, "", "gmtime" );

        # Only allow put back if current web and topic match stored information
        my $putBack = "";
        if( $web eq $toWeb && $topic eq $toTopic ) {
            $putBack  = " - <a title=\"Click to move topic back to previous location, with option to change references.\"";
            $putBack .= " href=\"".$this->{session}->getScriptUrl($web, $topic, 'rename')."?newweb=$fromWeb&newtopic=$fromTopic&";
            $putBack .= "confirm=on\" $TWiki::cfg{NoFollow}>put it back</a>";
        }
        $text = "<i><nop>$toWeb.<nop>$toTopic moved from <nop>$fromWeb.<nop>$fromTopic on $date by $by </i>$putBack";
    }
    return $text;
}

sub _renderFormField {
    my( $this, $meta, $args ) = @_;
    my $text = "";
    if( $args ) {
        my $attrs = new TWiki::Attrs( $args );
        my $name = $attrs->{name};
        $text = TWiki::Search::getMetaFormField( $meta, $name ) if( $name );
    }
    return $text;
}

sub _renderFormData {
    my( $this, $web, $topic, $meta ) = @_;
    my $metaText = "";
    my $form = $meta->get( "FORM" );

    if( $form ) {
        my $name = $form->{name};
        $metaText = "<div class=\"twikiForm\">\n";
        $metaText .= "<p></p>\n"; # prefix empty line
        $metaText .= "|*[[$name]]*||\n"; # table header
        my @fields = $meta->find( "FIELD" );
        foreach my $field ( @fields ) {
            my $title = $field->{"title"};
            my $value = $field->{"value"};
            $value =~ s/\n/<br \/>/g;      # undo expansion
            $metaText .= "|  $title:|$value  |\n";
        }
        $metaText .= "\n</div>";
    }

    return $metaText;
}

# Add a list item, of the given type and indent depth. The list item may
# cause the opening or closing of lists currently being handled.
sub _addListItem {
    my( $this, $result, $theType, $theElement, $theIndent, $theOlType ) = @_;

    $theIndent =~ s/   /\t/g;
    my $depth = length( $theIndent );

    my $size = scalar( @{$this->{LIST}} );
    if( $size < $depth ) {
        my $firstTime = 1;
        while( $size < $depth ) {
            push( @{$this->{LIST}}, { type=>$theType, element=>$theElement } );
            push( @$result, "<$theElement>" ) unless( $firstTime );
            push( @$result, "<$theType>" );
            $firstTime = 0;
            $size++;
        }
    } else {
        while( $size > $depth ) {
            my $tags = pop( @{$this->{LIST}} );
            push( @$result, "</$tags->{element}>" );
            push( @$result, "</$tags->{type}>" );
            $size--;
        }
        if ($size) {
            push( @$result, "</$this->{LIST}->[$size-1]->{element}>" );
        }
    }

    if ( $size ) {
        my $oldt = $this->{LIST}->[$size-1];
        if( $oldt->{type} ne $theType ) {
            push( @$result, "</$oldt->{type}>\n<$theType>" );
            pop( @{$this->{LIST}} );
            push( @{$this->{LIST}}, { type=>$theType, element=>$theElement } );
        }
    }
}

sub _emitTR {
    my ( $this, $thePre, $theRow, $insideTABLE ) = @_;

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
    $theRow =~ s/(\|\|+)/$TWiki::TranslationToken . length($1) . "\|"/ge;  # calc COLSPAN

    foreach( split( /\|/, $theRow ) ) {
        $attr = "";
        # Avoid matching single columns
        if ( s/$TWiki::TranslationToken([0-9]+)//o ) { 
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

sub _fixedFontText {
    my( $this, $theText, $theDoBold ) = @_;
    # preserve white space, so replace it by "&nbsp; " patterns
    $theText =~ s/\t/   /g;
    $theText =~ s|((?:[\s]{2})+)([^\s])|'&nbsp; ' x (length($1) / 2) . "$2"|eg;
    if( $theDoBold ) {
        return "<code><b>$theText</b></code>";
    } else {
        return "<code>$theText</code>";
    }
}

# Build an HTML &lt;Hn> element with suitable anchor for linking from %<nop>TOC%
sub _makeAnchorHeading {
    my( $this, $theHeading, $theLevel ) = @_;

    # - Build '<nop><h1><a name="atext"></a> heading </h1>' markup
    # - Initial '<nop>' is needed to prevent subsequent matches.
    # - filter out $TWiki::regex{headerPatternNoTOC} ( '!!' and '%NOTOC%' )
    # CODE_SMELL: Empty anchor tags seem not to be allowed, but validators and browsers tolerate them

    my $anchorName =       $this->makeAnchorName( $theHeading, 0 );
    my $compatAnchorName = $this->makeAnchorName( $theHeading, 1 );
    # filter '!!', '%NOTOC%'
    $theHeading =~ s/$TWiki::regex{headerPatternNoTOC}//o;
    my $text = "<nop><h$theLevel>";
    $text .= "<a name=\"$anchorName\"> </a>";
    $text .= "<a name=\"$compatAnchorName\"> </a>" if( $compatAnchorName ne $anchorName );
    $text .= " $theHeading </h$theLevel>";

    return $text;
}

=pod

---++ ObjectMethod makeAnchorName($anchorName, $compatibilityMode) -> $anchorName

   * =$anchorName= -
   * =$compatibilityMode= -

Build a valid HTML anchor name

=cut

sub makeAnchorName {
    my( $this, $anchorName, $compatibilityMode ) = @_;
    ASSERT(ref($this) eq "TWiki::Render") if DEBUG;

    if ( ! $compatibilityMode && $anchorName =~ /^$TWiki::regex{anchorRegex}$/ ) {
	# accept, already valid -- just remove leading #
	return substr($anchorName, 1);
    }

    if ( $compatibilityMode ) {
	# remove leading/trailing underscores first, allowing them to be
	# reintroduced
	$anchorName =~ s/^[\s\#\_]*//;
        $anchorName =~ s/[\s\_]*$//;
    }
    $anchorName =~ s/<\w[^>]*>//gi;         # remove HTML tags
    $anchorName =~ s/\&\#?[a-zA-Z0-9]*;//g; # remove HTML entities
    $anchorName =~ s/\&//g;                 # remove &
    $anchorName =~ s/^(.+?)\s*$TWiki::regex{headerPatternNoTOC}.*/$1/o; # filter TOC excludes if not at beginning
    $anchorName =~ s/$TWiki::regex{headerPatternNoTOC}//o; # filter '!!', '%NOTOC%'

    # For most common alphabetic-only character encodings (i.e. iso-8859-*), remove non-alpha characters 
    if( $TWiki::siteCharset =~ /^iso-?8859-?/i ) {
        $anchorName =~ s/[^$TWiki::regex{mixedAlphaNum}]+/_/g;
    }
    $anchorName =~ s/__+/_/g;               # remove excessive '_' chars
    if ( !$compatibilityMode ) {
        $anchorName =~ s/^[\s\#\_]*//;      # no leading space nor '#', '_'
    }
    $anchorName =~ s/^(.{32})(.*)$/$1/;     # limit to 32 chars - FIXME: Use Unicode chars before truncate
    if ( !$compatibilityMode ) {
        $anchorName =~ s/[\s\_]*$//;        # no trailing space, nor '_'
    }

    # No need to encode 8-bit characters in anchor due to UTF-8 URL support

    return $anchorName;
}

# Returns =title="..."= tooltip info in case LINKTOOLTIPINFO perferences variable is set. 
# Warning: Slower performance if enabled.
sub _linkToolTipInfo {
    my( $this, $theWeb, $theTopic ) = @_;
    return "" unless( $this->{LINKTOOLTIPINFO} );
    return "" if( $this->{LINKTOOLTIPINFO} =~ /^off$/i );

    # FIXME: This is slow, it can be improved by caching topic rev info and summary
    my( $date, $user, $rev ) =
      $this->store()->getRevisionInfo( $theWeb, $theTopic );
    my $text = $this->{LINKTOOLTIPINFO};
    $text =~ s/\$web/<nop>$theWeb/g;
    $text =~ s/\$topic/<nop>$theTopic/g;
    $text =~ s/\$rev/1.$rev/g;
    $text =~ s/\$date/TWiki::Time::formatTime( $date )/ge;
    $text =~ s/\$username/<nop>$user/g;                                     # "jsmith"
    $text =~ s/\$wikiname/"<nop>" . $user->wikiName()/ge;  # "JohnSmith"
    $text =~ s/\$wikiusername/"<nop>" . $user->webDotWikiName()/ge; # "Main.JohnSmith"
    if( $text =~ /\$summary/ ) {
        my $summary = $this->store()->readTopicRaw
          ( undef, $theWeb, $theTopic, undef );
        $summary = $this->makeTopicSummary( $summary, $theTopic, $theWeb );
        $summary =~ s/[\"\']/<nop>/g;       # remove quotes (not allowed in title attribute)
        $text =~ s/\$summary/$summary/g;
    }
    return " title=\"$text\"";
}

=pod

---++ ObjectMethod internalLink ( $theWeb, $theTopic, $theLinkText, $theAnchor, $doLink, $doKeepWeb ) -> $html

Generate a link.

SMELL: why can topic be spaced out? is this to support auto squishing of [[Spaced Topic Naming]]?
and [[lowercase Spaced Topic Naming]]
   * =$theWeb= - the web containing the topic
   * =$theTopic= - the topic to be lunk
   * =$theLinkText= - text to use for the link
   * =$theAnchor= - the link anchor, if any
   * =$doLinkToMissingPages= - boolean: false means suppress link for non-existing pages
   * =$doKeepWeb= - boolean: true to keep web prefix (for non existing Web.TOPIC)

Called by _handleWikiWord and _handleSquareBracketedLink and by Func::internalLink
SMELL: why is this available to Func?

=cut

sub internalLink {
    my( $this, $theWeb, $theTopic, $theLinkText, $theAnchor, $doLinkToMissingPages, $doKeepWeb ) = @_;
    ASSERT(ref($this) eq "TWiki::Render") if DEBUG;
    # SMELL - shouldn't it be callable by TWiki::Func as well?

    # Get rid of leading/trailing spaces in topic name
    $theTopic =~ s/^\s*//;
    $theTopic =~ s/\s*$//;

    # Turn spaced-out names into WikiWords - upper case first letter of
    # whole link, and first of each word. TODO: Try to turn this off,
    # avoiding spaces being stripped elsewhere
    $theTopic =~ s/^(.)/\U$1/;
    $theTopic =~ s/\s([$TWiki::regex{mixedAlphaNum}])/\U$1/go;	

    # Add <nop> before WikiWord inside link text to prevent double links
    $theLinkText =~ s/([\s\(])([$TWiki::regex{upperAlpha}])/$1<nop>$2/go;

    return _renderWikiWord($this, $theWeb, $theTopic, $theLinkText, $theAnchor, $doLinkToMissingPages, $doKeepWeb);
}

# TODO: this should be overridable by plugins.
sub _renderWikiWord {
    my ($this, $theWeb, $theTopic, $theLinkText, $theAnchor, $doLinkToMissingPages, $doKeepWeb) = @_;
    my $topicExists = $this->store()->topicExists( $theWeb, $theTopic );

    unless( $topicExists ) {
        # topic not found - try to singularise
        my $singular = TWiki::Plurals::singularForm($theWeb, $theTopic);
        if( $singular ) {
            $topicExists = $this->store()->topicExists( $theWeb, $singular );
            $theTopic = $singular if $topicExists;
        }
    }

    my $ans = "";
    #NOTE: Yes, this hierarchy of ifs could be flattened but doing so makes
    # the logic much harder to read.
    if( $topicExists) {
        $ans = _renderExistingWikiWord($this, $theWeb,
                                       $theTopic, $theLinkText, $theAnchor);
    } else {
        if( $doLinkToMissingPages ) {
            $ans = _renderNonExistingWikiWord($this, $theWeb, $theTopic,
                                              $theLinkText, $theAnchor);
        } else {
            if( $doKeepWeb ) {
                $ans = "$theWeb.$theLinkText";
            } else {
                $ans = $theLinkText;
            }
        }
    }
    return $ans;
}

sub _renderExistingWikiWord {
    my ($this, $theWeb, $theTopic, $theLinkText, $theAnchor) = @_;
    my $ans;

    if( $theAnchor ) {
        my $anchor = $this->makeAnchorName( $theAnchor );
        $ans = "<a class=\"twikiAnchorLink\" href=\"".
	      $this->{session}->getScriptUrl($theWeb, $theTopic, 'view').
            "\#$anchor\""
              .  $this->_linkToolTipInfo( $theWeb, $theTopic )
                .  ">$theLinkText</a>";
    } else {
        $ans = "<a class=\"twikiLink\" href=\""
	      .	$this->{session}->getScriptUrl($theWeb, $theTopic, 'view') ."\""
            .  $this->_linkToolTipInfo( $theWeb, $theTopic )
              .  ">$theLinkText</a>";
    }
    return $ans;
}

sub _renderNonExistingWikiWord {
    my ($this, $theWeb, $theTopic, $theLinkText, $theAnchor) = @_;
    my $ans;

    $ans .= "<span class=\"twikiNewLink\" style='background : $this->{NEWTOPICBGCOLOR};'>"
      .  "<font color=\"$this->{NEWTOPICFONTCOLOR}\">$theLinkText</font>"
        .  "<a href=\"".
          $this->{session}->getScriptUrl($theWeb, $theTopic, 'edit')."?topicparent="
            .$this->{session}->{webName}.".".$this->{session}->{topicName}."\" $TWiki::cfg{NoFollow}>$this->{NEWLINKSYMBOL}</a></span>";
    return $ans;
}

# NOTE: factored for clarity. Test for any speed penalty.
# returns the (web, topic) 
#SMELL - we must have implemented this elsewhere?
sub _getWeb {
    # Internal link: get any 'Web.' prefix, or use current web
    my ($theLink) = @_;
    $theLink =~ s/^($TWiki::regex{webNameRegex}|$TWiki::regex{defaultWebNameRegex})\.//;
    my $web = $1;

    (my $baz = "foo") =~ s/foo//;       # reset $1, defensive coding
    # SMELL - is that really necessary?
    return ($web, $theLink);
}

# _handleWikiWord is called by the TWiki Render routine when it sees a 
# wiki word that needs linking.
# Handle the various link constructions. e.g.:
# WikiWord
# Web.WikiWord
# Web.WikiWord#anchor
#
# This routine adds missing parameters before passing off to internallink
sub _handleWikiWord {
    my ( $this, $theWeb, $web, $topic, $anchor ) = @_;

    my $linkIfAbsent = 1;
    my $keepWeb = 0;
    my $text;

    $web = $theWeb unless (defined($web));
    if( defined( $anchor )) {
        ASSERT(($anchor =~ m/\#.*/)) if DEBUG; # must include a hash.
    } else {
        $anchor = "" ;
    }

    if ( defined( $anchor ) ) {
        # 'Web.TopicName#anchor' or 'Web.ABBREV#anchor' link
        $text = "$topic$anchor";
    } else {
        $anchor = "";

        # 'Web.TopicName' or 'Web.ABBREV' link:
        if ( $topic eq $TWiki::cfg{HomeTopicName} &&
             $web ne $this->{session}->{webName} ) {
            $text = $web;
        } else {
            $text = $topic;
        }
    }

    # Allow spacing out, etc
    $text = $this->plugins()->renderWikiWordHandler( $text ) || $text;

    # =$doKeepWeb= boolean: true to keep web prefix (for non existing Web.TOPIC)
    # SMELL: Why set keepWeb when the topic is an abbreviation?
    # NO IDEA, and it doesn't work anyway; it adds "TWiki." in front
    # of every TWiki.CAPITALISED TWiki.WORD
    #$keepWeb = ( $topic =~ /^$TWiki::regex{abbrevRegex}$/o );

    # false means suppress link for non-existing pages
    $linkIfAbsent = ( $topic !~ /^$TWiki::regex{abbrevRegex}$/o );

    $text = $topic;
    # SMELL - it seems $linkIfAbsent, $keepWeb are always inverses of each
    # other
    # TODO: check the spec of doKeepWeb vs $doLinkToMissingPages

    return $this->internalLink( $web, $topic, $text, $anchor,
                                $linkIfAbsent, $keepWeb );
}


# Handle SquareBracketed links mentioned on page $theWeb.$theTopic
# format: [[$theText]]
# format: [[$theLink][$theText]]
sub _handleSquareBracketedLink {
    my( $this, $theWeb, $theTopic, $theText, $theLink ) = @_;

    $theText = $theLink unless defined( $theText );

    # Strip leading/trailing spaces
    $theLink =~ s/^\s*//;
    $theLink =~ s/\s*$//;
    return _protocolLink($theLink, $theText) if( $theLink =~ /^$TWiki::regex{linkProtocolPattern}\:/ );
    my $web;
    ($web, $theLink) = _getWeb($theLink);
    $web = $theWeb unless ($web);

    # Extract '#anchor'
    # FIXME and NOTE: Had '-' as valid anchor character, removed
    # $theLink =~ s/(\#[a-zA-Z_0-9\-]*$)//;
    $theLink =~ s/($TWiki::regex{anchorRegex}$)//;
    my $anchor = $1 || "";

    # Get the topic name
    my $topic = $theLink || $theTopic;  # remaining is topic
    # Capitalise
    $topic =~ s/^(.)/\U$1/;
    $topic =~ s/\s([$TWiki::regex{mixedAlphaNum}])/\U$1/go;	
    # filter out &any; entities
    $topic =~ s/\&[a-z]+\;//gi;
    # filter out &#123; entities
    $topic =~ s/\&\#[0-9]+\;//g;
    $topic =~ s/[\\\/\#\&\(\)\{\}\[\]\<\>\!\=\:\,\.]//g;
    $topic =~ s/$TWiki::cfg{NameFilter}//go;    # filter out suspicious chars
    if( ! $topic ) {
        return $theText; # no link if no topic
    }
    return $this->internalLink( $web, $topic, $theText, $anchor, 1, undef );
}

#---++ _protocolLink
# Called whenever SquareBracketed links point at an external URL 
# e.g. file: ftp: http: 
# used to be called specificLink, but renamed as it is specific to a protocol
#
# returns the HTML fragment
sub _protocolLink {
    my ($theLink, $theText) = @_;

    if ( $theLink =~ /^(\S+)\s+(.*)$/ ) {
	 # '[[URL#anchor display text]]' link:
	    $theLink = $1;
            $theText = $2;

        } else {
            # '[[Web.odd wiki word#anchor][display text]]' link:
            # '[[Web.odd wiki word#anchor]]' link:

            # External link: add <nop> before WikiWord and ABBREV 
            # inside link text, to prevent double links
            # SMELL - why is adding <nop> necessary? why is the output reparsed?
	    # SMELL - why regex{upperAlpha} here - surely this is a web match, not a CAPWORD match?

            $theText =~ s/([\s\(])([$TWiki::regex{upperAlpha}])/$1<nop>$2/go;
        }
#	  die $theText unless ($theText eq "GNU" || $theText eq "Run Test" || $theText eq "XHTML Validator");
       return "<a href=\"$theLink\" target=\"_top\">$theText</a>";
}

sub _externalLink {
    my( $this, $pre, $url ) = @_;
    if( $url =~ /\.(gif|jpg|jpeg|png)$/i ) {
        my $filename = $url;
        $filename =~ s@.*/([^/]*)@$1@go;
        return "$pre<img src=\"$url\" alt=\"$filename\" />";
    }

    return "$pre<a href=\"$url\" target=\"_top\">$url</a>";
}

sub _mailtoLink {
    my( $this, $theAccount, $theSubDomain, $theTopDomain ) = @_;

    my $addr = "$theAccount\@$theSubDomain$TWiki::cfg{NoSpamPadding}\.$theTopDomain";
    return "<a href=\"mailto\:$addr\">$addr</a>";
}

sub _mailtoLinkFull {
    my( $this, $theAccount, $theSubDomain, $theTopDomain, $theLinkText ) = @_;

    my $addr = "$theAccount\@$theSubDomain$TWiki::cfg{NoSpamPadding}\.$theTopDomain";
    return "<a href=\"mailto\:$addr\">$theLinkText</a>";
}

sub _mailtoLinkSimple {
    # Does not do any anti-spam padding, because address will not include '@'
    my( $this, $theMailtoString, $theLinkText ) = @_;	

    if ($theMailtoString =~ s/@//g ) {
    	writeWarning("mailtoLinkSimple called with an '\@' in string - internal TWiki error");
    }
    return "<a href=\"mailto\:$theMailtoString\">$theLinkText</a>";
}

=pod

---++ ObjectMethod filenameToIcon (  $fileName  ) -> $html

Produce an image tailored to the type of the file, guessed from
its extension.

used in TWiki::handleIcon

=cut

sub filenameToIcon {
    my( $this, $fileName ) = @_;
    ASSERT(ref($this) eq "TWiki::Render") if DEBUG;

    my @bits = ( split( /\./, $fileName ) );
    my $fileExt = lc $bits[$#bits];

    my $iconDir = "$TWiki::cfg{PubDir}/icn";
    my $iconUrl = "$TWiki::cfg{PubUrlPath}/icn";
    my $iconList = $this->store()->readFile( "$iconDir/_filetypes.txt" );
    foreach( split( /\n/, $iconList ) ) {
        @bits = ( split( / / ) );
	if( $bits[0] eq $fileExt ) {
            return "<img src=\"$iconUrl/$bits[1].gif\" width=\"16\" height=\"16\" align=\"top\" alt=\"\" border=\"0\" />";
        }
    }
    return "<img src=\"$iconUrl/else.gif\" width=\"16\" height=\"16\" align=\"top\" alt=\"\" border=\"0\" />";
}

=pod

---++ ObjectMethod renderFormField ( %params, $topic, $web ) -> $html

Returns the fully rendered expansion of a %FORMFIELD{}% tag.

=cut

sub renderFormField {
    my ( $this, $params, $topic, $web ) = @_;
    ASSERT(ref($this) eq "TWiki::Render") if DEBUG;

    my $formField = $params->{_DEFAULT};
    my $formTopic = $params->{topic};
    my $altText   = $params->{alttext};
    my $default   = $params->{default};
    my $format    = $params->{format};

    unless ( $format ) {
        # if null format explicitly set, return empty
        # SMELL: it's not clear what this does; the implication
        # is that it does something that violates TWiki tag syntax,
        # so I've had to comment it out....
        # return "" if ( $args =~ m/format\s*=/o);
        # Otherwise default to value
        $format = "\$value";
    }

    my $formWeb;
    if ( $formTopic ) {
        if ($topic =~ /^([^.]+)\.([^.]+)/o) {
            ( $formWeb, $topic ) = ( $1, $2 );
        } else {
            # SMELL: Undocumented feature, "web" parameter
            $formWeb = $params->{"web"};
        }
        $formWeb = $web unless $formWeb;
    } else {
        $formWeb = $web;
        $formTopic = $topic;
    }

    my $meta = $this->{ffCache}{"$formWeb.$formTopic"};
    unless ( $meta ) {
        my $dummyText;
        ( $meta, $dummyText ) =
          $this->store()->readTopic( $this->{session}->{user}, $formWeb, $formTopic, undef );
        $this->{ffCache}{"$formWeb.$formTopic"} = $meta;
    }

    my $text = "";
    my $found = 0;
    if ( $meta ) {
        my @fields = $meta->find( "FIELD" );
        foreach my $field ( @fields ) {
            my $title = $field->{"title"};
            my $name = $field->{"name"};
            if( $title eq $formField || $name eq $formField ) {
                $found = 1;
                my $value = $field->{"value"};
                if (length $value) {
                    $text = $format;
                    $text =~ s/\$value/$value/go;
                } elsif ( defined $default ) {
                    $text = $default;
                }
                last; #one hit suffices
            }
        }
    }

    unless ( $found ) {
        $text = $altText;
    }

    return "" unless $text;

    return $this->getRenderedVersion( $text, $web, $topic );
}

=pod

---++ ObjectMethod getRenderedVersion ( $text, $theWeb, $theTopic ) -> $html

The main rendering function.

=cut

sub getRenderedVersion {
    my( $this, $text, $theWeb, $theTopic ) = @_;
    ASSERT(ref($this) eq "TWiki::Render") if DEBUG;
    my( $head, $result, $insideNoAutoLink );

    return "" unless $text;  # nothing to do

    $theTopic ||= $this->{session}->{topicName};
    $theWeb ||= $this->{session}->{webName};

    $head = "";
    $result = "";
    $insideNoAutoLink = 0;

    @{$this->{LIST}} = ();

    # Initial cleanup
    $text =~ s/\r//g;
    # clutch to enforce correct rendering at end of doc
    $text =~ s/(\n?)$/\n<nop>\n/s;
    # Convert any occurrences of token (very unlikely - details in
    # Codev.NationalCharTokenClash)
    $text =~ s/$TWiki::TranslationToken/!/go;	

    my $removed = {};    # Map of placeholders to tag parameters and text

    $text =~ s/(<!DOCTYPE.*?>)//is;
    my $doctype = $1 || "";

    $text = $this->takeOutBlocks( $text, "verbatim", $removed );
    $text = $this->takeOutBlocks( $text, "head", $removed );

    # DEPRECATED startRenderingHandler before PRE removed
    # SMELL: could parse more efficiently if this wasn't
    # here.
    $this->plugins()->startRenderingHandler( $text, $theWeb, $theTopic );

    $text = $this->takeOutBlocks( $text, "pre", $removed );

    $this->plugins()->preRenderingHandler( \$text, $removed );

    if( $this->plugins()->haveHandlerFor( 'insidePREHandler' )) {
        foreach my $region ( sort keys %$removed ) {
            next unless ( $region =~ /^pre\d+$/i );
            my @lines = split( /\n/, $removed->{$region}{text} );
            my $result = "";
            while ( scalar( @lines )) {
                my $line = shift( @lines );
                $this->plugins()->insidePREHandler( $line );
                if ( $line =~ /\n/ ) {
                    unshift( @lines, split( /\n/, $line ));
                    next;
                }
                $result .= "$line\n";
            }
            $removed->{$region}{text} = $result;
        }
    }

    $text =~ s/\\\n//gs;  # Join lines ending in "\"

    if( $this->plugins()->haveHandlerFor( 'outsidePREHandler' )) {
        # DEPRECATED - this is the one call preventing
        # effective optimisation of the TWiki ML processing loop,
        # as it exposes the concept of a "line loop" to plugins,
        # but HTML is not a line-oriented language (though TML is).
        # But without it, a lot of processing could be moved
        # outside the line loop.
        my @lines = split( /\n/, $text );
        my @result = ();
        while ( scalar( @lines ) ) {
            my $line = shift( @lines );
            $this->plugins()->outsidePREHandler( $line );
            if ( $line =~ /\n/ ) {
                unshift( @lines, split( /\n/, $line ));
                next;
            }
            push( @result, $line );
        }

        $text = join("\n", @result );
    }

    # Escape rendering: Change " !AnyWord" to " <nop>AnyWord",
    # for final " AnyWord" output
    $text =~ s/(^|[\s\(])\!(?=[\w\*\=])/$1<nop>/gm;

    # Blockquoted email (indented with '> ')
    # Could be used to provide different colours for different numbers of '>'
    $text =~ s/^>(.*?)$/> <cite> $1 <\/cite><br \/>/gm;

    # locate isolated < and > and translate to entities
    # Protect isolated <!-- and -->
    $text =~ s/<!--/{$TWiki::TranslationToken!--/g;
    $text =~ s/-->/--}$TWiki::TranslationToken/g;
    # SMELL: this next fragment is a frightful hack, to handle the
    # case where simple HTML tags (i.e. without values) are embedded
    # in the values provided to other tags. The only way to do this
    # correctly (i.e. handle HTML tags with values as well) is to
    # parse the HTML (bleagh!)
    $text =~ s/<(\/[A-Za-z]+)>/{$TWiki::TranslationToken$1}$TWiki::TranslationToken/g;
    $text =~ s/<([A-Za-z]+(\s+\/)?)>/{$TWiki::TranslationToken$1}$TWiki::TranslationToken/g;
    $text =~ s/<(\S.*?)>/{$TWiki::TranslationToken$1}$TWiki::TranslationToken/g;
    # entitify lone < and >, praying that we haven't screwed up :-(
    $text =~ s/</&lt\;/g;
    $text =~ s/>/&gt\;/g;
    $text =~ s/{$TWiki::TranslationToken/</go;
    $text =~ s/}$TWiki::TranslationToken/>/go;

    # standard URI
    $text =~ s/(^|[\-\*\s\(])($TWiki::regex{linkProtocolPattern}\:([^\s\<\>\"]+[^\s\.\,\!\?\;\:\)\<]))/$this->_externalLink($1,$2)/geo;

    # other entities
    $text =~ s/&(\w+);/$TWiki::TranslationToken$1;/g;      # "&abc;"
    $text =~ s/&(#[0-9]+);/$TWiki::TranslationToken$1;/g;  # "&#123;"
    $text =~ s/&/&amp;/g;                         # escape standalone "&"
    $text =~ s/$TWiki::TranslationToken(#[0-9]+;)/&$1/go;
    $text =~ s/$TWiki::TranslationToken(\w+;)/&$1/go;

    # Headings
    # '<h6>...</h6>' HTML rule
    $text =~ s/$TWiki::regex{headerPatternHt}/$this->_makeAnchorHeading($2,$1)/geomi;
    # '\t+++++++' rule
    $text =~ s/$TWiki::regex{headerPatternSp}/$this->_makeAnchorHeading($2,(length($1)))/geom;
    # '----+++++++' rule
    $text =~ s/$TWiki::regex{headerPatternDa}/$this->_makeAnchorHeading($2,(length($1)))/geom;

    # Horizontal rule
    $text =~ s/^---+/<hr \/>/gm;

    # Now we really _do_ need a line loop, to process TML
    # line-oriented stuff.
    my $isList = 0;		# True when within a list
    my $insideTABLE = 0;
    my @result = ();
    foreach my $line ( split( /\n/, $text )) {
        # Table: | cell | cell |
        # allow trailing white space after the last |
        if( $line =~ m/^(\s*)\|.*\|\s*$/ ) {
            $line =~ s/^(\s*)\|(.*)/$this->_emitTR($1,$2,$insideTABLE)/e;
            $insideTABLE = 1;
        } elsif( $insideTABLE ) {
            push( @result, "</table>" );
            $insideTABLE = 0;
        }

        # Lists and paragraphs
        if ( $line =~ s/^\s*$/<p \/>/o ) {
            $isList = 0;
        }
        elsif ( $line =~ m/^(\S+?)/o ) {
            $isList = 0;
        }
        elsif ( $line =~ m/^(\t|   )+\S/ ) {
            $isList = 1;
            if ( $line =~ s/^((\t|   )+)\$\s(([^:]+|:[^\s]+)+?):\s/<dt> $3 <\/dt><dd> /o ) {
                # Definition list
                $this->_addListItem( \@result, "dl", "dd", $1, "" );
            }
            elsif ( $line =~ s/^((\t|   )+)(\S+?):\s/<dt> $3<\/dt><dd> /o ) {
                # Definition list
                $this->_addListItem( \@result, "dl", "dd", $1, "" );
            }
            elsif ( $line =~ s/^((\t|   )+)\* /<li> /o ) {
                # Unnumbered list
                $this->_addListItem( \@result, "ul", "li", $1, "" );
            }
            elsif ( $line =~ m/^((\t|   )+)([1AaIi]\.|\d+\.?) ?/ ) {
                # Numbered list
                my $ot = $3;
                $ot =~ s/^(.).*/$1/;
                if( $ot !~ /^\d$/ ) {
                    $ot = " type=\"$ot\"";
                } else {
                    $ot = "";
                }
                $line =~ s/^((\t|   )+)([1AaIi]\.|\d+\.?) ?/<li$ot> /;
                $this->_addListItem( \@result, "ol", "li", $1, $ot );
            }
            else {
                $isList = 0;
            }
        }

        # Finish the list
        if( ! $isList ) {
            $this->_addListItem( \@result, "", "", "" );
            $isList = 0;
        }

        push( @result, $line );
    }

    if( $insideTABLE ) {
        push( @result, "</table>" );
    }
    $this->_addListItem( \@result, "", "", "" );

    $text = join("\n", @result );

    # '#WikiName' anchors
    $text =~ s/^(\#)($TWiki::regex{wikiWordRegex})/ '<a name="' . $this->makeAnchorName( $2 ) . '"><\/a>'/geom;

    # Emphasizing
    $text =~ s/(^|[\s\(])==([^\s]+?|[^\s].*?[^\s])==([\s\,\.\;\:\!\?\)])/$1 . $this->_fixedFontText( $2, 1 ) . $3/gem;
    $text =~ s/(^|[\s\(])__([^\s]+?|[^\s].*?[^\s])__([\s\,\.\;\:\!\?\)])/$1<strong><em>$2<\/em><\/strong>$3/gm;
    $text =~ s/(^|[\s\(])\*([^\s]+?|[^\s].*?[^\s])\*([\s\,\.\;\:\!\?\)])/$1<strong>$2<\/strong>$3/gm;
    $text =~ s/(^|[\s\(])_([^\s]+?|[^\s].*?[^\s])_([\s\,\.\;\:\!\?\)])/$1<em>$2<\/em>$3/gm;
    $text =~ s/(^|[\s\(])=([^\s]+?|[^\s].*?[^\s])=([\s\,\.\;\:\!\?\)])/$1 . $this->_fixedFontText( $2, 0 ) . $3/gem;

    # Mailto
    # Email addresses must always be 7-bit, even within I18N sites

    # FIXME: check security...
    # Explicit [[mailto:... ]] link without an '@' - hence no 
    # anti-spam padding needed.
    # '[[mailto:string display text]]' link (no '@' in 'string'):
    $text =~ s/\[\[mailto:(.*?)\]\]/$this->_handleMailto($1)/geo;

    # Normal mailto:foo@example.com ('mailto:' part optional)
    # FIXME: Should be '?' after the 'mailto:'...
    $text =~ s/(^|[\s\(])(?:mailto\:)*([a-zA-Z0-9\-\_\.\+]+)\@([a-zA-Z0-9\-\_\.]+)\.([a-zA-Z0-9\-\_]+)(?=[\s\.\,\;\:\!\?\)])/$1 . $this->_mailtoLink( $2, $3, $4 )/gem;

    # Handle [[][] and [[]] links
    # Escape rendering: Change " ![[..." to " [<nop>[...", for final unrendered " [[..." output
    $text =~ s/(^|\s)\!\[\[/$1\[<nop>\[/gm;
    # Spaced-out Wiki words with alternative link text
    # i.e. [[$1][$3]]
    $text =~ s/\[\[([^\]]+)\](\[([^\]]+)\])?\]/$this->_handleSquareBracketedLink($theWeb,$theTopic,$3,$1)/ge;

    $text = $this->takeOutBlocks( $text, "noautolink", $removed );
    unless( $this->{NOAUTOLINK} ) {

        # do normal WikiWord link if not disabled by <noautolink> or
        # NOAUTOLINK preferences variable
        # Handle WikiWords 
        # " WebName.TopicName#anchor" or (WebName.TopicName#anchor) -> currentWeb, explicit web, topic, anchor
        $text =~ s/(^|[\s\(])(($TWiki::regex{webNameRegex})\.)?($TWiki::regex{wikiWordRegex}|$TWiki::regex{abbrevRegex})($TWiki::regex{anchorRegex})?/$1.$this->_handleWikiWord($theWeb,$3,$4,$5)/geom;
    }
    $this->putBackBlocks( $text, $removed, "noautolink" );
    $text =~ s/<\/?noautolink>//gi;

    $this->putBackBlocks( $text, $removed, "pre" );

    # DEPRECATED plugins hook after PRE re-inserted
    $this->plugins()->endRenderingHandler( $text );

    # replace verbatim with pre in the final output
    $this->putBackBlocks( $text, $removed,
                          "verbatim", "pre", \&verbatimCallBack );

    $text =~ s|\n?<nop>\n$||o; # clean up clutch

    $this->putBackBlocks( $text, $removed, "head" );

    $text = "$doctype$text";

    $this->plugins()->postRenderingHandler( $text );

    return $text;
}

sub _handleMailto {
    my ( $this, $text ) = @_;
    if ( $text =~ /^([^\s\@]+)\s+(.+)$/ ) {
        return $this->_mailtoLinkSimple( $1, $2 );
    } elsif ( $text =~ /^([a-zA-Z0-9\-\_\.\+]+)\@([a-zA-Z0-9\-\_\.]+)\.(.+?)(\s+|\]\[)(.*)$/ ) {
        # Explicit [[mailto:... ]] link including '@', with anti-spam 
        # padding, so match name@subdom.dom.
        # '[[mailto:string display text]]' link
        return $this->_mailtoLinkFull( $1, $2, $3, $5 );
    } else {
        # format not matched
        return "::mailto:$text::";
    }
}

=pod

---++ StaticMethod verbatimCallBack

Callback for use with putBackBlocks that replaces &lt; and >
by their HTML entities &amp;lt; and &amp;gt;

=cut

sub verbatimCallBack {
    my $val = shift;

    $val =~ s/&/&amp;/g;
    $val =~ s/</&lt;/g;
    $val =~ s/>/&gt;/g;
    # SMELL: A shame to do this, but been in TWiki.org have converted
    # 3 spaces to tabs since day 1
    $val =~ s/\t/   /g;

    return $val;
}

=pod

---++ ObjectMethod renderMetaTags (  $theWeb, $theTopic, $text, $meta, $isTopRev, $noexpand ) -> $html

   * =$theWeb - name of the web
   * =$theTopic - name of the topic
   * =$text - text being expanded
   * =$meta - meta-data object
   * =$isTopRev |- if this topic is being rendered at the most recent revision
   * =$noexpand= - if META tags are simply to be removed
Used to render %META{}% tags in templates for non-active views
(view, preview etc)

=cut

sub renderMetaTags {
    my( $this, $theWeb, $theTopic, $text, $meta, $isTopRev, $noexpand ) = @_;
    ASSERT(ref($this) eq "TWiki::Render") if DEBUG;

    if ( $noexpand ) {
        # SMELL - should the {} in the following be \} ?
        $text =~ s/%META{[^}]*}%//go;
        return $text;
    }

    $text =~ s/%META{\s*"form"\s*}%/$this->_renderFormData( $theWeb, $theTopic, $meta )/ge;    #this renders META:FORM and META:FIELD
    $text =~ s/%META{\s*"formfield"\s*(.*?)}%/$this->_renderFormField( $meta, $1 )/ge;                 #TODO: what does this do? (is this the old forms system, and so can be deleted)
    $text =~ s/%META{\s*"attachments"\s*(.*)}%/$this->attach()->renderMetaData( $theWeb,
                                                $theTopic, $meta, $1, $isTopRev )/ge;                                       #renders attachment tables
    $text =~ s/%META{\s*"moved"\s*}%/$this->_renderMoved( $theWeb, $theTopic, $meta )/ge;      #render topic moved information
    $text =~ s/%META{\s*"parent"\s*(.*)}%/$this->_renderParent( $theWeb, $theTopic, $meta, $1 )/ge;    #render the parent information

    $text = $this->{session}->handleCommonTags( $text, $theWeb, $theTopic );
    $text = $this->getRenderedVersion( $text, $theWeb, $theTopic );

    return $text;
}

=pod

---++ ObjectMethod TML2PlainText( $text, $web, $topic, $opts ) -> $plainText

Clean up TWiki text for display as plain text without pushing it
through the full rendering pipeline. Intended for generation of
topic and change summaries. Adds nop tags to prevent TWiki 
subsequent rendering; nops get removed at the very end.

Defuses TML.

$opts:
   * showvar - shows !%VAR% names
   * expandvar - expands !%VARS%
   * nohead - strips ---+ headings at the top of the text

=cut

sub TML2PlainText {
    my( $this, $text, $web, $topic, $opts ) = @_;
    ASSERT(ref($this) eq "TWiki::Render") if DEBUG;

    $opts = "" unless( $opts );
    if( $opts =~ /expandvar/ ) {
        $text =~ s/(\%)(SEARCH){/$1<nop>$2/g; # prevent recursion
        $text = $this->{session}->handleCommonTags( $text, $web, $topic );
    }
    $text =~ s/\r//g;  # SMELL, what about OS10?
    $text =~ s/%META:[A-Z].*?}%//g;  # remove meta data SMELL

    # Format e-mail to add spam padding (HTML tags removed later)
    $text =~ s/([\s\(])(?:mailto\:)*([a-zA-Z0-9\-\_\.\+]+)\@([a-zA-Z0-9\-\_\.]+)\.([a-zA-Z0-9\-\_]+)(?=[\s\.\,\;\:\!\?\)])/$1 . $this->_mailtoLink( $2, $3, $4 )/ge;
    $text =~ s/<\!\-\-.*?\-\->//gs;     # remove all HTML comments
    $text =~ s/<\!\-\-.*$//s;           # cut HTML comment
    $text =~ s/<\/?nop *\/?>/${TWiki::TranslationToken}NOP/g; # save <nop>
    $text =~ s/<[^>]*>//g;              # remove all HTML tags
    $text =~ s/\&[a-z]+;/ /g;           # remove entities
    $text =~ s/%WEB%/$web/g;
    $text =~ s/%TOPIC%/$topic/g;
    $text =~ s/%(WIKITOOLNAME)%/$this->{session}->{SESSION_TAGS}{$1}/g;
    if( $opts =~ /nohead/ ) {
        # skip headings on top
        while( $text =~ s/^\s*\-\-\-+\+[^\n\r]+// ) {}; # remove heading
    }
    unless( $opts =~ /showvar/ ) {
        # remove variables
        $text =~ s/%[A-Z_]+%//g;        # remove %VARS%
        $text =~ s/%[A-Z_]+{.*?}%//g;   # remove %VARS{}%
    }
    $text =~ s/\[\[([^\]]*\]\[|[^\s]*\s)(.*?)\]\]/$2/g; # keep only link text of [[][]]
    $text =~ s/[\[\]\*\|=_\&\<\>]/ /g;  # remove Wiki formatting chars
    $text =~ s/${TWiki::TranslationToken}NOP/<nop>/g;  # restore <nop>
    $text =~ s/\%(\w)/\%<nop>$1/g;      # defuse %VARS%
    $text =~ s/\!(\w)/<nop>$1/g;        # escape !WikiWord escapes
    $text =~ s/\-\-\-+\+*\s*\!*/ /g;    # remove heading formatting
    $text =~ s/\s+[\+\-]*/ /g;          # remove newlines and special chars
    $text =~ s/^\s+//;                  # remove leading whitespace
    $text =~ s/\s+$//;                  # remove trailing whitespace

    return $text;
}

=pod

---++ ObjectMethod protectPlainText($text) -> $tml

Protect plain text from expansions that would normally be done
duing rendering, such as wikiwords. Topic summaries, for example,
have to be protected this way.

=cut

sub protectPlainText {
    my( $this, $text ) = @_;

    # Encode special chars into XML &#nnn; entities for use in RSS feeds
    # - no encoding for HTML pages, to avoid breaking international 
    # characters. Only works for ISO-8859-1 sites, since the Unicode
    # encoding (&#nnn;) is identical for first 256 characters. 
    # I18N TODO: Convert to Unicode from any site character set.
    if( $this->{MODE} eq 'rss' and $TWiki::siteCharset =~ /^iso-?8859-?1$/i ) {
        $text =~ s/([\x7f-\xff])/"\&\#" . unpack( "C", $1 ) .";"/ge;
    }

    # prevent text from getting rendered in inline search and link tool
    # tip text by escaping links (external, internal, Interwiki)
    $text =~ s/([\s\(])((($TWiki::regex{webNameRegex})\.)?($TWiki::regex{wikiWordRegex}|$TWiki::regex{abbrevRegex}))/$1<nop>$2/g;
    $text =~ s/([\-\*\s])($TWiki::regex{linkProtocolPattern}\:)/$1<nop>$2/go;
    $text =~ s/@([a-zA-Z0-9\-\_\.]+)/@<nop>$1/g;	# email address

    return $text;
}

=pod

---++ ObjectMethod makeTopicSummary (  $theText, $theTopic, $theWeb, $theFlags ) -> $tml

Makes a plain text summary of the given topic by simply trimming a bit
off the top. Truncates to 162 chars or, if a number is specified in $theFlags,
to that length.

=cut

sub makeTopicSummary {
    my( $this, $theText, $theTopic, $theWeb, $theFlags ) = @_;
    ASSERT(ref($this) eq "TWiki::Render") if DEBUG;
    $theFlags ||= "";
    # called by search, mailnotify & changes after calling readFile

    my $htext = $this->TML2PlainText( $theText, $theWeb, $theTopic, $theFlags);

    # FIXME I18N: Avoid splitting within multi-byte characters (e.g. EUC-JP
    # encoding) by encoding bytes as Perl UTF-8 characters in Perl 5.8+. 
    # This avoids splitting within a Unicode codepoint (or a UTF-16
    # surrogate pair, which is encoded as a single Perl UTF-8 character),
    # but we ideally need to avoid splitting closely related Unicode codepoints.
    # Specifically, this means Unicode combining character sequences (e.g.
    # letters and accents) - might be better to split on word boundary if
    # possible.

    # limit to n chars
    my $nchar = $theFlags;
    unless( $nchar =~ s/^.*?([0-9]+).*$/$1/ ) {
        $nchar = 162;
    }
    $nchar = 16 if( $nchar < 16 );
    $htext =~ s/(.{$nchar})($TWiki::regex{mixedAlphaNumRegex})(.*?)$/$1$2 \.\.\./;

    return $this->protectPlainText( $htext );
}

=pod

---++ ObjectMethod setPageMode( $mode )

Set page rendering mode:
   * rss - encode 8-bit characters as XML entities
   * html - (default) no encoding of 8-bit characters

=cut

sub setRenderMode {
    my $this = shift;
    $this->{MODE} = shift;
}

=pod

---++ ObjectMethod takeOutBlocks( \$text, $tag, \%map ) -> $text

   * =$text= - Text to process
   * =$tag= - XHTML-style tag.
   * =\%map= - Reference to a hash to contain the removed blocks

Return value: $text with blocks removed

Searches through $text and extracts blocks delimited by a tag, appending each
onto the end of the @buffer and replacing with a token
string which is not affected by TWiki rendering.  The text after these
substitutions is returned.

Parameters to the open tag are recorded.

=cut

sub takeOutBlocks {
    my( $this, $intext, $tag, $map ) = @_;
    ASSERT(ref($this) eq "TWiki::Render") if DEBUG;

    return $intext unless ( $intext =~ m/<$tag>/ );

    my $open = qr/^\s*<$tag(\s[^>]+)?>(.*)$/i;
    my $close = qr/^\s*<\/$tag>(.*)$/i;
    my $out = "";
    my $depth = 0;
    my $scoop;
    my $tagParams;
    my $n = 0;

    foreach my $line ( split/\r?\n/, $intext ) {
        if ( $line =~ m/$open/ ) {
            unless ( $depth++ ) {
                $scoop = $2 || "";
                next;
            }
            $tagParams = $1;
        }
        if ( $depth && $line =~ m/$close/ ) {
            my $rest = $1;
            unless ( --$depth ) {
                my $placeholder = "$tag$n";
                $map->{$placeholder}{params} = $tagParams;
                $map->{$placeholder}{text} = $scoop;
                $line = "<!--$TWiki::TranslationToken$placeholder$TWiki::TranslationToken-->$rest";
                $n++;
            }
        }
        if ( $depth ) {
            $scoop .= "$line\n";
        } else {
            $out .= "$line\n";
        }
    }

    if ( $depth ) {
        # This would generate matching close tags
        # while ( $depth-- ) {
        #     $scoop .= "</$tag>\n";
        # }
        my $placeholder = "$tag$n";
        $map->{$placeholder}{params} = $tagParams;
        $map->{$placeholder}{text} = $scoop;
        $out .= "<!--$TWiki::TranslationToken$placeholder$TWiki::TranslationToken-->\n";
    }

    return $out;
}

=pod

---++ ObjectMethod putBackBlocks( $text, \%map, $tag, $newtag, $callBack ) -> $text

Return value: $text with blocks added back
   * =$text= - text to process
   * =\%map= - map placeholders to blocks removed by takeOutBlocks
   * =$tag= - Tag name processed by takeOutBlocks
   * =$newtag= - Tag name to use in output, in place of $tag. If undefined, uses $tag.
   * =$callback= - Reference to function to call on each block being inserted (optional)

Reverses the actions of takeOutBlocks.

Each replaced block is processed by the callback (if there is one) before
re-insertion.

Parameters to the outermost cut block are replaced into the open tag,
even if that tag is changed. This allows things like
&lt;verbatim class="">
to be mapped to
&lt;pre class="">

Cool, eh what? Jolly good show.

=cut

sub putBackBlocks {
    my( $this, $text, $map, $tag, $newtag, $callback ) = @_;
    ASSERT(ref($this) eq "TWiki::Render") if DEBUG;

    $newtag ||= $tag;
    my @k = keys %$map;
    foreach my $placeholder ( @k ) {
        if( $placeholder =~ /^$tag\d+$/ ) {
            my $params = $map->{$placeholder}{params} || "";
            my $val = $map->{$placeholder}{text};
            $val = &$callback( $val ) if ( defined( $callback ));
            $_[1] =~ s|<!--$TWiki::TranslationToken$placeholder$TWiki::TranslationToken-->|<$newtag$params>\n$val</$newtag>|;
            delete( $map->{$placeholder} );
        }
    }
}

=pod

---++ ObjectMethod renderRevisionInfo($web, $topic, $rev, $format) -> $string

Obtain and render revision info for a topic.
   * =$web= - the web of the topic
   * =$topic= - the topic
   * =$rev= - the rev number, defaults to latest rev
   * =$format= - the render format, defaults to =$rev - $time - $wikiusername=
=$format= can contain the following keys for expansion:
   | =$web= | the web name |
   | =$topic= | the topic name |
   | =$rev= | the rev number |
   | =$date= | the date of the rev (no time) |
   | =$time= | the full date and time of the rev |
   | =$comment= | the comment |
   | =$username= | the login of the saving user |
   | =$wikiname= | the wikiname of the saving user |
   | =$wikiusername= | the web.wikiname of the saving user |

=cut

sub renderRevisionInfo {
    my( $this, $web, $topic, $rev, $format ) = @_;

    if( $rev ) {
        $rev = $this->store()->cleanUpRevID( $rev );
    }

    my( $meta, $text ) =
      $this->store()->readTopic( undef, $web, $topic, $rev );

    my( $date, $user, $comment );
    ( $date, $user, $rev, $comment ) =
      $meta->getRevisionInfo( $web, $topic, $rev );

    my $wun = "";
    my $wn = "";
    my $un = "";
    if( $user ) {
        $wun = $user->webDotWikiName();
        $wn = $user->wikiName();
        $un = $user->login();
    }

    my $value = $format || "\$rev - \$time - \$wikiusername";
    $value =~ s/\$web/$web/gi;
    $value =~ s/\$topic/$topic/gi;
    $value =~ s/\$rev/r$rev/gi;
    $value =~ s/\$time/TWiki::Time::formatTime($date)/gei;
    $value =~ s/\$date/TWiki::Time::formatTime($date, "\$day \$mon \$year")/gei;
    $value =~ s/\$comment/$comment/gi;
    $value =~ s/\$username/$un/gi;
    $value =~ s/\$wikiname/$wn/gi;
    $value =~ s/\$wikiusername/$wun/gi;

    return $value;
}

1;
