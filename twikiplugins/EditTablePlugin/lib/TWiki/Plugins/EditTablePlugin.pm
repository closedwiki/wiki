# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2002-2007 Peter Thoeny, peter@thoeny.org and TWiki
# Contributors.
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
#
# This is the EditTablePlugin used to edit tables in place.

package TWiki::Plugins::EditTablePlugin;

use strict;

use vars qw(
  $web $topic $user $VERSION $RELEASE $debug
  $query $renderingWeb $usesJavascriptInterface $viewModeHeaderDone $editModeHeaderDone $encodeStart $encodeEnd $prefsInitialized $table
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '4.4';

$encodeStart = '--EditTableEncodeStart--';
$encodeEnd   = '--EditTableEncodeEnd--';

sub initPlugin {
    ( $topic, $web, $user ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between EditTablePlugin and Plugins.pm");
        return 0;
    }

    $query = TWiki::Func::getCgiQuery();
    if ( !$query ) {
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag('EDITTABLEPLUGIN_DEBUG');
    $usesJavascriptInterface =
      TWiki::Func::getPreferencesFlag('EDITTABLEPLUGIN_JAVASCRIPTINTERFACE');
    $viewModeHeaderDone = 0;
    $editModeHeaderDone = 0;
    $prefsInitialized   = 0;
    $renderingWeb       = $web;

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::EditTablePlugin::initPlugin( $web.$topic ) is OK")
      if $debug;

    # Initialize $table such that the code will correctly detect when to
    # read in a topic.
    undef $table;

    return 1;
}

=pod

Parse text before variables are expanded. This way TWiki variables can be used
inside table cells.

=cut

sub beforeCommonTagsHandler {
    _process(@_);

}

=pod

The handler has to be run from both beforeCommonTagsHandler and
commonTagsHandler, because beforeCommonTagsHandler allows us to
process tables before TWiki variables in their data are expanded,
while the second call allos us to handle tables that have been
included from other topics. Both handlers only fire when the topic
text contains %EDITTABLE, thus constraining the problem.

=cut

sub commonTagsHandler {
    _process(@_);
}

sub _process {
    my ( $theText, $theTopic, $theWeb ) = @_;

    return unless $_[0] =~ /%EDIT(TABLE|CELL){(.*)}%/os;
    addViewModeHeadersToHead();

    require TWiki::Plugins::EditTablePlugin::Core;
    TWiki::Plugins::EditTablePlugin::Core::process( $_[0], $theTopic, $theWeb,
        $topic, $web );
}

sub postRenderingHandler {
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    $_[0] =~ s/$encodeStart(.*?)$encodeEnd/decodeValue($1)/geos;
}

sub encodeValue {
    my ($theText) = @_;

    # FIXME: *very* crude encoding to escape Wiki rendering inside form fields
    # also prevents urls to get expanded to links
    $theText =~ s/\./%dot%/gos;
    $theText =~ s/(.)/\.$1/gos;

    # convert <br /> markup to unicode linebreak character for text areas
    $theText =~ s/.<.b.r. .\/.>/&#10;/gos;
    return $encodeStart . $theText . $encodeEnd;
}

sub decodeValue {
    my ($theText) = @_;

    $theText =~ s/\.(.)/$1/gos;
    $theText =~ s/%dot%/\./gos;
    $theText =~ s/\&([^#a-z])/&amp;$1/go;    # escape non-entities
    $theText =~ s/</\&lt;/go;                # change < to entity
    $theText =~ s/>/\&gt;/go;                # change > to entity
    $theText =~ s/\"/\&quot;/go;             # change " to entity

    return $theText;
}

=pod

Style sheet for table in view mode

=cut

sub addViewModeHeadersToHead {
    return if $viewModeHeaderDone;

    $viewModeHeaderDone = 1;

    my $header = <<'EOF';
<style type="text/css" media="all">
@import url("%PUBURL%/%SYSTEMWEB%/EditTablePlugin/edittable.css");
</style>
EOF
    TWiki::Func::addToHEAD( 'EDITTABLEPLUGIN', $header );
}

=pod

Style sheet and javascript for table in edit mode

=cut

sub addEditModeHeadersToHead {
    my ( $tableNr, $assetUrl ) = @_;

    return if $editModeHeaderDone;
    return if !$usesJavascriptInterface;

    require TWiki::Contrib::BehaviourContrib;
    TWiki::Contrib::BehaviourContrib::addHEAD();

    $editModeHeaderDone = 1;

    my $tableId = "edittable$tableNr";
    my $header  = "";
    $header .=
      '<meta name="EDITTABLEPLUGIN_EditTableId" content="' . $tableId . '" />';
    $header .= "\n"
      . '<meta name="EDITTABLEPLUGIN_EditTableUrl" content="'
      . $assetUrl . '" />';
    $header .= <<'EOF';
<style type="text/css" media="all">
@import url("%PUBURL%/%SYSTEMWEB%/EditTablePlugin/edittable.css");
</style>
<script type="text/javascript" src="%PUBURL%/%SYSTEMWEB%/EditTablePlugin/edittable.js"></script>
EOF

    TWiki::Func::addToHEAD( 'EDITTABLEPLUGIN', $header );
}

1;

