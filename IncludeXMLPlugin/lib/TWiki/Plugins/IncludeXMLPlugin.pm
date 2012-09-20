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

---+ package IncludeXMLPlugin

=cut

use strict;
package TWiki::Plugins::IncludeXMLPlugin;

use TWiki;
use TWiki::Func;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package.
use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

# This should always be $Rev: 12445$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 12445$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# Short description of this plugin
# One line description, is shown in the %TWIKIWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION = 'Display an XML document in a tabular format';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use preferences
# stored in the plugin topic. This default is required for compatibility with
# older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, use $TWiki::cfg entries set in LocalSite.cfg, or
# if you want the users to be able to change settings, then use standard TWiki
# preferences that can be defined in your Main.TWikiPreferences and overridden
# at the web and topic level.
$NO_PREFS_IN_TOPIC = 1;

# Name of this Plugin, only used in this module
$pluginName = 'IncludeXMLPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

REQUIRED

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using TWiki::Func::writeWarning and return 0. In this case
%FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

You may also call =TWiki::Func::registerTagHandler= here to register
a function to handle variables that have standard TWiki syntax - for example,
=%MYTAG{"my param" myarg="My Arg"}%. You can also override internal
TWiki variable handling functions this way, though this practice is unsupported
and highly dangerous!

__Note:__ Please align variables names with the Plugin name, e.g. if 
your Plugin is called FooBarPlugin, name variables FOOBAR and/or 
FOOBARSOMETHING. This avoids namespace issues.

=cut

my $handlerClass = 'TWiki::Plugins::IncludeXMLPlugin::Handler';
my $handlerLoaded = 0;
my $completePageHandlerSupported = 0;

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    if ($TWiki::Plugins::VERSION >= 1.2) {
        $completePageHandlerSupported = 1;
    }

    TWiki::Func::registerTagHandler(INCLUDEXML => \&_INCLUDEXML);

    return 1;
}

sub postRenderingHandler {
    unless ($completePageHandlerSupported) {
        $handlerClass->clearCache() if $handlerLoaded;
    }
}

sub completePageHandler {
    $completePageHandlerSupported = 1;
    $handlerClass->clearCache() if $handlerLoaded;
}

sub _INCLUDEXML {
    my ($session, $params, $theTopic, $theWeb) = @_;
    my $warn = TWiki::isTrue($params->{warn}, 1);
    my $tag = 'INCLUDEXML';

    unless ($handlerLoaded) {
        eval "use $handlerClass";

        if ($@) {
            TWiki::Func::writeWarning($@);

            if ($warn) {
                return "%RED%$tag: Failed to load package $handlerClass: "._formatError($@)."%ENDCOLOR%";
            } else {
                return '';
            }
        }

        $handlerLoaded = 1;
    }

    my $result = \'';

    eval {
        my $prefParams = TWiki::Func::getPreferencesValue($tag."_PARAMS");

        if ($prefParams) {
            my %commonParams = TWiki::Func::extractParameters($prefParams);

            for my $key (keys %commonParams) {
                unless (exists $params->{$key}) {
                    $params->{$key} = $commonParams{$key};
                }
            }
        }

        my $handler = $handlerClass->new(@_);
        $result = $handler->generate();
    };

    if ($@) {
        if (ref $@ eq 'SCALAR') {
            $result = \('<verbatim>'.${$@}.'</verbatim>');
        } else {
            $result = \("%RED%$tag: "._formatError($@)."%ENDCOLOR%") if $warn;
        }
    }

    return $$result;
}

sub _formatError {
    my ($err) = @_;

    # Do not show any stacktraces to the user
    $err =~ s/\n.*//s;

    # Escape HTML
    $err =~ s/&/&amp;/g;
    $err =~ s/</&lt;/g;
    $err =~ s/>/&gt;/g;
    $err =~ s/"/&quot;/g;

    return $err;
}

1;
