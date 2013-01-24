# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007-2010 Arthur Clemens (arthur@visiblearea.com), Michael Daum and Foswiki contributors
# Copyright (C) 2007-2011 TWiki Contributors
#
# All Rights Reserved. TWiki Contributors are listed in the AUTHORS
# file in the root of this distribution.
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
# As per the GPL, removal of this notice is prohibited.

package TWiki::Plugins::SendEmailPlugin;

use strict;
use TWiki::Func;

our $VERSION    = '$Rev$';
our $RELEASE    = '2013-01-24';
our $pluginName = 'SendEmailPlugin';
our $SHORTDESCRIPTION = "Allows to send e-mails through an e-mail form.";
our $NO_PREFS_IN_TOPIC = 1;
our $topic;
our $web;

sub initPlugin {
    ( $topic, $web ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between SendEmailPlugin and Plugins.pm");
        return 0;
    }

    TWiki::Func::registerTagHandler( 'SENDEMAIL', \&handleSendEmailTag );
    
    # Plugin correctly initialized
    return 1;
}

sub handleSendEmailTag {
    require TWiki::Plugins::SendEmailPlugin::Core;
    TWiki::Plugins::SendEmailPlugin::Core::handleSendEmailTag(@_);
}

1;
