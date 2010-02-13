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

	# set class variables
	$this->{debug} = ( exists $TWiki::cfg{OpenIdRpContrib}{Debug})
		? $TWiki::cfg{OpenIdRpContrib}{Debug} : 0;

    # override TWiki::LoginManager's LOGIN tag handler with OpenID-specific one
    TWiki::registerTagHandler('LOGIN', \&_LOGIN);

	# register tag handler for %OPENIDPROVIDERS% set of login buttons
    TWiki::registerTagHandler('OPENIDPROVIDERS', \&_OPENIDPROVIDERS);

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
	if ( $TWiki::cfg{OpenIdRpContrib}{Debug}) {
		print STDERR "debug: ".join( ' ', @_ )."\n";
	}
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

	# if it doesn't exist, get the provider's favicon
	# for now assume everyone has a /favicon.ico, TODO: check HTML <head> links
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

	# get the list of providers
	my @op_list = ( exists $TWiki::cfg{OpenIdRpContrib}{OpenIDProviders})
		? @{$TWiki::cfg{OpenIdRpContrib}{OpenIDProviders}}
		: ();

	# get parameters
	my $sb = $params->get("sidebar") ? "sidebar_" : "";

	# generate HTML list of providers
	my $result = '<div class="'.$sb.'OP_list">';
	while ( @op_list ) {
		my $op_name = shift @op_list;
		my $op_url = shift @op_list;
		check_provider_icon ( $twiki, $op_name, $op_url );
		
		$result .= '<button class="'.$sb.'OP_entry" type="submit" '
			.'name="openid.provider" value="'
			.$op_name.'" title="<nop>'.$op_name.' login via <nop>OpenID">'
			.'<img src="%PUBURL%/%SYSTEMWEB%/OpenIdRpContrib/op-icon-'
			.$op_name.'.ico" alt="" class="'.$sb.'OP_icon">'
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
    my $twiki = $this->{twiki};
    my $users = $twiki->{users};

    # collect CGI parameters
    my $web = $session->{webName};
    my $topic = $session->{topicName};
    my %params = $query->Vars;
    my $origurl = $params{'origurl'};
    my $loginName = $params{'username'};
    my $loginPass = $params{'password'};

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

	# if an OpenID provider button was selected, fill in the login name
	if ( exists $openid_p{provider} ) {
		my %ops = @{$TWiki::cfg{OpenIdRpContrib}{OpenIDProviders}};
		if ( exists $ops{$openid_p{provider}}) {
			debug "provider button selected:", $openid_p{provider},
				"=", $ops{$openid_p{provider}};
			$loginName = $ops{$openid_p{provider}};
			undef $loginPass;
		}

    # if no login provided, or login & password, use parent class login
    } elsif (( ! defined $loginName ) or
		(( defined $loginName ) and ( defined $loginPass )))
	{
    	return $this->SUPER::login( $query, $session );
    }

    # get OpenID configuration info
    my $ua_class = ( exists $TWiki::cfg{OpenIdRpContrib}{ua_class})
		? $TWiki::cfg{OpenIdRpContrib}{ua_class}
    	: "LWP::UserAgent";
    my $required_root = (( exists $TWiki::cfg{OpenIdRpContrib}{required_root})
		?  $TWiki::cfg{OpenIdRpContrib}{required_root}
		: $TWiki::cfg{DefaultUrlHost}).'/',
    my $nonce_pattern = ( exists $TWiki::cfg{OpenIdRpContrib}{nonce_pattern})
		? $TWiki::cfg{OpenIdRpContrib}{nonce_pattern}
    	: "GJvxv_%s";
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
			debug => $this->{debug},
		);

		# handle responses
		if (my $setup_url = $csr->user_setup_url) {
			# security: don't pass through sensitive info
			$query->delete( 'origurl', 'username', 'password',
				@openid_keys );

			# the OpenID request failed, requiring the user to perform setup
			throw TWiki::OopsException(
			'generic',
			web => $twiki->{web},
			topic => $twiki->{topic},
			params => [ "Error in OpenID Provider response",
				'<a href="'.$setup_url.'">setup required</a> for this user',
				"", "" ]);
			return;
		} elsif ($csr->user_cancel) {
			# security: don't pass through sensitive info
			$query->delete( 'origurl', 'username', 'password',
				@openid_keys );

			# the user or provider canceled the request
			throw TWiki::OopsException(
			'generic',
			web => $twiki->{web},
			topic => $twiki->{topic},
			params => [ "OpenID request canceled",
				'cancel received from OpenID Provider',
				"", "" ]);
			return;
		} elsif (my $vident = $csr->verified_identity) {
			# success, determine WikiName and redirect back as logged-in user

			# we need the identity string, or all else fails
			if ( ! exists $openid_p{identity}) {
				# security: don't pass through sensitive info
				$query->delete( 'origurl', 'username', 'password',
					@openid_keys );

				throw TWiki::OopsException( 'generic',
				web => $twiki->{web},
				topic => $twiki->{topic},
				params => [ 'OpenID error',
					"OpenID Provider did not provide user's identity string",
					"", "" ]);
				return;
			}

			# filter for identity providers if we have white or black lists
			my $op_host = $openid_p{identity};
			$op_host =~ s=^https{0,1}://==;
			$op_host =~ s=/.*==;
			if ( ! proc_wb_lists( $op_host,
				$TWiki::cfg{OpenIdRpContrib}{OPHostWhitelist},
				$TWiki::cfg{OpenIdRpContrib}{OPHostBlacklist}))
			{
				# security: don't pass through sensitive info
				$query->delete( 'origurl', 'username', 'password',
					@openid_keys );

				throw TWiki::OopsException( 'generic',
				web => $twiki->{web},
				topic => $twiki->{topic},
				params => [ 'OpenID error',
					"OpenID Provider $op_host not allowed at this site",
					"", "" ]);
				return;
			}

			# check URL to redirect now-logged-in user to
			if ( !$origurl or $origurl eq $query->url()
				or $origurl =~ /%[A-Z0-9_]+%/ )
			{
				my $topic = $twiki->{topicName};
				my $web   = $twiki->{webName};

				$origurl = $twiki->getScriptUrl( 0, 'view', $web, $topic );
			}

			# check if we already know this identity - if so we're done
			my $cUID = TWiki::Users::OpenIDMapping::openid2cUID( $twiki,
				$openid_p{identity});
			my $mapping = $twiki->{users}{mapping};
			my $wikiname = ( defined $cUID )
				? $mapping->getWikiName ( $cUID )
				: undef;
			debug "wn=$wikiname cUID=$cUID openid=".$openid_p{identity};
			if ( defined $wikiname ) {
				# log the user in
				$this->userLoggedIn( $wikiname );

				# security: don't pass through sensitive info
				$query->delete( 'origurl', 'username', 'password',
					@openid_keys );

				# redirect now-logged-in user to destination page
				$this->redirectCgiQuery($query, $origurl );
				return;
			}

			# collect user info from OpenID Provider
			my $sreg = $vident->extension_fields( 'http://openid.net/extensions/sreg/1.1' );
			my $ax = $vident->extension_fields( 'http://openid.net/srv/ax/1.0' );
			my ( $first_name, $last_name, $email, $country );
			if ( exists $ax->{"value.lastname"}) {
				# OpenID 2.0 AX (attribute exchange)
				$first_name = (( exists $ax->{'value.firstname'} )
					? $ax->{'value.firstname'} : "" );
				$last_name = (( exists $ax->{'value.lastname'} )
					? $ax->{'value.lastname'} : "" );
				$email = (( exists $ax->{'value.email'} )
					? $ax->{'value.email'} : "" );
				$country = (( exists $ax->{'value.country'} )
					? $ax->{'value.country'} : "" );
				$wikiname = $first_name.$last_name;
			} else {
				# OpenID 1.1 SREG (simple registration)
				$email = $sreg->{email};
				if ( exists $sreg->{fullname}) {
					$wikiname = $sreg->{fullname};
					$wikiname =~ s/\s*//g;
				}
				( $first_name, $last_name )
					= split ( " ", $sreg->{fullname}, 2 );
			}

			# check that we have required info
			if ( !$first_name or ! $last_name ) {
				# security: don't pass through sensitive info
				$query->delete( 'origurl', 'username', 'password',
					@openid_keys );

				throw TWiki::OopsException( 'generic',
				web => $twiki->{web},
				topic => $twiki->{topic},
				params => [ 'OpenID error',
					"OpenID Provider did not provide user's full name",
					"", "" ]);
				return;
			}
			if ( !$email ) {
				# security: don't pass through sensitive info
				$query->delete( 'origurl', 'username', 'password',
					@openid_keys );

				throw TWiki::OopsException( 'generic',
				web => $twiki->{web},
				topic => $twiki->{topic},
				params => [ 'OpenID error',
					"OpenID Provider did not provide user's e-mail address",
					"", "" ]);
				return;
			}

			# filter for email domains if we have white or black lists
			my $email_dom = $email;
			$email_dom =~ s=^.*@==;
			if ( ! proc_wb_lists( $email_dom,
				$TWiki::cfg{OpenIdRpContrib}{EmailDomWhitelist},
				$TWiki::cfg{OpenIdRpContrib}{EmailDomBlacklist}))
			{
				# security: don't pass through sensitive info
				$query->delete( 'origurl', 'username', 'password',
					@openid_keys );

				throw TWiki::OopsException( 'generic',
				web => $twiki->{web},
				topic => $twiki->{topic},
				params => [ 'OpenID error',
					"New user request requires manual approval.",
					"Contact the site administrator(s)", "" ]);
				return;
			}

			# check for WikiName collision, adjust wikiname if necessary
			$cUID = TWiki::Users::OpenIDMapping::_mapper_get( $twiki, "W2U",
				$wikiname );
			if ( defined $cUID ) {
				# append numbers to the wikiname until it isn't a collision
				my $suffix = 2;
				while ( 1 ) {
					$cUID = TWiki::Users::OpenIDMapping::_mapper_get(
						$twiki, "W2U", $wikiname.$suffix );
					if ( ! defined $cUID ) {
						# didn't find a cUID so the WikiName is available
						$wikiname = $wikiname.$suffix;
						last;
					}
					$suffix++;
				}
			}

			# log the user in as the WikiName
			$this->userLoggedIn( $wikiname );

			# save OpenID attributes in OpenID mapper
			$openid_p{WikiName} = $wikiname;
			$openid_p{FirstName} = $first_name;
			$openid_p{LastName} = $last_name;
			$openid_p{Email} = $email;
			delete $openid_p{return_to}; # don't need to save temp URL
			TWiki::Users::OpenIDMapping::save_openid_attrs( $twiki,
				$wikiname, \%openid_p );

			# auto-register user in TWiki if configured to do so
			if ( $TWiki::cfg{OpenIdRpContrib}{AutoRegisterUser}) {
				if ( ! $twiki->{store}->topicExists(
					$TWiki::cfg{UsersWebName}, $wikiname ))
				{
					# fill in parameters from OpenID
					$query->param( "FirstName", $first_name );
					$query->param( "WikiName", $wikiname );
					$query->param( "LastName", $last_name );
					$query->param( "LoginName", lc($wikiname));
					$query->param( "Email", $email );
					$query->param( "Country", $country ) if $country;
					
					# security: don't pass through sensitive info
					$query->delete( 'username', 'password', @openid_keys );

					# redirect now-logged-in user to destination page
					my $regurl = $twiki->getScriptUrl( 0, 'view',
						$TWiki::cfg{SystemWebName}, "TWikiRegistration" );
					$this->redirectCgiQuery($query, $regurl );
					return;
				}

			# auto-create user in TWiki if configured to do so
			} elsif ( $TWiki::cfg{OpenIdRpContrib}{AutoCreateUser}) {
				if ( ! $twiki->{store}->topicExists(
					$TWiki::cfg{UsersWebName}, $wikiname ))
				{
					TWiki::UI::Register::_registerSingleBulkUser(
						$twiki,
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
		} else {
			# security: don't pass through sensitive info
			$query->delete( 'origurl', 'username', 'password',
				@openid_keys );

			# catch-all reporting for other errors
			throw TWiki::OopsException(
				'generic',
				web => $twiki->{web},
				topic => $twiki->{topic},
				params => [ 'OpenID error', $csr->errcode(), $csr->errtext(),
					"" ]);
		}
    } elsif ( defined $loginName ) {
    	# we don't have a response, so prepare a request for OpenID provider

        my $csr = Net::OpenID::Consumer->new(
			cache => $cache,
			consumer_secret => $consumer_secret,
			required_root => $required_root,
			args => $query,
			ua => $ua_class->new,
			debug => $this->{debug},
        );
		if ( ! $csr ) {
			# security: don't pass through sensitive info
			$query->delete( 'origurl', 'username', 'password',
				@openid_keys );

			throw TWiki::OopsException(
			'generic',
			web => $twiki->{web},
			topic => $twiki->{topic},
			params => [ 'Unable to initialize !OpenID library',
				$csr->err, "", "" ]);
		}

		# if login name is a known WikiName, convert it to OpenID identity
		if ( $loginName =~ /$TWiki::cfg{LoginNameFilterIn}/ ) {
			my @openids = TWiki::Users::OpenIDMapping::login2openid( $twiki,
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
				my @req_fields = ( exists $TWiki::cfg{OpenIdRpContrib}{req_fields1})
					? ( required => $TWiki::cfg{OpenIdRpContrib}{req_fields1})
					: (required =>  'fullname,email');
				my @opt_fields = ( exists $TWiki::cfg{OpenIdRpContrib}{opt_fields1})
					? ( optional => $TWiki::cfg{OpenIdRpContrib}{opt_fields1})
					: (optional =>  'nickname,country,timezone');
				my @policy_url = ( exists $TWiki::cfg{OpenIdRpContrib}{policy_url1})
					? ( policy_url => $TWiki::cfg{OpenIdRpContrib}{policy_url1})
					: ();
				$claimed_id->set_extension_args(
					'http://openid.net/extensions/sreg/1.1',
					{
						@req_fields,
						@opt_fields,
						@policy_url,
					},
				);
			} else {
				# OpenID 2.0+ and AX (Attribute Exchange)
				my @req_fields = ( exists $TWiki::cfg{OpenIdRpContrib}{req_fields2})
					? ( required => $TWiki::cfg{OpenIdRpContrib}{req_fields2})
					: ( required =>  'firstname,lastname,email');
				my @opt_fields = ( exists $TWiki::cfg{OpenIdRpContrib}{opt_fields2})
					? ( if_available => $TWiki::cfg{OpenIdRpContrib}{opt_fields2})
					: ( if_available =>  'nickname,country,timezone');
				# TODO - get definitions of field names/URLs from table
				$claimed_id->set_extension_args(
					'http://openid.net/srv/ax/1.0',
					{
						"mode" => "fetch_request",
						@req_fields,
						@opt_fields,
						"type.firstname" => "http://axschema.org/namePerson/first",
						"type.lastname" => "http://axschema.org/namePerson/last",
						"type.email" => "http://axschema.org/contact/email",
						"type.nickname" => "http://axschema.org/namePerson/friendly",
						"type.country" => "http://axschema.org/contact/country/home",
						"type.timezone" => "http://axschema.org/pref/timezone",
					}
				);
			}
            my $check_url = $claimed_id->check_url (
	        # The place we go back to.
	        return_to  => $query->self_url,
	        # Having this simplifies the login process.
	        trust_root => $TWiki::cfg{DefaultUrlHost}.'/',
			# tell the OP that it has control
			# (we're not doing Ajax here yet - subject to change in future)
			delayed_return  => 1,
            );

            # Automatically redirect the user to the OpenID endpoint
			$twiki->redirect( $check_url, 0 );
        } else {
			# security: don't pass through sensitive info
			$query->delete( 'origurl', 'username', 'password',
				@openid_keys );

			throw TWiki::OopsException(
			'generic',
			web => $twiki->{web},
			topic => $twiki->{topic},
			params => [ 'Error in !OpenID claimed identity',
				"cannot initiate !OpenID",
				$csr->err, "" ]);
        }
    }
}

1;
