# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (c) 2007-2008 Michael Daum, http://michaeldaumconsulting.com
# Copyright (c) 2007-2011 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution.
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
  $doneInit $doneHeader $doneJQueryUI
  $jqPubUrlPath $header
);

$VERSION = '$Rev$';
$RELEASE = '1.2 (2011-02-28)';
$SHORTDESCRIPTION = 'jQuery <nop>JavaScript library for TWiki';
$NO_PREFS_IN_TOPIC = 1;

$jqPubUrlPath = '%PUBURLPATH%/%SYSTEMWEB%/JQueryPlugin';
$header = "<script type=\"text/javascript\" src=\"$jqPubUrlPath/jquery.js\"></script>\n"
        . "<link rel=\"stylesheet\" href=\"$jqPubUrlPath/jquery-all.css\" type=\"text/css\" media=\"all\" />\n"
        . "<script type=\"text/javascript\" src=\"$jqPubUrlPath/jquery-all.js\"></script>\n";

###############################################################################
sub initPlugin {
  my( $topic, $web, $user, $installWeb ) = @_;

  $doneInit = 0;
  $doneHeader = 0;
  $doneJQueryUI = 0;

  TWiki::Func::registerTagHandler('JQBUTTON', \&handleButton );
  TWiki::Func::registerTagHandler('JQTOGGLE', \&handleToggle );
  TWiki::Func::registerTagHandler('JQCLEAR', \&handleClear );
  TWiki::Func::registerTagHandler('JQTABPANE', \&handleTabPane );
  TWiki::Func::registerTagHandler('JQENDTABPANE', \&handleEndTabPane );
  TWiki::Func::registerTagHandler('JQTAB', \&handleTab );
  TWiki::Func::registerTagHandler('JQENDTAB', \&handleEndTab );
  TWiki::Func::registerTagHandler('JQSCRIPT', \&handleJQueryScript );
  TWiki::Func::registerTagHandler('JQTHEME', \&handleJQueryTheme );
  TWiki::Func::registerTagHandler('JQIMAGESURLPATH', \&handleJQueryImagesUrlPath );

  if( $TWiki::cfg{JQueryPlugin}{Legacy2008} ) {
    TWiki::Func::registerTagHandler('BUTTON', \&handleButton );
    TWiki::Func::registerTagHandler('TOGGLE', \&handleToggle );
    TWiki::Func::registerTagHandler('CLEAR', \&handleClear );
    TWiki::Func::registerTagHandler('TABPANE', \&handleTabPane );
    TWiki::Func::registerTagHandler('ENDTABPANE', \&handleEndTabPane );
    TWiki::Func::registerTagHandler('TAB', \&handleTab );
    TWiki::Func::registerTagHandler('ENDTAB', \&handleEndTab );
  }

  return 1;
}

###############################################################################
sub commonTagsHandler {

  return if $doneHeader;
  $doneHeader = 1 if ($_[0] =~ s/<head>(.*?[\r\n]+)/<head>$1$header/o);
}

###############################################################################
sub initCore {
  return if $doneInit;
  $doneInit = 1;
  eval "use TWiki::Plugins::JQueryPlugin::Core;";
  die $@ if $@;
  TWiki::Plugins::JQueryPlugin::Core::init( $jqPubUrlPath );
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
sub handleTabPane {
  initCore();
  return TWiki::Plugins::JQueryPlugin::Core::handleTabPane(@_);
}

###############################################################################
sub handleTab {
  initCore();
  return TWiki::Plugins::JQueryPlugin::Core::handleTab(@_);
}

###############################################################################
sub handleEndTab {
  return '</div></div>';
}

###############################################################################
sub handleEndTabPane {
  return '</div>';
}

###############################################################################
sub handleClear {
  return '<br clear="all" />';
}

###############################################################################
sub jQueryUI {
  return if $doneJQueryUI;
  $doneJQueryUI = 1;
  return "<script type=\"text/javascript\" src=\"$jqPubUrlPath/jquery-ui.js\"></script>";
}

###############################################################################
sub handleJQueryScript	{
  my ($session, $params, $theTopic, $theWeb) = @_;   

  my $scriptFileName = $params->{_DEFAULT};
  return '' unless $scriptFileName;
  $scriptFileName .= '.js' unless $scriptFileName =~ /\.js$/;
  return jQueryUI() if( $scriptFileName eq 'jquery-ui.js' );

  return "<script type=\"text/javascript\" src=\"$jqPubUrlPath/$scriptFileName\"></script>";
}

###############################################################################
sub handleJQueryTheme {
  my ($session, $params, $theTopic, $theWeb) = @_;   

  my $themeName = $params->{_DEFAULT};
  return '' unless $themeName;
  my $url = "$jqPubUrlPath/themes/$themeName/jquery-ui.$themeName.css";
  TWiki::Func::addToHEAD(
    "jquery_theme_$themeName",
    '<link rel="stylesheet" type="text/css" href="' . $url . '" media="all" />'
  );
  return jQueryUI();
}

###############################################################################
sub handleJQueryImagesUrlPath {
  my ($session, $params, $theTopic, $theWeb) = @_;   
  my $image = $params->{_DEFAULT};
  return "$jqPubUrlPath/images/$image" if defined $image;
  return "$jqPubUrlPath/images";
}

1;
