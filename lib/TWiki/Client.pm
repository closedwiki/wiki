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
my $M1 = chr(5);
my $M2 = chr(6);
my $M3 = chr(7);

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
    #TWiki::registerTagHandler('LOGINURLPATH', \&_LOGINURLPATH);
    TWiki::registerTagHandler('LOGIN', \&_LOGIN);
    #TWiki::registerTagHandler('LOGOUTURL', \&_LOGOUTURL);
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

    my $query = $this->{twiki}->{cgiQuery};

    my $twiki = $this->{twiki};

    $this->{haveCookie} = defined($query->raw_cookie( $CGI::Session::NAME ));

    # Use file serialisation.
    # An interesting experiment might be to change your serializer. Storable
    # is a good option. See CGI::Session on http://search.cpan.org/
    # for more information on adding ';initializer:Storable' after the
    # 'driver:File' below (other serializers are available as well).
    my $cgisession = CGI::Session->new( 'driver:File', $query,
                                       { Directory => $TWiki::cfg{SessionDir} } );

    $this->{cgisession} = $cgisession;

    # expire the session after idle time
    $cgisession->expire($TWiki::cfg{SessionExpiresAfter});

    my $sessionId = $cgisession->id();
    $this->{sessionId} = $sessionId;

    # Check, and clear bad, session.
    $this->checkSession();

    # See whether the user was logged in (first webserver, then
    # session, then default)
    my $authUser = $this->getUser( $this );
    $authUser ||= $cgisession->param( 'AUTHUSER' );

    # if we couldn't get the login manager or the http session to tell
    # us who the user is, then let's use the CGI "remote user"
    # variable (which may have been set manually by a unit test,
    # or it might have come from Apache).
    $authUser ||= $twiki->{remoteUser};

    # Save the users information again if they do not appear to be a guest
    my $sessionIsAuthenticated =
      ( $authUser && $authUser ne $TWiki::cfg{DefaultUserLogin} );

    my $do_logout = defined( $query ) && $query->param( 'logout' );
    if( $do_logout ) {
        $sessionIsAuthenticated = 0;
        $authUser = undef;
    }

    if( ( $do_logout || $sessionIsAuthenticated )) {
        $cgisession->param( 'AUTHUSER', $authUser );
        $cgisession->flush();
    }

    if( $do_logout ) {
        my $origurl = $query->url() . $query->path_info();
        #my $url = $twiki->getScriptUrl( $web, $topic, '' ).
        #  '?origurl='.$origurl;
        $this->redirectCgiQuery( $query, $origurl );

        # mod_perl is okay with calling exit (it patches it) but
        # the unit tests aren't. so doing a "redirect abort" should
        # probably terminate processing using an exception.
        # exit 0;
    }

    # Save our state to member variables, because we'll need them later.
    $this->{authUser} = $authUser;
    if( $sessionIsAuthenticated ) {
        $twiki->enterContext( 'authenticated' );
    } else {
        $twiki->leaveContext( 'authenticated' );
    }

    # Use transparent session IDs if cookies don't seem to be working
    $this->{useTransSID} = 
      ( !defined($query) || !$query->cookie( $CGI::Session::NAME ));

    $twiki->{SESSION_TAGS}{SESSIONID} = ( $sessionId || '' );
    $twiki->{SESSION_TAGS}{SESSIONVAR} = ( $CGI::Session::NAME || '' );

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
        $script =~ s@^.*/([^/]+)@$1@g;

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

    my $cgisession = $this->{cgisession};
    return unless $cgisession;

    # this predicate used to be
    # $this->{sessionIsAuthenticated} && defined($cgisession),
    # but that had the problem that sometimes an unauthenticated version
    # of the session would overwrite the more recent authenticated version
    # on disk. that's because with mod_perl, an unflushed session object
    # would sometimes hang around. then when the apache server was
    # terminated, it would get flushed. this way, if we didn't get a
    # cookie then we'll tell the session manager that we don't want
    # it to _ever_ flush the session.
    if($this->{haveCookie}) {
        $cgisession->flush();
    } else {
        # this is drastic and not really necessary, but unfortunately
        # CGI::Session makes it impossible for us to say "don't
        # _bother_ writing it to disk if you haven't already". :-(
        $cgisession->delete();
    }
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

    my $cgisession = $this->{cgisession};
    return 0 unless $cgisession;

    if( $authUser && $authUser ne $TWiki::cfg{DefaultUserLogin} ) {
        $cgisession->param( 'AUTHUSER', $authUser );
        $cgisession->flush();
        $this->{twiki}->enterContext( 'authenticated' );
    } else {
        $cgisession->param( 'AUTHUSER', '' );
        $cgisession->flush();
        $this->{twiki}->leaveContext( 'authenticated' );
    }

    $this->{authUser} = $authUser;
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

    my $useTransSID = $this->{useTransSID};
    my $sessionId = $this->{sessionId};

    # If cookies are not turned on and transparent CGI session IDs are,
    # grab every URL that is an internal link and pass a CGI variable
    # with the session ID
    if( $useTransSID ) {
        # Internal links are specified by forms, hrefs, or onclicks that either
        # point to a link with no colons in it or links that match links that
        # would bve returned by getScriptUrl. Internal links are additionally
        # specified by forms that have no target.

        # Gather the URLs one would expect to be returned by getScriptUrl
        # if a URL was inside of quotes (A) or outside of quotes (B) or
        # inside of single quotes for javascript (C).
        #
        # SMELL: this will munge URLs in verbatim sections
        #
        # Use these later in all the regex's below.
        my $myScriptUrlA = quotemeta($this->{twiki}->getScriptUrl( $M1, $M1,
                                                                   $M1 ));
        my $myScriptUrlB = $myScriptUrlA;
        my $myScriptUrlC = $myScriptUrlA;
        $myScriptUrlA =~ s/$M1/[^"#]*?/go;
        $myScriptUrlB =~ s/$M1/[^\\s#>]*?/go;
        $myScriptUrlC =~ s/$M1/[^'#>]*?/go;

        #
        # NOTE: Lots of the defined's here are to quiet down the highly overrated perl -w
        #

        # Catch hyperlinks with targets containing no colon
        $_[0] =~ s/(<a\s[^>]*?(?<=\s)href=)(?:(")([^:]*?)([#"])|([^:]*?(?=[#\s>])))/@{[ defined($5) ? "$1$5" : "$1$2$3" ]}@{[ ( (defined($3) && ($3=~m!\?!))||(defined($5) && ($5=~m!\?!)) ) ? ";" : "?" ]}$CGI::Session::NAME=$sessionId@{[defined($4) ? "$4" : ""]}/goi;

        # Catch hyperlinks with targets that could be returned by getScriptUrl
        $_[0] =~ s/(<a\s[^>]*?(?<=\s)href=)(?:(")((?-i:$myScriptUrlA[^"#]*?))([#"])|((?-i:$myScriptUrlB[^\s#>]*?).*?(?=[#\s>])))/@{[ defined($5) ? "$1$5" : "$1$2$3"]}@{[( (defined($3) && ($3=~m!\?!))||(defined($5) && ($5=~m!\?!)) )? ";" : "?" ]}$CGI::Session::NAME=$sessionId@{[ defined($4) ? "$4" : ""]}/goi;

        # Catch onclicks that trigger changes of location.href to targets with no colon
        $_[0] =~ s/(<[^>]*?\sonclick=(?:"[^"]*?|)(?=(?:javascript:|))location\.href=)(')([^:]*?)([#'])/$1$2$3@{[ ($3=~m!\?!) ? ";" :"?" ]}$CGI::Session::NAME=$sessionId$4/goi;

        # Catch onclicks that trigger changes of location.href to targets that could be returned by getScriptUrl
        $_[0] =~ s/(<[^>]*?\sonclick=(?:"[^"]*?|)(?=(?:javascript:|))location\.href=)(')((?-i:$myScriptUrlC[^'#]*?))([#'])/$1$2$3@{[ ($3=~m!\?!) ? ";" : "?" ]}$CGI::Session::NAME=$sessionId$4/goi;


        # Catch all FORM elements and add a hidden Session ID variable
        #
        # Only do this if the form is pointing to an internal link. This occurs if there are no
        # colons in its target, if it has no target, or if its target matches a getScriptUrl URL.
        #
        $_[0] =~ s%(<form[^>]*?>)%@{ [ "$1" . ( ( $1 =~ /^<form(?:(?!.*?\saction=).*?>|\s.*?(?<=\s)action=(?:"(?:[^:]*?|(?-i:$myScriptUrlA))"|(?:[^:"\s]*?|(?-i:$myScriptUrlB))(?:\s|>)))/ ) ? "\n<input type=\"hidden\" name=\"$CGI::Session::NAME\" value=\"$sessionId\" />" : "") ] }%gio;

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

    my $cgisession = $this->{cgisession};
    return unless $cgisession;

    my $query = $this->{twiki}->{cgiQuery};

    my $c = CGI::Cookie->new( -name => $CGI::Session::NAME,
                              -value => $cgisession->id,
                              -path => '/' );

    my @cs = @{$this->{cookies}};
    push @cs, $c;
    $hopts->{cookie} = \@cs;
}

=pod

---++ ObjectMethod redirectCgiQuery( $url )
Generate an HTTP redirect on STDOUT, if you can. Return 1 if you did.
Don't forget to pass all query parameters through.
   * =$url= - target of the redirection.

=cut

sub redirectCgiQuery {

    my( $this, $query, $url ) = @_;
    my $cgisession = $this->{cgisession};

    unless( $cgisession ) {
        # no session info to add
        return 0;
    }

    my $sessionId = $this->{sessionId};
    my $useTransSID = $this->{useTransSID};
    my @urlparts;

    if( $useTransSID && $url !~ m/\?$CGI::Session::NAME=/ ) {
        # If the URL has no colon in it, it must be an internal URL
        if( $url !~ /:/ ) {
            # Does it already have CGI parameters passed?
            if( $url =~ m/^(.*?)\?(.*)$/ ) {
                $url = $1 . '?'.$CGI::Session::NAME.'='.$sessionId.';'.$2;
            }
            # Does it have any anchors passed?
            elsif( $url =~ m/^(.*?)#(.*)$/ ) {
                $url = $1.'?'.$CGI::Session::NAME.'='.$sessionId.'#'.$2;
            }
            # Otherwise, we're the first CGI parameter
            else {
                $url .= '?'.$CGI::Session::NAME.'='.$sessionId;
            }

        } else {
            # It MAY be an external URL
            # This could be better. This could be integrated into the above...
            # This could use split instead of regex's...

            # Remember our scriptUrl form to match internal URLs that are referred
            # to like external URLs
            my $myScriptUrl = quotemeta($this->{twiki}->getScriptUrl(
                                            $M1, $M2, $M3 ));
            $myScriptUrl =~ s@$M1@[^/]*?@go;
            $myScriptUrl =~ s@$M2@[^#\?/]*@go;
            $myScriptUrl =~ s@$M3@[^/]*?@go;

            # If we start with our internal URL....
            if( $url =~ /(^$myScriptUrl)/o ) {
                my $theScript = $1;

                # Are there other CGI parameters?
                if( $url =~ /(?:^$theScript)(?:\?)(.*)/ ) {
                    $url = $theScript . '?' . $CGI::Session::NAME . '=' .
                      $sessionId . ';' . $1;
                }
                # Are there any anchors?
                elsif( $url =~ /(?:^$theScript)(#.*)/ ) {
                    $url = $theScript . '?' . $CGI::Session::NAME . '=' .
                      $sessionId . $1;
                }
                # Otherwise, we're the first CGI parameter
                else {
                    $url = $theScript . '?' . $CGI::Session::NAME . '=' .
                      $sessionId;
                }
            }
        }
    }

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
                                   -value => $cgisession->id,
                                   -path => '/' );
    my @cs = @{$this->{cookies}};
    push @cs, $cookie;
    print $query->redirect( -url => $url, -cookie => \@cs );

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

=pod

---++ ObjectMethod checkSession()

Verify that the username we're given matches the session
already stored, and clear the stored session if it doesn't.

If there is another valid username stored in the session,
then someone has somehow just borrowed a session ID from someone
else. To prevent further havoc, clear this session (perhaps
in the future it'd be better just to dispatch a new session ID
to this user; however, if they already have the session ID of
another user, it's probably best to get rid of it since it has
been compromised).

Only makes sense for session managers where there is an alternative source
for a username apart from the stored session (e.g. Apache).

=cut

sub checkSession {
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
    my $useTransSID = $this->{useTransSID};

    my $urlToUse = $this->loginUrlPath();

    if( $useTransSID ) {
        $urlToUse .= ( '?' . $CGI::Session::NAME . '=' . $sessionId );
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
