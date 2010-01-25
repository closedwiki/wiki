# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# part of OpenIDConsumerContrib by Ian Kluft
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

=begin twiki

---+ package TWiki::Users::OpenIDMapping

This user mapping module uses OpenID ( http://www.openid.org/ ) for user
logins based on remote OpenID accounts from an OpenID provider.  This module
is an OpenID consumer because it uses but does not originate user accounts.

This is a subclass of TWiki::Users::TWikiUserMapping

=cut

package TWiki::Users::OpenIDMapping;
use strict;

use base 'TWiki::Users::TWikiUserMapping';
use Error qw( :try );		# included with Perl
use Assert;			# included with TWiki
use TWiki::Func;		# included with TWiki
use DB_File::Lock;		# included with OpenIDConsumerContrib
use TWiki::LoginManager::OpenID; # included with OpenIDConsumerContrib
use Net::OpenID::Consumer;	# CPAN dependency

#use Monitor;
#Monitor::MonitorMethod('TWiki::Users::OpenIDMapping');

# configuration
our $OPENID_MAPPING_ID = 'OpenIDMapping_';

# globals
my %expanding;

=begin twiki

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

=begin twiki

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;

    # close DB_File mappings from _initOpenIDMapping
    untie $this->{L2U};
    untie $this->{U2W};
    untie $this->{W2U};

    # clean-up data structures
    undef $this->{session};
    undef $this->{mapping_id};
    $this->SUPER::finish();
}

=begin twiki

---++ ObjectMethod loginTemplateName () -> $templateFile

Allows UserMappings to come with customised login screens - that should
preferably only over-ride the UI function

In this case, OpenIDMapping returns "openidlogin".

=cut

sub loginTemplateName {
    return 'openidlogin';
}

=begin twiki

---++ ObjectMethod supportsRegistration ()
return 0 to indicate we don't suport user registration with this module

=cut

sub supportsRegistration {
    return TWiki::Users::TWikiUserMapping::supportsRegistration();
}

=begin twiki

---++ ObjectMethod handlesUser ( $cUID, $login, $wikiname) -> $boolean

Called by the TWiki::Users object to determine which loaded mapping
to use for a given user.

If it doesn't look like OpenID, hands off to TWiki::Users::TWikiUserMapping.

=cut

sub handlesUser {
    my ($this, $cUID, $login, $wikiname) = @_;
	
    # if login wasn't provided, we won't touch this with a 10-foot (3m) pole
    ( defined $login ) or return 0;

    # if it matches the OpenID LoginManager's patters, assume it's OpenID
    if ( $login =~ $TWiki::LoginManager::OpenID::openid_pattern ) {
	return 1;
    }

    # hand off to the superclass
    return $this->SUPER::handlesUser( $cUID, $login, $wikiname );
}

# initialize the DB mapping data between OpenID and TWiki users
# 
# TODO: split out to something like TWiki::Users::Data::DB_File
# For more scalability, we need finer-grained locking w/ DB access only
# on a cache miss.  Consider upgrading to SQL database - SQLite is
# appropriately lightweight for this operation.  But optionally allow
# other SQL DBs via DBI.
sub _initOpenIDMapping {
    my $this = shift;
    return if $this->{OpenID_init_done};
    $this->{OpenID_init_done} = 1;

    # initialize DB tied hashes
    my $mode;
    foreach $mode ( "L2U", "U2W", "W2U" ) {
    	    # derive DB file name
	    my $db_filename = $TWiki::cfg{DataDir}."/OpenID-$mode.db";

	    # open DB file
	    #tie(%{$this->{$mode}}, 'DB_File::Lock', $db_filename,  O_RDONLY, 0600, $DB_HASH, 'read');
	    tie(%{$this->{$mode}}, 'DB_File', $db_filename,  O_RDONLY, 0600, $DB_HASH, 'read');
    }
}

1;
