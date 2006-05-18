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
package TWiki::Plugins::SectionalEditPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $debug
        $bgcolor $label $skipskin $leftjustify $alwayssection
    );

use vars qw( %TWikiCompatibility );

use TWiki;

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '17 May 2006';

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

    $alwayssection = &TWiki::Func::getPreferencesValue( "EDITSECTIONS" ) || 0;
    $sectiondepth = &TWiki::Func::getPreferencesValue( "SECTIONDEPTH" ) || "";
    $editstyle = &TWiki::Func::getPreferencesValue( "SECTIONALEDITPLUGIN_STYLE" ) || "";

    if ($editstyle) {
      $placement = &TWiki::Func::getPreferencesValue( "SECTIONALEDITPLUGIN_PLACEMENT" ) || "above";
      $placement = ($placement =~ /above/i ? 1 : 0);
    } else {
      $placement = $leftjustify;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "SECTIONALEDITPLUGIN_DEBUG" );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::SectionalEditPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub blankCell
{
    return ($editstyle)?"":"<td></td>";
}

# =========================
sub editLink
{
    my ($eurl,$pos,$title) = @_;
    return "<a href=\"$eurl\?t=" . time() . "&sec=$pos#SECEDITBOX\"><small>$title</small></a>";
}

# =========================
sub editCell
{
    my ($eurl,$pos) = @_;
    if ($editstyle) {
      return "<div align=\"" . (($leftjustify)?"left":"right") . "\">" . editLink($eurl,$pos,$label) . "</div>";
    } else {
      return "<td bgcolor=\"$bgcolor\" align=\"right\" valign=\"top\" width=\"0%\">" . editLink($eurl,$pos,$label) . "</td>";
    }
}

# =========================
sub editableContentCell
{
    if ($editstyle) {
      return "<div $editstyle>\n" . join("", @_) . "</div>";
    } else {
      return "<td align=\"left\" valign=\"top\" width=\"100%\">\n" . 
           join("", @_) . "</td>";
    }
}

sub contentCell
{
    if ($editstyle) {
      return join("", @_);
    } else {
      return "<td align=\"left\" valign=\"top\" width=\"100%\">\n" . 
           join("", @_) . "</td>";
    }
}

# =========================
sub editRow
{
    my ($eurl,$pos,@content) = @_;
    return (($editstyle)?"":"<tr>") .
	($placement
	 ? editCell($eurl,$pos) . editableContentCell(@content)
	 : editableContentCell(@content) . editCell($eurl,$pos)) .
	   (($editstyle)?"":"</tr>");
}

# =========================
sub displayRow
{
    return (($editstyle)?"":"<tr>") .
	($placement
	 ? blankCell() . contentCell(@_)
	 : contentCell(@_) . blankCell()) .
	 (($editstyle)?"":"</tr>");
}

## disable the call to endRenderingHandler in Dakar (i.e. TWiki::Plugins::VERSION >= 1.1)
$TWikiCompatibility{startRenderingHandler} = 1.1;

sub startRenderingHandler
{

    # startRenderingHandler is depreciated post Cairo, but needed for
    # Cairo compatibility 
    return preRenderingHandler( @_ );
}

# =========================
sub preRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    &TWiki::Func::writeDebug( "- SectionalEditPlugin::startRenderingHandler( $_[1].$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop
    # Only bother with this plugin if viewing (i.e. not searching, etc)
    return unless ($0 =~ m/\/view|\/viewauth/o);

    my $cskin = &TWiki::Func::getSkin();
    my $skipit = 0;
    foreach my $ss (split(/\s*,\s*/, $skipskin)) {
        if ($cskin eq $ss) {
            $skipit = 1;
        }
    }

    unless($skipit) {
	my $editsections = 'EditSections' if (($alwayssection && $_[0] !~ /^\s*<body/is) || ($_[0] =~ m%<editsections\s*/>%i));
	# <sectionbreak/> inserts break in sections, <editsections/> sections all.
	# why did we also use <sectionbreak/> in the first line to section all?
	# Make sure space before /> is allowed also in the script
	my $sectionbreak = 'SectionBreak' if ($_[0] =~ m%<sectionbreak\s*/?>%i);
	# Why is the /> possible?
	my $sectionedit  = 'SectionEdit' if ($_[0] =~ m%<sectionedit.*?>%i);
	my $activate = $editsections || $sectionbreak || $sectionedit;

	if ($activate) {
	    my $ret = '';
	    $ret = '<table border="0" width="100%">' unless $editstyle;
	    my $eurl = TWiki::Func::getScriptUrlPath() . "/editsection/$web/$topic";
	    &TWiki::Func::writeDebug( "- $activate Found" ) if $debug;

	    if ($editsections) {
		my $pos = 0;
		my $lastpos = 0;
		my $lastmark = "";
		my $text = $_[0];
		my $sec = "";
	        while ( $text =~ m/^---\+{1,$sectiondepth}[^+]/mg ) {
		    # Minor bug in the above regex: A "---+" with no
		    # title text before either newline or end of topic
		    # does not render as heading but is treated as 
		    # editable section
		    my $curpos = pos $text;
		    my $curmark = $&;
		    $sec = substr($text,$lastpos,$curpos - length($&) - $lastpos);
		    $ret .= editRow($eurl,$pos, ($pos > 0 ? "\n". $lastmark : "") . $sec) unless ($sec =~ /^\s*$/o);
		    $lastmark = $curmark;
		    $lastpos = $curpos;
		    $pos++;
		}
		$sec = substr($text,$lastpos);
		$ret .= editRow($eurl,$pos, ($pos > 0 ? "\n". $lastmark : "") . $sec) unless ($sec =~ /^\s*$/o);
	    }
	    if ($sectionbreak) {
		my @sections = split(/<sectionbreak\s*\/?>/i, $_[0]);
		my $pos = 0;
		foreach $sec (@sections) {
		    $ret .= editRow($eurl,$pos,$sec);
		    $pos++;
		}
	    }
	    if ($sectionedit) { 
		my @sections = split(/(<\/?sectionedit.*?>)/i, $_[0]);
		my $pos = 0;
		my $state = "noedit";
		my $origstyle = $editstyle;
		foreach $sec (@sections) {
		    if ( $sec =~ m/<sectionedit(.*?)>/i ) {
		      $editstyle = $1 if $1;
		      $state="edit"; next; 
		    }
		    if ( $sec eq "</sectionedit>" ) { 
		      $editstyle = $origstyle;
		      $state="noedit"; next; 
		    }
		    if ( $state eq "edit" ) { $ret .= editRow($eurl,$pos,$sec); }
		    else { $ret .= displayRow($sec); };
		    $pos++;
		}
	    }
	    $ret .= '</table>' unless $editstyle;
	    $_[0] = $ret;
	}
    }
}

1;
