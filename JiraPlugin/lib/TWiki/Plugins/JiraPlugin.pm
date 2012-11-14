# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2012 TWiki:Main.MahiroAndo
# Copyright (C) 2012 TWiki Contributors
# All Rights Reserved.
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

=pod

---+ package JiraPlugin

Jira Plugin

=cut

package TWiki::Plugins::JiraPlugin;

# Always use strict to enforce variable scoping
use strict;

require TWiki::Func;
require TWiki::Plugins;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

$VERSION = '$Rev$';
$RELEASE = '2012-11-13';

# Short description of this plugin
# One line description, is shown in the %TWIKIWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION = 'Display JIRA issues using JQL search';
$NO_PREFS_IN_TOPIC = 1;

# Name of this Plugin, only used in this module
$pluginName = 'JiraPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

=cut

my $logging = 0;

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    $logging = $TWiki::cfg{Plugins}{JiraPlugin}{TagUsageLogging} || 0;
    TWiki::Func::registerTagHandler( 'JIRA', \&_JIRA );

    return 1;
}

sub _JIRA {
    my($session, $params, $theTopic, $theWeb) = @_;
    my $warn = TWiki::Func::isTrue($params->{warn}, 1);
    my $result = '';
    
    eval {
        my $handlerClass = 'TWiki::Plugins::JiraPlugin::Handler';
        eval "use $handlerClass";
        die $@ if $@;

        my $handler = $handlerClass->new($session, $params, $theTopic, $theWeb);
        $handler->logging($logging);
        $result = $handler->generate();
    };

    if ($@) {
        if ($warn) {
            (my $msg = (split /\n/, $@)[0]) =~ s/^(.*) at .*/$1/;
            return '%RED%'.$msg.'%ENDCOLOR%';
        } else {
            return '';
        }
    }

    return $result;
}

1;
