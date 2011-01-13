# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2002-2003 TWiki:Main.DaleBrayden
# Copyright (C) 2007-2011 TWiki:TWiki.TWikiContributor
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


# =========================
package TWiki::Plugins::StylePlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $debug
        $skipskin $styles $applied
    );

$VERSION = '$Rev$';
$RELEASE = '2011-01-12';

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between StylePlugin and Plugins.pm" );
        return 0;
    }

    $skipskin = &TWiki::Func::getPreferencesValue( "STYLEPLUGIN_SKIPSKIN" ) || "";

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "STYLEPLUGIN_DEBUG" );
    $styles = &TWiki::Func::getPreferencesValue( "STYLEPLUGIN_SITESTYLES" ) ||
      ".sample {text-decoration:underline}"; # drb 3/9
    $applied = 0;

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::StylePlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

sub startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    &TWiki::Func::writeDebug( "- StylePlugin::startRenderingHandler( $_[1].$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    my $cskin = &TWiki::Func::getSkin();
    my $skipit = 0;
    foreach my $ss (split(/\s*,\s*/, $skipskin)) {
        if ($cskin eq $ss) {
            $skipit = 1;
        }
    }
    return if ($skipit);
    # emit the custom styles ...
    $_[0] = "<style type=\"text/css\">$styles</style>\n$_[0]" if ! $applied;
    # ... but only once
    $applied = 1;
}

# ------------------------=
sub outsidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

#   &TWiki::Func::writeDebug( "- StylePlugin::outsidePREHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, in loop outside of <PRE> tag.
    # This is the place to define customized rendering rules.
    # Note: This is an expensive function to comment out.
    # Consider startRenderingHandler instead
	# blockquote begin: ---"(
	$_[0] =~ s/^---\"\(\s*$/<blockquote>/go;
	# blockquote end: ---")
	$_[0] =~ s/^---\"\)\s*$/<\/blockquote>/go;
	# pre style begin: ---{.style
	$_[0] =~ s/^---\{\.(\w+)\s*$/<pre class=$1>/go;
	# pre style end: ---}
	$_[0] =~ s/^---\}\s*$/<\/pre>/go;
	# div style begin: ---[.style
	$_[0] =~ s/^---\[\.(\w+)\s*$/<div class=$1>/go;
	# div style end: ---]
	$_[0] =~ s/^---\]\s*$/<\/div>/go;
	# paragraph style begin: .style
	$_[0] =~ s/^\.(\w+)\s*$/<p class=$1>/go;
	# acronym: ((acronym)(abbreviation)(text)) e.g. ((acronym)(RSS)(Rich Site Summary))
	$_[0] =~ s/\(\(acronym\)\((\w+)\)\(([^\(\)]*)\)\)/<acronym title="$2">$1<\/acronym>/go;
	# span: ((style)(text))
	$_[0] =~ s/\(\((\w+)\)\(([^\(\)]*)\)\)/<span class=$1>$2<\/span>/go;
}

1;
