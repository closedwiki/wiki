# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# part of OpenIdRpContrib by Ian Kluft
# Copyright (C) 2007-2010 TWiki Inc and TWiki Contributors.
# All Rights Reserved. TWiki Contributors
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
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package TWiki::Users::OpenIDMapping

This user mapping module uses OpenID ( http://www.openid.org/ ) for user
logins based on remote OpenID accounts from an OpenID provider.  This module
is an OpenID consumer because it uses but does not originate user accounts.

This is a subclass of TWiki::Users::TWikiUserMapping

=cut

package TWiki::Users::OpenIDMapping;
use strict;

use base 'TWiki::Users::TWikiUserMapping';
use Error qw( :try );					# included with Perl
use DB_File;							# included with Perl
use Assert;								# included with TWiki
use TWiki::Contrib::OpenIdRpContrib::DBLockPerAccess;	# included with OpenIdRpContrib
use Net::OpenID::Consumer;				# CPAN dependency

#use Monitor;
#Monitor::MonitorMethod('TWiki::Users::OpenIDMapping');

# configuration
our $OPENID_MAPPING_ID = 'OpenIDMapping_';
our $openid_attr_delim = "\0";
our $openid_rec_delim = $openid_attr_delim x 3;
our $openid_pattern = '^(http:|https:|xri:)?[\w.:;,~/?#\[\]()*!&\'-]+$';

# globals
my %expanding;

=pod

---++ ClassMethod new ($session, $impl)

Constructs a new user mapping handler of this type, referring to $session
for any required TWiki services.

=cut

sub new {
    my( $class, $session ) = @_;

    # instantiate
    my $this = bless( $class->SUPER::new( $session, $OPENID_MAPPING_ID ),
    	__PACKAGE__ );

    # initialize
    $this->_initOpenIDMapping();
    $this->{session} = $session;
    $this->{mapping_id} = $OPENID_MAPPING_ID;

    return $this;
}

=pod

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;

    # close DB_File mappings from _initOpenIDMapping
    untie $this->{L2U};	# login to cUID
    untie $this->{U2W}; # cUID to wiki name
    untie $this->{W2U}; # wiki name to cUID
    untie $this->{O2U}; # OpenID identity to cUID
    untie $this->{U2A}; # cUID to OpenID attrs

    # clean-up data structures
    undef $this->{session};
    undef $this->{mapping_id};
    $this->SUPER::finish();
}

=pod

---++ ObjectMethod loginTemplateName () -> $templateFile

Allows UserMappings to come with customised login screens - that should
preferably only over-ride the UI function

In this case, OpenIDMapping returns "openidlogin".

=cut

sub loginTemplateName {
    return 'openidlogin';
}

=pod

---++ ObjectMethod supportsRegistration ()
return 0 to indicate we don't suport user registration with this module

=cut

sub supportsRegistration {
    return TWiki::Users::TWikiUserMapping::supportsRegistration();
}

=pod

---++ ObjectMethod handlesUser ( $cUID, $login, $wikiname) -> $boolean

Called by the TWiki::Users object to determine which loaded mapping
to use for a given user.

If it isn't in the OpenIdRpContrib DB file already, and doesn't look like
an OpenID URL, hands off to TWiki::Users::TWikiUserMapping.

=cut

sub handlesUser {
    my ($this, $cUID, $login, $wikiname) = @_;
	
	# if user exists in the OpenIdRpContrib DB files, claim it
	( defined $login )
		and ( exists $this->{session}{users}{mapping}{L2U}{$login} )
		and return 1;
	( defined $login )
		and ( exists $this->{session}{users}{mapping}{W2U}{$login} )
		and return 1;
	( defined $cUID )
		and ( exists $this->{session}{users}{mapping}{U2W}{$cUID} )
		and return 1;
	( defined $wikiname )
		and ( exists $this->{session}{users}{mapping}{W2U}{$wikiname} )
		and return 1;

    # if it matches the OpenID LoginManager's pattern, assume it's OpenID
    if (( defined $login ) and ( $login =~ $openid_pattern )) {
		return 1;
    }

    # hand off to the superclass
    return $this->SUPER::handlesUser( $cUID, $login, $wikiname );
}

=pod

---++ ObjectMethod getWikiName ($cUID) -> $wikiname

Map a canonical user name to a wikiname. 

=cut

sub getWikiName {
	my ($this, $cUID) = @_;

	# required params
	( defined $this ) or return undef;
	( defined $cUID ) or return undef;

	# look up in table
	( exists $this->{U2W}{$cUID}) or return undef;
	return $this->{U2W}{$cUID};
}

=pod

---++ ObjectMethod userExists ($this, $cUID ) -> boolean

Override TWiki::Users::TWikiUserMapping::userExists so that
OpenID users can be found whether AllowLoginName is set or not.

=cut

sub userExists {
	my $this = shift;
	my $cUID = shift;

	return 1 if $this->_userReallyExists( $cUID );
	return $this->SUPER::userExists( $cUID );
}

=pod

---++ ObjectMethod login2cUID ($login, $dontcheck) -> $cUID

Override TWiki::Users::TWikiUserMapping::login2cUID()

make sure login name for OpenID users is based on WikiName but forced to
lower case.
(undef on failure)

(if dontcheck is true, it returns a cUID for a nonexistant user
for registration)

=cut

sub login2cUID {
    my( $this, $login, $dontcheck ) = @_;

    unless ($dontcheck) {
        return undef unless (_userReallyExists($this, $login));
    }

    return $this->{mapping_id}.lc(TWiki::Users::mapLogin2cUID($login));
}

=pod

---++ StaticMethod openid2cUID($openid) -> $cUID

Convert an OpenID identity to the corresponding canonical user name.
(undef on failure)

=cut

sub openid2cUID {
    my( $session, $openid ) = @_;

	if ( exists $session->{users}{mapping}{O2U}{$openid}) {
		return $session->{users}{mapping}{O2U}{$openid};
	} else {
		return undef;
	}
}

=pod

---++ StaticMethod login2openid($login) -> $openid

Convert a login/WikiName to the corresponding OpenID identity.
(undef on failure)

=cut

sub login2openid {
    my( $session, $login ) = @_;

	my $mapping = $session->{users}{mapping};
	if ( exists $mapping->{L2U}{lc($login)}) {
		my $cUID = $mapping->{L2U}{lc($login)};
		return cUID2openid( $session, $cUID );
	}
	if ( exists $mapping->{W2U}{$login}) {
		my $cUID = $mapping->{W2U}{$login};
		return cUID2openid( $session, $cUID );
	}
	return undef;
}

=pod

---++ StaticMethod cUID2openid($login) -> $openid

Convert a cUID to the corresponding OpenID identity.
(undef on failure)

=cut

sub cUID2openid {
    my( $session, $cUID ) = @_;

	my $mapping = $session->{users}{mapping};
	( exists $mapping->{U2A}{$cUID}) or return ();
    my $attr_recs = $mapping->{U2A}{$cUID};
	my @recs = split ( $openid_rec_delim, $attr_recs );
	my %openids;
	foreach my $rec ( @recs ) {
		my %attr = split ( $openid_attr_delim, $rec );
		$openids{$attr{identity}} = 1;
	}
	return keys %openids;
}

=pod

---++ StaticMethod mapper_getEmails($session, $user)

This overrides TWiki::Users::TWikiUserMapping::mapper_getEmails in order
to use the DB_File infrastructure of OpenIdRpContrib to access user OpenID
attributes.

=cut

sub mapper_getEmails {
    my( $session, $cUID ) = @_;

	( exists $session->{users}{mapping}{U2A}{$cUID}) or return undef;
	my $attr_recs = $session->{users}{mapping}{U2A}{$cUID};
	( defined $attr_recs ) or return undef;
	my @recs = split ( $openid_rec_delim, $attr_recs );
	my %emails;
	foreach my $rec ( @recs ) {
		my %attr = split ( $openid_attr_delim, $rec );
		$emails{$attr{Email}} = 1;
	}
	return keys %emails;
}

=pod

---++ StaticMethod mapper_setEmails ($session, $user, @emails)

This overrides TWiki::Users::TWikiUserMapping::mapper_getEmails in order
to use the DB_File infrastructure of OpenIdRpContrib to access user OpenID
attributes.

=cut

sub mapper_setEmails {
    my $session = shift;
    my $cUID = shift;
	my $mails = join( ';', @_ );

	my $attr = $session->{users}{mapping}{U2A}{$cUID};
	my %attr = split $openid_attr_delim, $attr;
	$attr{Email} = $mails;
	$session->{users}{mapping}{U2A}{$cUID} = join( $openid_attr_delim, %attr );
}

=pod

---++ ObjectMethod findUserByWikiName ($wikiname) -> list of cUIDs associated with that wikiname

This overrides TWiki::Users::TWikiUserMapping::findUserByWikiName in order
to let OpenID users be found whether AllowLoginName is set or not

=cut

sub findUserByWikiName
{
	my $this = shift;
	my $wn = shift;
	my $skipExistanceCheck = shift; # sic/spelling error from parent

	my $cUID = mapper_get( $this->{session}, "W2U", $wn );
	if ( defined $cUID ) {
		return [ $cUID ];
	}
	return $this->SUPER::findUserByWikiName( $wn, $skipExistanceCheck );
}

=pod

---++ StaticMethod mapper_get ($session, $table, $key)

looks up data in mapping tables

=cut

sub mapper_get {
    my $session = shift;
    my $table = shift;
	my $key = shift;

	my $mapping = $session->{users}{mapping};
	( $table =~ /^[LOUW]2[AUW]$/ ) or return undef; # no snooping elsewhere
	( exists $mapping->{$table}) or return undef;	# exact table name exists
	( exists $mapping->{$table}{$key}) or return undef;	# entry name exists
	return $mapping->{$table}{$key};
}

=pod

---++ StaticMethod mapper_keys ($session, $table )

get keys from a mapping table

=cut

sub mapper_keys {
    my $session = shift;
    my $table = shift;
	
	my $mapping = $session->{users}{mapping};
	( $table =~ /^[LOUW]2[AUW]$/ ) or return undef; # no snooping elsewhere
	( exists $mapping->{$table}) or return undef;	# exact table name exists
	return keys %{$mapping->{$table}};
}

=pod

---++ StaticMethod save_openid_attrs ($session, $user, $attrs )

Save the OpenID attributes of a new user we have not handled before.

This overrides TWiki::Users::TWikiUserMapping::mapper_getEmails in order
to use the DB_File infrastructure of OpenIdRpContrib to access user OpenID
attributes.

=cut

sub save_openid_attrs {
    my $session = shift;
    my $wikiname = shift;
	my $attrs = shift;

	# generate cUID from wikiname/login
	my $mapping = $session->{users}{mapping};
	my $cUID = $mapping->login2cUID( $wikiname, 1 );
	( defined $cUID ) or throw TWiki::OopsException( 'generic',
				web => $session->{web}, topic => $session->{topic},
				params => [ "Internal error",
				"save_openid_attrs w/ empty canonical ID",
				"wikiname=$wikiname", "" ]);
	my $identity = $attrs->{identity};

	# save TWiki mapping
	$mapping->{U2W}{$cUID}     = $wikiname;
	$mapping->{L2U}{lc($wikiname)} = $cUID;
	$mapping->{W2U}{$wikiname} = $cUID;
	
	# save OpenID mapping
	$mapping->{O2U}{$identity} = $cUID;
	$mapping->{U2A}{$cUID} = join( $openid_attr_delim, %$attrs );
}

=pod

---++ StaticMethod add_openid_identity ($session, $cUID, $attrs )

Save an OpenID identity for the user

=cut

sub add_openid_identity {
    my $session = shift;
    my $cUID = shift;
	my $attrs = shift;

	# check if other acct was using or pre-approved for that OpenID identity
	my $mapping = $session->{users}{mapping};
	my $identity = $attrs->{identity};
	if ( exists $mapping->{O2U}{$identity}) {
		# if it was in use, remove it first to maintain referential integrity
		my $old_cUID = $mapping->{O2U}{$identity};
		del_openid_identity( $session, $old_cUID, { identity => $identity });
	}

	# save OpenID mapping
	$mapping->{O2U}{$identity} = $cUID;

	# get OpenID identity records
	my $attr_recs = $mapping->{U2A}{$cUID};
	if ( ! defined $attr_recs ) {
		$attr_recs = "";
	}
	my @recs = split ( $openid_rec_delim, $attr_recs );

	# delete any existing records which contain the same identity
	my $i;
	for ( $i = 0; $i < scalar @recs; $i++ ) {
		my %attr = split ( $openid_attr_delim, $recs[$i] );
		if ( $attr{identity} eq $identity ) {
			delete $recs[$i];
			$i--;
		}
	}

	# append OpenID attrs to existing records
	push @recs, join( $openid_attr_delim, %$attrs );

	# write modified attributes back
	$mapping->{U2A}{$cUID} = join ( $openid_rec_delim, @recs );

	# verify contents from tied DB and return status
	my $test_u2a = $mapping->{U2A}{$cUID};
	if ( !defined $test_u2a ) {
		return 0;
	}
	my @test_recs = split ( $openid_rec_delim, $test_u2a );
	for ( $i = 0; $i < scalar @test_recs; $i++ ) {
		my %attr = split ( $openid_attr_delim, $recs[$i] );
		if ( $attr{identity} eq $identity ) {
			return 1;
		}
	}
	return 0;
}

=pod

---++ StaticMethod del_openid_user ($session, $cUID )

Delete/purge an OpenID user from the system

=cut

sub del_openid_user {
    my $session = shift;
    my $cUID = shift;

	# delete all the DB records associated with this user
	my $mapping = $session->{users}{mapping};
	my $wn = $mapping->getWikiName( $cUID );
	my $login = lc($wn);
	if ( exists $mapping->{L2U}{$login}) {
		delete $mapping->{L2U}{$login};
	}
	if ( exists $mapping->{U2A}{$cUID}) {
		delete $mapping->{U2A}{$cUID};
	}
	if ( exists $mapping->{U2W}{$cUID}) {
		delete $mapping->{U2W}{$cUID};
	}
	if ( exists $mapping->{W2U}{$wn}) {
		delete $mapping->{W2U}{$wn};
	}

	# make sure there are no stray O2U OpenID identities pointing to this cUID
	my $key;
	my $done = 0;
	foreach $key ( keys %{$mapping->{O2U}}) {
		if ( $mapping->{O2U}{$key} eq $cUID ) {
			delete $mapping->{O2U}{$key};
			$done = 1;
			last;
		}
	}

	# verify and return result
	if ( $done and !exists $mapping->{O2U}{$key}) {
		return 1;
	} else {
		return 0;
	}
}

=pod

---++ StaticMethod del_openid_identity ($session, $cUID, $params )

Delete an OpenID identity for the user

returns 0 for error, 1 for success removing record, 2 if last record was
removed and user was deleted from the OpenID records.

=cut

sub del_openid_identity {
    my $session = shift;
    my $cUID = shift;
	my $params = shift;

	# get OpenID records
	my $mapping = $session->{users}{mapping};
	my $attr_recs = $mapping->{U2A}{$cUID};
	if ( ! defined $attr_recs ) {
		throw TWiki::OopsException( 'generic',
			web => $session->{web}, topic => $session->{topic},
			params => [ "no OpenID records found for this account",
			"There are no OpenID records to delete.",
			"cUID = $cUID", "" ]);
	}
	my @recs = split ( $openid_rec_delim, $attr_recs );

	# determine index within user record of identity to delete
	my ( $index, $identity );
	if ( exists $params->{identity}) {
		# check if the identity is known to this system at all
		$identity = $params->{identity};
		if ( !exists $mapping->{O2U}{$identity}) {
			throw TWiki::OopsException( 'generic',
				web => $session->{web}, topic => $session->{topic},
				params => [ "OpenID identity does not match any account",
				"There are no OpenID records to delete.",
				"", "" ]);
			
		}

		my $i;
		for ( $i=0; $i < scalar @recs; $i++ ) {
			my %attr = split ( $openid_attr_delim, $recs[$i] );
			if ( $attr{identity} eq $identity ) {
				$index = $i;
				last;
			}
		}
		if ( !defined $index ) {
			throw TWiki::OopsException( 'generic',
				web => $session->{web}, topic => $session->{topic},
				params => [ "no OpenID found in $cUID matching $identity",
				"There are no OpenID records to delete.",
				"", "" ]);
		}
	} elsif ( exists $params->{index}) {
		$index = $params->{index} - 1;
	}

	# delete OpenID identity by index
	if ( !defined $identity ) {
		my %attrs = split ( $openid_attr_delim, $recs[$index] );
		$identity = $attrs{identity};
	}
	delete $recs[$index];
	delete $mapping->{O2U}{$identity};

	# if that was the last record, delete user from OpenID
	# this maintains referential integrity of the data structures
	if ( ! @recs ) {
		if ( del_openid_user( $session, $cUID )) {
			return 2;
		} else {
			return 0;
		}
	}

	# write remaining records back
	$mapping->{U2A}{$cUID} = join ( $openid_rec_delim, @recs );

	# verify contents from tied DB and return status
	my $test_u2a = $mapping->{U2A}{$cUID};
	if ( !defined $test_u2a ) {
		return 0;
	}
	my @test_recs = split ( $openid_rec_delim, $test_u2a );
	my $i;
	for ( $i = 0; $i < scalar @test_recs; $i++ ) {
		my %attr = split ( $openid_attr_delim, $recs[$i] );
		if ( $attr{identity} eq $identity ) {
			return 0;
		}
	}
	return 1;
}

# initialize the DB mapping data between OpenID and TWiki users
# 
# TODO: Consider upgrading to SQL database - SQLite is appropriately
# lightweight for this operation.  But optionally allow other SQL DBs via DBI.
sub _initOpenIDMapping {
    my $this = shift;
    return if $this->{OpenID_init_done};
    $this->{OpenID_init_done} = 1;

    # initialize variables
    my $mode;
	my $session = $this->{session};
	my $exception = sub { throw TWiki::OopsException( 'generic',
		web => $session->{web}, topic => $session->{topic},
		params => [ @_, "", "", "" ]); };

	# make subdirectory if needed
	if ( ! -d $TWiki::cfg{WorkingDir}."/openid" ) {
		mkdir $TWiki::cfg{WorkingDir}."/openid", 0770
			or throw TWiki::OopsException( 'generic',
				web => $session->{web}, topic => $session->{topic},
				params => [ "mkdir failed", "OpenID work dir", $!, "" ]);
	}

    # initialize DB tied hashes
	# L = login, U = cUID, W = wikiname, O = OpenID identity, A = OpenID attrs
	# so...
	# L2U = login to cUID
	# U2W = cUID to wiki name
	# W2U = wiki name to cUID
	# O2U = OpenID identity to cUID
	# U2A = cUID to OpenID attribute data
    foreach $mode ( "L2U", "U2W", "W2U", "O2U", "U2A" ) {
		# derive DB file name
	    my $db_filename = $TWiki::cfg{WorkingDir}."/openid/OpenID-$mode.db";

	    # open DB file
	    tie( %{$this->{$mode}}, 'TWiki::Contrib::OpenIdRpContrib::DBLockPerAccess', $db_filename,  O_RDWR|O_CREAT, 0660, $DB_HASH, $exception );
    }
}

# simpler version of TWiki::Users::TWikiUserMapping::_userReallyExists()
sub _userReallyExists
{
	my $this = shift;
	my $login = shift;

	return ( exists $this->{L2U}{$login})
		or ( exists $this->{W2U}{$login})
		or ( exists $this->{U2W}{$login})
		or SUPER::_userReallyExists( $this, $login );
}

1;
