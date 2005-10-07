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
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName $debug
        $label $skipskin $placement $renderedText $prefix
    );

use TWiki;

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'MultiEditPlugin';

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
    #$label = "<br><img src=\"". &TWiki::getPubUrlPath() . "/$installWeb/EditTablePlugin/edittable.gif\" alt=\"Edit\" border=\"0\">";
    $skipskin = &TWiki::Func::getPreferencesValue( "\U$pluginName\E_SKIPSKIN" ) || "";
    $placement = &TWiki::Func::getPreferencesValue( "\U$pluginName\E_PLACEMENT" ) || "after";
    $placement = ($placement =~ /left/i ? 1 : 0);

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

    my $cskin = &TWiki::Func::getSkin();
    my $skipit = 0;
    foreach my $ss (split(/\s*,\s*/, $skipskin)) {
        if ($cskin eq $ss) {
            $skipit = 1;
        }
    }

    unless($skipit) {
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

    TWiki::Func::writeDebug( "- ${pluginName}::endRenderingHandler( $web.$topic )" ) if $debug;

    if (@$renderedText) {
        while ($_[0] =~ s/$prefix([0-9]+)/$$renderedText[$1]/e) {}
    }
}

1;
