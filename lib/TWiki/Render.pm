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

use TWiki::Attach;

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
        $ah = TWiki::extractParameters( $args );
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
    my $text = "";
    my %parentMeta = $meta->findOne( "TOPICPARENT" );
    my $parent;
    $parent = $parentMeta{name} if %parentMeta;
    my @stack;

    while( $parent ) {
        my $pTopic = $parent;
        if( $parent =~ /^(.*)\.(.*)$/ ) {
            $pWeb = $1;
            $pTopic = $2;
        }
        $parent = "$pWeb.$pTopic";
        last if( $noWebHome && ( $pTopic eq $TWiki::cfg{HomeTopicName} ) ||
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
    my %moved = $meta->findOne( "TOPICMOVED" );

    if( %moved ) {
        my $from = $moved{"from"};
        $from =~ /(.*)\.(.*)/;
        my $fromWeb = $1;
        my $fromTopic = $2;
        my $to   = $moved{"to"};
        $to =~ /(.*)\.(.*)/;
        my $toWeb = $1;
        my $toTopic = $2;
        my $by   = $moved{"by"};
        my $u = $this->users()->findUser( $by );
        $by = $u->webDotWikiName() if $u;
        my $date = $moved{"date"};
        $date = TWiki::formatTime( $date, "", "gmtime" );

        # Only allow put back if current web and topic match stored information
        my $putBack = "";
        if( $web eq $toWeb && $topic eq $toTopic ) {
            $putBack  = " - <a title=\"Click to move topic back to previous location, with option to change references.\"";
            $putBack .= " href=\"".$this->{session}->getScriptUrl($web, $topic, 'rename')."?newweb=$fromWeb&newtopic=$fromTopic&";
            $putBack .= "confirm=on\">put it back</a>";
        }
        $text = "<i><nop>$to moved from <nop>$from on $date by $by </i>$putBack";
    }
    return $text;
}


sub _renderFormField {
    my( $this, $meta, $args ) = @_;
    my $text = "";
    if( $args ) {
        my $name = TWiki::extractNameValuePair( $args, "name" );
        $text = TWiki::Search::getMetaFormField( $meta, $name ) if( $name );
    }
    return $text;
}

sub _renderFormData {
    my( $this, $web, $topic, $meta ) = @_;
    my $metaText = "";
    my %form = $meta->findOne( "FORM" );

    if( %form ) {
        my $name = $form{"name"};
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
            push( @$result, "<$theElement>\n" ) unless( $firstTime );
            push( @$result, "<$theType>\n" );
            $firstTime = 0;
            $size++;
        }
    } else {
        while( $size > $depth ) {
            my $tags = pop( @{$this->{LIST}} );
            push( @$result, "</$tags->{element}>\n" );
            push( @$result, "</$tags->{type}>\n" );
            $size--;
        }
        if ($size) {
            push( @$result, "</$this->{LIST}->[$size-1]->{element}>\n" );
        }
    }

    if ( $size ) {
        my $oldt = $this->{LIST}->[$size-1];
        if( $oldt->{type} ne $theType ) {
            push( @$result, "</$oldt->{type}>\n<$theType>\n" );
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
    $text =~ s/\$date/TWiki::formatTime( $date )/ge;
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

   * =$theWeb= - the web containing the topic
   * =$theTopic= - the topic to be lunk
   * =$theLinkText= - text to use for the link
   * =$theAnchor= - the link anchor, if any
   * =$doLink= - boolean: false means suppress link for non-existing pages
   * =$doKeepWeb= - boolean: true to keep web prefix (for non existing Web.TOPIC)

=cut

sub internalLink {
    my( $this, $theWeb, $theTopic, $theLinkText, $theAnchor, $doLink, $doKeepWeb ) = @_;
    ASSERT(ref($this) eq "TWiki::Render") if DEBUG;

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

     # Allow spacing out, etc
     if (TWiki::isValidWikiWord($theLinkText)) {
        $theLinkText = $this->plugins()->renderWikiWordHandler( $theLinkText ) || $theLinkText;
     }

    my $exist = $this->store()->topicExists( $theWeb, $theTopic );

    # I18N - Only apply plural processing if site language is English, or
    # if a built-in English-language web (Main, TWiki or Plugins).  Plurals
    # apply to names ending in 's', where topic doesn't exist with plural
    # name.
    if(  ( $TWiki::cfg{PluralToSingular} ) and ( $TWiki::siteLang eq 'en' 
					or $theWeb eq $TWiki::cfg{UsersWebName}
					or $theWeb eq $TWiki::cfg{SystemWebName}
					or $theWeb eq 'Plugins' 
				     ) 
	    and ( $theTopic =~ /s$/ ) and not ( $exist ) ) {
        # Topic name is plural in form and doesn't exist as written
        my $tmp = $theTopic;
        $tmp =~ s/ies$/y/;       # plurals like policy / policies
        $tmp =~ s/sses$/ss/;     # plurals like address / addresses
        $tmp =~ s/([Xx])es$/$1/; # plurals like box / boxes
        $tmp =~ s/([A-Za-rt-z])s$/$1/; # others, excluding ending ss like address(es)
        if( $this->store()->topicExists( $theWeb, $tmp ) ) {
            $theTopic = $tmp;
            $exist = 1;
        }
    }

    my $text = "";
    if( $exist) {
        if( $theAnchor ) {
            my $anchor = $this->makeAnchorName( $theAnchor );
            $text .= "<a class=\"twikiAnchorLink\" href=\"".
				$this->{session}->getScriptUrl($theWeb, $theTopic, 'view')."\#$anchor\""
                  .  $this->_linkToolTipInfo( $theWeb, $theTopic )
                  .  ">$theLinkText</a>";
            return $text;
        } else {
            $text .= "<a class=\"twikiLink\" href=\""
				  .	$this->{session}->getScriptUrl($theWeb, $theTopic, 'view') ."\""
                  .  $this->_linkToolTipInfo( $theWeb, $theTopic )
                  .  ">$theLinkText</a>";
            return $text;
        }

    } elsif( $doLink ) {
        $text .= "<span class=\"twikiNewLink\" style='background : $this->{NEWTOPICBGCOLOR};'>"
              .  "<font color=\"$this->{NEWTOPICFONTCOLOR}\">$theLinkText</font>"
              .  "<a href=\"".
				$this->{session}->getScriptUrl($theWeb, $theTopic, 'edit')."?topicparent="
                .$this->{session}->{webName}.".".$this->{session}->{topicName}."\">$this->{NEWLINKSYMBOL}</a></span>";
        return $text;

    } elsif( $doKeepWeb ) {
        $text .= "$theWeb.$theLinkText";
        return $text;

    } else {
        $text .= $theLinkText;
        return $text;
    }
}

# Handle specific links of the form:
# format: [[$theText]]
# format: [[$theLink][$theText]]
sub _specificLink {
    my( $this, $theWeb, $theTopic, $theText, $theLink ) = @_;

    $theText = $theLink unless defined( $theText );

    # Current page's $theWeb and $theTopic are also used

    # Strip leading/trailing spaces
    $theLink =~ s/^\s*//;
    $theLink =~ s/\s*$//;

    if( $theLink =~ /^$TWiki::regex{linkProtocolPattern}\:/ ) {
        if ( $theLink =~ /^(\S+)\s+(.*)$/ ) {
            # '[[URL#anchor display text]]' link:
            $theLink = $1;
            $theText = $2;
        } else {
            # '[[Web.odd wiki word#anchor][display text]]' link:
            # '[[Web.odd wiki word#anchor]]' link:

            # External link: add <nop> before WikiWord and ABBREV 
            # inside link text, to prevent double links
            $theText =~ s/([\s\(])([$TWiki::regex{upperAlpha}])/$1<nop>$2/go;
        }
        return "<a href=\"$theLink\" target=\"_top\">$theText</a>";
    }

    # Internal link: get any 'Web.' prefix, or use current web
    $theLink =~ s/^($TWiki::regex{webNameRegex}|$TWiki::regex{defaultWebNameRegex})\.//;
    my $web = $1 || $theWeb;
    (my $baz = "foo") =~ s/foo//;       # reset $1, defensive coding

    # Extract '#anchor'
    # FIXME and NOTE: Had '-' as valid anchor character, removed
    # $theLink =~ s/(\#[a-zA-Z_0-9\-]*$)//;
    $theLink =~ s/($TWiki::regex{anchorRegex}$)//;
    my $anchor = $1 || "";

    # Get the topic name
    my $topic = $theLink || $theTopic;  # remaining is topic
    $topic =~ s/\&[a-z]+\;//gi;        # filter out &any; entities
    $topic =~ s/\&\#[0-9]+\;//g;       # filter out &#123; entities
    $topic =~ s/[\\\/\#\&\(\)\{\}\[\]\<\>\!\=\:\,\.]//g;
    $topic =~ s/$TWiki::cfg{NameFilter}//go;    # filter out suspicious chars
    if( ! $topic ) {
        return $theText; # no link if no topic
    }

    return $this->internalLink( $web, $topic, $theText, $anchor, 1 );
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

    return $this->getRenderedVersion( $text, $web );
}

=pod

---++ ObjectMethod getRenderedVersion (  $text, $theWeb, $meta  ) -> $html

The main rendering function.

=cut

sub getRenderedVersion {
    my( $this, $text, $theWeb, $meta ) = @_;
    ASSERT(ref($this) eq "TWiki::Render") if DEBUG;
    my( $head, $result, $extraLines, $insidePRE, $insideTABLE, $insideNoAutoLink );

    return "" unless $text;  # nothing to do

    # FIXME: Get $theTopic from parameter to handle [[#anchor]] correctly
    # (fails in %INCLUDE%, %SEARCH%)
    my $theTopic = $this->{session}->{topicName};

    if( !$theWeb ) {
        $theWeb = $this->{session}->{webName};
    }

    $head = "";
    $result = "";
    $insidePRE = 0;
    $insideTABLE = 0;
    $insideNoAutoLink = 0;

    @{$this->{LIST}} = ();

    # Initial cleanup
    $text =~ s/\r//g;
    # clutch to enforce correct rendering at end of doc
    $text =~ s/(\n?)$/\n<nop>\n/s;
    # Convert any occurrences of token (very unlikely - details in
    # Codev.NationalCharTokenClash)
    $text =~ s/$TWiki::TranslationToken/!/go;	

    my @verbatim = ();
    $text = $this->takeOutBlocks( $text, "verbatim", \@verbatim );

    $text =~ s/\\\n//gs;  # Join lines ending in "\"

    # do not render HTML head, style sheets and scripts
    # SMELL: this is easily defeated by <body in a comment in the head
    if( $text =~ m/<body[\s\>]/i ) {
        my $bodyTag = "";
        my $bodyText = "";
        ( $head, $bodyTag, $bodyText ) = split( /(<body)/i, $text, 3 );
        $text = $bodyTag . $bodyText;
    }

    # Wiki Plugin Hook
    $this->plugins()->startRenderingHandler( $text, $theWeb, $meta );

    my $isList = 0;		# True when within a list

    my @lines = split( /\n/, $text );
    my @result;

    while ( scalar( @lines ) ) {
        my $line = shift( @lines );

        # change state:
        if ( $line =~ m/<pre>/i ) {
            $insidePRE = 1;
        }
        if ( $line =~ m/<\/pre>/i ) {
            $insidePRE = 0;
        }
        if ( $line =~ m/<noautolink>/i ) {
            $insideNoAutoLink = 1;
        }
        if ( $line =~ m/<\/noautolink>/i ) {
            $insideNoAutoLink = 0;
        }

        if( $insidePRE ) {
            # inside <PRE>

            # close list tags if any
            if( @{$this->{LIST}} ) {
                $this->_addListItem( \@result, "", "", "" );
                $isList = 0;
            }

            # Wiki Plugin Hook
            $this->plugins()->insidePREHandler( $line );

            # \n is required inside PRE blocks
            push( @result, "$line\n" );

            next;
        }

        # normal state, do Wiki rendering

        $this->plugins()->outsidePREHandler( $line );

        # insert any extra lines generated by the plugin. New lines
        # are inserted at the head of the queue of lines, in the order
        # they would appear in the text.
        if ( $line =~ /\n/ ) {
            unshift( @lines, split( /\n/, $line ));
            # need to do full processing on these new lines, so start again
            next;
        }

        # Escape rendering: Change " !AnyWord" to " <nop>AnyWord",
        # for final " AnyWord" output
        $line =~ s/(^|[\s\(])\!(?=[\w\*\=])/$1<nop>/g;

        # Blockquoted email (indented with '> ')
        $line =~ s/^>(.*?)$/> <cite> $1 <\/cite><br \/>/g;

        # locate isolated < and > and translate to entities
        # Protect isolated <!-- and -->
        $line =~ s/<!--/{$TWiki::TranslationToken!--/g;
        $line =~ s/-->/--}$TWiki::TranslationToken/g;
        # SMELL: this next fragment is a frightful hack, to handle the
        # case where simple HTML tags (i.e. without values) are embedded
        # in the values provided to other tags. The only way to do this
        # correctly (i.e. handle HTML tags with values as well) is to
        # parse the HTML (bleagh!)
        $line =~ s/<(\/[A-Za-z]+)>/{$TWiki::TranslationToken$1}$TWiki::TranslationToken/g;
        $line =~ s/<([A-Za-z]+(\s+\/)?)>/{$TWiki::TranslationToken$1}$TWiki::TranslationToken/g;
        $line =~ s/<(\S.*?)>/{$TWiki::TranslationToken$1}$TWiki::TranslationToken/g;
        # entitify lone < and >, praying that we haven't screwed up :-(
        $line =~ s/</&lt\;/g;
        $line =~ s/>/&gt\;/g;
        $line =~ s/{$TWiki::TranslationToken/</go;
        $line =~ s/}$TWiki::TranslationToken/>/go;

        # standard URI
        $line =~ s/(^|[\-\*\s\(])($TWiki::regex{linkProtocolPattern}\:([^\s\<\>\"]+[^\s\.\,\!\?\;\:\)\<]))/$this->_externalLink($1,$2)/geo;

        # other entities
        $line =~ s/&(\w+?)\;/$TWiki::TranslationToken$1\;/g;      # "&abc;"
        $line =~ s/&(\#[0-9]+)\;/$TWiki::TranslationToken$1\;/g;  # "&#123;"
        $line =~ s/&/&amp;/g;                              # escape standalone "&"
        $line =~ s/$TWiki::TranslationToken/&/go;

        # Headings
        # '<h6>...</h6>' HTML rule
        $line =~ s/$TWiki::regex{headerPatternHt}/$this->_makeAnchorHeading($2,$1)/geoi;
        # '\t+++++++' rule
        $line =~ s/$TWiki::regex{headerPatternSp}/$this->_makeAnchorHeading($2,(length($1)))/geo;
        # '----+++++++' rule
        $line =~ s/$TWiki::regex{headerPatternDa}/$this->_makeAnchorHeading($2,(length($1)))/geo;

        # Horizontal rule
        $line =~ s/^---+/<hr \/>/;

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

        # '#WikiName' anchors
        $line =~ s/^(\#)($TWiki::regex{wikiWordRegex})/ '<a name="' . $this->makeAnchorName( $2 ) . '"><\/a>'/geo;

        # enclose in white space for the regex that follow
        $line = "\n$line\n";

        # Emphasizing
        $line =~ s/([\s\(])==([^\s]+?|[^\s].*?[^\s])==([\s\,\.\;\:\!\?\)])/$1 . $this->_fixedFontText( $2, 1 ) . $3/ge;
        $line =~ s/([\s\(])__([^\s]+?|[^\s].*?[^\s])__([\s\,\.\;\:\!\?\)])/$1<strong><em>$2<\/em><\/strong>$3/g;
        $line =~ s/([\s\(])\*([^\s]+?|[^\s].*?[^\s])\*([\s\,\.\;\:\!\?\)])/$1<strong>$2<\/strong>$3/g;
        $line =~ s/([\s\(])_([^\s]+?|[^\s].*?[^\s])_([\s\,\.\;\:\!\?\)])/$1<em>$2<\/em>$3/g;
        $line =~ s/([\s\(])=([^\s]+?|[^\s].*?[^\s])=([\s\,\.\;\:\!\?\)])/$1 . $this->_fixedFontText( $2, 0 ) . $3/ge;

        # Mailto
        # Email addresses must always be 7-bit, even within I18N sites

        # FIXME: check security...
        # Explicit [[mailto:... ]] link without an '@' - hence no 
        # anti-spam padding needed.
        # '[[mailto:string display text]]' link (no '@' in 'string'):
        $line =~ s/\[\[mailto:(.*?)\]\]/$this->_handleMailto($1)/geo;

        # Normal mailto:foo@example.com ('mailto:' part optional)
        # FIXME: Should be '?' after the 'mailto:'...
        $line =~ s/([\s\(])(?:mailto\:)*([a-zA-Z0-9\-\_\.\+]+)\@([a-zA-Z0-9\-\_\.]+)\.([a-zA-Z0-9\-\_]+)(?=[\s\.\,\;\:\!\?\)])/$1 . $this->_mailtoLink( $2, $3, $4 )/ge;

        # Handle [[][] and [[]] links
        # Escape rendering: Change " ![[..." to " [<nop>[...", for final unrendered " [[..." output
        $line =~ s/(\s)\!\[\[/$1\[<nop>\[/g;
        # Spaced-out Wiki words with alternative link text
        $line =~ s/\[\[([^\]]+)\](\[([^\]]+)\])?\]/$this->_specificLink($theWeb,$theTopic,$3,$1)/ge;

        # do normal WikiWord link if not disabled by <noautolink> or
        # NOAUTOLINK preferences variable
        unless( $this->{NOAUTOLINK} || $insideNoAutoLink ) {
            # Handle all styles of TWiki link in one hit
            $line =~ s/([\s\(])(($TWiki::regex{webNameRegex})\.)?($TWiki::regex{wikiWordRegex}|$TWiki::regex{abbrevRegex})($TWiki::regex{anchorRegex})?/$1.$this->_handleLink($theWeb,$3,$4,$5)/geo;
#CCCC            $line =~ s/$TWiki::TranslationToken(\S.*?)$TWiki::TranslationToken/$1/go;
ASSERT($line !~ /$TWiki::TranslationToken/);
        }

        $line =~ s/\n//;

        push( @result, $line );
    }
    if( $insideTABLE ) {
        push( @result, "</table>" );
    }
    $this->_addListItem( \@result, "", "", "" );

    if( $insidePRE ) {
        push( @result, "</pre>" );
    }

    my $res = join( "", @result );
    $res =~ s/\t/   /g;

    # Wiki Plugin Hook
    $this->plugins()->endRenderingHandler( $res );

    # replace verbatim with pre in the final output
    $result = $this->putBackBlocks( $res, \@verbatim, "verbatim",
                                    "pre", \&verbatimCallBack );

    $result =~ s|\n?<nop>\n$||o; # clean up clutch
    return "$head$result";
}

# Handle the various link constructions
sub _handleLink {
    my ( $this, $theWeb, $web, $topic, $anchor ) = @_;

    my $linkIfAbsent = 1;
    my $keepWeb = 0;
    my $text;

    if ( defined( $web )) {
        if ( defined( $anchor ) ) {
            # 'Web.TopicName#anchor' or 'Web.ABBREV#anchor' link
            $text = "$topic$anchor";
        } else {
            $anchor = "";
            # 'Web.TopicName' or 'Web.ABBREV' link:
            if ( $topic eq $TWiki::cfg{HomeTopicName} && $web ne $this->{session}->{webName} ) {
                $text = $web;
            } else {
                $text = $topic;
            }
            $keepWeb =
              ( $topic =~ /^$TWiki::regex{abbrevRegex}$/o );
        }
    } else {
        $web = $theWeb;
        if ( defined( $anchor )) {
            # 'TopicName#anchor' or 'ABBREV#anchor' link:
            $text = "$topic$anchor";
        } else {
            # 'TopicName' or 'ABBREV' link:
            $anchor = "";
            $text = $topic;
            $linkIfAbsent =
              ( $topic !~ /^$TWiki::regex{abbrevRegex}$/o );;
        }
    }

    return $this->internalLink( $web, $topic, $text,
                         $anchor, $linkIfAbsent, $keepWeb );
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
        $text =~ s/%META{[^}]*}%//go;
        return $text;
    }

    $text =~ s/%META{\s*"form"\s*}%/$this->_renderFormData( $theWeb, $theTopic, $meta )/ge;    #this renders META:FORM and META:FIELD
    $text =~ s/%META{\s*"formfield"\s*(.*?)}%/$this->_renderFormField( $meta, $1 )/ge;                 #TODO: what does this do? (is this the old forms system, and so can be deleted)
    $text =~ s/%META{\s*"attachments"\s*(.*)}%/$this->attach()->renderMetaData( $theWeb,
                                                $theTopic, $meta, $1, $isTopRev )/ge;                                       #renders attachment tables
    $text =~ s/%META{\s*"moved"\s*}%/$this->_renderMoved( $theWeb, $theTopic, $meta )/ge;      #render topic moved information
    $text =~ s/%META{\s*"parent"\s*(.*)}%/$this->_renderParent( $theWeb, $theTopic, $meta, $1 )/ge;    #render the parent information

    $text = $this->{session}->handleCommonTags( $text, $theTopic );
    $text = $this->getRenderedVersion( $text, $theWeb );

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
        $text = $this->{session}->handleCommonTags( $text, $topic, $web );
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

---++ ObjectMethod takeOutBlocks( $text, $tag, \@buffer ) -> $text

   * =$text= - Text to process
   * =$tag= - XHTML-style tag.
   * =\@buffer= - Reference to an array to contain the remove blocks

Return value: $text with blocks removed

Searches through $text and extracts blocks delimited by a tag, appending each
onto the end of the @buffer and replacing with a token
string which is not affected by TWiki rendering.  The text after these
substitutions is returned.

Parameters to the open tag are recorded.

=cut

sub takeOutBlocks {
    my( $this, $intext, $tag, $buffer ) = @_;
    ASSERT(ref($this) eq "TWiki::Render") if DEBUG;

    return $intext unless ( $intext =~ m/<$tag>/ );

    my $open = qr/^\s*<$tag(\s[^>]+)?>\s*$/i;
    my $close = qr/^\s*<\/$tag>\s*$/i;
    my $out = "";
    my $depth = 0;
    my $scoop;
    my $tagParams;

    foreach my $line ( split/\r?\n/, $intext ) {
        if ( $line =~ m/$open/ ) {
            unless ( $depth++ ) {
                $scoop = "";
                next;
            }
            $tagParams = $1;
        }
        if ( $depth && $line =~ m/$close/ ) {
            unless ( --$depth ) {
                push( @$buffer, { params=>$tagParams, text=>$scoop } );
                $line = "%_$tag$#$buffer%";
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
        push( @$buffer, { params=>$tagParams, text=>$scoop } );
        $out .= "%_$tag$#$buffer%\n";
    }

    return $out;
}

=pod

---++ ObjectMethod putBackBlocks( $text, \@buffer, $tag, $newtag, $callBack ) -> $text

Return value: $text with blocks added back
   * =$text= - text to process
   * =$buffer= - Buffer of removed blocks generated by takeOutBlocks
   * =$tag= - Tag name processed by takeOutBlocks
   * =$newtag= - Tag name to use in output, in place of $tag (optional)
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
    my( $this, $text, $buffer, $tag, $newtag, $callback ) = @_;
    ASSERT(ref($this) eq "TWiki::Render") if DEBUG;

    $newtag = $tag unless defined( $newtag );

    for( my $i = $#$buffer; $i >= 0; $i-- ) {
        my $params = $buffer->[$i]{params} || "";
        my $val = $buffer->[$i]{text};
        $val = &$callback( $val ) if ( defined( $callback ));
        $text =~ s|%_$tag$i%|<$newtag$params>\n$val</$newtag>|;
    }

    return $text;
}

=end twiki

=cut

1;
