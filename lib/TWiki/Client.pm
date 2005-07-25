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

Factory for client objects (session managers) and also
base class for these same objects. The default behaviour
is no logins.

If you are building a new login manager, then you should write
a new subclass of this class, implementing the methods marked
as *VIRTUAL*. There are already examples in the =lib/TWiki/Client=
directory.

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

    if( $TWiki::cfg{LoginManager} eq 'none' ||
          !$TWiki::cfg{UseClientSessions} ) {
        # No login manager; just use default behaviours
        return new TWiki::Client( $twiki);
    } else {
        eval 'use CGI::Session; use CGI::Cookie; use '.
          $TWiki::cfg{LoginManager};
        throw Error::Simple( 'Login Manager: '.$@) if $@;

        return $TWiki::cfg{LoginManager}->new( $twiki );
    }
}

# protected: Construct new client object.

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( {}, $class );
    ASSERT($session->isa( 'TWiki')) if DEBUG;
    $this->{twiki} = $session;
    $this->{canLogin} = 0; # override in subclass constructor
    $this->{cookies} = [];
    map{ $this->{authScripts}{$_} = 1; }
      split( /[\s,]+/, $TWiki::cfg{AuthScripts} );

    # register tag handlers and values
    TWiki::registerTagHandler('LOGINURL', \&_LOGINURL);
    #TWiki::registerTagHandler('LOGINURLPATH', \&_LOGINURLPATH);
    TWiki::registerTagHandler('LOGIN', \&_LOGIN);
    #TWiki::registerTagHandler('LOGOUTURL', \&_LOGOUTURL);
    TWiki::registerTagHandler('LOGOUT', \&_LOGOUT);
    TWiki::registerTagHandler('CANLOGIN', \&_CANLOGIN);
    TWiki::registerTagHandler('SESSION_VARIABLE', \&_SESSION_VARIABLE);
    TWiki::registerTagHandler('AUTHENTICATED', \&_AUTHENTICATED);

    return $this;
}

=pod

---++ ObjectMethod load()

Get the client session data, using the cookie and/or the request URL.

=cut

sub load {
    my $this = shift;

    return unless( $TWiki::cfg{UseClientSessions} );

    my $query = $this->{twiki}->{cgiQuery};

    my $twiki = $this->{twiki};

    # Initialize the session (you may wish to change this directory,
    # but /tmp is probably best)
    #
    # Borrowing from the previous version of TWiki, perhaps using:
    #
    #   TWiki::Func::getDataDir() . '/.session'
    #
    # would work well for you. Just be sure to create data/.session
    # and make it writable by the webserver.
    #
    # Another experiment might be to change your serializer. Storable
    # is a good option. See CGI::Session on http://search.cpan.org/
    # for more information on adding ';initializer:Storable' after the
    # 'driver:File' below (other serializers are available as well).

    $this->{haveCookie} = defined($query->raw_cookie( $CGI::Session::NAME ));

    my $cgisession = new CGI::Session( 'driver:File', $query,
                                       { Directory=>'/tmp' } );

    $this->{cgisession} = $cgisession;

    my $sessionId = $cgisession->id();
    $this->{sessionId} = $sessionId;

    my $guest = $TWiki::cfg{DefaultUserLogin};

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

    # Save the user's information again if they do not appear to be a guest
    my $sessionIsAuthenticated = ( $authUser ne $guest );

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

    # SMELL: $TWiki::cfg{UseTransSessionId} is not set in TWiki.cfg,
    # and it isn't clear what it should be set to even if it is.
    # $useTransSID sets whether or not to use
    # transparent CGI session IDs. If cookies are working, turn
    # this off. Otherwise, set it to whatever the user set in
    # $useTransSessionId. Still report to the user though that
    # %USE_TRANS_SESSIONID% is set to $useTransSessionId
    my $useTransSID = (defined($query) &&
                         $query->cookie( $CGI::Session::NAME ))
      ? 0 : $TWiki::cfg{UseTransSessionId};

    # Save our state to member variables, because we'll need them later.
    $this->{authUser} = $authUser;
    $this->{sessionIsAuthenticated} = $sessionIsAuthenticated;
    $this->{useTransSID} = $useTransSID;

    $twiki->{SESSION_TAGS}{SESSIONID} = ( $sessionId || '' );
    $twiki->{SESSION_TAGS}{SESSIONVAR} = ( $CGI::Session::NAME || '' );
    #$twiki->{SESSION_TAGS}{USE_TRANS_SESSIONID} = ( $useTransSID || '');

    # SMELL: are these really necessary? Put them back if they are
    # justified/documented
    #$twiki->{SESSION_TAGS}{STICKSKIN} =
    #( defined($query) && $query->param( 'stickskin' ) ) || '';
    #$twiki->{SESSION_TAGS}{STICKSKINVAR} = 'stickskin';
    #$twiki->{SESSION_TAGS}{STICKSKINOFFVALUE} = 'default';

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

    unless( $this->{sessionIsAuthenticated} ) {
        my $script = $ENV{'SCRIPT_NAME'} || $ENV{'SCRIPT_FILENAME'};
        $script =~ s@^.*/([^/]+)@$1@g;

        if( defined $script && $this->{authScripts}{$script} ) {
            my $topic = $this->{twiki}->{topicName};
            my $web = $this->{twiki}->{webName};
            throw TWiki::AccessControlException(
                $script, $this->{twiki}->{user}, $web, $topic,
                'authorization required' );
        }
    }
}

=pod

---++ ObjectMethod finish
Complete processing after the client's HTTP request has been responded
to. Flush the user's session (if any) to disk.

=cut

sub finish {
    return unless( $TWiki::cfg{UseClientSessions} );
    my $this = shift;
    my $cgisession = $this->{cgisession};

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
    my ( $this, $authUser, $wikiName ) = @_;

    my $cgisession = $this->{cgisession};
    my $sessionIsAuthenticated = defined($authUser) ? 1 : 0;

    if( $TWiki::cfg{DefaultUserLogin} ne $authUser ) {
        $cgisession->param( 'AUTHUSER', $authUser );
        $cgisession->flush();
    }

    $this->{authUser} = $authUser;
    $this->{sessionIsAuthenticated} = $sessionIsAuthenticated;
}

=pod

---++ ObjectMethod endRenderingHandler()
SMELL: this method uses the plugins endRenderingHandler method which is
deprecated, and stunningly inefficient. It badly needs to be refactored.

=cut

sub endRenderingHandler {
    return unless( $TWiki::cfg{UseClientSessions} );

    my $this = shift;

    my $useTransSID = $this->{useTransSID};
    my $sessionId = $this->{sessionId};

    # This handler is called by getRenderedVersion just after the line loop, that is,
    # after almost all XHTML rendering of a topic. <nop> tags are removed after this.

    # If cookies are not turned on and transparent CGI session IDs are,
    # grab every URL that is an internal link and pass a CGI variable
    # with the session ID
    if( $useTransSID ) {
        # Internal links are specified by forms, hrefs, or onclicks that either
        # point to a link with no colons in it or links that match links that
        # would bve returned by getScriptUrl. Internal links are additionally
        # specified by forms that have no target.

        # Gather the URLs one would expect to be returned by getScriptUrl if a URL
        # was inside of quotes (A) or outside of quotes (B) or inside of single quotes
        # for javascript (C).
        #
        # Use these later in all the regex's below.
        my $myScriptUrlA = quotemeta($this->{twiki}->getScriptUrl( $M1, $M1,
                                                                   $M1 ));
        my $myScriptUrlB = $myScriptUrlA;
        my $myScriptUrlC = $myScriptUrlA;
        $myScriptUrlA =~ s/$M1/[^"#]*?/g;
        $myScriptUrlB =~ s/$M1/[^\\s#>]*?/g;
        $myScriptUrlC =~ s/$M1/[^'#>]*?/g;

        #
        # NOTE: Lots of the defined's here are to quiet down the highly overrated perl -w
        #

        # Catch hyperlinks with targets containing no colon
        $_[0] =~ s/(<a\s[^>]*?(?<=\s)href=)(?:(")([^:]*?)([#"])|([^:]*?(?=[#\s>])))/@{[ defined($5) ? "$1$5" : "$1$2$3" ]}@{[ ( (defined($3) && ($3=~m!\?!))||(defined($5) && ($5=~m!\?!)) ) ? "&" : "?" ]}$CGI::Session::NAME=$sessionId@{[defined($4) ? "$4" : ""]}/goi;

        # Catch hyperlinks with targets that could be returned by getScriptUrl
        $_[0] =~ s/(<a\s[^>]*?(?<=\s)href=)(?:(")((?-i:$myScriptUrlA[^"#]*?))([#"])|((?-i:$myScriptUrlB[^\s#>]*?).*?(?=[#\s>])))/@{[ defined($5) ? "$1$5" : "$1$2$3"]}@{[( (defined($3) && ($3=~m!\?!))||(defined($5) && ($5=~m!\?!)) )? "&" : "?" ]}$CGI::Session::NAME=$sessionId@{[ defined($4) ? "$4" : ""]}/goi;

        # Catch onclicks that trigger changes of location.href to targets with no colon
        $_[0] =~ s/(<[^>]*?\sonclick=(?:"[^"]*?|)(?=(?:javascript:|))location\.href=)(')([^:]*?)([#'])/$1$2$3@{[ ($3=~m!\?!) ? "&" :"?" ]}$CGI::Session::NAME=$sessionId$4/goi;

        # Catch onclicks that trigger changes of location.href to targets that could be returned by getScriptUrl
        $_[0] =~ s/(<[^>]*?\sonclick=(?:"[^"]*?|)(?=(?:javascript:|))location\.href=)(')((?-i:$myScriptUrlC[^'#]*?))([#'])/$1$2$3@{[ ($3=~m!\?!) ? "&" : "?" ]}$CGI::Session::NAME=$sessionId$4/goi;


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
    return unless( $TWiki::cfg{UseClientSessions} );

    my( $this, $hopts ) = @_;

    my $query = $this->{twiki}->{cgiQuery};

    my $c = new CGI::Cookie( -name => $CGI::Session::NAME,
                             -value => $this->{cgisession}->id,
                             -path => '/' );

    my @cs = @{$this->{cookies}};
    push @cs, $c;
    $hopts->{cookie} = \@cs;
}

=pod

---++ ObjectMethod redirectCgiQuery( $url )
Generate an HTTP redirect on STDOUT. Return 1 if the redirect was generated,
0 otherwise.
   * =$url= - target of the redirection.

=cut

sub redirectCgiQuery {
    return 0 unless $TWiki::cfg{UseClientSessions};

    my( $this, $query, $url ) = @_;

    my $sessionId = $this->{sessionId};
    my $useTransSID = $this->{useTransSID};
    my $cgisession = $this->{cgisession};
    my @urlparts;

    if( $useTransSID && $url !~ m/\?$CGI::Session::NAME=/ ) {
        # If the URL has no colon in it, it must be an internal URL
        if( $url !~ /:/ ) {
            # Does it already have CGI parameters passed?
            if( $url =~ m/\?/ ) {
                @urlparts = split( $url, /\?/, 2 );
                $url = $urlparts[0] . "?$CGI::Session::NAME=$sessionId;" . $urlparts[1];
            }
            # Does it have any anchors passed?
            elsif( $url =~ m/#/ ) {
                @urlparts = split( $url, /#/, 2 );
                $url = $urlparts[0] . "?$CGI::Session::NAME=$sessionId#" . $urlparts[1];
            }
            # Otherwise, we're the first CGI parameter
            else {
                $url .= "?$CGI::Session::NAME=$sessionId";
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
    my $cookie = new CGI::Cookie( -name => $CGI::Session::NAME,
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
    if(( $key ne 'AUTHUSER' ) &&
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
    if( ( $key ne 'AUTHUSER' ) && 
          defined( $cgisession->param( $key ))) {
        $cgisession->clear( [ $_[1] ] );

        return 1;
    }

    return undef;
}

=pod

---++ ObjectMethod authenticate()

*VIRTUAL METHOD* implemented by subclasses

Test to see if the current session is authenticated or not. If not,
generate a redirect to an appropriate login URL.

If the user has an existing authenticated session, the function simply drops
though and returns 0. If session is not authenticated it
forces redirection to the "login" script, passing it the original URL,
and returns 1;

=cut

sub authenticate {
    # Default behaviour is no login
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

=pod

---++ ObjectMethod login( $query, $session )

Handler called from the "login" script. This script is automatically
redirected to if there is no existing session cookie.

If a login name and password have been passed in the query, it
validates these and if authentic, redirects to the original
script. If there is no username in the query or the username/password is
invalid (validate returns non-zero) then it prompts again.

=cut

sub login {
    my( $this, $query, $twikiSession ) = @_;
    my $cgisession = $this->{cgisession};
    my $twiki = $this->{twiki};

    my $origurl = $query->param( 'origurl' );
    my $loginName = $query->param( 'username' );
    my $loginPass = $query->param( 'password' );

    my $tmpl = $twiki->{templates}->readTemplate(
        'login', $twiki->getSkin() );

    my $banner = $twiki->{templates}->expandTemplate( 'LOG_IN_BANNER' );
    my $note = '';
    my $topic = $twiki->{topicName};
    my $web = $twiki->{webName};

    my $currUser = $cgisession->param( 'AUTHUSER' );
    if( $currUser ) {
        $banner = $twiki->{templates}->expandTemplate( 'LOGGED_IN_BANNER' );
        $note = $twiki->{templates}->expandTemplate( 'NEW_USER_NOTE' );
    }

    if( $loginName ) {
        my $passwordHandler = $twiki->{users}->{passwords};
        my $validation = $passwordHandler->checkPassword( $loginName, $loginPass );
        if( $validation ) {
            $this->userLoggedIn( $loginName );
            $cgisession->param( 'VALIDATION', $validation );
            if( !$origurl || $origurl eq $query->url() ) {
                $origurl = $twiki->getScriptUrl( $web, $topic, 'view' );
            }
            $this->redirectCgiQuery( $query, $origurl );
            return;
        } else {
            $banner = $twiki->{templates}->expandTemplate('UNRECOGNISED_USER');
        }
    }

    # TODO: add JavaScript password encryption in the template
    # to use a template)
    $origurl ||= '';
    $tmpl =~ s/%ORIGURL%/$origurl/g;
    $tmpl =~ s/%BANNER%/$banner/g;
    $tmpl =~ s/%NOTE%/$note/g;

    $tmpl = $twiki->handleCommonTags( $tmpl, $web, $topic );
    $tmpl = $twiki->{renderer}->getRenderedVersion( $tmpl, '' );
    $twiki->writePageHeader( $query );
    print $tmpl;
}

sub _CANLOGIN {
    return shift->{client}->{canLogin};
}

sub _LOGIN {
    #my( $session, $params, $topic, $web ) = @_;
    my $twiki = shift;
    my $this = $twiki->{client};
    ASSERT($this->isa('TWiki::Client')) if DEBUG;
    my $sessionIsAuthenticated = $this->{sessionIsAuthenticated};

    return '' if($sessionIsAuthenticated);

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

    return '' unless( $this->{sessionIsAuthenticated} );

    my $url = _LOGOUTURL( @_ );
    if( $url ) {
        my $text = $twiki->{templates}->expandTemplate('LOG_OUT');
        return '[['.$url.']['.$text.']]';
    }
    return '';
}

sub _AUTHENTICATED {
    my( $session, $params ) = @_;
    my $this = $session->{client};
    ASSERT($this->isa('TWiki::Client')) if DEBUG;

    if( $this->{sessionIsAuthenticated} ) {
        return $params->{then} || 1;
    } else {
        return $params->{else} || 0;
    }
}

sub _SESSION_VARIABLE {
    my( $session, $params ) = @_;
    my $this = $session->{client};
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
    my( $session, $params ) = @_;
    my $this = $session->{client};
    ASSERT($this->isa('TWiki::Client')) if DEBUG;
    return $this->loginUrl();
}

sub _LOGINURLPATH {
    my( $session, $params ) = @_;
    my $this = $session->{client};
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
