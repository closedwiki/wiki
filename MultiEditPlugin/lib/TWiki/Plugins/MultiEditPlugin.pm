#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
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
package TWiki::Plugins::MultiEditPlugin;

# =========================
use vars qw(
        $VERSION $pluginName $debug
        $label $skipskin $placement $renderedText $prefix
    );

use TWiki::Func;
use TWiki::Contrib::EditContrib;

$VERSION = '$Rev: 0000';
$pluginName = 'MultiEditPlugin';

$RELEASE = 'Dakar';

use strict;

# =========================
sub initPlugin
{
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning( "This version of $pluginName works only with TWiki 4 and greater." );
        return 0;
    }

    $label = &TWiki::Func::getPreferencesValue( "\U$pluginName\E_LABEL" ) || "Edit";
    #Figure out how to do security in Dakar
    #$label =~ s/$TWiki::securityFilter//go;    # zap anything suspicious
    #$label = eval $label;
    $label = TWiki::Func::expandCommonVariables( $label );
    #Example for img tag:
    #$label = "<br><img src=\"". &TWiki::Func::getPubUrlPath() . "/$installWeb/EditTablePlugin/edittable.gif\" alt=\"Edit\" border=\"0\">";
    $skipskin = &TWiki::Func::getPreferencesValue( "\U$pluginName\E_SKIPSKIN" ) || '';
    $placement = &TWiki::Func::getPreferencesValue( "\U$pluginName\E_PLACEMENT" ) || 'after';
    $placement = ($placement =~ /before/i ? 1 : 0);

    #initialize a few other things
    $renderedText = ();
    $prefix = "<_render_>";

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================

# NOTE: At preRenderingHandler (were all the heavy lifting is done), 
# we have lost the information that the text might be included from 
# another topic, and all edit links will be not to the included topic 
# but the including topic, resulting in the edit failing.
# As a workaround (TWiki core should really help here) remember the
# web and topic in commonTagsHandler (the only place where the included
# topic is accessible) in the section tag. Unfortunately we cannot use
# the more efficient registered tags, as this only works for tags
# delimited with '%' (then we would use $this->{SESSION_TAGS}{'TOPIC'}
# to access the topic.

# TW: BUG: Works only when a complete topic is included, as otherwise
# the sections start from the wrong place (i.e., after the %STARTINCLUDE%
# This could be solved by having a =beforeIncludeHandler= (see
# TWiki:Codev.NeedBeforeIncludeHandler)

sub commonTagsHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    my $sec = 0;
    $_[0] =~ s/<section((\s+[^>]+)?)>/&rememberTopic($_[1], $_[2], $1, $sec)/geo;

    TWiki::Func::writeDebug( "- after ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

}

sub rememberTopic {
  my ( $topic, $web, $posattr ) = @_;

  if ($posattr =~ / topic=/o) {
    return "<section$posattr>";
  } else {
    $_[3]++;
    return "<section$posattr topic=\"$topic\" web=\"$web\" section=\"$_[3]\">";
  }
}

# =========================

sub preRenderingHandler
{
### my ( $text, $pmap ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    my $session = $TWiki::Plugins::SESSION;
    &TWiki::Func::writeDebug( "- ${pluginName}::preRenderingHandler( $session->{webName}.$session->{topicName} )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    # Only bother with this plugin if viewing (i.e. not searching, etc)
    return unless ($0 =~ m/view|viewauth|render/o);

    my $ctmpl = $session->{cgiQuery}->param('template') || '';
    my $cskin = &TWiki::Func::getSkin() || '';
    my $skipit = 0;
    foreach my $ss (split(/\s*,\s*/, $skipskin)) {
        if (($cskin eq $ss)||($ctmpl eq $ss)) {
            $skipit = 1;
        }
    }

    return if $skipit;
    my $ret = '';
    my $eurl = TWiki::Func::getScriptUrlPath() . '/editonesection';

    my $sectionedit = ($_[0] =~ m%<section( |>)%i);

    if ($sectionedit) {
      my @sections = split(/(<\/?section(\s+[^>]+)?>)/i, $_[0]);
      my $dontedit;
      my $pos = 0;
      my $state = 'noedit';
      my $skip = 0;
      my $lastsec = '';
      my $topic;
      my $web;
      foreach my $sec (@sections) {
	if ( $skip ) { $skip = 0; next; }
	if ( $sec =~ m/<section(.*)>/i ) 
	  { use TWiki::Attrs;
	    my $attrs = new TWiki::Attrs($1, 1);
	    $dontedit = ( defined $attrs->{edit} && ! $attrs->{edit} );
	    $topic = $attrs->{topic};
	    $web = $attrs->{web};
	    $pos = $attrs->{section};
	    $state='edit'; $skip = 1; next; }
	if ( $sec eq "</section>" ) {
	  $skip = 1;
	  my $tmp = TWiki::Func::renderText($lastsec, $_[1], $_[2]);
	  # restore verbatim markers
	  $tmp =~ s/\<\!\-\-\!([a-z0-9]+)\!\-\-\>/\<\!\-\-$TWiki::TranslationToken$1$TWiki::TranslationToken\-\-\>/gio;
	  my $rText = ( $dontedit )? $tmp : &editRow("$eurl/$web/$topic", $pos, $tmp);
	  $$renderedText{"$pos$web$topic"} = $rText;
	  $lastsec = '';
	  $ret .= "$prefix$pos$web$topic$prefix";
          $dontedit = 0;
	  $state='noedit'; next; 
	}
	if ( $state eq 'edit' ) { $lastsec = $sec; }
	else { $ret .= $sec; };
      }
      $_[0] = $ret . $lastsec;

    }
}

# =========================
sub editLink
{
    my ($eurl,$pos,$title) = @_;
    return "<a href=\"$eurl\?t=" . time() . "&sec=$pos#SECEDITBOX\"><small>$title</small></a>";
}

# =========================
sub editRow
{
    my ($eurl,$pos,@content) = @_;
    #return '<table border=\"0\"><tr><td>' .
    return '<div>' .
	($placement
	 ? editLink($eurl,$pos,$label) . join("", @content)
	 : join('', @content) . editLink($eurl,$pos,$label)) .
	 '</div>';
	 #'</td></tr></table>';
}

# =========================
sub postRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    return if ($_[0] =~ m/\<\/?body[^>]*\>/o);

    my $session = $TWiki::Plugins::SESSION;
    TWiki::Func::writeDebug( "- ${pluginName}::postRenderingHandler( $session->{webName}.$session->{topicName} )" ) if $debug;

    if ( ref $renderedText ) {
        while ($_[0] =~ s/$prefix(.*?)$prefix/$$renderedText{$1}/e) {}
    }
}

# =========================

sub doEdit
{
    my $session = shift;
    my $text= '';
    my $tmpl = '';
    ( $session, $text, $tmpl ) = &TWiki::Contrib::EditContrib::edit( $session );

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};
    my $theSec = int($query->param('sec')) || 0;
    my $editUrl = &TWiki::Func::getScriptUrl( $webName, $topic, 'editonesection' );
    my $editUrlParams = "&sec=$theSec#SECEDITBOX";
    $tmpl =~ s/%EDIT%/$editUrl/go;
    $tmpl =~ s/%EDITPARAMS%/$editUrlParams/go;
    my $sectxt = '';
    my $pretxt = '';
    my $postxt = '';
    my $pos = 1;

    # Get rid of CRs (we only want to deal with LFs)
    $text =~ s/\r//g;

    if ( $text =~ m/<\/?section>/i ) { 
	my @sections = split(/(<\/?section\s*(\s+[^>]+)?>)/i, $text); 
	$pretxt .= $sections[0];
	for ( my $s = 1; $s<$#sections; $s+=6 ) {
	  if ($pos < $theSec) {
	    $pretxt .= $sections[$s] . $sections[$s+2] . $sections[$s+3] . $sections[$s+5];
	  } elsif ($pos > $theSec) {
	    $postxt .= $sections[$s] . $sections[$s+2] . $sections[$s+3] . $sections[$s+5];
	  } else {
	    $pretxt .= $sections[$s];
	    $sectxt  = $sections[$s+2];
	    $postxt .= $sections[$s+3] . $sections[$s+5];
	  }
	  $pos++;
	}
    }

    TWiki::Contrib::EditContrib::finalize_edit ( $session, $pretxt, $sectxt, $postxt, '', '', $tmpl );

}

1;
