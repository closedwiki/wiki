# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
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

=pod

---+ package JiraPlugin

Jira Plugin

=cut

# change the package name and $pluginName!!!
package TWiki::Plugins::JiraPlugin;

# Always use strict to enforce variable scoping
use strict;

require TWiki::Func;
require TWiki::Plugins;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package.
use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# Short description of this plugin
# One line description, is shown in the %TWIKIWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION = 'Display JIRA issues by JQL search';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use preferences
# stored in the plugin topic. This default is required for compatibility with
# older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, use $TWiki::cfg entries set in LocalSite.cfg, or
# if you want the users to be able to change settings, then use standard TWiki
# preferences that can be defined in your Main.TWikiPreferences and overridden
# at the web and topic level.
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
