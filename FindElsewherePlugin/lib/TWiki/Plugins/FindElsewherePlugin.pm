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
# =========================
#
# This is the FindElsewhere TWiki plugin, 
# see http://twiki.org/cgi-bin/view/Plugins/FindElsewherePlugin for details.
#
# Each plugin is a package that contains the subs:
#
#   initPlugin           ( $topic, $web, $user, $installWeb )
#   commonTagsHandler    ( $text, $topic, $web )
#   startRenderingHandler( $text, $web )
#   outsidePREHandler    ( $text )
#   insidePREHandler     ( $text )
#   endRenderingHandler  ( $text )
#
# initPlugin is required, all other are optional. 
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name.
# 
# NOTE: To interact with TWiki use the official TWiki functions
# in the &TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!

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
# 31-Mar-2005: SteffenPoulsen
#		- updated plugin to be I18N-aware
# 02-Apr-2005: SteffenPoulsen
#		- fixed problems with WikiWordAsWebName.WikiWord
# 04-Apr-2005: SteffenPoulsen
#		- made plugin less greedy - now leaves [[WikiWord][long link with ACRONYM or WikiWord]] alone
# 05-Apr-2005: SteffenPoulsen
#		- bugfix: Preambles for ACRONYMS were doubled
# 08-Apr-2005: SteffenPoulsen
#		- negated vars "DISABLELOOKELSEWHERE" and "DISABLEPLURALTOSINGULAR" can now be set per topic or web (WebPreferences)
# 07-Apr-2006: ScottHunter
#		- replaced direct usage of %regex with TWiki::Func::getRegularExpression()
#		- replaced some implicit scalar references with explicit $ notation
# 21-Apr-2006 - MichaeDaum
#       - respects <noautolink> ... </noautolink> blocks as well as the
#         NOAUTOLINK preference flag#

# =========================
package TWiki::Plugins::FindElsewherePlugin;

# =========================
use vars qw(
	    $web $topic $user $installWeb $VERSION $debug
	    $disabledFlag $disablePluralToSingular
	    $webNameRegex $wikiWordRegex $abbrevRegex $singleMixedAlphaNumRegex
	    $noAutolink
	    );


# ===========================
# Read the configuration file at compile time in order to set locale
BEGIN {
    # Do a dynamic 'use locale' for this module
    if( $TWiki::useLocale ) {
        require locale;
        import locale ();
    }
} 

$VERSION = '1.000';

# =========================
sub initPlugin
{
   ( $topic, $web, $user, $installWeb ) = @_;
   
   # check for Plugins.pm versions
   if( $TWiki::Plugins::VERSION < 1 ) {
      &TWiki::Func::writeWarning( "Version mismatch between FindElsewherePlugin and Plugins.pm" );
      return 0;
   }

   # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
   $debug = &TWiki::Func::getPreferencesFlag( "FINDELSEWHEREPLUGIN_DEBUG" );

   $disabledFlag = &TWiki::Func::getPreferencesFlag( "DISABLELOOKELSEWHERE" ) || 
          &TWiki::Func::getPreferencesFlag( "FINDELSEWHEREPLUGIN_DISABLELOOKELSEWHERE" ) || 
          0 ;

   $otherWebs = &TWiki::Func::getPreferencesValue( "LOOKELSEWHEREWEBS" ) || 
          &TWiki::Func::getPreferencesValue( "FINDELSEWHEREPLUGIN_LOOKELSEWHEREWEBS" ) || 
          "" ;

   $disablePluralToSingular = &TWiki::Func::getPreferencesFlag( "DISABLEPLURALTOSINGULAR" ) || 
          &TWiki::Func::getPluginPreferencesFlag( "DISABLEPLURALTOSINGULAR" ) || 
          0 ;

   @webList = split( /[\,\s]+/, $otherWebs );

   $webNameRegex = TWiki::Func::getRegularExpression('webNameRegex');
   $wikiWordRegex = TWiki::Func::getRegularExpression('wikiWordRegex');
   $abbrevRegex = TWiki::Func::getRegularExpression('abbrevRegex');
   
   $noAutolink = TWiki::Func::getPreferencesFlag('NOAUTOLINK');

   my $upperAlphaRegex = TWiki::Func::getRegularExpression('upperAlpha');
   my $lowerAlphaRegex = TWiki::Func::getRegularExpression('lowerAlpha');
   my $numericRegex = TWiki::Func::getRegularExpression('numeric');
   $singleMixedAlphaNumRegex = qr/[$upperAlphaRegex$lowerAlphaRegex$numericRegex]/;

   # Plugin correctly initialized
   &TWiki::Func::writeDebug( "- TWiki::Plugins::FindElsewherePlugin::initPlugin( $web.$topic ) is OK ($disabledFlag/'disabledFlag', otherWebs/'$otherWebs', disablePluralToSingular/'$disablePluralToSingular', &TWiki::Func::getPreferencesFlag( \"DISABLEPLURALTOSINGULAR\" ))".&TWiki::Func::getPreferencesFlag( "DISABLEPLURALTOSINGULAR" )."(" ) if $debug;
   return 1;
}


# =========================
sub startRenderingHandler
{
# This handler is called by getRenderedVersion just before the line loop
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

   &TWiki::Func::writeDebug( "- FindElsewherePlugin::startRenderingHandler( $_[1].$topic )" ) if $debug;

   if ( $disabledFlag ) {
      &TWiki::Func::writeDebug( "- FindElsewherePlugin::startRenderingHandler( Plugin is disabled (DISABLELOOKELSEWHERE set), returning $_[1].$topic untouched! )" ) if $debug;
      return;
   }
   if ( $noAutolink ) {
      &TWiki::Func::writeDebug( "- FindElsewherePlugin::startRenderingHandler( Plugin is disabled (NOAUTOLINK set), returning $_[1].$topic untouched! )" ) if $debug;
      return;
   }

   # Find instances of WikiWords not in this web, but in the otherWeb(s)
   # If the WikiWord is found in theWeb, put the word back unchanged
   # If the WikiWord is found in the otherWeb, link to it via [[otherWeb.WikiWord]]
   # If it isn't found there either, put the word back unchnaged

   # Debug incoming topic text if uncommented
   # &TWiki::Func::writeDebug( "- FindElsewherePlugin::startRenderingHandler( Incoming text: $_[0] )" ) if $debug;

   my $text = $_[0];
   my $removed = {};

   my $renderer;
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        # Cairo doesn't have takeOutBlocks
    } else {
        # SMELL: No renderer / takeOutBlocks in Func.pm, bypassing API
        $renderer = $TWiki::Plugins::SESSION->{renderer};
        $text = $renderer->takeOutBlocks( $text, 'noautolink', $removed );
    }

   # Match 
   # 0) (Allowed preambles: "\s" and "(")
   # 1) [[something]] - (including [[something][something]], but non-greedy),
   # 2) WikiWordAsWebName.WikiWord,
   # 3) WikiWords, and 
   # 4) WIK IWO RDS

   $text =~ s/([\s\(])(\[\[.*?\]\]|$webNameRegex\.$wikiWordRegex|$wikiWordRegex|$abbrevRegex)/&findTopicElsewhere($_[1],$1,$2)/geo;

    if( $TWiki::Plugins::VERSION < 1.1 ) {
        # Cairo doesn't have putBackBlocks
    } else {
        $renderer->putBackBlocks( \$text, $removed, 'noautolink' );
    }
   $_[0] = $text;

   # Debug outgoing topic text if uncommented
   # &TWiki::Func::writeDebug( "- FindElsewherePlugin::startRenderingHandler( Outgoing text: $_[0] )" ) if $debug;
}

sub makeTopicLink
{
  ##my($otherWeb, $theTopic) = @_;
  return "[[$_[0].$_[1]][$_[0]]]";
}

# =========================
sub findTopicElsewhere
{
   # This was copied and pruned from TWiki::internalLink

   my( $theWeb, $thePreamble, $theTopic ) = @_;
   
   my $text = $thePreamble;
   
   # If we got ourselves something like [[something][something]] or WebName.WikiWord 
   # the links is absolute. We're done - return untouched info
   if ($theTopic =~ /(\[\[.*\]\[.*\]\]|$webNameRegex\.$wikiWordRegex)/o) {
      &TWiki::Func::writeDebug( "FindElsewherePlugin::findTopicElsewhere: \"$theTopic\" is an absolute link, leaving it untouched." ) if $debug;
      $text .= "$theTopic";
      return $text;
   }
   
   # preserve link style formatting
   my $oldTheTopic = $theTopic;

   # Turn spaced-out names into WikiWords - upper case first letter of
   # whole link, and first of each word.
   $theTopic =~ s/^(.)/\U$1/o;
   $theTopic =~ s/\s($singleMixedAlphaNumRegex)/\U$1/go;
   $theTopic =~ s/\[\[($singleMixedAlphaNumRegex)(.*)\]\]/\u$1$2/o;

   # Look in the current web, return when found
   &TWiki::Func::writeDebug( "FindElsewherePlugin::findTopicElsewhere: Looking for \"$theTopic\" elsewhere .." ) if $debug;
   my $exist = &TWiki::Func::topicExists( $theWeb, $theTopic );
   if ( ! $exist ) {
      if ( ( !$disablePluralToSingular ) && ( $theTopic =~ /s$/ ) ) {
         my $theTopicSingular = &makeSingular( $theTopic );
         if( &TWiki::Func::topicExists( $theWeb, $theTopicSingular ) ) {
            &TWiki::Func::writeDebug( "FindElsewherePlugin::findTopicElsewhere: - $theTopicSingular was found in $theWeb" ) if $debug;
            $text .= "$oldTheTopic"; # leave it as we found it
            return $text;
         }
      }
   }
   else  {
      &TWiki::Func::writeDebug( "FindElsewherePlugin::findTopicElsewhere: - $theTopic was found in $theWeb" ) if $debug;
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
         &TWiki::Func::writeDebug( "- $theTopic is the name of another web $otherWeb." );# if $debug;
         $text .= "[[$otherWeb.WebHome][$otherWeb]]";
         return $text;
      }

      my $exist = &TWiki::Func::topicExists( $otherWeb, $theTopic );
      if ( ! $exist ) {
         if ( ( !$disablePluralToSingular ) && ( $theTopic =~ /s$/ ) ) {
            my $theTopicSingular = &makeSingular( $theTopic );
            if( &TWiki::Func::topicExists( $otherWeb, $theTopicSingular ) ) {
               &TWiki::Func::writeDebug( "FindElsewherePlugin::findTopicElsewhere: - $theTopicSingular was found in $otherWeb" ) if $debug;
               push(@topicLinks, makeTopicLink($otherWeb,$theTopic));
            }
         }
      }
      else  {
         &TWiki::Func::writeDebug( "FindElsewherePlugin::findTopicElsewhere: - $theTopic was found in $otherWeb" ) if $debug;
         push(@topicLinks, makeTopicLink($otherWeb,$theTopic));
      }
   }

   if (@topicLinks > 0)
   { 
      if (@topicLinks == 1)
      {
	# Topic found elsewhere
	# If link text [[was in this form]], free it
	$oldTheTopic =~ s/\[\[(.*)\]\]/$1/o;

        # Link to topic
     	$topicLinks[0] =~ s/(\[\[.*?\]\[)(.*?)(\]\])/$1$oldTheTopic$3/o;
     	$text .= $topicLinks[0] ;
      } else {
	# topic found elsewhere
	# If link text [[was in this form]] <em> it
	$oldTheTopic =~ s/\[\[(.*)\]\]/<em>$1<\/em>/go;

	# If $oldTheTopic is a WikiWord, prepend with <nop> (prevent double links)
	$oldTheTopic =~ s/($wikiWordRegex)/<nop\/>$1/go;
	$text .= "$oldTheTopic<sup>(".join(",", @topicLinks ).")</sup>" ;
      }
   }
   else
   {
     &TWiki::Func::writeDebug( "FindElsewherePlugin::findTopicElsewhere: - $theTopic was not in any of these webs: @webList" ) if $debug;
     $text .= "$oldTheTopic"; 
   }

   return $text;
}

# =========================
sub makeSingular 
{
   my ($theWord) = @_;

   $theWord =~ s/ies$/y/o;       # plurals like policy / policies
   $theWord =~ s/sses$/ss/o;     # plurals like address / addresses
   $theWord =~ s/([Xx])es$/$1/o; # plurals like box / boxes
   $theWord =~ s/([A-Za-rt-z])s$/$1/o; # others, excluding ending ss like address(es)
   return $theWord;
}


# =========================

1;
