# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2002-2012 Peter Thoeny, peter[at]thoeny.org
# Copyright (C) 2005-2006 Michael Daum <micha@nats.informatik.uni-hamburg.de>
# Copyright (C) 2005-2012 TWiki Contributors
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
# =========================
#
# This is the HeadlinesPlugin used to show RSS news feeds.
# Plugin home: http://TWiki.org/cgi-bin/view/Plugins/HeadlinesPlugin
#

# =========================
package TWiki::Plugins::HeadlinesPlugin;
use strict;

# =========================
our $VERSION = '$Rev$';
our $RELEASE = '2012-12-10';
our $NO_PREFS_IN_TOPIC = 1;
our $SHORTDESCRIPTION = 'Show headline news in TWiki pages based on RSS and ATOM news feeds from external sites';
our $isInitialized = 0;
our $doneHeader = 0;

# =========================
sub initPlugin {

  $isInitialized = 0;
  $doneHeader = 0;

  return 1;
}

# =========================
my $cssLink = 
      '<link rel="stylesheet" '.
      'href="%PUBURL%/%SYSTEMWEB%/HeadlinesPlugin/style.css" '.
      'type="text/css" media="all" />';
sub commonTagsHandler {

  my $r = ($_[0] =~
    s/([ \t]*)%HEADLINES{(.*?)}%/handleHeadlinesTag($_[2], $_[1], $1, $2)/geo);

  if ($r && !$doneHeader) {
    TWiki::Func::addToHEAD('HEADLINESPLUGIN', $cssLink);
    $doneHeader = 1;
  }
}

# =========================
sub handleHeadlinesTag {
  
  unless ($isInitialized) {
    eval 'use TWiki::Plugins::HeadlinesPlugin::Core;';
    die $@ if $@;
    $isInitialized = 1;
  }

  return TWiki::Plugins::HeadlinesPlugin::Core::handleHeadlinesTag(@_);
}

1;
