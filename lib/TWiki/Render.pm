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

---+ package TWiki::Render

This module provides most of the actual HTML rendering code in TWiki.

=cut

package TWiki::Render;

use strict;
use Assert;

# Use -any to force creation of functions for unrecognised tags, like del and ins,
# on earlier releases of CGI.pm (pre 2.79)
use CGI qw( -any );

use TWiki::Plurals;
use TWiki::Attach;
use TWiki::Attrs;
use TWiki::Time;

# defaults for trunctation of summary text
my $TMLTRUNC = 162;
my $PLAINTRUNC = 70;
my $MINTRUNC = 16;
# max number of lines in a summary (best to keep it even)
my $SUMMARYLINES = 6;

# limiting lookbehind and lookahead for wikiwords and emphasis
# use like \b
my $STARTWW = qr/^|(?<=[\s\(])/m;
my $ENDWW = qr/$|(?=[\s\,\.\;\:\!\?\)])/m;

=pod

---++ ClassMethod new ($session)

Creates a new renderer with initial state from preference values
(NEWTOPICBGCOLOR, NEWTOPICFONTCOLOR NEWTOPICLINKSYMBOL
 LINKTOOLTIPINFO)

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( {}, $class );
    ASSERT($session->isa( 'TWiki')) if DEBUG;

    # Do a dynamic 'use locale' for this module
    if( $TWiki::cfg{UseLocale} ) {
        require locale;
    }

    $this->{session} = $session;

    $this->{MODE} = 'html';        # Default is to render as HTML
    $this->{NEWTOPICBGCOLOR} =
      $session->{prefs}->getPreferencesValue('NEWTOPICBGCOLOR')
        || '#FFFFCE';
    $this->{NEWTOPICFONTCOLOR} =
      $session->{prefs}->getPreferencesValue('NEWTOPICFONTCOLOR')
        || '#0000FF';
    $this->{NEWLINKSYMBOL} =
      $session->{prefs}->getPreferencesValue('NEWTOPICLINKSYMBOL')
        || CGI::sup('?');
    # tooltip init
    $this->{LINKTOOLTIPINFO} =
      $session->{prefs}->getPreferencesValue('LINKTOOLTIPINFO')
        || '';
    $this->{LINKTOOLTIPINFO} = '$username - $date - r$rev: $summary'
      if( TWiki::isTrue( $this->{LINKTOOLTIPINFO} ));

    return $this;
}

sub _renderParent {
    my( $this, $web, $topic, $meta, $args ) = @_;

    my $ah;

    if( $args ) {
        $ah = new TWiki::Attrs( $args );
    }
    my $dontRecurse = $ah->{dontrecurse} || 0;
    my $noWebHome =   $ah->{nowebhome} || 0;
    my $prefix =      $ah->{prefix} || '';
    my $suffix =      $ah->{suffix} || '';
    my $usesep =      $ah->{separator} || ' &gt; ';

    my %visited;
    $visited{$web.'.'.$topic} = 1;

    my $sep = '';
    my $pWeb = $web;
    my $pTopic;
    my $text = '';
    my $parentMeta = $meta->get( 'TOPICPARENT' );
    my $parent;
    my $store = $this->{session}->{store};

    $parent = $parentMeta->{name} if $parentMeta;

    my @stack;

    while( $parent ) {
        ( $pWeb, $pTopic ) =
          $this->{session}->normalizeWebTopicName( $pWeb, $parent );
        $parent = $pWeb.'.'.$pTopic;
        last if( $noWebHome &&
                 ( $pTopic eq $TWiki::cfg{HomeTopicName} ) ||
                 $dontRecurse ||
                 $visited{$parent} );
        $visited{$parent} = 1;
        unshift( @stack, "[[$parent][$pTopic]]" );
        $parent = $store->getTopicParent( $pWeb, $pTopic );
    }
    $text = join( $usesep, @stack );

    if( $text) {
        $text = $prefix.$text if ( $prefix );
        $text .= $suffix if ( $suffix );
    }

    return $text;
}

sub _renderMoved {
    my( $this, $web, $topic, $meta ) = @_;
    my $text = '';
    my $moved = $meta->get( 'TOPICMOVED' );
    $web =~ s#\.#/#go;

    if( $moved ) {
        my( $fromWeb, $fromTopic ) =
          $this->{session}->normalizeWebTopicName( $web, $moved->{from} );
        my( $toWeb, $toTopic ) =
          $this->{session}->normalizeWebTopicName( $web, $moved->{to} );
        my $by = $moved->{by};
        my $u = $this->{session}->{users}->findUser( $by );
        $by = $u->webDotWikiName() if $u;
        my $date = TWiki::Time::formatTime( $moved->{date}, '', 'gmtime' );

        # Only allow put back if current web and topic match stored information
        my $putBack = '';
        if( $web eq $toWeb && $topic eq $toTopic ) {
            $putBack  = ' - '.
              CGI::a( { title=>'Click to move topic back to previous location, with option to change references.',
                        href => $this->{session}->getScriptUrl
                        ($web, $topic,
                         'rename',
                         newweb => $fromWeb,
                         newtopic => $fromTopic,
                         confirm => 'on' ),
                        rel => 'nofollow'
                      },
                      'put it back' );
        }
        $text = CGI::i("<nop>$toWeb.<nop>$toTopic moved from <nop>$fromWeb".
          ".<nop>$fromTopic on $date by $by ").$putBack;
    }
    return $text;
}

sub _renderFormField {
    my( $this, $meta, $args ) = @_;
    my $text = '';
    if( $args ) {
        my $attrs = new TWiki::Attrs( $args );
        my $name = $attrs->{name};
        $text = renderFormFieldArg( $meta, $name ) if( $name );
    }
    # change any new line character sequences to <br />
    $text =~ s/(\n\r?)|(\r\n?)+/ <br \/> /gos;
    # escape "|" to HTML entity
    $text =~ s/\|/\&\#124;/gos;
    return $text;
}

sub _renderFormData {
    my( $this, $web, $topic, $meta ) = @_;
    my $form = $meta->get( 'FORM' );

    return '' unless( $form );

    my $name = $form->{name};
    my $metaText = CGI::Tr( CGI::th( { class => 'twikiFirstCol',
                                       colspan => 2 },
                                     '[['.$name.']]' ));
    my @fields = $meta->find( 'FIELD' );
    foreach my $field ( @fields ) {
        my $fa = $field->{attributes} || '';
        unless ( $fa =~ /H/ ) {
            my $value = $field->{value} || '&nbsp;';
            $metaText .= CGI::Tr( { valign => 'top' },
                                  CGI::td( { class => 'twikiFirstCol',
                                             align => 'right' },
                                           ' '.$field->{title}.':' ).
                                  CGI::td( ' '.$value.' ' ));
        }
    }
    return CGI::div( { class => 'twikiForm' },
                     CGI::table( { border => 1 }, $metaText ));
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

    unless( $insideTABLE ) {
        $thePre .=
          CGI::start_table({ border=>1, cellspacing=>0, cellpadding=>1} );
    }

    $theRow =~ s/\t/   /g;  # change tabs to space
    $theRow =~ s/\s*$//;    # remove trailing spaces
    $theRow =~ s/(\|\|+)/$TWiki::TranslationToken.length($1).'|'/ge;  # calc COLSPAN
    my $cells = '';
    foreach( split( /\|/, $theRow ) ) {
        my @attr;

        # Avoid matching single columns
        if ( s/$TWiki::TranslationToken([0-9]+)//o ) {
            push( @attr, colspan => $1 );
        }
        s/^\s+$/ &nbsp; /;
        my( $l1, $l2 ) = ( 0, 0 );
        if( /^(\s*).*?(\s*)$/ ) {
            $l1 = length( $1 );
            $l2 = length( $2 );
        }
        if( $l1 >= 2 ) {
            if( $l2 <= 1 ) {
                push( @attr, align => 'right' );
            } else {
                push( @attr, align => 'center' );
            }
        }
        if( /^\s*\*(.*)\*\s*$/ ) {
            push( @attr, bgcolor => '#99CCCC' );
            $cells .= CGI::th( { @attr }, CGI::strong( $1 ));
        } else {
            $cells .= CGI::td( { @attr }, " $_" );
        }
    }
    return $thePre.CGI::Tr( $cells );
}

sub _fixedFontText {
    my( $theText, $theDoBold ) = @_;
    # preserve white space, so replace it by '&nbsp; ' patterns
    $theText =~ s/\t/   /g;
    $theText =~ s|((?:[\s]{2})+)([^\s])|'&nbsp; ' x (length($1) / 2) . $2|eg;
    $theText = CGI::b( $theText ) if $theDoBold;
    return CGI::code( $theText );
}

# Build an HTML &lt;Hn> element with suitable anchor for linking from %<nop>TOC%
sub _makeAnchorHeading {
    my( $this, $theHeading, $theLevel ) = @_;

    # - Build '<nop><h1><a name='atext'></a> heading </h1>' markup
    # - Initial '<nop>' is needed to prevent subsequent matches.
    # - filter out $TWiki::regex{headerPatternNoTOC} ( '!!' and '%NOTOC%' )
    # CODE_SMELL: Empty anchor tags seem not to be allowed, but validators and browsers tolerate them

    my $anchorName =       $this->makeAnchorName( $theHeading, 0 );
    my $compatAnchorName = $this->makeAnchorName( $theHeading, 1 );
    # filter '!!', '%NOTOC%'
    $theHeading =~ s/$TWiki::regex{headerPatternNoTOC}//o;
    my $text = "<nop><h$theLevel>";
    $text .= CGI::a( { name=>$anchorName }, "" );
    $text .= CGI::a( { name=>$compatAnchorName }, "") if( $compatAnchorName ne $anchorName );
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
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;

    if ( ! $compatibilityMode && $anchorName =~ /^$TWiki::regex{anchorRegex}$/ ) {
    # accept, already valid -- just remove leading #
    return substr($anchorName, 1);
    }

    # strip out potential links so they don't get rendered.  Screws up header rendering.
    $anchorName =~ s/\s*\[\s*\[.*?\]\s*\[(.*?)\]\s*\]/$1/go; # remove double bracket link 
    $anchorName =~ s/\s*\[\s*\[\s*(.*?)\s*\]\s*\]/$1/go; # remove double bracket link
    $anchorName =~ s/($TWiki::regex{wikiWordRegex})/_$1/go; # add an _ before bare WikiWords

    if ( $compatibilityMode ) {
    # remove leading/trailing underscores first, allowing them to be
    # reintroduced
    $anchorName =~ s/^[\s\#\_]*//;
        $anchorName =~ s/[\s\_]*$//;
    }
    $anchorName =~ s/<[\/]?\w[^>]*>//gi;         # remove HTML tags
    $anchorName =~ s/\&\#?[a-zA-Z0-9]*;//g; # remove HTML entities
    $anchorName =~ s/\&//g;                 # remove &
    $anchorName =~ s/^(.+?)\s*$TWiki::regex{headerPatternNoTOC}.*/$1/o; # filter TOC excludes if not at beginning
    $anchorName =~ s/$TWiki::regex{headerPatternNoTOC}//o; # filter '!!', '%NOTOC%'

    # For most common alphabetic-only character encodings (i.e. iso-8859-*), remove non-alpha characters 
    if( defined($TWiki::cfg{Site}{CharSet}) && $TWiki::cfg{Site}{CharSet} =~ /^iso-?8859-?/i ) {
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

# Returns =title='...'= tooltip info in case LINKTOOLTIPINFO perferences variable is set. 
# Warning: Slower performance if enabled.
sub _linkToolTipInfo {
    my( $this, $theWeb, $theTopic ) = @_;
    return '' unless( $this->{LINKTOOLTIPINFO} );
    return '' if( $this->{LINKTOOLTIPINFO} =~ /^off$/i );

    # FIXME: This is slow, it can be improved by caching topic rev info and summary
    my $store = $this->{session}->{store};
    # SMELL: we ought not to have to fake this. Topic object model, please!!
    my $meta = new TWiki::Meta( $this->{session}, $theWeb, $theTopic );
    my( $date, $user, $rev ) = $meta->getRevisionInfo();
    my $text = $this->{LINKTOOLTIPINFO};
    $text =~ s/\$web/<nop>$theWeb/g;
    $text =~ s/\$topic/<nop>$theTopic/g;
    $text =~ s/\$rev/1.$rev/g;
    $text =~ s/\$date/TWiki::Time::formatTime( $date )/ge;
    $text =~ s/\$username/<nop>$user/g;                                     # 'jsmith'
    $text =~ s/\$wikiname/'<nop>' . $user->wikiName()/ge;  # 'JohnSmith'
    $text =~ s/\$wikiusername/'<nop>' . $user->webDotWikiName()/ge; # 'Main.JohnSmith'
    if( $text =~ /\$summary/ ) {
        my $summary = $store->readTopicRaw
          ( undef, $theWeb, $theTopic, undef );
        $summary = $this->makeTopicSummary( $summary, $theTopic, $theWeb );
        $summary =~ s/[\"\']/<nop>/g;       # remove quotes (not allowed in title attribute)
        $text =~ s/\$summary/$summary/g;
    }
    return $text;
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

Calls _renderWikiWord, which in turn will use Plurals.pm to match fold plurals to equivalency with their singular form 

SMELL: why is this available to Func?

=cut

sub internalLink {
    my( $this, $theWeb, $theTopic, $theLinkText, $theAnchor, $doLinkToMissingPages, $doKeepWeb ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;
    # SMELL - shouldn't it be callable by TWiki::Func as well?

    #PN: Webname.Subweb -> Webname/Subweb
    $theWeb =~ s/\./\//go;
    #PN: Webname/Subweb/ -> Webname/Subweb
    $theWeb =~ s/\/\Z//o;

    if($theLinkText eq $theWeb) {
      $theLinkText =~ s/\//\./go;
    }


    # Get rid of leading/trailing spaces in topic name
    $theTopic =~ s/^\s*//o;
    $theTopic =~ s/\s*$//o;

    # Turn spaced-out names into WikiWords - upper case first letter of
    # whole link, and first of each word. TODO: Try to turn this off,
    # avoiding spaces being stripped elsewhere
    $theTopic =~ s/^(.)/\U$1/;
    $theTopic =~ s/\s([$TWiki::regex{mixedAlphaNum}])/\U$1/go;    

    # Add <nop> before WikiWord inside link text to prevent double links
    $theLinkText =~ s/(?<=[\s\(])([$TWiki::regex{upperAlpha}])/<nop>$1/go;

    return _renderWikiWord($this, $theWeb, $theTopic, $theLinkText, $theAnchor, $doLinkToMissingPages, $doKeepWeb);
}

# TODO: this should be overridable by plugins.
sub _renderWikiWord {
    my ($this, $theWeb, $theTopic, $theLinkText, $theAnchor, $doLinkToMissingPages, $doKeepWeb) = @_;
    my $store = $this->{session}->{store};
    my $topicExists = $store->topicExists( $theWeb, $theTopic );

    my $singular = '';
    unless( $topicExists ) {
        # topic not found - try to singularise
        $singular = TWiki::Plurals::singularForm($theWeb, $theTopic);
        if( $singular ) {
            $topicExists = $store->topicExists( $theWeb, $singular );
            $theTopic = $singular if $topicExists;
        }
    }

    if( $topicExists) {
        return _renderExistingWikiWord($this, $theWeb,
                                       $theTopic, $theLinkText, $theAnchor);
    }
    if( $doLinkToMissingPages ) {
        my @topics = ( $theTopic );
        # CDot: disabled until SuggestSingularNotPlural is resolved
        # if ($singular && $singular ne $theTopic) {
        #     #unshift( @topics, $singular);
        # }
        return _renderNonExistingWikiWord($this, $theWeb, \@topics,
                                          $theLinkText, $theAnchor);
    }
    if( $doKeepWeb ) {
        return $theWeb.'.'.$theLinkText;
    }

    return $theLinkText;
}

sub _renderExistingWikiWord {
    my ($this, $theWeb, $theTopic, $theLinkText, $theAnchor) = @_;

    my @attrs;
    my $href = $this->{session}->getScriptUrl($theWeb, $theTopic, 'view');
    if( $theAnchor ) {
        my $anchor = $this->makeAnchorName( $theAnchor );
        push( @attrs, class => 'twikiAnchorLink', href => $href.'#'.$anchor );
    } else {
        push( @attrs, class => 'twikiLink', href => $href );
    }
    my $tooltip = $this->_linkToolTipInfo( $theWeb, $theTopic );
    push( @attrs, title => $tooltip ) if $tooltip;
    return CGI::a( { @attrs }, $theLinkText );
}

sub _renderNonExistingWikiWord {
    my ($this, $theWeb, $theTopic, $theLinkText, $theAnchor) = @_;
    my $ans;

    $ans = $theLinkText;

    if (ref $theTopic && ref $theTopic eq 'ARRAY') {
        my $num = 1;
        foreach my $t(@{ $theTopic }) {
            next if ! $t;
            $ans .= CGI::a( { href=>$this->{session}->getScriptUrl
                      ($theWeb, $t, 'edit',
                       topicparent => $this->{session}->{webName}.'.'.
                       $this->{session}->{topicName} ),
                       rel=>'nofollow',
                       title=>'Create this topic'
                    },
                    $this->{NEWLINKSYMBOL} x $num . " " );
            $num++;
        }
    } else {
        $ans .= CGI::a( { href=>$this->{session}->getScriptUrl
                      ($theWeb, $theTopic, 'edit',
                       topicparent => $this->{session}->{webName}.'.'.
                       $this->{session}->{topicName} ),
                       rel=>'nofollow',
                       title=>'Create this topic'
                    },
                    $this->{NEWLINKSYMBOL} );
    }
    return CGI::span( { class=>'twikiNewLink' },
                      $ans );
}

# NOTE: factored for clarity. Test for any speed penalty.
# returns the (web, topic) 
#SMELL - we must have implemented this elsewhere?
sub _getWeb {
    # Internal link: get any 'Web.' prefix, or use current web
    my ($theLink) = @_;
    $theLink =~ s/^($TWiki::regex{webNameRegex}|$TWiki::regex{defaultWebNameRegex})\.//;
    my $web = $1;

    (my $baz = 'foo') =~ s/foo//;       # reset $1, defensive coding
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
        $anchor = '' ;
    }

    if ( defined( $anchor ) ) {
        # 'Web.TopicName#anchor' or 'Web.ABBREV#anchor' link
        $text = $topic.$anchor;
    } else {
        $anchor = '';

        # 'Web.TopicName' or 'Web.ABBREV' link:
        if ( $topic eq $TWiki::cfg{HomeTopicName} &&
             $web ne $this->{session}->{webName} ) {
            $text = $web;
        } else {
            $text = $topic;
        }
    }

    # Allow spacing out, etc
    $text = $this->{session}->{plugins}->renderWikiWordHandler( $text ) || $text;

    # =$doKeepWeb= boolean: true to keep web prefix (for non existing Web.TOPIC)
    # SMELL: Why set keepWeb when the topic is an abbreviation?
    # NO IDEA, and it doesn't work anyway; it adds 'TWiki.' in front
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
    if( $theLink =~ /^$TWiki::regex{linkProtocolPattern}\:/ ) {
        return _protocolLink($theLink, $theText);
    }
    my $web;
    ($web, $theLink) = _getWeb($theLink);
    $web = $theWeb unless ($web);

    # Extract '#anchor'
    # FIXME and NOTE: Had '-' as valid anchor character, removed
    # $theLink =~ s/(\#[a-zA-Z_0-9\-]*$)//;
    my $anchor = '';
    if( $theLink =~ s/($TWiki::regex{anchorRegex}$)// ) {
        $anchor = $1;
    }

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
    my ($url, $theText) = @_;

    if ( $url =~ /^(\S+)\s+(.*)$/ ) {
        # '[[URL#anchor display text]]' link:
        $url = $1;
        $theText = $2;

    } else {
        # '[[Web.odd wiki word#anchor][display text]]' link:
        # '[[Web.odd wiki word#anchor]]' link:
        # External link: add <nop> before WikiWord and ABBREV
        # inside link text, to prevent double links
        # SMELL - why regex{upperAlpha} here - surely this is a web
        # match, not a CAPWORD match?
        $theText =~ s/(?<=[\s\(])([$TWiki::regex{upperAlpha}])/<nop>$1/go;
    }
    return CGI::a( { href=>$url, target=>'_top' }, $theText );
}

# Handle an external link typed directly into text. If it's an image
# (as indicated by the file type), then use an img tag, otherwise
# generate a link.
sub _externalLink {
    my( $this, $pre, $url ) = @_;

    if( $url =~ /\.(gif|jpg|jpeg|png)$/i ) {
        my $filename = $url;
        $filename =~ s@.*/([^/]*)@$1@go;
        return $pre.CGI::img( { src => $url, alt => $filename } );
    }
    return $pre.CGI::a( { href => $url, target => '_top' }, $url );
}

sub _unprotectedMailLink {
    my( $this, $addr, $text ) = @_;
    $text ||= $addr;
    return CGI::a( { href=>'mailto:'.$addr }, $text );
}

sub _spamProtectedMailLink {
    my( $this, $theAccount, $theSubDomain, $theTopDomain, $text ) = @_;

    my $addr = $theAccount.'@'.$theSubDomain.
      $TWiki::cfg{AntiSpam}{EmailPadding}.'.'.$theTopDomain;

    return $this->_mailToLinkSimple( $addr, $text );
}

# Handle [[mailto:...]]
sub _handleMailto {
    my ( $this, $text ) = @_;
    if ( $text =~ /^([^\s\@]+)\s+(.+)$/ ) {
        # e.g. mailto:fred
        return $this->_unprotectedMailLink( $1, $2 );

    } elsif ( $text =~ /^([\w\-\_\.\+]+)\@([\w\-\_\.]+)\.(.+?)(\s+|\]\[)(.*)$/ ) {
        # [[mailto:... ]] link including '@'
        # '[[mailto:string display text]]' link
        return $this->_spamProtectedMailLink( $1, $2, $3, $5 );
    } else {
        # format not matched
        return '::mailto:'.$text.'::';
    }
}

=pod

---++ ObjectMethod filenameToIcon (  $fileName  ) -> $html

Fetches an image file from an image directory, mapped from _filetypes.txt (on basis of the file extension). Calls _getSkinIconTopicPath to get the attachment topic path from preference variable ICONTOPIC. 

Prerequisites:
    - ICONTOPIC must be defined, as Web.TopicName or as TopicName (then %WEB%.TopicName is used)
    - The file _filetypes.txts hould be in the same directory as the image attachments
    
used in: Attach::_expandAttrs

=cut

sub filenameToIcon {
    my( $this, $fileName ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;

    my @bits = ( split( /\./, $fileName ) );
    my $fileExt = lc $bits[$#bits];

    my $iconUrl = $TWiki::cfg{PubUrlPath}.'/'.$this->_getSkinIconTopicPath();
    # SMELL: use of direct access to PubDir violates store encapsulation
    my $iconDir = $TWiki::cfg{PubDir}.'/'.$this->_getSkinIconTopicPath();

    my $store = $this->{session}->{store};
    # The file _filetypes.txt should be in the same directory as the image attachments
    my $iconList = $store->readFile( $iconDir.'/_filetypes.txt' );
    foreach( split( /\n/, $iconList ) ) {
        @bits = ( split( / / ) );
        if( $bits[0] eq $fileExt ) {
            return CGI::img( { src => "$iconUrl/$bits[1].gif",
                               width => 16, height=>16, align => 'top',
                               alt => '', border => 0 } );
        }
    }
    return CGI::img( { src => "$iconUrl/else.gif",
                       width => 16, height => 16, align => 'top', alt => '',
                       border => 0 } );
}

=pod

---++ ObjectMethod getDocGraphic (  $iconName  ) -> $html

Creates an image tag from an icon name. Calls getDocGraphicFilePath to get the attachment topic path from preference variable ICONTOPIC.

Prerequisites:
    - ICONTOPIC must be defined, as Web.TopicName or as TopicName (then %WEB%.TopicName is used)
    
used in: TWiki::_ICON
    
=cut

sub getDocGraphic {
    my( $this, $iconName ) = @_;
    my $docGraphicFilePath = $this->getDocGraphicFilePath( $iconName );
    return CGI::img( { src => $docGraphicFilePath,
                       align => 'top', alt => '', border => 0 } );
}

=pod

---++ ObjectMethod getDocGraphicFilePath (  $iconName  ) -> $iconFilePath

Creates an image file path from an icon name. Calls _getSkinIconTopicPath to get the attachment topic path from preference variable ICONTOPIC.

Prerequisites:
    - ICONTOPIC must be defined, as Web.TopicName or as TopicName (then %WEB%.TopicName is used)
    
used in: getDocGraphic, TWiki::_ICONPATH
    
=cut

sub getDocGraphicFilePath {
    my( $this, $iconName ) = @_;
    ASSERT(ref($this) eq 'TWiki::Render') if DEBUG;
    my $iconUrl = $TWiki::cfg{PubUrlPath}.'/'.$this->_getSkinIconTopicPath();
    my $iconFilePath = $iconUrl.'/'.$iconName.'.gif';
    return $iconFilePath;
}

=pod

---++ ObjectMethod _getSkinIconTopicPath (  ) -> $skinIconTopicPath

Reads the variable ICONTOPIC from the preferences, and returns a relative file path (url) to this topic. Web.TopicName becomes Web/TopicName; TopicName becomes %WEB%.TopicName.
    
=cut

sub _getSkinIconTopicPath {
    my( $this ) = @_;
    my $session = $this->{session};
    my $prefs = $session->{prefs};
    my $web = $session->{webName};
    my $skinIconTopicPath = $prefs->getPreferencesValue('ICONTOPIC');
    # Remove whitespace at end
    $skinIconTopicPath =~ s/\s*$//s;
    # If there is no dot in $skinIconTopicPath, no web has been specified; use the local web
    if ( index( $skinIconTopicPath, '.' ) == -1 ) {
        $skinIconTopicPath = $web.'.'.$skinIconTopicPath;
    }
    # Replace dot in Web.TopicName with slash to get the path: Web/TopicName
    $skinIconTopicPath =~ s/\./\//;
    return $skinIconTopicPath;
}

=pod

---++ ObjectMethod renderFormField ( %params, $topic, $web ) -> $html

Returns the fully rendered expansion of a %FORMFIELD{}% tag.

=cut

sub renderFormField {
    my ( $this, $params, $topic, $web ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;

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
        # return '' if ( $args =~ m/format\s*=/o);
        # Otherwise default to value
        $format = '$value';
    }

    my $formWeb;
    if ( $formTopic ) {
        if ($topic =~ /^([^.]+)\.([^.]+)/o) {
            ( $formWeb, $topic ) = ( $1, $2 );
        } else {
            # SMELL: Undocumented feature, 'web' parameter
            $formWeb = $params->{web};
        }
        $formWeb = $web unless $formWeb;
    } else {
        $formWeb = $web;
        $formTopic = $topic;
    }

    my $meta = $this->{ffCache}{$formWeb.'.'.$formTopic};
    my $store = $this->{session}->{store};
    unless ( $meta ) {
        my $dummyText;
        ( $meta, $dummyText ) =
          $store->readTopic( $this->{session}->{user}, $formWeb, $formTopic, undef );
        $this->{ffCache}{$formWeb.'.'.$formTopic} = $meta;
    }

    my $text = '';
    my $found = 0;
    if ( $meta ) {
        my @fields = $meta->find( 'FIELD' );
        foreach my $field ( @fields ) {
            my $title = $field->{title};
            my $name = $field->{name};
            if( $title eq $formField || $name eq $formField ) {
                $found = 1;
                my $value = $field->{value};
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

    return '' unless $text;

    return $this->getRenderedVersion( $text, $web, $topic );
}

=pod

---++ ObjectMethod getRenderedVersion ( $text, $theWeb, $theTopic ) -> $html

The main rendering function.

=cut

sub getRenderedVersion {
    my( $this, $text, $theWeb, $theTopic ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;
    my( $head, $result, $insideNoAutoLink );

    return '' unless $text;  # nothing to do

    $theTopic ||= $this->{session}->{topicName};
    $theWeb ||= $this->{session}->{webName};
    my $session = $this->{session};
    my $plugins = $session->{plugins};
    my $prefs = $session->{prefs};

    $head = '';
    $result = '';
    $insideNoAutoLink = 0;

    @{$this->{LIST}} = ();

    # Initial cleanup
    $text =~ s/\r//g;
    # clutch to enforce correct rendering at end of doc
    $text =~ s/\n?$/\n<nop>\n/s;
    # Convert any occurrences of token (very unlikely - details in
    # Codev.NationalCharTokenClash)
    # WARNING: since the token is used as a marker in takeOutBlocks,
    # be careful never to call this method on text which has already had
    # embedded blocks removed!
    $text =~ s/$TWiki::TranslationToken/!/go;    

    my $removed = {};    # Map of placeholders to tag parameters and text

    my $doctype = '';
    if( $text =~ s/(\s*<!DOCTYPE.*?>\s*)//is ) {
        $doctype = $1;
    }

    $text = $this->takeOutBlocks( $text, 'verbatim', $removed );
    $text = $this->takeOutBlocks( $text, 'head', $removed );

    # DEPRECATED startRenderingHandler before PRE removed
    # SMELL: could parse more efficiently if this wasn't
    # here.
    $plugins->startRenderingHandler( $text, $theWeb, $theTopic );

    $text = $this->takeOutBlocks( $text, 'pre', $removed );

    # Join lines ending in '\'
    $text =~ s/\\\n//gs;

    $plugins->preRenderingHandler( $text, $removed );

    if( $plugins->haveHandlerFor( 'insidePREHandler' )) {
        foreach my $region ( sort keys %$removed ) {
            next unless ( $region =~ /^pre\d+$/i );
            my @lines = split( /\n/, $removed->{$region}{text} );
            my $result = '';
            while ( scalar( @lines )) {
                my $line = shift( @lines );
                $plugins->insidePREHandler( $line );
                if ( $line =~ /\n/ ) {
                    unshift( @lines, split( /\n/, $line ));
                    next;
                }
                $result .= $line."\n";
            }
            $removed->{$region}{text} = $result;
        }
    }

    if( $plugins->haveHandlerFor( 'outsidePREHandler' )) {
        # DEPRECATED - this is the one call preventing
        # effective optimisation of the TWiki ML processing loop,
        # as it exposes the concept of a 'line loop' to plugins,
        # but HTML is not a line-oriented language (though TML is).
        # But without it, a lot of processing could be moved
        # outside the line loop.
        my @lines = split( /\n/, $text );
        my @result = ();
        while ( scalar( @lines ) ) {
            my $line = shift( @lines );
            $plugins->outsidePREHandler( $line );
            if ( $line =~ /\n/ ) {
                unshift( @lines, split( /\n/, $line ));
                next;
            }
            push( @result, $line );
        }

        $text = join("\n", @result );
    }

    # Escape rendering: Change ' !AnyWord' to ' <nop>AnyWord',
    # for final ' AnyWord' output
    $text =~ s/$STARTWW\!(?=[\w\*\=])/<nop>/gm;

    # Blockquoted email (indented with '> ')
    # Could be used to provide different colours for different numbers of '>'
    $text =~ s/^>(.*?)$/'&gt;'.CGI::cite( $1 ).CGI::br()/gem;

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
    $text =~ s/(^|[-*\s(])($TWiki::regex{linkProtocolPattern}:([^\s<>"]+[^\s*.,!?;:)<]))/$this->_externalLink($1,$2)/geo;

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
    my $hr = CGI::hr();
    $text =~ s/^---+/$hr/gm;

    # Now we really _do_ need a line loop, to process TML
    # line-oriented stuff.
    my $isList = 0;        # True when within a list
    my $insideTABLE = 0;
    my @result = ();

    foreach my $line ( split( /\n/, $text )) {
        # Table: | cell | cell |
        # allow trailing white space after the last |
        if( $line =~ m/^(\s*)\|.*\|\s*$/ ) {
            $line =~ s/^(\s*)\|(.*)/$this->_emitTR($1,$2,$insideTABLE)/e;
            $insideTABLE = 1;
        } elsif( $insideTABLE ) {
            push( @result, '</table>' );
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
                $this->_addListItem( \@result, 'dl', 'dd', $1, '' );
            }
            elsif ( $line =~ s/^((\t|   )+)(\S+?):\s/<dt> $3<\/dt><dd> /o ) {
                # Definition list
                $this->_addListItem( \@result, 'dl', 'dd', $1, '' );
            }
            elsif ( $line =~ s/^((\t|   )+)\* /<li> /o ) {
                # Unnumbered list
                $this->_addListItem( \@result, 'ul', 'li', $1, '' );
            }
            elsif ( $line =~ m/^((\t|   )+)([1AaIi]\.|\d+\.?) ?/ ) {
                # Numbered list
                my $ot = $3;
                $ot =~ s/^(.).*/$1/;
                if( $ot !~ /^\d$/ ) {
                    $ot = ' type="'.$ot.'"';
                } else {
                    $ot = '';
                }
                $line =~ s/^((\t|   )+)([1AaIi]\.|\d+\.?) ?/<li$ot> /;
                $this->_addListItem( \@result, 'ol', 'li', $1, $ot );
            }
            else {
                $isList = 0;
            }
        }

        # Finish the list
        if( ! $isList ) {
            $this->_addListItem( \@result, '', '', '' );
            $isList = 0;
        }

        push( @result, $line );
    }

    if( $insideTABLE ) {
        push( @result, '</table>' );
    }
    $this->_addListItem( \@result, '', '', '' );

    $text = join("\n", @result );

    # '#WikiName' anchors
    $text =~ s/^(\#)($TWiki::regex{wikiWordRegex})/CGI::a( { name=>$this->makeAnchorName( $2 )}, '')/geom;

    $text =~ s/${STARTWW}==([^\s]+?|[^\s].*?[^\s])==$ENDWW/_fixedFontText($1,1)/gem;
    $text =~ s/${STARTWW}__([^\s]+?|[^\s].*?[^\s])__$ENDWW/<strong><em>$1<\/em><\/strong>/gm;
    $text =~ s/${STARTWW}\*([^\s]+?|[^\s].*?[^\s])\*$ENDWW/<strong>$1<\/strong>/gm;
    $text =~ s/${STARTWW}\_([^\s]+?|[^\s].*?[^\s])\_$ENDWW/<em>$1<\/em>/gm;
    $text =~ s/${STARTWW}\=([^\s]+?|[^\s].*?[^\s])\=$ENDWW/_fixedFontText($1,0)/gem;

    # Mailto
    # Email addresses must always be 7-bit, even within I18N sites

    # FIXME: check security...
    # Explicit [[mailto:... ]] link without an '@' - hence no 
    # anti-spam padding needed.
    # '[[mailto:string display text]]' link (no '@' in 'string'):
    $text =~ s/\[\[mailto:(.*?)\]\]/$this->_handleMailto($1)/geo;

    # Normal mailto:foo@example.com ('mailto:' part optional)
    # FIXME: Should be '?' after the 'mailto:'...
    $text =~ s/$STARTWW(?:mailto\:)*([a-zA-Z0-9\-\_\.\+]+)\@([a-zA-Z0-9\-\_\.]+)\.([a-zA-Z0-9\-\_]+)$ENDWW/$this->_spamProtectedMailLink( $1, $2, $3 )/gem;

    # Handle [[][] and [[]] links
    # Escape rendering: Change ' ![[...' to ' [<nop>[...', for final unrendered ' [[...' output
    $text =~ s/(^|\s)\!\[\[/$1\[<nop>\[/gm;
    # Spaced-out Wiki words with alternative link text
    # i.e. [[$1][$3]]
    $text =~ s/\[\[([^\]]+)\](\[([^\]]+)\])?\]/$this->_handleSquareBracketedLink($theWeb,$theTopic,$3,$1)/ge;

    unless( $prefs->getPreferencesFlag('NOAUTOLINK') ) {
        # Handle WikiWords
        $text = $this->takeOutBlocks( $text, 'noautolink', $removed );
        $text =~ s/$STARTWW(?:($TWiki::regex{webNameRegex})\.)?($TWiki::regex{wikiWordRegex}|$TWiki::regex{abbrevRegex})($TWiki::regex{anchorRegex})?/$this->_handleWikiWord($theWeb,$1,$2,$3)/geom;
        $this->putBackBlocks( \$text, $removed, 'noautolink' );
    }

    $this->putBackBlocks( \$text, $removed, 'pre' );

    # DEPRECATED plugins hook after PRE re-inserted
    $plugins->endRenderingHandler( $text );

    # replace verbatim with pre in the final output
    $this->putBackBlocks( \$text, $removed,
                          'verbatim', 'pre', \&verbatimCallBack );

    $text =~ s|\n?<nop>\n$||o; # clean up clutch

    $this->putBackBlocks( \$text, $removed, 'head' );

    $text = $doctype.$text;

    $plugins->postRenderingHandler( $text );
    return $text;
}

=pod

---++ StaticMethod verbatimCallBack

Callback for use with putBackBlocks that replaces &lt; and >
by their HTML entities &amp;lt; and &amp;gt;

=cut

sub verbatimCallBack {
    my $val = shift;

    # SMELL: A shame to do this, but been in TWiki.org have converted
    # 3 spaces to tabs since day 1
    $val =~ s/\t/   /g;

    return TWiki::entityEncode( $val );
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
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;

    if ( $noexpand ) {
        $text =~ s/%META{[^}]*}%//go;
        return $text;
    }

    $text =~ s/%META{\s*"form"\s*}%/$this->_renderFormData( $theWeb, $theTopic, $meta )/ge;    #this renders META:FORM and META:FIELD
    $text =~ s/%META{\s*"formfield"\s*(.*?)}%/$this->_renderFormField( $meta, $1 )/ge;         #renders a formfield from within topic text
    $text =~ s/%META{\s*"attachments"\s*(.*)}%/$this->{session}->{attach}->renderMetaData( $theWeb, $theTopic, $meta, $1, $isTopRev )/ge;                                       #renders attachment tables
    $text =~ s/%META{\s*"moved"\s*}%/$this->_renderMoved( $theWeb, $theTopic, $meta )/ge;      #render topic moved information
    $text =~ s/%META{\s*"parent"\s*(.*)}%/$this->_renderParent( $theWeb, $theTopic, $meta, $1 )/ge;    #render the parent information

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
   * showvar - shows !%VAR% names if not expanded
   * expandvar - expands !%VARS%
   * nohead - strips ---+ headings at the top of the text
   * showmeta - does not filter meta-data

=cut

sub TML2PlainText {
    my( $this, $text, $web, $topic, $opts ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;
    $opts ||= '';

    $text =~ s/\r//g;  # SMELL, what about OS10?

    if( $opts =~ /showmeta/ ) {
        $text =~ s/%META:/%<nop>META:/g;
    } else {
        $text =~ s/%META:[A-Z].*?}%//g;
    }

    if( $opts =~ /expandvar/ ) {
        $text =~ s/(\%)(SEARCH){/$1<nop>$2/g; # prevent recursion
        $text = $this->{session}->handleCommonTags( $text, $web, $topic );
    } else {
        $text =~ s/%WEB%/$web/g;
        $text =~ s/%TOPIC%/$topic/g;
        $text =~ s/%(WIKITOOLNAME)%/$this->{session}->{SESSION_TAGS}{$1}/g;
        if( $opts =~ /showvar/ ) {
            $text =~ s/%(\w+({.*?}))%/\%$1/g; # defuse
        } else {
            $text =~ s/%$TWiki::regex{tagNameRegex}({.*?})?%//g;  # remove
        }
    }

    # Format e-mail to add spam padding (HTML tags removed later)
    $text =~ s/(?<=[\s\(])(?:mailto\:)*([a-zA-Z0-9\-\_\.\+]+)\@([a-zA-Z0-9\-\_\.]+)\.([a-zA-Z0-9\-\_]+)(?=[\s\.\,\;\:\!\?\)])/$this->_spamProtectedMailLink( $1, $2, $3 )/ge;
    $text =~ s/<\!\-\-.*?\-\->//gs;     # remove all HTML comments
    $text =~ s/<[^>]*>//g;              # remove all HTML tags
    $text =~ s/\&[a-z]+;/ /g;           # remove entities
    if( $opts =~ /nohead/ ) {
        # skip headings on top
        while( $text =~ s/^\s*\-\-\-+\+[^\n\r]+// ) {}; # remove heading
    }
    # keep only link text of [[][]]
    $text =~ s/\[\[([^\]]*\]\[|[^\s]*\s)(.*?)\]\]/$2/g;
    $text =~ s/[\[\]\*\|=_\&\<\>]/ /g;  # remove Wiki formatting chars
    $text =~ s/^\-\-\-+\+*\s*\!*/ /gm;  # remove heading formatting and hbar
    $text =~ s/[\+\-]+/ /g;             # remove special chars
    $text =~ s/^\s+//;                  # remove leading whitespace
    $text =~ s/\s+$//;                  # remove trailing whitespace
    $text =~ s/\n+/\n/s;
    $text =~ s/[ \t]+/ /s;

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
        $text =~ s/([\x7f-\xff])/"\&\#" . unpack( 'C', $1 ) .';'/ge;
    }

    # prevent text from getting rendered in inline search and link tool
    # tip text by escaping links (external, internal, Interwiki)
    $text =~ s/(?<=[\s\(])((($TWiki::regex{webNameRegex})\.)?($TWiki::regex{wikiWordRegex}|$TWiki::regex{abbrevRegex}))/<nop>$1/g;
    $text =~ s/(?<=[\-\*\s])($TWiki::regex{linkProtocolPattern}\:)/<nop>$1/go;
    $text =~ s/([@%])/@<nop>$1/g;    # email address, variable

    return $text;
}

=pod

---++ ObjectMethod makeTopicSummary (  $theText, $theTopic, $theWeb, $theFlags ) -> $tml

Makes a plain text summary of the given topic by simply trimming a bit
off the top. Truncates to $TMTRUNC chars or, if a number is specified in $theFlags,
to that length.

=cut

sub makeTopicSummary {
    my( $this, $theText, $theTopic, $theWeb, $theFlags ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;
    $theFlags ||= '';
    # called by search, mailnotify & changes after calling readFile

    my $htext = $this->TML2PlainText( $theText, $theWeb, $theTopic, $theFlags);
    $htext =~ s/\n+/ /g;
 
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
        $nchar = $TMLTRUNC;
    }
    $nchar = $MINTRUNC if( $nchar < $MINTRUNC );
    $htext =~ s/^(.{$nchar}.*?)($TWiki::regex{mixedAlphaNumRegex}).*$/$1$2 \.\.\./s;

    # newline conversion to permit embedding in TWiki tables
    $htext =~ s/\s+/ /g;

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
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;

    return $intext unless ( $intext =~ m/<$tag\b/ );

    my $open = qr/^\s*<$tag\b([^>]*)?>(.*)$/i;
    my $close = qr/^\s*<\/$tag>(.*)$/i;
    my $out = '';
    my $depth = 0;
    my $scoop;
    my $tagParams;
    my $n = 0;

    foreach my $line ( split/\r?\n/, $intext ) {
        if ( $line =~ m/$open/ ) {
            unless ( $depth++ ) {
                $tagParams = $1;
                $scoop = $2;
                next;
            }
        }
        if ( $depth && $line =~ m/$close/ ) {
            my $rest = $1;
            unless ( --$depth ) {
                my $placeholder = $tag.$n;
                $map->{$placeholder}{params} = $tagParams;
                $map->{$placeholder}{text} = $scoop;

                $line = '<!--'.$TWiki::TranslationToken.$placeholder.
                  $TWiki::TranslationToken.'-->'.$rest;
                $n++;
            }
        }
        if ( $depth ) {
            $scoop .= $line."\n";
        } else {
            $out .= $line."\n";
        }
    }

    if ( $depth ) {
        # This would generate matching close tags
        # while ( $depth-- ) {
        #     $scoop .= "</$tag>\n";
        # }
        my $placeholder = $tag.$n;
        $map->{$placeholder}{params} = $tagParams;
        $map->{$placeholder}{text} = $scoop;
        $out .= '<!--'.$TWiki::TranslationToken.$placeholder.
          $TWiki::TranslationToken."-->\n";
    }

    return $out;
}

=pod

---++ ObjectMethod putBackBlocks( \$text, \%map, $tag, $newtag, $callBack ) -> $text

Return value: $text with blocks added back
   * =\$text= - reference to text to process
   * =\%map= - map placeholders to blocks removed by takeOutBlocks
   * =$tag= - Tag name processed by takeOutBlocks
   * =$newtag= - Tag name to use in output, in place of $tag. If undefined, uses $tag.
   * =$callback= - Reference to function to call on each block being inserted (optional)

Reverses the actions of takeOutBlocks.

Each replaced block is processed by the callback (if there is one) before
re-insertion.

Parameters to the outermost cut block are replaced into the open tag,
even if that tag is changed. This allows things like
&lt;verbatim class=''>
to be mapped to
&lt;pre class=''>

Cool, eh what? Jolly good show.

=cut

sub putBackBlocks {
    my( $this, $text, $map, $tag, $newtag, $callback ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;

    $newtag ||= $tag;

    foreach my $placeholder ( keys %$map ) {
        if( $placeholder =~ /^$tag\d+$/ ) {
            my $params = $map->{$placeholder}{params} || '';
            my $val = $map->{$placeholder}{text};
            $val = &$callback( $val ) if ( defined( $callback ));
            $$text =~ s(<!--$TWiki::TranslationToken$placeholder$TWiki::TranslationToken-->)
              (<$newtag$params>\n$val</$newtag>);
            delete( $map->{$placeholder} );
        }
    }
}

=pod

---++ ObjectMethod renderRevisionInfo($web, $topic, $meta, $rev, $format) -> $string

Obtain and render revision info for a topic.
   * =$web= - the web of the topic
   * =$topic= - the topic
   * =$meta= if specified, get rev info from here. If not specified, or meta contains rev info for a different version than the one requested, will reload the topic
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
    my( $this, $web, $topic, $meta, $rrev, $format ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;
    my $store = $this->{session}->{store};

    if( $rrev ) {
        $rrev = $store->cleanUpRevID( $rrev );
    }

    unless( $meta ) {
        my $text;
        ( $meta, $text ) = $store->readTopic( undef, $web, $topic, $rrev );
    }
    my( $date, $user, $rev, $comment ) = $meta->getRevisionInfo( $rrev );

    my $wun = '';
    my $wn = '';
    my $un = '';
    if( $user ) {
        $wun = $user->webDotWikiName();
        $wn = $user->wikiName();
        $un = $user->login();
    }

    my $value = $format || '$rev - $time - $wikiusername';
    $value =~ s/\$web/$web/gi;
    $value =~ s/\$topic/$topic/gi;
    $value =~ s/\$rev/r$rev/gi;
    $value =~ s/\$time/TWiki::Time::formatTime($date)/gei;
    $value =~ s/\$date/TWiki::Time::formatTime($date, '$day $mon $year')/gei;
    $value =~ s/\$comment/$comment/gi;
    $value =~ s/\$username/$un/gi;
    $value =~ s/\$wikiname/$wn/gi;
    $value =~ s/\$wikiusername/$wun/gi;

    return $value;
}

=pod

---++ ObjectMethod summariseChanges($user, $web, $topic, $orev, $nrev, $plain) -> $text
   * =$user= - user (null to ignore permissions)
   * =$web= - web
   * =$topic= - topic
   * =$orev= - older rev
   * =$nrev= - later rev
   * =$tml= - if true will generate renderable TML (i.e. HTML with NOPs. if false will generate a summary suitable for use in plain text (mail, for example)
Generate a (max 3 line) summary of the differences between the revs.

If there is only one rev, a topic summary will be returned.

If =$plain= is set, all HTML will be removed.

In plain, lines are truncated to 70 characters. Differences are shown using + and - to indicate added and removed text.

=cut

sub summariseChanges {
    my( $this, $user, $web, $topic, $orev, $nrev, $tml ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;
    my $summary = '';
    my $store = $this->{session}->{store};

    my( $nmeta, $ntext ) =
      $store->readTopic( $user, $web, $topic, $nrev );

    if( $nrev > 1 && $orev ne $nrev ) {
        # there was a prior version. Diff it.
        $ntext = $this->TML2PlainText( $ntext, $web, $topic, 'nonop' );

        my( $ometa, $otext ) =
          $store->readTopic( $user, $web, $topic, $orev );
        $otext = $this->TML2PlainText( $otext, $web, $topic, 'nonop' );

        my $blocks = TWiki::Merge::simpleMerge( $otext, $ntext, qr/[\r\n]+/ );
        # sort through, keeping one line of context either side of a change
        my @revised;
        my $getnext = 0;
        my $prev = '';
        my $ellipsis = $tml ? '&hellip;' : '...';
        my $trunc = $tml ? $TMLTRUNC : $PLAINTRUNC;
        while ( scalar @$blocks && scalar( @revised ) < $SUMMARYLINES ) {
            my $block = shift( @$blocks );
            next unless $block =~ /\S/;
            my $trim = length($block) > $trunc;
            $block =~ s/^(.{$trunc}).*$/$1/ if( $trim );
            if ( $block =~ m/^[-+]/ ) {
                if( $tml ) {
                    $block =~ s/^-(.*)$/CGI::del( $1 )/se;
                    $block =~ s/^\+(.*)$/CGI::ins( $1 )/se;
                }
                push( @revised, $prev ) if $prev;
                $block .= $ellipsis if $trim;
                push( @revised, $block );
                $getnext = 1;
                $prev = '';
            } else {
                if( $getnext ) {
                    $block .= $ellipsis if $trim;
                    push( @revised, $block );
                    $getnext = 0;
                    $prev = '';
                } else {
                    $prev = $block;
                }
            }
        }
        if( $tml ) {
            $summary = join(CGI::br(), @revised );
        } else {
            $summary = join("\n", @revised );
        }
    }

    unless( $summary ) {
        $summary = $this->makeTopicSummary( $ntext, $topic, $web );
    }

    if( $tml ) {
        $summary = $this->protectPlainText( $summary );
    }
    return $summary;
}

=pod

---++ ObjectMethod forEachLine( $text, \&fn, \%options ) -> $newText

Iterate over each line, calling =\&fn= on each.
\%options may contain:
   * =pre= => true, will call fn for each line in pre blocks
   * =verbatim= => true, will call fn for each line in verbatim blocks
   * =noautolink= => true, will call fn for each line in =noautolink= blocks
The spec of \&fn is sub fn( \$line, \%options ) -> $newLine; the %options hash passed into this function is passed down to the sub, and the keys =in_pre=, =in_verbatim= and =in_noautolink= are set boolean TRUE if the line is from one (or more) of those block types.

The return result replaces $line in $newText.

=cut

sub forEachLine {
    my( $this, $text, $fn, $options ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;

    $options->{in_pre} = 0;
    $options->{in_pre} = 0;
    $options->{in_verbatim} = 0;
    $options->{in_noautolink} = 0;
    my $newText = '';
    foreach my $line ( split( /([\r\n]+)/, $text ) ) {
        if( $line =~ /[\r\n]/ ) {
            $newText .= $line;
            next;
        }
        $options->{in_verbatim}++ if( $line =~ m|^\s*<verbatim\b[^>]*>\s*$|i );
        $options->{in_verbatim}-- if( $line =~ m|^\s*</verbatim>\s*$|i );
        unless( $options->{in_verbatim} > 0 ) {
            $options->{in_pre}++ if( $line =~ m|<pre\b|i );
            $options->{in_pre}-- if( $line =~ m|</pre>|i );
            $options->{in_noautolink}++ if( $line =~ m|^\s*<noautolink\b[^>]*>\s*$|i );
            $options->{in_noautolink}-- if( $line =~ m|^\s*</noautolink>\s*|i );
        }
        unless( $options->{in_pre} > 0 && !$options->{pre} ||
                $options->{in_verbatim} > 0 && !$options->{verbatim} ||
                $options->{in_noautolink} > 0 && !$options->{noautolink} ) {

            $line = &$fn( $line, $options );
        }
        $newText .= $line;
    }
    return $newText;
}

=pod

---++ StaticMethod replaceTopicReferences( $text, \%options ) -> $text
Callback designed for use with forEachLine, to replace topic references.
\%options contains:
   * =oldWeb= => Web of reference to replace
   * =oldTopic= => Topic of reference to replace
   * =spacedTopic= => RE matching spaced out oldTopic
   * =newWeb= => Web of new reference
   * =newTopic= => Topic of new reference
   * =inWeb= => the web which the text we are presently processing resides in
   * =fullPaths= => optional, if set forces all links to full web.topic form
For a usage example see TWiki::UI::Manage.pm

=cut

sub replaceTopicReferences {
    my( $text, $args ) = @_;

    ASSERT(defined $args->{oldWeb}) if DEBUG;
    ASSERT(defined $args->{oldTopic}) if DEBUG;
    ASSERT(defined $args->{spacedTopic}) if DEBUG;
    ASSERT(defined $args->{newWeb}) if DEBUG;
    ASSERT(defined $args->{newTopic}) if DEBUG;
    ASSERT(defined $args->{inWeb}) if DEBUG;

    my $repl = $args->{newTopic};

    $args->{inWeb}=~s/\//./go;
    $args->{newWeb}=~s/\//./go;
    $args->{oldWeb}=~s/\//./go;
    my $oldWebRegex=$args->{oldWeb};

    $oldWebRegex=~s#\.#[.\\/]#go;

    if( $args->{inWeb} ne $args->{newWeb} || $args->{fullPaths} ) {
        $repl = $args->{newWeb}.'.'.$repl;
    }

    $text =~ s/$STARTWW$oldWebRegex\.$args->{oldTopic}$ENDWW/$repl/g;
    $text =~ s/\[\[$oldWebRegex\.$args->{spacedTopic}(\](\[[^\]]+\])?\])/[[$repl$1/g;

    return $text unless( $args->{inWeb} eq $args->{oldWeb} );

    $text =~ s/$STARTWW$args->{oldTopic}$ENDWW/$repl/g;
    $text =~ s/\[\[($args->{spacedTopic})(\](\[[^\]]+\])?\])/[[$repl$2/g;

    return $text;
}


=pod

---++ StaticMethod replaceWebReferences( $text, \%options ) -> $text
Callback designed for use with forEachLine, to replace web references.
\%options contains:
   * =oldWeb= => Web of reference to replace
   * =newWeb= => Web of new reference
For a usage example see TWiki::UI::Manage.pm

=cut

sub replaceWebReferences {
    my( $text, $args ) = @_;

    ASSERT(defined $args->{oldWeb}) if DEBUG;
    ASSERT(defined $args->{newWeb}) if DEBUG;

    my $repl = $args->{newWeb};

    $args->{newWeb}=~s/\//./go;
    $args->{oldWeb}=~s/\//./go;
    my $oldWebRegex=$args->{oldWeb};

    $oldWebRegex=~s#\.#[.\\/]#go;

    $text =~ s/\b$oldWebRegex\b/$repl/g;

    return $text;
}

=pod

---++ ObjectMethod replaceWebInternalReferences( \$text, \%meta, $oldWeb, $oldTopic )

Change within-web wikiwords in $$text and $meta to full web.topic syntax.

\%options must include topics => list of topics that must have references
to them changed to include the web specifier.

=cut

sub replaceWebInternalReferences {
    my( $this, $text, $meta, $oldWeb, $oldTopic, $newWeb, $newTopic ) = @_;
    ASSERT($this->isa( 'TWiki::Render')) if DEBUG;

    my @topics = $this->{session}->{store}->getTopicNames( $oldWeb );
    my $options =
      {
       # exclude this topic from the list
       topics => [ grep { !/^$oldTopic$/ } @topics ],
       inWeb => $oldWeb,
       inTopic => $oldTopic,
       oldWeb => $oldWeb,
       newWeb => $oldWeb,
      };

    $$text = $this->forEachLine( $$text, \&_replaceInternalRefs, $options );

    $meta->forEachSelectedValue( qw/^(FIELD|TOPICPARENT)$/, undef,
                                 \&_replaceInternalRefs, $options );
    $meta->forEachSelectedValue( qw/^TOPICMOVED$/, qw/^by$/,
                                 \&_replaceInternalRefs, $options );
    $meta->forEachSelectedValue( qw/^FILEATTACHMENT$/, qw/^user$/,
                                 \&_replaceInternalRefs, $options );

    ## Ok, let's do it again, but look for links to topics in the new web and remove their full paths
    @topics = $this->{session}->{store}->getTopicNames( $newWeb );
    $options =
      {
       # exclude this topic from the list
       topics => [ @topics ],
       fullPaths => 0,
       inWeb => $newWeb,
       inTopic => $oldTopic,
       oldWeb => $newWeb,
       newWeb => $newWeb,
      };

    $$text = $this->forEachLine( $$text, \&_replaceInternalRefs, $options );

    $meta->forEachSelectedValue( qw/^(FIELD|TOPICPARENT)$/, undef,
                                 \&_replaceInternalRefs, $options );
    $meta->forEachSelectedValue( qw/^TOPICMOVED$/, qw/^by$/,
                                 \&_replaceInternalRefs, $options );
    $meta->forEachSelectedValue( qw/^FILEATTACHMENT$/, qw/^user$/,
                                 \&_replaceInternalRefs, $options );

}

# callback used by replaceWebInternalReferences
sub _replaceInternalRefs {
    my( $text, $args ) = @_;
    foreach my $topic ( @{$args->{topics}} ) {
        $args->{fullPaths} =  ( $topic ne $args->{inTopic} ) if (!defined($args->{fullPaths}));
        $args->{oldTopic} = $topic;
        $args->{newTopic} = $topic;
        $args->{spacedTopic} = TWiki::spaceOutWikiWord( $topic );
        $args->{spacedTopic} =~ s/ / */g;
        $text = replaceTopicReferences( $text, $args );
    }
    return $text;
}

=pod

---++ StaticMethod renderFormFieldArg( $meta, $args ) -> $text

Parse the arguments to a $formfield specification and extract
the relevant formfield from the given meta data.

=cut

sub renderFormFieldArg {
    my( $meta, $args ) = @_;

    my $name = $args;
    my $breakArgs = '';
    my @params = split( /\,\s*/, $args, 2 );
    if( @params > 1 ) {
        $name = $params[0] || '';
        $breakArgs = $params[1] || 1;
    }
    my $value = '';
    my @fields = $meta->find( 'FIELD' );
    foreach my $field ( @fields ) {
        if( $name =~ /^($field->{name}|$field->{title})$/ ) {
            $value = $field->{value};
            $value =~ s/^\s*(.*?)\s*$/$1/go;
            $value = breakName( $value, $breakArgs );
            return $value;
        }
    }
    return '';
}

=pod

---++ StaticMethod breakName( $text, $args) -> $text
   * =$text= - text to "break"
   * =$args= - string of format (\d+)([,\s*]\.\.\.)?)
Hyphenates $text every $1 characters, or if $2 is "..." then shortens to
$1 characters and appends "..." (making the final string $1+3 characters
long)

_Moved from Search.pm because it was obviously unhappy there,
as it is a rendering function_

=cut

sub breakName {
    my( $text, $args ) = @_;

    my @params = split( /[\,\s]+/, $args, 2 );
    if( @params ) {
        my $len = $params[0] || 1;
        $len = 1 if( $len < 1 );
        my $sep = '- ';
        $sep = $params[1] if( @params > 1 );
        if( $sep =~ /^\.\.\./i ) {
            # make name shorter like 'ThisIsALongTop...'
            $text =~ s/(.{$len})(.+)/$1.../s;

        } else {
            # split and hyphenate the topic like 'ThisIsALo- ngTopic'
            $text =~ s/(.{$len})/$1$sep/gs;
            $text =~ s/$sep$//;
        }
    }
    return $text;
}

1;
