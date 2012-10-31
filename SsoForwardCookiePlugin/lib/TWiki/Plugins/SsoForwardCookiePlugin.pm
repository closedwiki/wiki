# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2011 Peter Thoeny, peter[at]thoeny.org
# Copyright (C) 2001-2011 TWiki Contributors.
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
# For licensing info read LICENSE file in the TWiki root.

=pod

---+ package SsoForwardCookiePlugin

This plugin forwards SSO cookies to external resources.

=cut

# Always use strict to enforce variable scoping
use strict;

package TWiki::Plugins::SsoForwardCookiePlugin;

# Name of this Plugin, only used in this module
our $pluginName = 'SsoForwardCookiePlugin';

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package. It should always be Rev enclosed in dollar
# signs so that TWiki can determine the checked-in status of the plugin.
# It is used by the build automation tools, so you should leave it alone.
our $VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS. Add a release date in ISO
# format (preferred) or a release number such as '1.3'.
our $RELEASE = '2012-10-24';

# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION = 'This plugin forwards SSO cookies to external resources.';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use preferences
# stored in the plugin topic. This default is required for compatibility with
# older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, use $TWiki::cfg entries set in LocalSite.cfg, or
# if you want the users to be able to change settings, then use standard TWiki
# preferences that can be defined in your Main.TWikiPreferences and overridden
# at the web and topic level.
our $NO_PREFS_IN_TOPIC = 1;

# Define other global package variables
our $debug;

my $handler;

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.5 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    $handler = __PACKAGE__->new();
    TWiki::Func::registerExternalHTTPHandler( \&handleExternalHTTPRequest );

    # Plugin correctly initialized
    return 1;
}

sub handleExternalHTTPRequest {
    my ($session, $url) = @_;
    my $this = $handler;

    my $headers = [];
    my $params = {};

    $this->writeDebug("Begin hook: $url") if $this->debug;

    if (defined(my $matchedDomain = $this->matchDomain($url))) {
        if (@{$this->{cookieNames}}) {
            if ($this->debug) {
                my $names = join(', ', @{$this->{cookieNames}});
                $this->writeDebug("Forwardable cookie names = $names");
            }

            my $cookieJar = ($params->{cookie_jar} ||= do {
                require HTTP::Cookies;
                HTTP::Cookies->new();
            });

            my $domain = $this->{cookieDomain} || $matchedDomain;
            my $path = $this->{cookiePath} || '/';
            $this->addForwardedCookies($cookieJar, $this->{cookieNames}, $domain, $path);
        } else {
            $this->writeDebug("No cookie names are configured") if $this->debug;
        }
    }

    $this->writeDebug("End hook") if $this->debug;

    return ($headers, $params);
}

sub new {
    my ($class) = @_;
    my $cfg = $TWiki::cfg{Plugins}{SsoForwardCookiePlugin} || {};

    my @domains;
    $class->parseDomains($cfg->{Domains} || '', \@domains);

    my @cookieNames;

    for my $name (split /\s*,\s*/, ($cfg->{CookieNames} || '')) {
        $name =~ s/^\s+|\s+$//g;
        push @cookieNames, $name if $name ne '';
    }

    # RFC2965: Domain comparisons SHALL be case-insensitive
    # RFC2109: x.y.com domain-matches .y.com but not y.com
    my $domainPattern = join('|', map {
        (/^\./ ? '' : '^').quotemeta($_).'$';
    } @domains);

    my $this = bless {
        debug         => TWiki::isTrue($cfg->{Debug}),
        domainPattern => (@domains ? qr{($domainPattern)}i : undef),
        cookieNames   => \@cookieNames,
        cookieDomain  => $cfg->{CookieDomain},
        cookiePath    => $cfg->{CookiePath},
    }, $class;

    if ($this->debug) {
        for my $key (keys %$cfg) {
            my $lhs = "\$cfg{Plugins}{SsoForwardCookiePlugin}{$key}";
            my $rhs = $cfg->{$key};
            $this->writeDebug("$lhs = $rhs");
        }
    }

    return $this;
}

sub parseDomains {
    my ($this, $input, $result, $seen) = @_;
    $result ||= [];
    $seen   ||= {};

    for my $domain (split /\s*,\s*/, $input) {
        $domain =~ s/^\s+|\s*#.*|\s+$//g;
        next if $domain eq '';

        if ($domain =~ m{^file:(.*)}i) {
            my $file = $1;
            next if $seen->{$file};
            $seen->{$file} = 1; # avoid unintended recursion

            if (open(my $in, $file)) {
                $this->parseDomains($_, $result, $seen) while <$in>;
                close $in;
            } else {
                $this->writeWarning("$!: $file");
            }
        } else {
            push @$result, $domain;
        }
    }

    return $result;
}

sub debug {
    my ($this) = @_;
    return $this->{debug};
}

sub writeDebug {
    my $this = shift;

    if ($this->{debug}) {
        TWiki::Func::writeDebug("SsoForwardCookiePlugin: $_") foreach @_;
    }
}

sub writeWarning {
    my $this = shift;
    TWiki::Func::writeWarning("SsoForwardCookiePlugin: $_") foreach @_;
}

sub matchDomain {
    my ($this, $url) = @_;
    my $pattern = $this->{domainPattern};

    $this->writeDebug("Matching URL with domain pattern") if $this->debug;

    if ($pattern) {
        $this->writeDebug("Pattern = $pattern") if $this->debug;
	} else {
        $this->writeDebug("No SSO domains are configured") if $this->debug;
        return undef;
    }

    my $host;
   
    if (ref $url) {
        $host = $url->host;
    } else {
        if ($url =~ m{^https?://([^\/\?\#:]+)}) {
            $host = $1;
            $host =~ s/.*@//;
        }
    };

    return undef if !defined $host;

    $this->writeDebug("Target host = $host") if $this->debug;

    if ($host =~ $pattern) {
        my $matched = $1;
        $this->writeDebug("Matched domain = $matched") if $this->debug;
        return $matched;
    } else {
        $this->writeDebug("Did not match any domains") if $this->debug;
        return undef;
    }
}

sub addForwardedCookies {
    my ($this, $cookieJar, $cookieNames, $domain, $path) = @_;
    $path ||= '/';

    my $forwardAll = (@$cookieNames == 1 && $cookieNames->[0] eq '*');
    my $shouldForward = {map {$_ => 1} @$cookieNames};

    if ($this->debug) {
        $this->writeDebug("All cookies are forwarded") if $forwardAll;

        my $len = length($ENV{HTTP_COOKIE} || '');
        $this->writeDebug("HTTP_COOKIE env var has length $len");
    }

    my $cnt = 0;

    for my $c (split(/\s*;\s*/, $ENV{HTTP_COOKIE})) {
        my ($name, $value) = split(/=/, $c, 2);
        $this->writeDebug("- Checking cookie: $name") if $this->debug;

        if ($forwardAll || $shouldForward->{$name}) {
            $this->writeDebug("  - Adding cookie: $name") if $this->debug;
            $cookieJar->set_cookie(undef, $name, $value, $path, $domain);
            $cnt++;
        }
    }

    $this->writeDebug("$cnt cookie(s) have been added") if $this->debug;
    return $cookieJar;
}

1;
