# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 Michael Daum http://wikiring.com
# Portions Copyright (C) 2006 Spanlink Communications
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

package TWiki::Plugins::LdapNgPlugin;

use strict;
use vars qw($VERSION $RELEASE $isInitialized);

$VERSION = '$Rev$';
$RELEASE = 'v0.01';

###############################################################################
sub initPlugin { 
  $isInitialized = 0;
  return 1; 
}

###############################################################################
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;

  $_[0] =~ s/%LDAP{(.*?)}%/&handleLdap($_[2], $_[1], $1)/ge;
}

###############################################################################
sub afterCommonTagsHandler {
  return unless $isInitialized;
  return TWiki::Plugins::LdapNgPlugin::Core::afterCommonTagsHandler(@_);
}

###############################################################################
sub handleLdap {

  unless ($isInitialized) {
    eval 'use TWiki::Plugins::LdapNgPlugin::Core;';
    die $@ if $@;
    $isInitialized = 1;
  }

  return TWiki::Plugins::LdapNgPlugin::Core::handleLdap(@_);
}




1;
