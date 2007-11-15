# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (c) 2007 Michael Daum, daum@wikiring.de
# 
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::JQueryPlugin;
use strict;
use vars qw( 
  $VERSION $RELEASE $SHORTDESCRIPTION 
  $NO_PREFS_IN_TOPIC
  $doneInit $doneHeader
);

$VERSION = '$Rev$';
$RELEASE = 'v0.4'; 
$SHORTDESCRIPTION = 'jQuery <nop>JavaScript library for TWiki';
$NO_PREFS_IN_TOPIC = 1;

###############################################################################
sub initPlugin {
  my( $topic, $web, $user, $installWeb ) = @_;

  $doneInit = 0;
  $doneHeader = 0;
  TWiki::Func::registerTagHandler('BUTTON', \&handleButton );
  TWiki::Func::registerTagHandler('TOGGLE', \&handleToggle );
  TWiki::Func::registerTagHandler('CLEAR', \&handleClear );
  return 1;
}

###############################################################################
sub commonTagsHandler {

  return if $doneHeader;

  my $header = <<'HERE';
<link rel="stylesheet" href="%PUBURLPATH%/%TWIKIWEB%/JQueryPlugin/jquery-all.css" type="text/css" media="all" />
<script type="text/javascript">
var twiki;
if (!twiki) { 
  twiki = {}; 
}
twiki.pubUrlPath = '%PUBURLPATH%';
twiki.viewUrlPath = '%SCRIPTURLPATH{"view"}%';
twiki.editUrlPath = '%SCRIPTURLPATH{"edit"}%';
twiki.renameUrlPath = '%SCRIPTURLPATH{"rename"}%';
twiki.saveUrlPath = '%SCRIPTURLPATH{"save"}%';
twiki.twikiWeb = '%TWIKIWEB%';
twiki.mainWeb = '%MAINWEB%';
twiki.wikiName = '%USERINFO{format="$wikiname"}%';
twiki.userName = '%USERINFO{format="$username"}%';
twiki.JQueryPluginEnabled = 1;
</script>
<script type="text/javascript" src="%PUBURLPATH%/%TWIKIWEB%/JQueryPlugin/jquery-all.js"></script>
HERE

  $doneHeader = 1 if ($_[0] =~ s/<head>(.*?[\r\n]+)/<head>$1$header\n/o);
}

###############################################################################
sub initCore {
  return if $doneInit;
  $doneInit = 1;
  eval "use TWiki::Plugins::JQueryPlugin::Core;";
  die $@ if $@;
}

###############################################################################
sub handleButton {
  initCore();
  return TWiki::Plugins::JQueryPlugin::Core::handleButton(@_);
}

###############################################################################
sub handleToggle {
  initCore();
  return TWiki::Plugins::JQueryPlugin::Core::handleToggle(@_);
}

###############################################################################
sub handleClear {
  return '<br clear="all" />';
}

1;
