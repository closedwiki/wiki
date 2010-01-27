# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# by Ian Kluft
# Copyright (C) 2010 by TWiki Inc and the TWiki Contributors.
# All Rights Reserved. TWiki Contributors are listed in the AUTHORS file
# in the root of this distribution.
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
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package TWiki::LoginManager::OpenID

This is a login manager class for use with OpenID authentication.
It provides users with a template-based form to enter their OpenID
credentials, and contacts their OpenID provider for verification.

OpenID support is via the CPAN module Net::OpenID::Consumer, which
supports OpenID 1.1 and 2.0 at the time of this writing and is expected
to track new developments in OpenID as they occur.

This is a subclass of TWiki::LoginManager::TemplateLogin, which is a
subclass of TWiki::LoginManager.  See those classes for details and
non-OpenID documentation.

=cut

package TWiki::LoginManager::OpenID;
use base 'TWiki::LoginManager::TemplateLogin';
use strict;
use Assert;					# included with Perl
use Error qw( :try );				# included with Perl
use TWiki::LoginManager::TemplateLogin;		# included with TWiki
use Cache::FileCache;				# CPAN dependency
use Net::OpenID::Consumer;      		# CPAN dependency

# class data
our $openid_pattern = '^(http:|https:|xri:)?[\w.:;,~/?#\[\]()*!&\'-]+$';

=pod

---++ ClassMethod new ($session, $impl)

Construct the TWiki::LoginManager::OpenID object

=cut

sub new {
    my( $class, $session ) = @_;

    # init via TWiki::LoginManager::TemplateLogin and TWiki::LoginManager first
    my $this = bless( $class->SUPER::new($session), $class );

    # set state to enable login
    $session->enterContext('can_login');

    # override TWiki::LoginManager's LOGIN tag handler with OpenID-specific one
    TWiki::registerTagHandler('LOGIN', \&_LOGIN);

    return $this;
}

=begin twiki

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    $this->complete(); # call to flush the session if not already done
    undef $this->{_cookies};
    undef $this->{_authScripts};
    undef $this->{_cgisession};
    undef $this->{_haveCookie};
    undef $this->{_MYSCRIPTURL};
    undef $this->{twiki};
}


=pod

---++ ObjectMethod _LOGIN ($thisl)

The is the handler function for the LOGIN tag. It generates CSS and HTML for
the login prompt.

=cut

sub _LOGIN {
    #my( $twiki, $params, $topic, $web ) = @_;
    my $twiki = shift;
    my $this = $twiki->{users}->{loginManager};

    # already done if authenticated
    return '' if $twiki->inContext( 'authenticated' );

    # if there's a login URL then we can process the template for it
    my $url = $this->loginUrl();
    $url or return '';

    # load relevant templates for login page
    $twiki->templates->readTemplate('login');
    $twiki->templates->readTemplate($twiki->{users}->loginTemplateName());

    # add CSS to the HTML head section
    my $head =  $twiki->templates->expandTemplate('openidcss')
        .$twiki->templates->expandTemplate('leftbarlogincss');
    $twiki->addToHEAD('OpenIDConsumer_openidcss', $head );

    # return the text for the LOGIN tag 
    return $twiki->templates->expandTemplate('leftbarlogin');
}

sub login {
    my( $this, $query, $session ) = @_;
    my $twiki = $this->{twiki};
    my $users = $twiki->{users};
    my ( $wikiName, $cUID, $login, $user, $email );

    # collect CGI parameters
    my $web = $session->{webName};
    my $topic = $session->{topicName};
    my %params = $query->Vars;
    my $origurl = $params{'origurl'};
    my $loginName = $params{'username'};
    my $loginPass = $params{'password'};

    # if no login provided, fail
    if ( ! defined $loginName ) {
    	return 0;
    # if login & password provided, use normal TWiki template login
    } elsif (( defined $loginName ) and ( defined $loginPass )) {
    	return $this->SUPER::login( $query, $session );
    }

    # collect OpenID parameters
    my @openid_keys = grep ( /^openid\./, keys %params );
    my %openid_p;
    foreach my $p ( @openid_keys ) {
	if ( $p =~ /^openid\.(.*)/ ) {
	    my $p_suffix = $1;
            my $val = $query->param( $p );
            if ( defined $val ) {
                $openid_p{$p_suffix} = $val;
            }
	}
    }

    # get OpenID configuration info
    my $ua_class = $TWiki::cfg{OpenIDConsumer}{ua_class}
    	or "LWP::UserAgent";
    my $required_root = (( exists $TWiki::cfg{OpenIDConsumer}{required_root})
		    ?  $TWiki::cfg{OpenIDConsumer}{required_root}
		    : $TWiki::cfg{DefaultUrlHost}).'/',
    my $nonce_pattern = $TWiki::cfg{OpenIDConsumer}{nonce_pattern}
    	or "GJvxv_%s";
    my $consumer_secret = sub { sprintf($nonce_pattern, shift^0xCAFEFEED )};
    my $cache = Cache::FileCache->new({ namespace => 'OpenIDConsumerContrib' });

    # Note: the following conditions may be a little confusing
    # These sections are ordered by conditions checked, not chronologically.
    # It may seem counterintuitive at first.
    # 
    # The first check is for conditions of a response from the OpenID provider
    # If that isn't present, we prepare a request for the OpenID provider

    # did we get any OpenID parameters?
    if ( exists $openid_p{mode}) {
        # found OpenID parameters so process response from OpenID provider

	my $csr = Net::OpenID::Consumer->new (
	    cache => $cache,
	    consumer_secret => $consumer_secret,
	    required_root => $required_root,
	    args  => $query,
	);

	# handle responses
	if (my $setup_url = $csr->user_setup_url) {
	    # the OpenID request failed, requiring the user to perform setup
	    throw TWiki::OopsException(
		'openid_setup_required',
		web => $web,
		topic => $topic,
		params => [ 'OpenID Provider <a href="'.$setup_url
			.'">requires setup</a>' ]);
	} elsif ($csr->user_cancel) {
	    # the user or provider canceled the request
	    throw TWiki::OopsException(
		'openid_cancel',
		web => $web,
		topic => $topic,
		params => [ 'cancel received from OpenID Provider' ]);
	} elsif (my $vident = $csr->verified_identity) {
	    # success, redirect back as the logged-in user
	    $this->userLoggedIn($vident->url);
	    $query->delete( 'origurl', 'username', 'password', @openid_keys );
	    $this->redirectCgiQuery($query, $query->self_url );
	} else {
	    # catch-all reporting for other errors
	    throw TWiki::OopsException(
		'openid_response_error',
		web => $web,
		topic => $topic,
		params => [ 'OpenID error: '.$csr->errcode() ]);
	}
    } elsif ( defined $loginName ) {
    	# we don't have a response, so prepare a request for OpenID provider

        my $csr = Net::OpenID::Consumer->new(
	    cache => $cache,
	    consumer_secret => $consumer_secret,
	    required_root => $required_root,
	    args => $query,
    	    ua => $ua_class->new,
        );

        # if no OpenID parameters but we have a login name, process OpenID
	# claimed identity (not yet authenticated, just finding provider)
	# and redirect to OpenID Provider
        my $claimed_id = $csr->claimed_identity($loginName);
        if ($claimed_id) {
            my $check_url = $claimed_id->check_url (
	        # The place we go back to.
	        return_to  => $query->self_url,
	        # Having this simplifies the login process.
	        trust_root => $TWiki::cfg{DefaultUrlHost}.'/',
            );

            # Automatically redirect the user to the OpenID endpoint
	    TWiki::Func::redirectCgiQuery( $query, $check_url, 0 );
        } else {
	    throw TWiki::OopsException(
		'openid_claimed_identity_error',
		web => $web,
		topic => $topic,
		params => [ 'error in OpenID claimed identity: '
			.$csr->errcode() ]);
        }
    }
}
