use strict;
use warnings;

package TWiki::Plugins::SingleSignOnPlugin::HTTPRequestHandler;

sub new {
    my ($class, $session) = @_;
    my $cfg = $TWiki::cfg{Plugins}{SingleSignOnPlugin} || {};

    my @domains;

    for my $domain (split /\s*,\s*/, ($cfg->{Domains} || '')) {
        $domain =~ s/^\s+|\s+$//g;
        push @domains, $domain if $domain ne '';
    }

    my @cookieNames;

    for my $name (split /\s*,\s*/, ($cfg->{ForwardedCookieNames} || '')) {
        $name =~ s/^\s+|\s+$//g;
        push @cookieNames, $name if $name ne '';
    }

    my $this = bless {
        session      => $session,
        enabled      => TWiki::isTrue($cfg->{Debug}),
        debug        => TWiki::isTrue($cfg->{Debug}),
        domains      => \@domains,
        cookieNames  => \@cookieNames,
        cookieDomain => $cfg->{ForwardedCookieDomain},
        cookiePath   => $cfg->{ForwardedCookiePath},
    }, $class;

    if ($this->debug) {
        if ($this->{enabled}) {
            for my $key (keys %$cfg) {
                my $lhs = "\$cfg{Plugins}{SingleSignOnPlugin}{$key}";
                my $rhs = $cfg->{$key};
                $this->writeDebug("$lhs = $rhs");
            }
        } else {
            $this->writeDebug("Plugin is not enabled");
        }
    }

    return $this;
}

sub debug {
    my ($this) = @_;
    return $this->{debug};
}

sub writeDebug {
    my $this = shift;

    if ($this->{debug}) {
        TWiki::Func::writeDebug("SingleSignOnPlugin: $_") foreach @_;
    }
}

sub handle {
    my ($this, $ua, $request) = @_;

    unless ($this->{enabled}) {
        return;
    }

    my $uri = $request->uri;

    $this->writeDebug("Begin hook: ".$request->method." => $uri") if $this->debug;

    if (defined(my $matchedDomain = $this->matchDomain($uri, $this->{domains}))) {
        if (@{$this->{cookieNames}}) {
            if ($this->debug) {
                my $names = join(', ', @{$this->{cookieNames}});
                $this->writeDebug("Forwardable cookie names: $names");
            }

            my $cookieJar = $ua->cookie_jar || do {
                require HTTP::Cookies;
                HTTP::Cookies->new();
            };

            my $domain = $this->{cookieDomain} || $matchedDomain;
            my $path = $this->{cookiePath} || '/';
            $this->addForwardedCookies($cookieJar, $this->{cookieNames}, $domain, $path);
            $ua->cookie_jar($cookieJar);
        } else {
            $this->writeDebug("No cookie names are configured") if $this->debug;
        }
    }

    $this->writeDebug("End hook") if $this->debug;
}

sub matchDomain {
    my ($this, $uri, $domains) = @_;

    $this->writeDebug("Matching URI with domains: ".join(', ', @$domains)) if $this->debug;

    if (@$domains == 0) {
        $this->writeDebug("No SSO domains are configured") if $this->debug;
        return undef;
    }

    my $host;
   
    if (ref $uri) {
        $host = $uri->host;
    } else {
        if ($uri =~ m{^https?://([^\/\?\#:])}) {
            $host = $1;
            $host =~ s/.*@//;
        }
    };

    return undef if !defined $host;
    my $lc_host = lc $host; # RFC2965: Domain comparisons SHALL be case-insensitive

    $this->writeDebug("Target host = $lc_host") if $this->debug;

    for my $domain (@$domains) {
        my $lc_domain = lc $domain;
        $this->writeDebug("- Checking domain: $domain") if $this->debug;

        # RFC2109: x.y.com domain-matches .y.com but not y.com
        if ($lc_domain =~ /^\./) {
            if (substr($lc_host, -length($lc_domain)) eq $lc_domain) {
                $this->writeDebug("  - Matched domain: $domain") if $this->debug;
                return $domain;
            }
        } else {
            if ($lc_host eq $lc_domain) {
                $this->writeDebug("  - Matched domain: $domain") if $this->debug;
                return $domain;
            }
        }
    }

    $this->writeDebug("Matched no domains") if $this->debug;
    return undef;
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
