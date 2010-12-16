# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
# Copyright (C) 2005 TWiki:Main.SteveRJones
# Copyright (C) 2010 TWiki:Main.PeterThoeny
# Copyright (C) 2005-2010 TWiki:TWiki.TWikiContributor
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
# This is the ReStructuredText TWiki plugin.
# written by
# Nicolas Tisserand (tisser_n@epita.fr), Nicolas Burrus (burrus_n@epita.fr)
# and Perceval Anichini (anichi_p@epita.fr)
# Modified for reStructuredText by Mark Nodine (nodine@freescale.com).
# 
# It uses trip as HTML renderer for reStructuredText.
#######!!!!!! Need Copyright notice for Freescale wrt trip !!!!!!!
# 
# Use it in your twiki text by writing %RESTSTART{tripopts}% ... %RESTEND%

package TWiki::Plugins::ReStructuredTextPlugin;

use IPC::Open2;

# =========================
use vars qw(
	      $web $topic $user $installWeb $VERSION $RELEASE $pluginName $debug $trip
	      $tripoptions
	    );

$VERSION = '1.2';
$RELEASE = '2010-12-16';

$pluginName = 'ReStructuredTextPlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.021 ) {
        TWiki::Func::writeWarning( "Version mismatch between ReStructuredTextPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = $TWiki::cfg{Plugins}{$pluginName}{Debug} || 0;

    # Get trip override flag
    $trip = $TWiki::cfg{Plugins}{$pluginName}{TripCmd}
          || '/var/www/twiki/lib/TWiki/Plugins/ReStructuredTextPlugin/trip/bin/trip';

    # Get trip override flag
    $tripoptions = $TWiki::cfg{Plugins}{$pluginName}{TripOptions}
          || '-D source_link=0 -D time=0 -D xformoff=DocTitle -D generator=0 -D tabstops=3';

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::ReStructuredTextPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub pipeThru
{
    my $out;

    my $pid = open2( \*Reader, \*Writer, $_[0]);

    print Writer $_[1];
    close(Writer);

    while (<Reader>)
    {
	$out .= $_;
    }
    close (Reader);

    return $out;
}
# =========================
sub reST2html
{
    my ($text, $opts) = @_;

    # security fix: Filter options to prevent nasty stuff
    $opts =~ s/[^a-zA-Z0-9_\=\- ]//go;
    my %opts = $opts =~ /(\w+)="(.*?)"/g;
    # Convert each tab to 3 spaces
    $text =~ s/\t/   /g;
    my $html = pipeThru("tee /tmp/trip.dat | $trip $tripoptions $opts{options} -D trusted=0 -- -", $text);

    if ($html =~ s/.*\<body\>\n(.*?)\n?\<\/body\>.*/$1/ios)
    {
	# Convert <PRE> tags to <VERBATIM> since TWiki does markup with <PRE>
	$html =~ s|<(/?)pre.*?>\b|<$1verbatim>|gi;
	return ($opts{stylesheet} ?
		qq(<link rel="stylesheet" type="text/css" href="$opts{stylesheet}">\n) : '') .
	    $html;
    }	
    else
    {
	return "<font color=\"red\"> ReStructuredTextPlugin: internal error  </font>\n<verbatim>\n$html\n</verbatim>\n";
    }
}

# =========================

sub commonTagsHandler
{
    TWiki::Func::writeDebug( "- ReStructuredTextPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # matches %RESTSTART{options}% ... %RESTEND%
    $_[0] =~ s/^%RESTSTART(?:\s*\{(.*?)\})?%\n(.*?)^%RESTEND%$/reST2html($2,$1)/megis;

}

# =========================

1;
