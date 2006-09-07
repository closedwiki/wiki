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
        $web $topic $user $installWeb $VERSION $pluginName $debug
        $label $skipskin $placement $renderedText $prefix
    );

use TWiki::Func;
use TWiki::Contrib::EditContrib;

$VERSION = '$Rev: 0000';
$pluginName = 'MultiEditPlugin';

$RELEASE = 'Dakar';

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
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
    $placement = &TWiki::Func::getPreferencesValue( "\U$pluginName\E_PLACEMENT" ) || "after";
    $placement = ($placement =~ /before/i ? 1 : 0);

    #initialize a few other things
    $renderedText = [];
    $prefix = "<_render_>";

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    &TWiki::Func::writeDebug( "- ${pluginName}::startRenderingHandler( $_[1].$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    # Only bother with this plugin if viewing (i.e. not searching, etc)
    return unless ($0 =~ m/view|viewauth|render/o);

    my $ctmpl = $TWiki::Plugins::SESSION->{cgiQuery}->param('template');
    my $cskin = &TWiki::Func::getSkin();
    my $skipit = 0;
    foreach my $ss (split(/\s*,\s*/, $skipskin)) {
        if (($cskin eq $ss)||($ctmpl eq $ss)) {
            $skipit = 1;
        }
    }

    return if $skipit;
    my $ret = '';
    my $eurl = TWiki::Func::getScriptUrlPath() . "/editonesection/$web/$topic";

    my $sectionedit = ($_[0] =~ m%<section/?>%i);

    if ($sectionedit) {
      my @sections = split(/(<\/?section>)/i, $_[0]);
      my $pos = 0;
      my $state = "noedit";
      my $lastsec = "";
      foreach $sec (@sections) {
	if ( $sec eq "<section>" ) { $state="edit"; next; }
	if ( $sec eq "</section>" ) {
	  my $tmp = TWiki::Func::renderText($lastsec, $_[1], $_[2]);
	  # restore verbatim markers
	  $tmp =~ s/\<\!\-\-\!([a-z0-9]+)\!\-\-\>/\<\!\-\-$TWiki::TranslationToken$1$TWiki::TranslationToken\-\-\>/gio;
	  my $rText = &editRow($eurl, $pos, $tmp);
	  $$renderedText[$pos] = $rText;
	  $lastsec = "";
	  $ret .= ($prefix . $pos);
	  $state="noedit"; next; 
	}
	if ( $state eq "edit" ) { $lastsec = $sec; }
	else { $ret .= $sec; };
	$pos++;
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
    #return "<table border=\"0\"><tr><td>" .
    return "<div>" .
	($placement
	 ? editLink($eurl,$pos,$label) . join("", @content)
	 : join("", @content) . editLink($eurl,$pos,$label)) .
	 "</div>";
	 #"</td></tr></table>";
}

# =========================
sub endRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    return if ($_[0] =~ m/\<\/?body[^>]*\>/o);

    TWiki::Func::writeDebug( "- ${pluginName}::endRenderingHandler( $web.$topic )" ) if $debug;

    if (@$renderedText) {
        while ($_[0] =~ s/$prefix([0-9]+)/$$renderedText[$1]/e) {}
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
    my $editUrl = &TWiki::Func::getScriptUrl( $webName, $topic, "editonesection" );
    my $editUrlParams = "&sec=$theSec#SECEDITBOX";
    $tmpl =~ s/%EDIT%/$editUrl/go;
    $tmpl =~ s/%EDITPARAMS%/$editUrlParams/go;
    my $sectxt = "";
    my $pretxt = "";
    my $postxt = "";
    my $pos = 1;

    # Get rid of CRs (we only want to deal with LFs)
    $text =~ s/\r//g;

    if ( $text =~ m/<\/?section>/i ) { 
	my @sections = split(/(<\/?section>)/i, $text); 
	foreach my $s (@sections) {
	    if ($pos < $theSec) {
		if ( $s =~ m/<(\/?)section>/ ) { $pretxt .= "<$1section>"; next; }
		$pretxt .= $s;
	    } elsif ($pos > $theSec) {
		if ( $s =~ m/<(\/?)section>/ ) { $postxt .= "<$1section>"; next; }
		$postxt .= $s;
	    } else {
		if ( $s =~ m/<(\/?)section>/ ) { $pretxt .= "<$1section>"; next; }
		$sectxt = $s;
	    }
	    $pos++;
	}
    }

    TWiki::Contrib::EditContrib::finalize_edit ( $session, $pretxt, $sectxt, $postxt, "", "", $tmpl );

}

1;
