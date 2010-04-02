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
use Assert;								# included with Perl
use Error qw( :try );					# included with Perl
use TWiki::LoginManager::TemplateLogin;	# included with TWiki
use TWiki::UI::Register;				# included with TWiki
use LWP::UserAgent;						# CPAN dependency
use Cache::FileCache;					# CPAN dependency
use Net::OpenID::Consumer;      		# CPAN dependency

# class configuration variables
our ( $debug, @op_list, $no_user_add_id, $no_user_del_id, $ua_class,
	$required_root, $nonce_pattern, $op_host_whitelist, $op_host_blacklist,
	$op_dom_whitelist, $op_dom_blacklist, @req_fields1, @opt_fields1,
	@policy_url1, @req_fields2, @opt_fields2, $auto_register_user,
	$auto_create_user, $user_menu_thresh1, $user_menu_thresh2, $reg_web,
	$reg_page, $forbidden_accounts );

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

	#
	# set class variables
	#

	# flag: debug mode
	$debug = ( exists $TWiki::cfg{OpenIdRpContrib}{Debug})
		? $TWiki::cfg{OpenIdRpContrib}{Debug} : 0;

	# OpenID Provider (OP) list configuration - controls login menu buttons
	@op_list = ( exists $TWiki::cfg{OpenIdRpContrib}{OpenIDProviders})
		? @{$TWiki::cfg{OpenIdRpContrib}{OpenIDProviders}}
		: ();

	# flag: inhibit user console addition of OpenID identities
	$no_user_add_id = ( exists $TWiki::cfg{OpenIdRpContrib}{NoUserAddId})
		? $TWiki::cfg{OpenIdRpContrib}{NoUserAddId} : 0;

	# flag: inhibit user console deletion of OpenID identities
	$no_user_del_id = ( exists $TWiki::cfg{OpenIdRpContrib}{NoUserDelId})
		? $TWiki::cfg{OpenIdRpContrib}{NoUserDelId} : 0;

	# Net::OpenID::Consumer library configuration
	# The defaults should be adequate for these
    $ua_class = ( exists $TWiki::cfg{OpenIdRpContrib}{ua_class})
		? $TWiki::cfg{OpenIdRpContrib}{ua_class}
    	: "LWP::UserAgent";
    $required_root = (( exists $TWiki::cfg{OpenIdRpContrib}{required_root})
		?  $TWiki::cfg{OpenIdRpContrib}{required_root}
		: $TWiki::cfg{DefaultUrlHost}).'/';
    $nonce_pattern = ( exists $TWiki::cfg{OpenIdRpContrib}{nonce_pattern})
		? $TWiki::cfg{OpenIdRpContrib}{nonce_pattern}
    	: "GJvxv_%s";

	# OP host/email domain whitlists/blacklists
	$op_host_whitelist = $TWiki::cfg{OpenIdRpContrib}{OPHostWhitelist};
	$op_host_blacklist = $TWiki::cfg{OpenIdRpContrib}{OPHostBlacklist};
	$op_dom_whitelist = $TWiki::cfg{OpenIdRpContrib}{EmailDomWhitelist};
	$op_dom_blacklist = $TWiki::cfg{OpenIdRpContrib}{EmailDomBlacklist};

	# OpenID 1.1 Simple Registration (SREG) required and optional fields
	@req_fields1 = ( exists $TWiki::cfg{OpenIdRpContrib}{req_fields1})
		? ( required => $TWiki::cfg{OpenIdRpContrib}{req_fields1})
		: (required =>  'fullname,email');
	@opt_fields1 = ( exists $TWiki::cfg{OpenIdRpContrib}{opt_fields1})
		? ( optional => $TWiki::cfg{OpenIdRpContrib}{opt_fields1})
		: ( optional =>  'nickname,country,timezone');

	# OpenID 1.1 Simple Registration (SREG) policy URL (optional)
	@policy_url1 = ( exists $TWiki::cfg{OpenIdRpContrib}{policy_url1})
		? ( policy_url => $TWiki::cfg{OpenIdRpContrib}{policy_url1})
		: ();

	# OpenID 2.x Attribute eXchange (AX) required and optional fields
	@req_fields2 = ( exists $TWiki::cfg{OpenIdRpContrib}{req_fields2})
		? ( required => $TWiki::cfg{OpenIdRpContrib}{req_fields2})
		: ( required =>  'firstname,lastname,email');
	@opt_fields2 = ( exists $TWiki::cfg{OpenIdRpContrib}{opt_fields2})
		? ( if_available => $TWiki::cfg{OpenIdRpContrib}{opt_fields2})
		: ( if_available =>  'nickname,country,timezone');

	# automatically register new user - pop up form (default false)
	$auto_register_user = $TWiki::cfg{OpenIdRpContrib}{AutoRegisterUser};

	# automatically create new user (default false)
	$auto_create_user = $TWiki::cfg{OpenIdRpContrib}{AutoCreateUser};

	# user menu threshold to split to 2 levels (default 50)
    $user_menu_thresh1 = ( exists $TWiki::cfg{OpenIdRpContrib}{UserMenuThresh1})
		? $TWiki::cfg{OpenIdRpContrib}{UserMenuThresh1}
    	: 50;

	# user menu threshold to split to 3 levels (default 500)
    $user_menu_thresh2 = ( exists $TWiki::cfg{OpenIdRpContrib}{UserMenuThresh2})
		? $TWiki::cfg{OpenIdRpContrib}{UserMenuThresh2}
    	: 500;

	# automatically create new user (default false)
	$reg_web = ( exists $TWiki::cfg{OpenIdRpContrib}{TWikiRegistrationWeb})
		? $TWiki::cfg{OpenIdRpContrib}{TWikiRegistrationWeb}
		: $TWiki::cfg{SystemWebName};
	$reg_page = ( exists $TWiki::cfg{OpenIdRpContrib}{TWikiRegistrationTopic})
		? $TWiki::cfg{OpenIdRpContrib}{TWikiRegistrationTopic}
		: "TWikiRegistration";

	# make hash keyed w/ names of forbidden accounts for OpenID
	$forbidden_accounts =
		( exists $TWiki::cfg{OpenIdRpContrib}{ForbiddenAccounts})
		? ( $TWiki::cfg{OpenIdRpContrib}{ForbiddenAccounts})
		: "TWikiContributor,TWikiGuest,TWikiRegistrationAgent,UnknownUser";

    # override TWiki::LoginManager's LOGIN tag handler with OpenID-specific one
    TWiki::registerTagHandler('LOGIN', \&_LOGIN);

	# register tag handler for %OPENIDPROVIDERS% set of login buttons
    TWiki::registerTagHandler('OPENIDPROVIDERS', \&_OPENIDPROVIDERS);

	# register tag handler for %OPENIDCONSOLE% user & admin console interface
    TWiki::registerTagHandler('OPENIDCONSOLE', \&_OPENIDCONSOLE);

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
	$this->SUPER::finish();
}

=begin twiki

---++ StaticMethod debug()
print debugging info when debug mode is enabled

=cut

# debugging output
sub debug
{
	if ( $debug ) {
		print STDERR "debug: ".join( ' ', @_ )."\n";
	}
}

=pod

---++ ObjectMethod loadSession($defaultUser) -> $login

Get the client session data, using the cookie and/or the request URL.
Set up appropriate session variables in the twiki object and return
the login name.

$defaultUser is a username to use if one is not available from other
sources. The username passed when you create a TWiki instance is
passed in here.

=cut

sub loadSession {
    my ($this, $defaultUser) = @_;
    my $twiki = $this->{twiki};

	# call superclass' loadSession()
	my $login = $this->SUPER::loadSession( $defaultUser );

	# intercept status regarding whether this login arrived by OpenID
	if ( defined $login ) {
		my $logged_in_openid = $this->getSessionValue( "LOGGED_IN_OPENID" );
		if (( defined $logged_in_openid ) and $logged_in_openid ) {
			$twiki->enterContext('logged_in_openid');
		}
	} else {
		$this->clearSessionValue( "LOGGED_IN_OPENID" );
		$twiki->leaveContext('logged_in_openid');
	}

	# return login name
	return $login;
}
=pod

---++ ObjectMethod _LOGIN ($twiki)

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
        .$twiki->templates->expandTemplate('sidebarlogincss');
    $twiki->addToHEAD('OpenIdRpContrib-sidebar', $head );

    # return the text for the LOGIN tag 
    return $twiki->templates->expandTemplate('sidebarlogin');
}

# internal function to check OpenID Provider icons
sub check_provider_icon
{
	my $twiki = shift;
	my $op_name = shift;
	my $op_url = shift;

	# check if the icon file exists - if so, return
	my $pub_path = $TWiki::cfg{PubDir}."/".$TWiki::cfg{SystemWebName}
		."/OpenIdRpContrib/";
	my $op_icon = $pub_path."/op-icon-$op_name.ico";
	( -e $op_icon ) and return;
	my $default_icon = $pub_path."/icon-globe.png";

	# if it doesn't exist, get the provider's /favicon.ico
	my $host = $op_url;
	$host =~ s=^https{0,1}://==;
	$host =~ s=/.*==;
	my @domain_name = split ( /\./, $host );
	my @hosts;
	my $ua = LWP::UserAgent->new;
	while ( scalar @domain_name >= 2 ) {
		push @hosts, (join ".", @domain_name);
		shift @domain_name;
	}
	my $wwwhost = "www.".($hosts[$#hosts]);
	push @hosts, $wwwhost;
	foreach my $dhost ( @hosts ) {
		debug "trying icon from", $dhost;
		my $response = $ua->get( "http://$dhost/favicon.ico" );
		if ($response->is_success) {
			my $content = $response->decoded_content;
			( length $content ) or next;
			( $content =~ /<!DOCTYPE/ ) and next;
			if ( open ICO, ">$op_icon" ) {
				# write the icon file and we're done
				print ICO $content;
				close ICO;
			}
			last;
		}
	}

	# still looking for the icon?  Ask the top-level HTML page...
	my $response = $ua->get( "http://$wwwhost/" );
	if ($response->is_success) {
		my $html = $response->decoded_content;
		if ( $html =~ /<link rel="[^\"]*icon[^\"]*" href="([^\"])"/igs ) {
			my $icon_uri = $1;
			if ( substr( $icon_uri, 0, 4 ) ne "http" ) {
				if ( substr( $icon_uri, 0, 1 ) ne "/" ) {
					$icon_uri = "/".$icon_uri;
				}
				$icon_uri = "http://$wwwhost".$icon_uri;
			}
			my $response = $ua->get( $icon_uri );
			if ($response->is_success) {
				my $content = $response->decoded_content;
				if (( length $content ) and ( open ICO, ">$op_icon" )) {
					# write the icon file and we're done
					print ICO $content;
					close ICO;
				}
			}
		}
	}

	# didn't find it? symlink the default icon so we won't try this every time
	# if it doesn't work, fail silently - this is low priority
	symlink $default_icon, $op_icon;

	# done
	return;
}

=pod

---++ ObjectMethod _OPENIDPROVIDERS ($twiki)

The is the handler function for the OPENIDPROVIDERS tag. It generates 
OpenID login icons for providers this TWiki site chooses to support.

=cut

sub _OPENIDPROVIDERS {
    #my( $twiki, $params, $topic, $web ) = @_;
	my $twiki = shift;
	my $params = shift;

	# get parameters
	my $sb = ( defined $params->get("sidebar")) ? "sidebar_" : "";
	my $action = ( defined $params->get("action"))
		? $params->get("action") : "login";

	# generate HTML list of providers
	my $result = '<div class="'.$sb.'OP_list">';
	while ( @op_list ) {
		my $op_name = shift @op_list;
		my $op_name_norm = $op_name;
		$op_name_norm =~ s/\s+/_/g;
		my $op_url = shift @op_list;
		check_provider_icon ( $twiki, $op_name_norm, $op_url );
		
		$result .= '<button class="'.$sb.'OP_entry" type="submit" '
			.'name="openid.provider" value="'
			.$op_name.'" title="<nop>'.$op_name.' '
			.$action.' via <nop>OpenID">'
			.'<img src="%PUBURL%/%SYSTEMWEB%/OpenIdRpContrib/op-icon-'
			.$op_name_norm.'.ico" alt="" class="'.$sb.'OP_icon">'
			.($sb ? "" : "<nop>".$op_name )
			.'</button>';
	}
	$result .= '</div>';

	# insert CSS in header
    my $head =  $twiki->templates->expandTemplate('openidcss');
    $twiki->addToHEAD('OpenIdRpContrib-providers', $head );
	return $result;
}

# internal function to filter host names based on white or black lists
sub proc_wb_lists
{
	my $host = shift;
	my $wl = shift;
	my $bl = shift;

	my $allow = 0;
	my $deny = 0;
	my $wl_exists = defined $wl;
	my $bl_exists = defined $bl;
	if ( $wl_exists ) {
		my @whitelist = split( ',', $wl );
		foreach my $wl_host ( @whitelist ) {
			if (( $host eq $wl_host ) or ( $host =~ $wl_host )) {
				$allow = 1;
				last;
			}
		}
		$deny = 1 if ! $allow;
	} elsif ( $bl_exists ) {
		my @blacklist = split( ',', $bl );
		foreach my $bl_host ( @blacklist ) {
			if (( $host eq $bl_host ) or ( $host =~ $bl_host )) {
				$deny = 1;
				last;
			}
		}
		$allow = 1 if ! $deny;
	} else {
		$allow = 1; # default to allowing OPs if no WL or BL
	}

	return !( $deny and !$allow );
}

# internal function to collect OpenID parameters from CGI
sub collect_openid_params
{
	my $twiki = shift;
	my $query = $twiki->{cgiQuery};
	my $cgiparams = $query->Vars;

    # collect OpenID parameters
    my @openid_keys = grep ( /^openid\./, keys %$cgiparams );
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

	return { keys => \@openid_keys, params => \%openid_p };
}

# internal function to collect OpenID user info via SREG or AX
sub collect_openid_userinfo
{
	my $vident = shift;
	my %result;
	
	# collect user info from OpenID Provider
	my $sreg = $vident->extension_fields( 'http://openid.net/extensions/sreg/1.1' );
	my $ax = $vident->extension_fields( 'http://openid.net/srv/ax/1.0' );
	if ( exists $ax->{"value.lastname"}) {
		# OpenID 2.0 AX (attribute exchange)
		$result{first_name} = (( exists $ax->{'value.firstname'} )
			? $ax->{'value.firstname'} : "" );
		$result{last_name} = (( exists $ax->{'value.lastname'} )
			? $ax->{'value.lastname'} : "" );
		$result{email} = (( exists $ax->{'value.email'} )
			? $ax->{'value.email'} : "" );
		$result{country} = (( exists $ax->{'value.country'} )
			? $ax->{'value.country'} : "" );
		if (( exists $ax->{'value.fullname'}) and 
			(( !exists $ax->{'value.firstname'})
			or ( !exists $ax->{'value.lastname'})))
		{
			# wild guess: take first element as first name, remainder as last
			( $result{first_name}, $result{last_name} )
				= split ( " ", $ax->{'value.fullname'}, 2 );
		}
	} else {
		# OpenID 1.1 SREG (simple registration)
		$result{email} = $sreg->{email};
		( $result{first_name}, $result{last_name} )
			= split ( " ", $sreg->{fullname}, 2 );
	}
	return \%result;
}

# internal function to check if a provider was selected from the icon menu
sub check_selected_op
{
	my $openid_p_ref = shift;

	if ( exists $openid_p_ref->{provider} ) {
		my %ops = @op_list;
		if ( exists $ops{$openid_p_ref->{provider}}) {
			debug "provider button selected:", $openid_p_ref->{provider},
				"=", $ops{$openid_p_ref->{provider}};
			return $ops{$openid_p_ref->{provider}};
		}
	}
	return undef;
}

# internal function to connect to OpenID provider and get login info
sub openid_provider_login
{
	my $session = shift;
	my $loginName = shift;
	my $o_ref = shift;
	my $query = $session->{cgiQuery};
    my @openid_keys = @{$o_ref->{keys}};
    my %openid_p = %{$o_ref->{params}};
	my %result;

    # get OpenID configuration info
    my $consumer_secret = sub { sprintf($nonce_pattern, shift^0xCAFEFEED )};
    my $cache = Cache::FileCache->new({ namespace => 'OpenIdRpContrib' });

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
			debug => $debug,
		);

		# handle responses
		if ( my $setup_url = $csr->user_setup_url) {
			# security: don't pass through sensitive info
			$query->delete( 'origurl', 'username', 'password',
				@openid_keys );

			# the OpenID request failed, requiring the user to perform setup
			throw TWiki::OopsException(
				'generic',
				web => $session->{web},
				topic => $session->{topic},
				params => [ "Error in OpenID Provider response",
					'<a href="'.$setup_url.'">setup required</a> for this user',
					"", "" ]);
		} elsif ( $csr->user_cancel) {
			# security: don't pass through sensitive info
			$query->delete( 'origurl', 'username', 'password',
				@openid_keys );

			# the user or provider canceled the request
			throw TWiki::OopsException(
				'generic',
				web => $session->{web},
				topic => $session->{topic},
				params => [ "OpenID request canceled",
					'cancel received from OpenID Provider',
					"", "" ]);
		} elsif ( $result{vident} = $csr->verified_identity) {
			# success, determine WikiName and redirect back as logged-in user

			# we need the identity string, or all else fails
			if ( ! exists $openid_p{identity}) {
				# security: don't pass through sensitive info
				$query->delete( 'origurl', 'username', 'password',
					@openid_keys );

				throw TWiki::OopsException( 'generic',
				web => $session->{web},
				topic => $session->{topic},
				params => [ 'OpenID error',
					"OpenID Provider did not provide user's identity string",
					"", "" ]);
			}

			# filter for identity providers if we have white or black lists
			my $op_host = $openid_p{identity};
			$op_host =~ s=^https{0,1}://==;
			$op_host =~ s=/.*==;
			if ( ! proc_wb_lists( $op_host,
				$op_host_whitelist, $op_host_blacklist ))
			{
				# security: don't pass through sensitive info
				$query->delete( 'origurl', 'username', 'password',
					@openid_keys );

				throw TWiki::OopsException( 'generic',
				web => $session->{web},
				topic => $session->{topic},
				params => [ 'OpenID error',
					"OpenID Provider $op_host not allowed at this site",
					"", "" ]);
			}

			# If no error by this point, login succeeded.
			# Caller uses $openid_p{identity} for verified OpenID identity.
		} else {
			# security: don't pass through sensitive info
			$query->delete( 'origurl', 'username', 'password',
				@openid_keys );

			# catch-all reporting for other errors
			throw TWiki::OopsException(
				'generic',
				web => $session->{web},
				topic => $session->{topic},
				params => [ 'OpenID error', $csr->errcode(), $csr->errtext(),
					"" ]);
		}
    } elsif (( defined $loginName ) and length( $loginName )) {

    	# we don't have a response, so prepare a request for OpenID provider
        my $csr = Net::OpenID::Consumer->new(
			cache => $cache,
			consumer_secret => $consumer_secret,
			required_root => $required_root,
			args => $query,
			ua => $ua_class->new,
			debug => $debug,
        );
		if ( ! $csr ) {
			# security: don't pass through sensitive info
			$query->delete( 'origurl', 'username', 'password', @openid_keys );

			throw TWiki::OopsException(
				'generic',
				web => $session->{web},
				topic => $session->{topic},
				params => [ 'Unable to initialize !OpenID library',
					$csr->err, "", "" ]);
		}

		# if login name is a known login/WikiName, convert to OpenID identity
		if ( $loginName =~ /$TWiki::cfg{LoginNameFilterIn}/ ) {
			my @openids = TWiki::Users::OpenIDMapping::login2openid( $session,
				$loginName );
			if ( @openids ) {
				# override login string with known OpenID identity
				# we'll use the first one that is non-empty
				foreach my $id ( @openids ) {
					( length $id ) or next;
					$loginName = $id;
				}
			}
		}

        # use the login name to process an OpenID claimed identity
		# (not yet authenticated, just finding the provider so far)
		# and redirect to OpenID Provider.
		# This is where HTML and Yadis discovery of the provider are done.
		my $claimed_id = $csr->claimed_identity($loginName);
		debug "login:", $loginName, "claimed ID:", $claimed_id;
        if ($claimed_id) {
			my $version = $claimed_id->protocol_version;
			if ( $version == 1 ) {
				# OpenID version 1.1 and SREG (Simple Registration)
				$claimed_id->set_extension_args(
					'http://openid.net/extensions/sreg/1.1',
					{
						@req_fields1,
						@opt_fields1,
						@policy_url1,
					},
				);
			} else {
				# OpenID 2.0+ and AX (Attribute Exchange)
				# TODO - get definitions of field names/URLs from table
				$claimed_id->set_extension_args(
					'http://openid.net/srv/ax/1.0',
					{
						"mode" => "fetch_request",
						@req_fields2,
						@opt_fields2,
						"type.firstname" => "http://axschema.org/namePerson/first",
						"type.lastname" => "http://axschema.org/namePerson/last",
						"type.fullname" => "http://axschema.org/namePerson",
						"type.email" => "http://axschema.org/contact/email",
						"type.nickname" => "http://axschema.org/namePerson/friendly",
						"type.country" => "http://axschema.org/contact/country/home",
						"type.timezone" => "http://axschema.org/pref/timezone",
					}
				);
			}
			$query->delete( 'username', 'password' );
            my $check_url = $claimed_id->check_url (
				# The place we go back to.
				return_to  => $query->self_url,
				# Having this simplifies the login process.
				trust_root => $TWiki::cfg{DefaultUrlHost}.'/',
				# tell the OP that it has control
				# (we're not doing Ajax here yet - subject to change in future)
				delayed_return  => 1,
            );

			# Add OpenID provider to sites allowed for redirects.
			# (The assumption is that if you listed the OpenID provider
			# in your $TWiki::cfg{OpenIdRpContrib}{OpenIDProviders} then
			# you imply you want to allow users to redirect to those providers.
			# Otherwise the user would get an error from TWiki when they select
			# the button for their provider, saying it won't redirect there.)
			# This is temporary to the process, not a permanent config change.
			my $op_host = $check_url;
			if ( $op_host =~ s=^(https{0,1}://|xri://)== ) {
				my $proto = $1;
				$op_host =~ s=/.*==;
				my @prhUrls = split /,\s*/,
					$TWiki::cfg{PermittedRedirectHostUrls};
				push @prhUrls, $proto.$op_host;
				$TWiki::cfg{PermittedRedirectHostUrls} = join( ',', @prhUrls );
			}

            # Automatically redirect the user to the OpenID endpoint
			$session->redirect( $check_url, 0 );
			$result{redirected} = 1;
        } else {
			# security: don't pass through sensitive info
			$query->delete( 'origurl', 'username', 'password',
				@openid_keys );

			throw TWiki::OopsException(
			'generic',
			web => $session->{web},
			topic => $session->{topic},
			params => [ 'Error in !OpenID claimed identity',
				"cannot initiate !OpenID",
				$csr->err, "" ]);
        }
    }

	return \%result;
}

sub gen_wikiname
{
	my $session = shift;
	my $first_name = shift;
	my $last_name = shift;

	# construct wikiname
	my @wn_parts;
	push @wn_parts, split( /\s+/, $first_name );
	push @wn_parts, split( /\s+/, $last_name );
	my $wnindex;
	for ( $wnindex = 0; $wnindex < scalar @wn_parts; $wnindex++ ) {
		$wn_parts[$wnindex] =~ s/[^\w]//g; # remove non-alphanumeric
		if ( $wn_parts[$wnindex] !~ /^[A-Z][a-z]\w*[A-Z]/ ) {
			# not already in CamelCase so only capitalize first letter
			$wn_parts[$wnindex] = ucfirst(lc($wn_parts[$wnindex]));
		}
	}
	my $wikiname = join( '', @wn_parts );

	# check for WikiName collision, adjust wikiname if necessary
	my $cUID = TWiki::Users::OpenIDMapping::mapper_get( $session, "W2U",
		$wikiname );
	if ( defined $cUID ) {
		# append numbers to the wikiname until it isn't a collision
		my $suffix = 2;
		while ( 1 ) {
			$cUID = TWiki::Users::OpenIDMapping::mapper_get(
				$session, "W2U", $wikiname.$suffix );
			if ( ! defined $cUID ) {
				# didn't find a cUID so the WikiName is available
				$wikiname = $wikiname.$suffix;
				last;
			}
			$suffix++;
		}
	}

	return $wikiname;
}

=pod

---++ ObjectMethod login( $query, $twiki )

called by the login CGI or any CGI protected by $TWiki::cfg{AuthScripts}

Usually TWiki login managers expect a login and password to be passed via
the CGI query.  For OpenID, there is no password - that is handled at the
OpenID Provider (OP).

For OpenID, we use Net::OpenID::Consumer from CPAN.  CGI query parameters
beginning with "openid" are checked for indications that this is a redirect
back from an OP, and then handle login success or failure.

If those are not found, then it assumes we have not yet initiated the OpenID
login and must do so.  Information is collected on the "claimed identity"
string which the user provided via their login info (which may delegate the
identity handling from a user-controlled page to another OP.  This phase ends
in redirecting the user to the OP.

=cut

sub login {
    my( $this, $query, $session ) = @_;
    my $users = $session->{users};

    # collect CGI parameters
    my $web = $session->{webName};
    my $topic = $session->{topicName};
    my %cgiparams = $query->Vars;
    my $origurl = $cgiparams{'origurl'};
    my $loginName = $cgiparams{'username'};
    my $loginPass = $cgiparams{'password'};

    # collect OpenID parameters
	my $o_ref = collect_openid_params($session);
    my @openid_keys = @{$o_ref->{keys}};
    my %openid_p = %{$o_ref->{params}};

	# if an OpenID provider button was selected, fill in the login name
	my $selected_op = check_selected_op( \%openid_p );
	if ( defined $selected_op ) {
		$loginName = $selected_op;
		undef $loginPass;

    # if no login provided, or login & password, use parent class login
    } elsif (( ! defined $loginName ) or ( ! $loginName )
		or (( defined $loginName ) and length( $loginName)
			and ( defined $loginPass ) and length( $loginPass)))
	{
    	return $this->SUPER::login( $query, $session );
    }

	# call OpenID Provider for login
	my $openid_res = openid_provider_login( $session, $loginName, $o_ref );

	# check return conditions
	if ( $openid_res->{redirected}) {
		# a redirect command was output - all done, let it happen
		return;
	}
	if ( ! exists $openid_res->{vident}) {
		debug "openid_provider_login returned without vident:", ( %openid_p );
		throw TWiki::OopsException( 'generic',
			web => $session->{web}, topic => $session->{topic},
			params => [ "OpenID login failed",
			"Data is missing from OP server response - this is unexpected",
			"The admins can find more details in the server logs", "" ]);
	}

	#
	# We should only get here if the OpenID exchange completed successfully
	#

	# check URL to redirect now-logged-in user to
	if ( !$origurl or $origurl eq $query->url()
		or $origurl =~ /%[A-Z0-9_]+%/ )
	{
		my $topic = $session->{topicName};
		my $web   = $session->{webName};

		$origurl = $session->getScriptUrl( 0, 'view', $web, $topic );
	}

	# collect user info from OpenID Provider
	my ( $first_name, $last_name, $email, $country );
	{
		my $userinfo = collect_openid_userinfo( $openid_res->{vident} );
		$first_name = $userinfo->{first_name};
		$last_name = $userinfo->{last_name};
		$email = $userinfo->{email};
		$country = $userinfo->{country};
	}

	# check that we have required info
	if ( !$first_name or ! $last_name ) {
		# security: don't pass through sensitive info
		$query->delete( 'origurl', 'username', 'password',
			@openid_keys );

		debug "first or last name missing; received: ", join " ", %openid_p;

		throw TWiki::OopsException( 'generic',
		web => $session->{web},
		topic => $session->{topic},
		params => [ 'OpenID error',
			"OpenID Provider did not provide user's full name",
			"", "" ]);
		return;
	}
	if ( !$email ) {
		# security: don't pass through sensitive info
		$query->delete( 'origurl', 'username', 'password',
			@openid_keys );

		debug "e-mail missing; received: ", join " ", %openid_p;

		throw TWiki::OopsException( 'generic',
		web => $session->{web},
		topic => $session->{topic},
		params => [ 'OpenID error',
			"OpenID Provider did not provide user's e-mail address",
			"", "" ]);
		return;
	}

	# check if we already know this identity - if so we're done
	my $cUID = TWiki::Users::OpenIDMapping::openid2cUID( $session,
		$openid_p{identity});
	my $mapping = $session->{users}{mapping};
	my $wikiname = ( $cUID ) ? $mapping->getWikiName ( $cUID ) : undef;
	debug "wn=".((defined $wikiname) ? $wikiname : "" ),
		" cUID=".((defined $cUID) ? $cUID : "" ),
		" openid=".$openid_p{identity};
	if (( defined $wikiname ) and length( $wikiname )) {
		# log the user in
		$this->userLoggedIn( $wikiname );
		$this->setSessionValue( "LOGGED_IN_OPENID", "1" );
		$session->enterContext('logged_in_openid');

		# updates the OpenID parameters from the provider
		$openid_p{WikiName} = $wikiname;
		$openid_p{FirstName} = $first_name;
		$openid_p{LastName} = $last_name;
		$openid_p{Email} = $email;
		$openid_p{Country} = $country if defined $country;
		TWiki::Users::OpenIDMapping::add_openid_identity( $session, $cUID,
			\%openid_p );

		# security: don't pass through sensitive info
		$query->delete( 'origurl', 'username', 'password',
			@openid_keys );

		# redirect now-logged-in user to destination page
		$this->redirectCgiQuery($query, $origurl );
		return;
	}

	# filter for email domains if we have white or black lists
	my $email_dom = $email;
	$email_dom =~ s=^.*@==;
	if ( ! proc_wb_lists( $email_dom, $op_dom_whitelist, $op_dom_blacklist )) {
		# security: don't pass through sensitive info
		$query->delete( 'origurl', 'username', 'password',
			@openid_keys );

		throw TWiki::OopsException( 'generic',
		web => $session->{web},
		topic => $session->{topic},
		params => [ 'OpenID error',
			"New user request requires manual approval.",
			"Contact the site administrator(s)", "" ]);
		return;
	}

	# construct wikiname
	$wikiname = gen_wikiname( $session, $first_name, $last_name );

	# log the user in as the WikiName
	$this->userLoggedIn( $wikiname );
	$this->setSessionValue( "LOGGED_IN_OPENID", "1" );
	$session->enterContext('logged_in_openid');

	# save OpenID attributes in OpenID mapper
	$openid_p{WikiName} = $wikiname;
	$openid_p{FirstName} = $first_name;
	$openid_p{LastName} = $last_name;
	$openid_p{Email} = $email;
	delete $openid_p{return_to}; # don't need to save temp URL
	debug "calling save_openid_attrs",
		" wn=".((defined $wikiname) ? $wikiname : "" );
	TWiki::Users::OpenIDMapping::save_openid_attrs( $session,
		$wikiname, \%openid_p );

	# auto-register user in TWiki if configured to do so
	if ( $auto_register_user ) {
		if ( ! $session->{store}->topicExists(
			$TWiki::cfg{UsersWebName}, $wikiname ))
		{
			# fill in registration form parameters from OpenID
			my @params = (
				"FirstName", $first_name,
				"WikiName", $wikiname,
				"LastName", $last_name,
				"LoginName", lc($wikiname),
				"Email", $email,
				( $country ? ( "Country", $country ) : ()));
			
			# security: don't pass through sensitive info
			$query->delete( 'username', 'password', @openid_keys );

			# redirect now-logged-in user to destination page
			my $regurl = $session->getScriptUrl( 0, 'view', $reg_web,
				$reg_page, @params );
			$this->redirectCgiQuery($query, $regurl );
			return;
		}

	# auto-create user in TWiki if configured to do so
	} elsif ( $auto_create_user ) {
		if ( ! $session->{store}->topicExists(
			$TWiki::cfg{UsersWebName}, $wikiname ))
		{
			TWiki::UI::Register::_registerSingleBulkUser(
				$session,
				[ qw( LoginName WikiName FirstName LastName Email
					WebName ) ],
				{
					LoginName => lc($wikiname),
					WikiName => $wikiname,
					FirstName => $first_name,
					LastName => $last_name,
					Email => $email,
					WebName => $TWiki::cfg{UsersWebName},
				},
				{
					# misnamed setting: actually allows writing
					# TWikiUsers, still needed if topic doesn't exist
					doOverwriteTopics => 1,
				}
			);
		}
	}

	# security: don't pass through sensitive info
	$query->delete( 'origurl', 'username', 'password', @openid_keys );

	# redirect now-logged-in user to destination page
	$this->redirectCgiQuery($query, $origurl );
	return;
}

# internal function to recursively resolve variable names in strings
# uses both the provided %$vars parameter and TWiki templates to resolve vars
sub _resolve_console_vars
{
	my $twiki = shift;
	my $str = shift;
	my $vars = shift;
	my $resolved = shift;

	# avoid using undefined values
	if ( !defined $str ) {
		return "";
	}
	if ( !defined $vars ) {
		$vars = {};
	}
	if ( !defined $resolved ) {
		# %$resolved is needed to avoid infinite recursion
		$resolved = {};
	}
	
	# get variable names from string and resolve them one by one
	my @vars = ( $str =~ /%(\w+)%/g );
	foreach my $var ( @vars ) {
		my $value;
		if ( exists $resolved->{$var}) {
			# already resolved - use previous value
			$value = $resolved->{$var};
		} elsif ( exists $vars->{$var}) {
			# variable defined but not previously resolved

			# check if the variable contains a function or string
			if ( ref $vars->{$var} eq "CODE" ) {
				# if it's a function, call it w/ parameters allowing recursion
				$value = _resolve_console_vars( $twiki,
					&{$vars->{$var}}($var, $vars, $resolved),
					$vars, $resolved );
			} else {
				# otherwise just use its value
				$value = _resolve_console_vars( $twiki, $vars->{$var},
					$vars, $resolved );
			}
			$resolved->{$var} = $value;
		} elsif ( $var =~ /^openid_.*/ ) {
			# looks like a TWiki template name by this contrib - use it
			$value = _resolve_console_vars( $twiki, $twiki->templates->expandTemplate($var), $vars, $resolved );
			if ( !defined $value ) {
				# turns out it didn't exist - don't mess with the value
				$value = "\%$var\%";
			}
			$resolved->{$var} = $value;
		}
		$str =~ s/%$var%/$value/g;
	}
	return $str;
}

# internal function to display user identity records for user & admin consoles
sub _format_user_openids
{
	my $twiki = shift;
	my $vars = shift;
	my $mode = shift;
	my $con;
	if ( $mode eq "user" ) {
		$con = "ucon";
	} elsif ( $mode eq "admin" ) {
		$con = "acon";
	} else {
		throw TWiki::OopsException(
		'generic',
		web => $vars->{web},
		topic => $vars->{topic},
		params => [ 'Internal error: formatting function mode not set',
			"cannot display !OpenID identities",
			"", "" ]);
	}

	# read OpenID records for selected user
	my $user = $vars->{user};
	my $cuid = TWiki::Users::OpenIDMapping::mapper_get( $twiki, "W2U", $user );
	my $attr_recs = TWiki::Users::OpenIDMapping::mapper_get( $twiki, "U2A",
		$cuid );
	my @openids = TWiki::Users::OpenIDMapping::cUID2openid( $twiki, $cuid );
	my $openid_attr_delim = $TWiki::Users::OpenIDMapping::openid_attr_delim;
	my $openid_rec_delim = $TWiki::Users::OpenIDMapping::openid_rec_delim;

	# display console
	my @recs_str;
	my @recs = split ( $openid_rec_delim, $attr_recs );
	my $rec_count = 1;
	my $attr_count = 1;
	my $recs;
	if ( @recs ) {
		my $con_attr_tmpl = $twiki->templates->expandTemplate('openid_'.$con.'_attr');
		foreach my $rec ( @recs ) {
			my %attr = split ( $openid_attr_delim, $rec );
			my @vis_keys = sort grep( /^(twiki|sreg|ax|ext[0-9]+)\./,
				keys %attr );
			my ( @data_strs, @attr_strs );
			foreach my $key ( "FirstName", "LastName", "WikiName", "Email" ) {
				exists $attr{$key} or next;
				my $odd_even = ($attr_count++ % 2 ) ? "odd" : "even";
				my $data_str = $con_attr_tmpl;
				$data_str =~ s/%OPENID_ATTR_ODDEVEN%/$odd_even/g;
				$data_str =~ s/%OPENID_ATTR_KEY%/$key/g;
				$data_str =~ s/%OPENID_ATTR_VAL%/$attr{$key}/g;
				push @data_strs, $data_str;
			}
			foreach my $key ( @vis_keys ) {
				exists $attr{$key} or next;
				my $odd_even = ($attr_count++ % 2 ) ? "odd" : "even";
				my $attr_str = $con_attr_tmpl;
				$attr_str =~ s/%OPENID_ATTR_ODDEVEN%/$odd_even/g;
				$attr_str =~ s/%OPENID_ATTR_KEY%/$key/g;
				$attr_str =~ s/%OPENID_ATTR_VAL%/$attr{$key}/g;
				push @attr_strs, $attr_str;
			}
			my $rec_str = $twiki->templates->expandTemplate('openid_'.$con.'_rec');
			my $data = join( "\n", @data_strs );
			my $attrs = join( "\n", @attr_strs );
			$rec_str =~ s/%OPENID_USER_ID_COUNT%/$rec_count/g;
			$rec_str =~ s/%OPENID_USER_ID%/$attr{identity}/g;
			$rec_str =~ s/%OPENID_USER_DATA%/$data/g;
			$rec_str =~ s/%OPENID_USER_ID_ATTRS%/$attrs/g;
			$rec_count++;
			push @recs_str, $rec_str;
		}
		$vars->{OPENID_USER_RECS} = join( "\n", @recs_str );
		$recs = '%openid_'.$con.'_recs%';
	} else {
		$recs = '%openid_'.$con.'_recs_empty%';
	}

	return $recs;
}

# internal function to handle administrator console user-editing interface
sub _admin_console_createuser
{
	my $twiki = shift;
	my $vars = shift;
	my $mapping = $twiki->{users}{mapping};

	# collect ID attribute data
	my @missing;
	foreach my $req_var ( qw( openid.identity first_name last_name )) {
		if (( !exists $vars->{$req_var}) or ( !length $vars->{$req_var})) {
			push @missing, $req_var;
		}
	}
	if ( @missing ) {
		$vars->{message} = "create user failed: parameter"
			.(( scalar @missing >= 2 ) ? "s" : "" )
			." missing: "
			.join( ", ", @missing )."\n";
		return;
	}
	my %attrs;
	$attrs{identity} = $vars->{"openid.identity"};
	$attrs{FirstName} = $vars->{first_name};
	$attrs{LastName} = $vars->{last_name};
	$attrs{WikiName} = gen_wikiname( $twiki,
		$attrs{FirstName}, $attrs{LastName});
	my $admin_cuid = $twiki->{user};
	my $admin_user = $mapping->getWikiName( $admin_cuid );
	$attrs{"twiki.preapproval"} = $admin_user;
	$vars->{message} = "create user not implemented: recvd id=$attrs{identity} fn=$attrs{FirstName} ln=$attrs{LastName} wn=$attrs{WikiName} preapproval=$attrs{'twiki.preapproval'}";
	my $user_cuid = $mapping->login2cUID( $attrs{WikiName}, 1 );
	my $test_u2a = $mapping->{U2A}{$user_cuid};
	if ( defined $test_u2a ) {
		$vars->{message} = "user ".$attrs{WikiName}." already exists";
		return;
	}
	TWiki::Users::OpenIDMapping::save_openid_attrs( $twiki, $attrs{WikiName},
		\%attrs );
	$test_u2a = $mapping->{U2A}{$user_cuid};
	if ( defined $test_u2a ) {
		$vars->{message} = "created user ".$attrs{WikiName};
	} else {
		$vars->{message} = "failed to create user ".$attrs{WikiName};
	}
}

# internal function to handle administrator console user deletion interface
sub _admin_console_deleteuser
{
	my $twiki = shift;
	my $vars = shift;
	my $mapping = $twiki->{users}{mapping};

	# TODO - add a confirmation step

	# delete the user
	my $user = $vars->{user};
	if (( !defined $user ) or ( !length $user )) {
		$vars->{message} = "user deletion failed: missing user parameter";
		return;
	}
	my $user_cuid = $mapping->{W2U}{$vars->{user}};
	if ( TWiki::Users::OpenIDMapping::del_openid_user( $twiki, $user_cuid )) {
		$vars->{message} = "deleted user <nop>$user";
	} else {
		$vars->{message} = "failed to delete or verify deletion of user <nop>$user";
	}
}

# internal function to handle administrator console ID pre-approval interface
sub _admin_console_preapprove
{
	my $twiki = shift;
	my $vars = shift;
	my $mapping = $twiki->{users}{mapping};

	# collect ID attribute data
	my @missing;
	foreach my $req_var ( qw( openid.identity user )) {
		if (( !exists $vars->{$req_var}) or ( !length $vars->{$req_var})) {
			push @missing, $req_var;
		}
	}
	if ( @missing ) {
		$vars->{message} = "create user failed: parameter"
			.(( scalar @missing >= 2 ) ? "s" : "" )
			." missing: "
			.join( ", ", @missing )."\n";
		return;
	}
	my $user_cuid = $mapping->{W2U}{$vars->{user}};
	if ( !defined $user_cuid ) {
		$vars->{message} = "user $vars->{user} does not exist";
		return;
	}
	my %attrs;
	$attrs{identity} = $vars->{"openid.identity"};
	$attrs{WikiName} = $vars->{user};
	my $admin_cuid = $twiki->{user};
	my $admin_user = $mapping->getWikiName( $admin_cuid );
	$attrs{"twiki.preapproval"} = $admin_user;
	if ( TWiki::Users::OpenIDMapping::add_openid_identity( $twiki, $user_cuid,
		\%attrs ))
	{
		$vars->{message} = "identity successfully added";
	} else {
		$vars->{message} = "failed to add identity, or failed to verify";
	}
}

# internal function to handle administrator console ID deletion interface
# TODO - merge with _user_console_delete
sub _admin_console_deleteid
{
	my $twiki = shift;
	my $vars = shift;
	my $mapping = $twiki->{users}{mapping};

	my $user_wn = $vars->{user};
	my $user_cuid = $mapping->{W2U}{$user_wn};
	my $index = $vars->{deleteid};

	# make sure user exists
	if ( !defined $user_cuid ) {
		throw TWiki::OopsException( 'generic',
			web => $twiki->{web}, topic => $twiki->{topic},
			params => [ "user $user_wn not found",
			"Cannot delete OpenID identity record without a user name",
			"", "" ]);
	}

	# make sure index was properly set from delete parameter
	if ( !defined $index ) {
		throw TWiki::OopsException( 'generic',
			web => $twiki->{web}, topic => $twiki->{topic},
			params => [ "no OpenID record number found",
			"Cannot delete OpenID identity record without a record number",
			"", "" ]);
	}

	# delete the record
	if ( TWiki::Users::OpenIDMapping::del_openid_identity( $twiki, $user_cuid,
		{ index => $index }))
	{
		$vars->{message} = "record deleted - can be re-added via "
			."admin pre-approval, or user verification with !OpenID provider";
		return 1;
	} else {
		$vars->{message} = "record not deleted, or verification failed";
		return 0;
	}
}

# internal function to handle administrator console user-editing interface
sub _admin_console_user
{
	my $twiki = shift;
	my $vars = shift;

	$vars->{OPENID_ADMIN_USER_MENU} = _format_user_openids( $twiki, $vars,
		"admin" )."%openid_acon_add%";
}

# internal function to handle administrator console interface
sub _admin_console
{
	my $twiki = shift;
	my $vars = shift;
	my $mapping = $twiki->{users}{mapping};

	# determine if user is an admin
	my $cuid = $twiki->{user};
	my $isAdmin = $twiki->{users}->isAdmin( $cuid );
	my $admin_user = $mapping->getWikiName( $cuid );

	# reject from admin console if user is not an admin
	if ( ! $isAdmin ) {
		return "(Sorry: admin features are not available to non-admin users.)";
	}

	# read template
	$twiki->templates->readTemplate('openidlogin');

	# handle form actions
	my $res;
	if ( exists $vars->{createuser}) {
		_admin_console_createuser( $twiki, $vars );
	} elsif ( exists $vars->{deleteuser}) {
		_admin_console_deleteuser( $twiki, $vars );
		delete $vars->{user}; # don't display user we just deleted
	} elsif ( exists $vars->{preapprove}) {
		_admin_console_preapprove( $twiki, $vars );
	} elsif ( exists $vars->{deleteid}) {
		$res = _admin_console_deleteid( $twiki, $vars );
		my $user = (( exists $vars->{user}) and ( length $vars->{user}))
			? $vars->{user} : "undef";
		if ( $res == 2 ) {
			$vars->{message} = "user <nop>$user deleted: last identity removed";
			delete $vars->{user}; # don't display user we just deleted
		} elsif ( $res == 1 ) {
			$vars->{message} = "identity removed from <nop>$user";
		} elsif ( $res == 0 ) {
			$vars->{message} = "failed to remove identity from <nop>$user";
		}
	}

	# generate admin console content
	my ( $wn_count_total, $wn_count_openid, $wn_count_nonopenid );
	if ( exists $vars->{user}) {
		# admin console for editing a user
		$vars->{cuid} = TWiki::Users::OpenIDMapping::mapper_get( $twiki, "W2U",
			$vars->{user});
		_admin_console_user( $twiki, $vars );
		$vars->{OPENID_ADMIN_PANEL_HEADING} = "%openid_acon_upanel_heading%";
	} else {
		# admin console for menu of users to edit

		# stuff list of forbidden accounts into a hash for quick lookup
		my %forbidden_accounts;
		foreach ( split /,\s*/, $forbidden_accounts ) {
			$forbidden_accounts{$_} = 1;
		}

		# read user list for menu
		my ( @wn, $wn );
		my $mapping_id = $TWiki::Users::OpenIDMapping::OPENID_MAPPING_ID;
		my $filter = lc($vars->{filter});
		$filter =~ s/\W//g;
		my @raw_wn = grep { ! exists $forbidden_accounts{$_}}
			keys %{$mapping->{W2U}};
		if (( defined $filter ) and ( length $filter )) {
			@wn = sort grep /^$filter/i, @raw_wn;
		} else {
			@wn = sort @raw_wn;
		}

		# count the total number of OpenID users
		$wn_count_openid = scalar grep { ! exists $forbidden_accounts{$_}}
			keys %{$mapping->{U2A}};
		$wn_count_total = scalar grep { ! exists $forbidden_accounts{$_}}
			keys %{$mapping->{W2U}};
		$wn_count_nonopenid = $wn_count_total - $wn_count_openid;

		# generate different levels of menus based on how many users there are
		my $level = 1;
		$level++ if ( $wn_count_total > $user_menu_thresh1 );
		$level++ if ( $wn_count_total > $user_menu_thresh2 );
		$level -= length $filter;
		if ( $level > 1 ) {
			# generate links to query down to smaller lists of accounts
			my ( %uprefixes, $prefix );
			foreach $wn ( @wn ) {
				$prefix = ucfirst(lc(substr $wn, 0, 1 + length $filter ));
				if ( exists $uprefixes{$prefix}) {
					$uprefixes{$prefix}++;
				} else {
					$uprefixes{$prefix} = 1;
				}
			}
			my @ulinks;
			my $ulink_text = $twiki->templates->expandTemplate('openid_acon_ulink');
			foreach $prefix ( keys %uprefixes ) {
				my $link = $ulink_text;
				$link =~ s/%prefix%/$prefix/g;
				$link =~ s/%count%/$uprefixes{$prefix}/g;
				push @ulinks, $link;
			}
			$vars->{OPENID_ACON_ULINKS} = join " &ndash; ", @ulinks;
			$vars->{OPENID_ADMIN_USER_MENU} = '%openid_acon_ulinks%';
		} else {
			# generate drop-down select list of accounts
			my @uopt;
			push @uopt, '<option name="none">Select user</a><br>'."\n";
			foreach $wn ( @wn ) {
				push @uopt, '<option name="'.$wn.'">'.$wn."</a><br>\n";
			}
			my $uopt = join( "\n", @uopt )."\n";
			if (( defined $filter ) and ( length $filter )) {
				$vars->{OPENID_FILTER_NOTE} = (scalar @wn)
					." accounts starting with \"".uc($filter)."\"<br>\n";
			}
			$vars->{OPENID_ACON_F1_OPTS} = $uopt;
			$vars->{OPENID_ADMIN_USER_MENU} = '%openid_acon_uform%';
		}
	}

	# set the remaining variables and resolve the admin console
	if ( ! defined $vars->{OPENID_ADMIN_PANEL_HEADING}) {
		$vars->{OPENID_ADMIN_PANEL_HEADING} = "%openid_acon_panel_heading%";
	}
	$vars->{OPENID_USER} = $admin_user;
	$vars->{USER_COUNT_TOTAL} = $wn_count_total;
	$vars->{USER_COUNT_OPENID} = $wn_count_openid;
	$vars->{USER_COUNT_NONOPENID} = $wn_count_nonopenid;
	my $console =  _resolve_console_vars( $twiki, '%openid_acon%', $vars );
	
	# insert CSS in header
    my $head = $twiki->templates->expandTemplate('openidcss')
		.$twiki->templates->expandTemplate('openidconsolecss');
    $twiki->addToHEAD('OpenIdRpContrib-console', $head );

	return $console;
}

# internal function to delete an identity from a user's record
# TODO - merge with _admin_console_deleteid
sub _user_console_delete
{
	my $twiki = shift;
	my $vars = shift;
	my $mapping = $twiki->{users}{mapping};

	my $user_wn = $vars->{user};
	my $user_cuid = $mapping->{W2U}{$user_wn};
	my $index = $vars->{delete};

	# make sure user exists
	if ( !defined $user_cuid ) {
		throw TWiki::OopsException( 'generic',
			web => $twiki->{web}, topic => $twiki->{topic},
			params => [ "user $user_wn not found",
			"Cannot delete OpenID identity record without a user name",
			"", "" ]);
	}

	# make sure index was properly set from delete parameter
	if ( !defined $index ) {
		throw TWiki::OopsException( 'generic',
			web => $twiki->{web}, topic => $twiki->{topic},
			params => [ "no OpenID record number found",
			"Cannot delete OpenID identity record without a record number",
			"", "" ]);
	}

	# delete the record
	if ( TWiki::Users::OpenIDMapping::del_openid_identity( $twiki, $user_cuid,
		{ index => $index }))
	{
		$vars->{message} = "record deleted - can be re-added via !OpenID "
			."provider if needed";
		return 1;
	} else {
		$vars->{message} = "record not deleted, or verification failed";
		return 0;
	}
}

# internal function to update a user's identity from an OpenID Provider
sub  _user_console_update
{
	my $twiki = shift;
	my $vars = shift;
	my $cUID = $twiki->{user};
	my $cgiparams = $twiki->{cgiQuery}->Vars;
	my $index = $cgiparams->{update};

	# make sure index was properly set from update parameter
	if ( !defined $index ) {
		throw TWiki::OopsException( 'generic',
			web => $twiki->{web}, topic => $twiki->{topic},
			params => [ "no OpenID record number found",
			"Cannot update OpenID identity record without a record number",
			"", "" ]);
	}

    # collect OpenID parameters
	my $o_ref = collect_openid_params($twiki);
    my @openid_keys = @{$o_ref->{keys}};
    my %openid_p = %{$o_ref->{params}};

	# TODO
	return 0;
}

# internal function to update a user's identity from an OpenID Provider
sub  _user_console_claim
{
	my $twiki = shift;
	my $vars = shift;
	my $cUID = $twiki->{user};
	my $claimed_id = $vars->{"openid.claimed_id"};

	# make sure the claimed ID is not already used by another user
	my $mapping = $twiki->{users}{mapping};
	if ( exists $mapping->{O2U}{$cUID}) {
		$vars->{message} = "Another account already has that ID.  If it's yours, log in and remove its ID before claiming it here.";
		return 0;
	}

	# look up user's WikiName
	my $wikiname = $mapping->{U2W}{$cUID};
	if ( !$wikiname ) {
		throw TWiki::OopsException( 'generic',
			web => $twiki->{web}, topic => $twiki->{topic},
			params => [ "Can't look up wiki name for $cUID",
			"Possible referential integrity error in the !OpenID data",
			"", "" ]);
	}

    # collect OpenID parameters
    my @openid_keys = ( "openid.claimed_id" );
    my %openid_p = ( claimed_id => $claimed_id );
	my $o_ref = { keys => \@openid_keys, params => \%openid_p };

	# call OpenID Provider for login
	my $openid_res = openid_provider_login( $twiki, $claimed_id, $o_ref );

	# check return conditions
	if ( $openid_res->{redirected}) {
		# a redirect command was output - all done, let it happen
		return -1;
	}
	if ( ! exists $openid_res->{vident}) {
		debug "openid_provider_login returned without vident:", ( %openid_p );
		throw TWiki::OopsException( 'generic',
			web => $twiki->{web}, topic => $twiki->{topic},
			params => [ "OpenID login failed",
			"Data is missing from OP server response - this is unexpected",
			"The admins can find more details in the server logs", "" ]);
	}

	#
	# We should only get here if the OpenID exchange completed successfully
	#

	# collect user info from OpenID Provider
	my ( $first_name, $last_name, $email, $country );
	{
		my $userinfo = collect_openid_userinfo( $openid_res->{vident} );
		$first_name = $userinfo->{first_name};
		$last_name = $userinfo->{last_name};
		$email = $userinfo->{email};
		$country = $userinfo->{country};
	}

	# check that we have required info
	if ( !$first_name or ! $last_name or !$email ) {
		$vars->{message} = "<nop>OpenID provider did not supply required name and/or e-mail address";
		return 0;
	}

	# if the ID is already assigned, can't be modified from user console
	if ( exists $mapping->{O2U}{$claimed_id}) {
		my $newid_cuid = $mapping->{O2U}{$claimed_id};
		if ( $newid_cuid eq $cUID ) {
			$vars->{message} = "The ID is already assigned to this account";
			return 1;
		} else {
			$vars->{message} = "The ID is already assigned to another account";
			return 0;
		}
	}

	# updates the OpenID parameters from the provider
	$openid_p{WikiName} = $wikiname;
	$openid_p{FirstName} = $first_name;
	$openid_p{LastName} = $last_name;
	$openid_p{Email} = $email;
	$openid_p{Country} = $country if defined $country;
	TWiki::Users::OpenIDMapping::add_openid_identity( $twiki, $cUID,
		\%openid_p );

	# verify and return result
	if ( exists $mapping->{O2U}{$claimed_id}) {
		$vars->{message} = "The ID was successfully added to this account";
		return 1;
	} else {
		$vars->{message} = "The ID failed to be added to this account";
		return 0;
	}
}

# internal function to handle user console interface
sub _user_console
{
	my $twiki = shift;
	my $vars = shift;
	my $user = $twiki->{user};
	my $wn = $twiki->{users}{mapping}->getWikiName( $user );

	# read template
	$twiki->templates->readTemplate('openidlogin');

	# process actions if any
	my ( $action, $res );
	if ( exists $vars->{delete}) {
		$action = "delete";
		$res = _user_console_delete( $twiki, $vars );
	} elsif ( exists $vars->{update}) {
		$action = "update";
		$res = _user_console_update( $twiki, $vars );
	} elsif ( exists $vars->{claim}) {
		$action = "claim";
		$res = _user_console_claim( $twiki, $vars );
	}
	if ( $res == -1 ) {
		# a redirect was issued in the call - bail out
		return;
	} elsif (( defined $res ) and !exists $vars->{message}) {
		$vars->{message} = $action." ".( $res ? "succeeded" : "failed" );
	}

	# get formatted entries for user's OpenID identities
	$vars->{user} = $wn;
	my $recs = _format_user_openids( $twiki, $vars, "user" );

	# expand and fill in console
	$vars->{OPENID_USER_ID_ADD} = ( $no_user_add_id
		?  "" : '%openid_ucon_add%' );
	$vars->{OPENID_USER} = $wn;
	$vars->{OPENID_USER_INFO} = $recs;
	my $console =  _resolve_console_vars( $twiki, '%openid_ucon%', $vars );

	# insert CSS in header
    my $head = $twiki->templates->expandTemplate('openidcss')
		.$twiki->templates->expandTemplate('openidconsolecss');
    $twiki->addToHEAD('OpenIdRpContrib-console', $head );

	# return text
	return $console;
}

=pod

---++ ObjectMethod _OPENIDCONSOLE ($twiki, $params, $topic, $web)

The is the handler function for the OPENIDCONSOLE tag. It generates
HTML for the user and admin console interfaces.

=cut

sub _OPENIDCONSOLE
{
    #my( $twiki, $params, $topic, $web ) = @_;
	my $twiki = shift;
	my $params = shift;
	my $topic = shift;
	my $web = shift;

	# make sure user is logged in
	if ( !defined $twiki->{user}) {
		return "not logged in";
	}

	# get parameters
	my $use_admin_console = (( exists $params->{admin}) and $params->{admin})
		? $params->{admin} : 0;

	# present user or admin interfaces
	my $vars = {};
	my $cgivars = $twiki->{cgiQuery}->Vars;
	foreach my $key ( keys %$cgivars ) {
		# deep-copy CGI variables so we don't end up modifying the source data
		$vars->{$key} = $cgivars->{$key};
	}
	$vars->{topic} = $topic;
	$vars->{web} = $web;
	if ( $use_admin_console ) {
		return _admin_console( $twiki, $vars );
	} else {
		return _user_console( $twiki, $vars );
	}
	
}

1;
