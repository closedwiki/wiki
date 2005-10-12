# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2005 Garage Games
# Copyright (C) 2005 Crawford Currie http://c-dot.co.uk
# Copyright (C) 2005 Greg Abbas, twiki@abbas.org
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

=pod

---+ package TWiki::Client

The package is also a Factory for login managers and also the base class
for all login managers.

On it's own, an object of this class is used when you specify 'none' in
the security setup section of
[[%SCRIPTURL%/configure%SCRIPTSUFFIX%][configure]]. When it is used,
logins are not supported. If you want to authenticate users then you should
consider TemplateLogin or ApacheLogin, which are subclasses of this class.

If you are building a new login manager, then you should write a new subclass
of this class, implementing the methods marked as *VIRTUAL*. There are already
examples in the =lib/TWiki/Client= directory.

=cut

package TWiki::Client;

use strict;
use Assert;
use Error qw( :try );

BEGIN {
    # suppress stupid warning in CGI::Cookie
    if ( exists $ENV{MOD_PERL} ) {
        if ( !defined( $ENV{MOD_PERL_API_VERSION} )) {
            $ENV{MOD_PERL_API_VERSION} = 1;
        }
    }
}

# Marker chars
use vars qw( $M1 $M2 $M3 );
$M1 = chr(5);
$M2 = chr(6);
$M3 = chr(7);

=pod

---++ StaticMethod makeClient( $twiki ) -> $TWiki::Client
Factory method, used to generate a new TWiki::Client object
for the given session.

=cut

sub makeClient {
    my $twiki = shift;
    ASSERT($twiki->isa( 'TWiki')) if DEBUG;

    if( $TWiki::cfg{UseClientSessions} ) {
        eval 'use CGI::Session; use CGI::Cookie';
        throw Error::Simple( $@ ) if $@;
        CGI::Session->name( 'TWIKISID' );
    }

    my $mgr;
    if( $TWiki::cfg{LoginManager} eq 'none' ) {
        # No login manager; just use default behaviours
        $mgr = new TWiki::Client( $twiki );
    } else {
        eval 'use '. $TWiki::cfg{LoginManager};
        throw Error::Simple( $@ ) if $@;
        $mgr = $TWiki::cfg{LoginManager}->new( $twiki );
    }
    return $mgr;
}

# protected: Construct new client object.

sub new {
    my ( $class, $twiki ) = @_;
    my $this = bless( {}, $class );
    ASSERT($twiki->isa( 'TWiki')) if DEBUG;
    $this->{twiki} = $twiki;
    $twiki->leaveContext( 'can_login' );
    $this->{cookies} = [];
    map{ $this->{authScripts}{$_} = 1; }
      split( /[\s,]+/, $TWiki::cfg{AuthScripts} );

    # register tag handlers and values
    TWiki::registerTagHandler('LOGINURL', \&_LOGINURL);
    TWiki::registerTagHandler('LOGIN', \&_LOGIN);
    TWiki::registerTagHandler('LOGOUT', \&_LOGOUT);
    TWiki::registerTagHandler('SESSION_VARIABLE', \&_SESSION_VARIABLE);
    TWiki::registerTagHandler('AUTHENTICATED', \&_AUTHENTICATED);
    TWiki::registerTagHandler('CANLOGIN', \&_CANLOGIN);

    return $this;
}

=pod

---++ ObjectMethod loadSession()

Get the client session data, using the cookie and/or the request URL.
Set up appropriate session variables in the twiki object and return
the login name.

=cut

sub loadSession {
    my $this = shift;

    return undef unless( $TWiki::cfg{UseClientSessions} );

    my $twiki = $this->{twiki};
    my $query = $twiki->{cgiQuery};

    $this->{haveCookie} = $query->raw_cookie();

    # Try and get the user from the webserver
    my $authUser = $this->getUser( $this );

    # First, see if there is a cookied session, creating a new session
    # if necessary.
    my $cgisession = CGI::Session->new(
        undef, $query,
        { Directory => $TWiki::cfg{SessionDir} } );

    $authUser ||= $cgisession->param( 'AUTHUSER' );

    # if we couldn't get the login manager or the http session to tell
    # us who the user is, then let's use the CGI "remote user"
    # variable (which may have been set manually by a unit test,
    # or it might have come from Apache).
    $authUser ||= $twiki->{remoteUser};

    # is this a logout?
    if( $query && $query->param( 'logout' ) ) {
        my $origurl = $query->url().$query->path_info();
        $this->redirectCgiQuery( $query, $origurl );
        $authUser = undef;
    }

    $this->{cgisession} = $cgisession;
    $this->userLoggedIn( $authUser );

    $twiki->{SESSION_TAGS}{SESSIONID} = $this->{sessionId};
    $twiki->{SESSION_TAGS}{SESSIONVAR} = $CGI::Session::NAME;

    return $authUser;
}

=pod

---++ ObjectMethod checkAccess()
Check if the script being run in this session is authorised for execution.
If not, throw an access control exception.

=cut

sub checkAccess {

    return unless( $TWiki::cfg{UseClientSessions} );

    my $this = shift;

    unless( $this->{twiki}->inContext( 'authenticated' ) ||
              $TWiki::cfg{LoginManager} eq 'none' ) {
        my $script = $ENV{'SCRIPT_NAME'} || $ENV{'SCRIPT_FILENAME'};
        $script =~ s@^.*/([^/]+)@$1@g if $script;

        if( defined $script && $this->{authScripts}{$script} ) {
            my $topic = $this->{twiki}->{topicName};
            my $web = $this->{twiki}->{webName};
            throw TWiki::AccessControlException(
                $script, $this->{twiki}->{user}, $web, $topic,
                'authentication required' );
        }
    }
}

=pod

---++ ObjectMethod finish
Complete processing after the client's HTTP request has been responded
to. Flush the user's session (if any) to disk.

=cut

sub finish {
    my $this = shift;

    _expireDeadSessions();
}

# Delete sessions that are sitting around but are really expired.
# This *assumes* that the sessions are stored as files.
# Ths doesn't get run until after the user's query has been
# responded to, so it shouldn't be burdensome.
sub _expireDeadSessions {
	my $time = time() || 0;

	opendir(D, $TWiki::cfg{SessionDir}) || return;
	foreach my $file ( grep { /cgisess_[0-9a-f]{32}/ } readdir(D) ) {
        $file = TWiki::Sandbox::untaintUnchecked(
            $TWiki::cfg{SessionDir}.'/'.$file );
		my @stat = stat( $file );

        my $lat = $stat[8] || $stat[9] || $stat[10] || 0;
		# Abort tiny 2-day olds. They can't be valid sessions.
		if( $time - $lat >= $TWiki::cfg{SessionExpiresAfter} &&
              $stat[7] <= 6 ) {
			unlink $file;
			next;
		}

		# Ignore tiny new files. They can't be complete sessions.
		next if ($stat[7] <= 6);

		open(F, $file) || next;
		my $session = <F>;
		close F;

        # SMELL: security hazard?
        $session = TWiki::Sandbox::untaintUnchecked( $session );

        my $D;
		eval $session;
		next if ( $@ );
        # The session is expired if it is empty, hasn't been accessed in ages
        # or has exceeded its registered expiry time.
        if( !$D ||
              $time >= $D->{_SESSION_ATIME} +
                $TWiki::cfg{SessionExpiresAfter} ||
                  $D->{_SESSION_ETIME} && $time >= $D->{_SESSION_ETIME} ) {
            unlink( $file );
            next;
        }
	}
	closedir D;
}

=pod

---++ ObjectMethod userLoggedIn( $login, $wikiname)

Called when the user logs in. It's invoked from TWiki::UI::Register::finish
for instance, when the user follows the link in their verification email
message.
   * =$login= - string login name
   * =$wikiname= - string wikiname

=cut

sub userLoggedIn {
    my( $this, $authUser, $wikiName ) = @_;

    my $twiki = $this->{twiki};

    my $cgisession = $this->{cgisession} ||
      # create new session if necessary
      CGI::Session->new(
          undef, $twiki->{cgiQuery},
          { Directory => $TWiki::cfg{SessionDir} } );
    $this->{cgisession} = $cgisession;

    if( $authUser && $authUser ne $TWiki::cfg{DefaultUserLogin} ) {
        $cgisession->param( 'AUTHUSER', $authUser );
        $twiki->enterContext( 'authenticated' );
    } else {
        # if we are not authenticated, expire any existing session
        $cgisession->clear( [ 'AUTHUSER' ] );
        $twiki->leaveContext( 'authenticated' );
    }

    $this->{sessionId} = $cgisession->id();
    $this->{authUser} = $authUser;
}

# get an RE that matches a local script URL
sub _myScriptURL {
    my $this = shift;

    my $s = $this->{_MYSCRIPTURL};
    unless( $s ) {
        $s = quotemeta($this->{twiki}->getScriptUrl( $M1, $M2, $M3 ));
        $s =~ s@\\$M1@[^/]*?@go;
        $s =~ s@\\$M2@[^#\?/]*@go;
        $s =~ s@\\$M3@[^/]*?@go;
        $this->{_MYSCRIPTURL} = $s;
    }
    return $s;
}

# Rewrite a URL inserting the session id
sub _rewriteURL {
    my( $this, $url ) = @_;

    return $url unless $url;
    my $sessionId = $this->{sessionId};
    return $url unless $sessionId;
    return $url if $url =~ m/\?$CGI::Session::NAME=/;

    my $s = $this->_myScriptURL();

    # If the URL has no colon in it, or it matches the local script
    # URL, it must be an internal URL and therefore needs the session.
    if( $url !~ /:/ || $url =~ /^$s/ ) {

        # strip off existing params
        my $params = "?$CGI::Session::NAME=$sessionId";
        if( $url =~ s/\?(.*)$// ) {
            $params .= ';'.$1;
        }

        # strip off the anchor
        my $anchor = '';
        if( $url =~ s/(#.*)// ) {
            $anchor = $1;
        }

        # rebuild the URL
        $url .= $anchor.$params;
    } # otherwise leave it untouched

    return $url;
}

# Catch all FORMs and add a hidden Session ID variable.
# Only do this if the form is pointing to an internal link.
# This occurs if there are no colons in its target, if it has
# no target, or if its target matches a getScriptUrl URL.
# '$rest' is the bit of the initial form tag up to the closing >
sub _rewriteFORM {
    my( $this, $url, $rest ) = @_;

    return $url.$rest unless $this->{sessionId};

    my $s = $this->_myScriptURL();

    if( $url !~ /:/ || $url =~ /^$s/ ) {
        $rest .= CGI::hidden( -name => $CGI::Session::NAME,
                              -value => $this->{sessionId});
    }
    return $url.$rest;
}

=pod

---++ ObjectMethod endRenderingHandler()

This handler is called by getRenderedVersion just before the plugins
postRenderingHandler. So it is passed all HTML text just before it is
printed.

=cut

sub endRenderingHandler {
    return unless( $TWiki::cfg{UseClientSessions} );

    my $this = shift;

    # If cookies are not turned on and transparent CGI session IDs are,
    # grab every URL that is an internal link and pass a CGI variable
    # with the session ID
    unless( $this->{haveCookie} ) {
        # rewrite internal links to include the transparent session ID
        # Doesn't catch Javascript, because there are just so many ways
        # to generate links from JS.
        # SMELL: this would probably be done better using javascript
        # that handles navigation away from this page, and uses the
        # rules to rewrite any relative URLs at that time.
        my $s = $this->_myScriptURL();

        # a href= rewriting
        $_[0] =~ s/(<a[^>]*(?<=\s)href=(["']))(.*?)(\2)/$1.$this->_rewriteURL($3).$4/geoi;

        # form action= rewriting
        # SMELL: Forms that have no target are also implicit internal
        # links, but are not handled. Does this matter>
        $_[0] =~ s/(<form[^>]*(?<=\s)(?:action)=(["']))(.*?)(\2[^>]*>)/$1.$this->_rewriteFORM($3, $4)/geoi;
    }

    # And, finally, the logon stuff
    # this MUST render after TigerSkinPlugin commonTagsHandler does TIGERLOGON
    $_[0] =~ s/%SESSIONLOGON%/$this->_dispLogon()/geo;
    $_[0] =~ s/%SKINSELECT%/$this->_skinSelect()/geo;
}

=pod

---++ ObjectMethod addCookie($c)

Add a cookie to the list of cookies for this session.
   * =$c= - a CGI::Cookie

=cut

sub addCookie {
    return unless( $TWiki::cfg{UseClientSessions} );

    my( $this, $c ) = @_;
    ASSERT($c->isa('CGI::Cookie')) if DEBUG;

    push( @{$this->{cookies}}, $c );
}

=pod

---++ ObjectMethod modifyHeader( \%header )
Modify a HTTP header
   * =\%header= - header entries

=cut

sub modifyHeader {
    my( $this, $hopts ) = @_;

    return unless $this->{sessionId};

    my $query = $this->{twiki}->{cgiQuery};
    my $c = CGI::Cookie->new( -name => $CGI::Session::NAME,
                              -value => $this->{sessionId},
                              -path => '/' );

    push( @{$this->{cookies}}, $c );
    $hopts->{cookie} = $this->{cookies};
}

=pod

---++ ObjectMethod redirectCgiQuery( $url )
Generate an HTTP redirect on STDOUT, if you can. Return 1 if you did.
Don't forget to pass all query parameters through.
   * =$url= - target of the redirection.

=cut

sub redirectCgiQuery {

    my( $this, $query, $url ) = @_;

    return 0 unless $this->{sessionId};

    $url = $this->_rewriteURL( $url ) unless $this->{haveCookie};

    # This usually won't be important, but just in case they haven't
    # yet received the cookie and happen to be redirecting, be sure
    # they have the cookie. (this is a lot more important with
    # transparent CGI session IDs, because the session DIES when those
    # people go across a redirect without a ?CGISESSID= in it... But
    # EVEN in that case, they should be redirecting to a URL that
    # already *HAS* a sessionID in it... Maybe...)
    #
    # So this is just a big fat precaution, just like the rest of this
    # whole handler.
    my $cookie = CGI::Cookie->new( -name => $CGI::Session::NAME,
                                   -value => $this->{sessionId},
                                   -path => '/' );
    push( @{$this->{cookies}}, $cookie );
    print $query->redirect( -url => $url, -cookie => $this->{cookies} );

    return 1;
}

=pod

---++ ObjectMethod getSessionValue( $name ) -> $value
Get the value of a session variable.

=cut

sub getSessionValue {
    my( $this, $key ) = @_;
    my $cgisession = $this->{cgisession};
    return undef unless $cgisession;

    return $cgisession->param( $key );
}

=pod

---++ ObjectMethod setSessionValue( $name, $value )
Set the value of a session variable.
We do not allow setting of AUTHUSER.

=cut

sub setSessionValue {
    my( $this, $key, $value ) = @_;
    my $cgisession = $this->{cgisession};

    # We do not allow setting of AUTHUSER.
    if( $cgisession &&
          $key ne 'AUTHUSER' &&
            defined( $cgisession->param( $key, $value ))) {
        return 1;
    }

    return undef;
}

=pod

---++ ObjectMethod clearSessionValue( $name )
Clear the value of a session variable.
We do not allow setting of AUTHUSER.

=cut

sub clearSessionValue {
    my( $this,, $key ) = @_;
    my $cgisession = $this->{cgisession};

    # We do not allow clearing of AUTHUSER.
    if( $cgisession &&
          $key ne 'AUTHUSER' &&
            defined( $cgisession->param( $key ))) {
        $cgisession->clear( [ $_[1] ] );

        return 1;
    }

    return undef;
}

=pod

---++ ObjectMethod forceAuthentication() -> boolean

*VIRTUAL METHOD* implemented by subclasses

Triggered by an access control violation, this method tests
to see if the current session is authenticated or not. If not,
it does whatever is needed so that the user can log in, and returns 1.

If the user has an existing authenticated session, the function simply drops
though and returns 0.

=cut

sub forceAuthentication {
    return 0;
}

=pod

---++ ObjectMethod loginUrl( ... ) -> $url

*VIRTUAL METHOD* implemented by subclasses

Return a full URL suitable for logging in.
   * =...= - url parameters to be added to the URL, in the format required by TWiki::getScriptUrl()

=cut

sub loginUrl {
    return '';
}

=pod

---++ ObjectMethod loginUrlPath() -> $url

*VIRTUAL METHOD* implemented by subclasses

Get a url path for login (no protocol, host)

=cut

sub loginUrlPath {
    my ( $this, $origurl ) = @_;
    my $path = $this->loginUrl( $origurl );
    $path =~ s@.*?//.*?/@/@ if $path;
    return $path;
}

=pod

---++ ObjectMethod getUser()

*VIRTUAL METHOD* implemented by subclasses

If there is some other means of getting a username - for example,
Apache has remote_user() - then return it. Otherwise, return undef and
the username stored in the session will be used.

=cut

sub getUser {
    return undef;
}

sub _LOGIN {
    #my( $twiki, $params, $topic, $web ) = @_;
    my $twiki = shift;
    my $this = $twiki->{client};
    ASSERT($this->isa('TWiki::Client')) if DEBUG;

    return '' if $twiki->inContext( 'authenticated' );

    my $url = $this->loginUrl();
    if( $url ) {
        my $text = $twiki->{templates}->expandTemplate('LOG_IN');
        return '[['.$url.']['.$text.']]';
    }
    return '';
}

sub _LOGOUTURL {
    my( $twiki, $params, $topic, $web ) = @_;
    my $this = $twiki->{client};
    ASSERT($this->isa('TWiki::Client')) if DEBUG;

    return $twiki->getScriptUrl(
        $twiki->{SESSION_TAGS}{BASEWEB},
        $twiki->{SESSION_TAGS}{BASETOPIC},
        'view',
        ( 'logout' => 1 ) );
}

sub _LOGOUT {
    my( $twiki, $params, $topic, $web ) = @_;
    my $this = $twiki->{client};
    ASSERT($this->isa('TWiki::Client')) if DEBUG;

    return '' unless $twiki->inContext( 'authenticated' );

    my $url = _LOGOUTURL( @_ );
    if( $url ) {
        my $text = $twiki->{templates}->expandTemplate('LOG_OUT');
        return '[['.$url.']['.$text.']]';
    }
    return '';
}

sub _AUTHENTICATED {
    my( $twiki, $params ) = @_;
    my $this = $twiki->{client};
    ASSERT($this->isa('TWiki::Client')) if DEBUG;

    if( $twiki->inContext( 'authenticated' )) {
        return $params->{then} || 1;
    } else {
        return $params->{else} || 0;
    }
}

sub _CANLOGIN {
    my( $twiki, $params ) = @_;
    my $this = $twiki->{client};
    ASSERT($this->isa('TWiki::Client')) if DEBUG;
    if( $twiki->inContext( 'can_login' )) {
        return $params->{then} || 1;
    } else {
        return $params->{else} || 0;
    }
}

sub _SESSION_VARIABLE {
    my( $twiki, $params ) = @_;
    my $this = $twiki->{client};
    ASSERT($this->isa('TWiki::Client')) if DEBUG;
    my $name = $params->{_DEFAULT};

    if( defined( $params->{set} ) ) {
        $this->setSessionValue( $name, $params->{set} );
        return '';
    } elsif( defined( $params->{clear} )) {
        $this->clearSessionValue( $name );
        return '';
    } else {
        return $this->getSessionValue( $name );
    }
}

sub _LOGINURL {
    my( $twiki, $params ) = @_;
    my $this = $twiki->{client};
    ASSERT($this->isa('TWiki::Client')) if DEBUG;
    return $this->loginUrl();
}

sub _LOGINURLPATH {
    my( $twiki, $params ) = @_;
    my $this = $twiki->{client};
    ASSERT($this->isa('TWiki::Client')) if DEBUG;
    return $this->loginUrlPath();
}

sub _dispLogon {
    my $this = shift;

    my $twiki = $this->{twiki};
    my $topic = $twiki->{topicName};
    my $web = $twiki->{webName};
    my $sessionId = $this->{sessionId};

    my $urlToUse = $this->loginUrlPath();

    unless( $this->{haveCookie} ) {
        $urlToUse = $this->_rewriteURL( $urlToUse );
    }

    my $text = $twiki->{templates}->expandTemplate('LOG_IN');
    return CGI::a({ class => 'twikiAlert', href => $urlToUse }, $text );
}

sub _skinSelect {
    my $this = shift;
    my $twiki = $this->{twiki};
    my $skins = $twiki->{prefs}->getPreferencesValue('SKINS');
    my $skin = $twiki->getSkin();
    my @skins = split( /,/, $skins );
    unshift( @skins, 'default' );
    my $options = '';
    foreach my $askin ( @skins ) {
        $askin =~ s/\s//go;
        if( $askin eq $skin ) {
            $options .= CGI::option(
                { selected => 'selected', name => $askin }, $askin );
        } else {
            $options .= CGI::option( { name => $askin }, $askin );
        }
    }
    return CGI::Select( { name => 'stickskin' }, $options );
}

1;
