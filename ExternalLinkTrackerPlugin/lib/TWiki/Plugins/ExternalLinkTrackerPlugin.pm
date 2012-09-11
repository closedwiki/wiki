# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2012 FIXME
# Copyright (C) 2012 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution.
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

package TWiki::Plugins::ExternalLinkTrackerPlugin;

use strict;

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version

#==================================================================
our $VERSION = '$Rev$';
our $RELEASE = '2012-09-10';
our $SHORTDESCRIPTION = 'Track and report on users clicking on external links';
our $NO_PREFS_IN_TOPIC = 1;

my $core;

#==================================================================
sub initPlugin {

    $core = undef;
    TWiki::Func::registerTagHandler( 'EXLINK', \&_EXLINK );

    # Plugin correctly initialized
    return 1;
}

#==================================================================
sub _EXLINK {
    my( $session, $params, $topic, $web ) = @_;

    # delay loading core module until run-time
    unless( $core ) {
        my $type = 'cgi';
        if( $session && $session->can( 'inContext' ) ) {
            $type = 'cli' if( $session->inContext( 'command_line' ) );
        } elsif( ! $ENV{GATEWAY_INTERFACE} && ! $ENV{MOD_PERL} ) {
            $type = 'cli';
        }
        require TWiki::Plugins::ExternalLinkTrackerPlugin::Core;
        my $cfg = {
          ScriptType => $type,
        };
        $core = new TWiki::Plugins::ExternalLinkTrackerPlugin::Core( $cfg );
    }
    my $query = TWiki::Func::getCgiQuery();
    if( $query ) {
        foreach my $key ( $query->param ) {
            next if( defined $params->{$key} );
            $params->{$key} = $query->param( $key );
        }
    }
    return $core->EXLINK( $params, $topic, $web );
}

#==================================================================
1;
