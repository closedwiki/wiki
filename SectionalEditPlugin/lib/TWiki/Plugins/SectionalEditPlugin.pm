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


# =========================
package TWiki::Plugins::SectionalEditPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $debug
        $bgcolor $label $skipskin $leftjustify
    );

$VERSION = '1.003';

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between SectionalEditPlugin and Plugins.pm" );
        return 0;
    }

    $bgcolor = &TWiki::Func::getPreferencesValue( "SECTIONALEDITPLUGIN_BGCOLOR" ) || "silver";
    $bgcolor = &TWiki::Func::expandCommonVariables($bgcolor, $topic, $web);
    $label = &TWiki::Func::getPreferencesValue( "SECTIONALEDITPLUGIN_LABEL" ) || "Edit";
    $skipskin = &TWiki::Func::getPreferencesValue( "SECTIONALEDITPLUGIN_SKIPSKIN" ) || "";
    $leftjustify = &TWiki::Func::getPreferencesValue( "SECTIONALEDITPLUGIN_JUSTIFICATION" ) || "left";
    $leftjustify = ($leftjustify =~ /left/i ? 1 : 0);

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "SECTIONALEDITPLUGIN_DEBUG" );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::SectionalEditPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub blankCell
{
    return "<td></td>";
}

# =========================
sub editLink
{
    my ($eurl,$pos,$title) = @_;
    return "<a href=\"$eurl?sec=$pos#SECEDITBOX\"><small>$title</small></a>";
}

# =========================
sub editCell
{
    my ($eurl,$pos) = @_;
    return "<td bgcolor=\"$bgcolor\" align=\"right\" valign=\"top\" width=\"0%\">" . 
           editLink($eurl,$pos,$label) . "</td>";
}

# =========================
sub contentCell
{
    return "<td align=\"left\" valign=\"top\" width=\"100%\">" . 
           join("", @_) . "</td>";
}

# =========================
sub editRow
{
    my ($eurl,$pos,@content) = @_;
    return "<tr>" .
	($leftjustify
	 ? editCell($eurl,$pos) . contentCell(@content)
	 : contentCell(@content) . editCell($eurl,$pos)) .
	 "</tr>";
}

# =========================
sub displayRow
{
    return "<tr>" .
	($leftjustify
	 ? blankCell() . contentCell(@_)
	 : contentCell(@_) . blankCell()) .
	 "</tr>";
}

# =========================
sub startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    &TWiki::Func::writeDebug( "- SectionalEditPlugin::startRenderingHandler( $_[1].$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    my $cskin = &TWiki::Func::getSkin();
    my $skipit = 0;
    foreach my $ss (split(/\s*,\s*/, $skipskin)) {
        if ($cskin eq $ss) {
            $skipit = 1;
        }
    }

    unless($skipit) {
	my $editsections = 'EditSections' if ($_[0] =~ m%<editsections/>%i);
	my $sectionbreak = 'SectionBreak' if ($_[0] =~ m%<sectionbreak/?>%i);
	my $sectionedit  = 'SectionEdit' if ($_[0] =~ m%<sectionedit/?>%i);
	my $activate = $editsections || $sectionbreak || $sectionedit;

	if ($activate) {
	    my $ret = '<table border="0" width="100%">';
	    my $eurl = TWiki::Func::getScriptUrlPath() . "/editsection/$web/$topic";
	    &TWiki::Func::writeDebug( "- $activate Found" ) if $debug;

	    if ($editsections) {
		my @sections = split(m%^---\+%m, $_[0]);
		my $pos = 0;
		foreach $sec (@sections) {
		    $ret .= editRow($eurl,$pos, ($pos > 0 ? "\n---+" : "") . $sec)
			unless ($sec =~ /^\s*$/o);
		    $pos++;
		}
	    }
	    if ($sectionbreak) {
		my @sections = split(/<sectionbreak\/?>/i, $_[0]);
		my $pos = 0;
		foreach $sec (@sections) {
		    $ret .= editRow($eurl,$pos,$sec);
		    $pos++;
		}
	    }
	    if ($sectionedit) { 
		my @sections = split(/(<\/?sectionedit>)/i, $_[0]);
		my $pos = 0;
		my $state = "noedit";
		foreach $sec (@sections) {
		    if ( $sec eq "<sectionedit>" ) { $state="edit"; next; }
		    if ( $sec eq "</sectionedit>" ) { $state="noedit"; next; }
		    if ( $state eq "edit" ) { $ret .= editRow($eurl,$pos,$sec); }
		    else { $ret .= displayRow($sec); };
		    $pos++;
		}
	    }
	    $ret .= '</table>';
	    $_[0] = $ret;
	}
    }
}

1;
