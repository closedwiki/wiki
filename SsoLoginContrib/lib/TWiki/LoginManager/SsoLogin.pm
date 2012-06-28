# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2012 Wave Systems Corp.
# Copyright (C) 2005-2012 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution. NOTE: Please extend that file, not this notice.
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

---+ package TWiki::LoginManager::SsoLogin

This login manager can specified in the security setup section of
[[%SCRIPTURL{"configure"}%][configure]]. It instructs TWiki to use
SSO (single sign-on).

Configuration:

<verbatim>
$TWiki::cfg{SsoLoginContrib}{AuthTokenName} = 'name-of-authtoken-cookie';
$TWiki::cfg{SsoLoginContrib}{VerifyAuthTokenUrl} = 'https://example.com/api/auth/%AUTHTOKEN%';
$TWiki::cfg{SsoLoginContrib}{VerifyAuthTokenHeader} = 'x-sso-api-key-name', api-key-value';
$TWiki::cfg{SsoLoginContrib}{VerifyResponseLoginRE} = '"loginName":"([^"]*)';
$TWiki::cfg{SsoLoginContrib}{LoginUrl} = 'https://example.com/login?redirect=%ORIGURL%';
$TWiki::cfg{SsoLoginContrib}{LogoutUrl} = 'https://example.com/logout?redirect=%ORIGURL%';
</verbatim>

See also TWikiUserAuthentication.

Subclass of TWiki::LoginManager; see that class for documentation of the
methods of this class.

=cut

package TWiki::LoginManager::SsoLogin;
use base 'TWiki::LoginManager';

use strict;
use Assert;


=pod

---++ ClassMethod new ($session)

Construct the SsoLogin object

TODO: The current implementation verifies the user with each page request. For 
better performance, the auth token cookie should be stored persistently and
checked only when changed or timed out.

=cut

sub new {
    my( $class, $session ) = @_;
    my $this = $class->SUPER::new($session);
    $session->enterContext( 'can_login' );
    TWiki::registerTagHandler( 'LOGOUTURL', \&_LOGOUTURL );
    TWiki::registerTagHandler( 'LOGOUT',    \&_LOGOUT );

    my $name = $TWiki::cfg{SsoLoginContrib}{AuthTokenName} || 'undefined-AuthTokenName';
    $this->{authtoken} = $session->{request}->cookie( $name ) || '';
    $this->{loginName} = ''; 
    if( $this->{authtoken} ) {
        my @headers = split( /, */, $TWiki::cfg{SsoLoginContrib}{VerifyAuthTokenHeader} );
        my $url = $TWiki::cfg{SsoLoginContrib}{VerifyAuthTokenUrl};
        $url =~ s/%AUTHTOKEN%/$this->{authtoken}/go;
        my $response = $session->net->getExternalResource( $url, @headers );
        if (!$response->is_error() && $response->isa('HTTP::Response')) {
            # Example response in JSON format:
            #   {"message":null,"info":{"type":"named","displayName":"Firstname Lastname",
            #    "loginName":"user@example.com"},"result":"OK"}
            if( $response->content =~ /$TWiki::cfg{SsoLoginContrib}{VerifyResponseLoginRE}/ ) {
                $this->{loginName} = $1;
            }
        }
    }
    $session->{remoteUser} = $this->{loginName};
    return $this;
}

=pod

---++ ObjectMethod _LOGOUTURL ($twiki)

=cut

sub _LOGOUTURL {
    my( $twiki, $params, $topic, $web ) = @_;

    my $redirectUrl = TWiki::urlEncode( $twiki->getScriptUrl( 1, 'view', $web, $topic ) );
    my $url = $TWiki::cfg{SsoLoginContrib}{LogoutUrl};
    $url =~ s/%ORIGURL%/$redirectUrl/;

    return $url;
}

=pod

---++ ObjectMethod _LOGOUT ($twiki)

=cut

sub _LOGOUT {
    my( $twiki, $params, $topic, $web ) = @_;

    return '' unless $twiki->inContext( 'authenticated' );

    my $url = _LOGOUTURL( @_ );
    if( $url ) {
        my $text = $twiki->templates->expandTemplate( 'LOG_OUT' );
        return CGI::a( {href=>$url }, $text );
    }
    return '';
}

=pod

---++ ObjectMethod forceAuthentication () -> boolean

method called when authentication is required - redirects to (...|view)auth
Triggered on auth fail

=cut

sub forceAuthentication {
    my $this  = shift;
    my $twiki = $this->{twiki};

    unless ( $twiki->inContext( 'authenticated' ) ) {
        my $query = $twiki->{request};

        # Redirect with passthrough so we don't lose the original query params
        my $twiki = $this->{twiki};
        my $topic = $twiki->{topicName};
        my $web   = $twiki->{webName};
        my $redirectUrl = TWiki::urlEncode( $TWiki::cfg{DefaultUrlHost} . $twiki->{request}->uri() );
        my $url = $TWiki::cfg{SsoLoginContrib}{LoginUrl};
        $url =~ s/%ORIGURL%/$redirectUrl/;

        $twiki->redirect( $url, 1 );
        return 1;
    }
    return undef;
}

=pod

---++ ObjectMethod loginUrl () -> $loginUrl

=cut

sub loginUrl {
    my $this = shift;
    my $twiki = $this->{twiki};
    my $topic = $twiki->{topicName};
    my $web = $twiki->{webName};
    my $redirectUrl = TWiki::urlEncode( $twiki->getScriptUrl( 1, 'view', $web, $topic ) );
    my $url = $TWiki::cfg{SsoLoginContrib}{LoginUrl};
    $url =~ s/%ORIGURL%/$redirectUrl/;
    return $url;
}

=pod

---++ ObjectMethod login( $query, $twiki )

this allows the login and logon cgi-scripts to use the same code. 
all a logon does, is re-direct to viewauth, and apache then figures out 
if it needs to challenge the user

=cut

sub login {
    my( $this, $query, $twikiSession ) = @_;

    my $topic = $twikiSession->{topicName};
    my $web = $twikiSession->{webName};
    my $redirectUrl = TWiki::urlEncode( $twikiSession->getScriptUrl( 1, 'view', $web, $topic ) );
    my $url = $TWiki::cfg{SsoLoginContrib}{LoginUrl};
    $url =~ s/%ORIGURL%/$redirectUrl/;

    $twikiSession->redirect( $url, 1 );
}


=pod

---++ ObjectMethod getUser () -> $authUser

returns the userLogin if stored in the apache CGI query (ie session)

=cut

sub getUser {
    my $this = shift;

    my $query = $this->{twiki}->{request};
    my $authUser;
    # Ignore remote user if we got here via an error
    # Only useful with CGI engine & Apache webserver
    unless (($ENV{REDIRECT_STATUS} || 0) >= 400 ) {
        $authUser = $query->remote_user() if $query;
        TWiki::LoginManager::_trace($this, "apache getUser says ".($authUser||'undef'));
    }
    return $authUser;
}

1;
