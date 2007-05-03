# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
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

---+ package TWiki::Users

This package provides services for the lookup and manipulation of login and
wiki names of users, and their authentication.

It is a Facade that presents a common interface to the User Mapping
and Password modules.

TWiki uses the concept of a _login name_ which is used to authenticate a
user. A login name maps to a _wiki name_ that is used to identify the user
for display. Each login name is unique to a single user, though several
login names may map to the same wiki name.

Using this module (and the associated plug-in user mapper) TWiki supports
the concept of _groups_. Groups are sets of login names that are treated
equally for the purposes of access control. Group names do not have to be
wiki names, though it is helpful for display if they are.

Internally in the code TWiki uses something referred to as a _canonical user
id_ or just _user id_. The user id is also used externally to uniquely identify
the user when (for example) recording topic histories. The user id is *usually*
just the login name, but it doesn't need to be. It just has to be a unique
7-bit alphanumeric and underscore string that can be mapped to/from login
and wiki names by the user mapper.

The canonical user id should *never* be seen by a user.

*Terminology*
   * A *login name* is the name used to log in to TWiki. Each login name is
     assumed to be unique to a human. The Password module is responsible for
     authenticating and manipulating login names.
   * A *canonical user id* is an internal TWiki representation of a user. Each
     canonical user id maps 1:1 to a login name.
   * A *wikiname* is how a user is displayed. Many user ids may map to a
     single wikiname. The user mapping module is responsible for mapping
     the user id to a wikiname.
   * A *group id* represents a group of users and other groups.
     The user mapping module is responsible for mapping from a group id to
     a list of canonical user ids for the users in that group.
   * An *email* is an email address asscoiated with a *login name*. A single
     login name may have many emails.
	 
*NOTE:* 
   * wherever the code references $user, its a canonical_id
   * wherever the code references $group, its a group_name (TODO: extract a canonical_group_id and mapping)

=cut

package TWiki::Users;

use strict;
use Assert;
use TWiki::Time;

BEGIN {
    # Do a dynamic 'use locale' for this module
    if( $TWiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

=pod

---++ ClassMethod new ($session, $impl)

Construct the user management object

=cut

sub new {
    my ( $class, $session ) = @_;
    ASSERT($session->isa( 'TWiki')) if DEBUG;
    my $this = bless( {}, $class );

    $this->{session} = $session;

    my $implUserMappingManager = $TWiki::cfg{UserMappingManager};
    $implUserMappingManager = 'TWiki::Users::TWikiUserMapping'
      if( $implUserMappingManager eq 'none' );
    eval "use $implUserMappingManager";
    die "User Mapping Manager: $@" if $@;
    $this->{mapping} = $implUserMappingManager->new( $session );
    #the UI for rego supported/not is different from rego temporarily turned off
    $session->enterContext('registration_supported') if $this->supportsRegistration();
    $implUserMappingManager =~ /^TWiki::Users::(.*)$/;
    $this->{mapping_id} = $1.'_';

    return $this;
}

=pod

---++ ObjectMethod finish

Complete processing after the client's HTTP request has been responded
to.
   1 breaking circular references to allow garbage collection in persistent
     environments
   1 let more complex usermappers & password handlers close their connections

=cut

sub finish {
    my $this = shift;

    $this->{mapping}->finish();
}

#return 1 if the UserMapper supports registration (ie can create new users)
sub supportsRegistration {
    my( $this ) = @_;
    return $this->{mapping}->supportsRegistration();
}


# global used by test harness to give predictable results
use vars qw( $password );

=pod

---++ randomPassword()
Static function that returns a random password

=cut

sub randomPassword {
    return $password || int( rand(9999999999) );
}

=pod

---++ ObjectMethod addUser($login, $wikiname, $password, $emails) -> ($user, $password)

   * =$login= - user login name. If =undef=, =$wikiname= will be used as the login name.
   * =$wikiname= - user wikiname. If =undef=, the user mapper will be asked
     to provide it.
   * =$password= - password. If undef, a password will be generated.

Add a new TWiki user identity, returning the canonical user id for the new
user. Used ONLY for user registration.

The user is added to the password system (if there is one, and if it accepts
changes). If the user already exists in the password system, then the password
is checked and an exception thrown if it doesn't match. If there is no
existing user, and no password is given, a random password is generated.

$login can be undef; $wikiname must always have a value.

The return value is an array containing the canonical user id that is used
by TWiki to identify the user, and the actual (unencrypted) password.

=cut

sub addUser {
    my( $this, $login, $wikiname, $password, $emails) = @_;
    my $removeOnFail = 0;

	$this->ASSERT_IS_USER_LOGIN_ID($login) if DEBUG;
    ASSERT($login || $wikiname) if DEBUG; # must have one

    # create a new user and get the canonical user ID from the user mapping
    # manager.
    my $user = $this->{mapping}->addUser( $login, $wikiname, $password, $emails);
	$this->ASSERT_IS_CANONICAL_USER_ID($user) if DEBUG;

#TODO: why are we passing the password back?
    return ( $user, $password );

}

=pod

---++ ObjectMethod getCanonicalUserID( $login ) -> $user

Works out the unique TWiki identifier for the user who logs in with the
given login. The canonical user ID is an alphanumeric string that is unique
to the login name, and can be mapped back to a login name and the
corresponding wiki name using the methods of this class.

=cut

sub getCanonicalUserID {
    my( $this, $login ) = @_;
	$this->ASSERT_IS_USER_LOGIN_ID($login) if DEBUG;

    return $this->{mapping}->login2canonical( $login );
}

=pod

---++ ObjectMethod findUserByWikiName( $wn ) -> \@users
   * =$wn= - wikiname to look up
Return a list of canonical user names for the users that have this wikiname.
Since a single wikiname might be used by multiple login ids, we need a list.

If $wn is the name of a group, the group will *not* be expanded.

=cut

sub findUserByWikiName {
    my( $this, $wn ) = @_;
    ASSERT($wn) if DEBUG;
    return $this->{mapping}->findUserByWikiName( $wn );
}

=pod

---++ ObjectMethod findUserByEmail( $email ) -> \@users
   * =$email= - email address to look up
Return a list of canonical user names for the users that have this email
registered with the password manager or the user mapping manager.

The password manager is asked first for whether it maps emails.
If it doesn't, then the user mapping manager is asked instead.

=cut

sub findUserByEmail {
    my( $this, $email ) = @_;
    ASSERT($email) if DEBUG;

    return $this->{mapping}->findUserByEmail( $email );
}

=pod

---++ ObjectMethod getEmails($user) -> @emailAddress

If this is a user, return their email addresses. If it is a group,
return the addresses of everyone in the group.

The password manager and user mapping manager are both consulted for emails
for each user (where they are actually found is implementation defined).

Duplicates are removed from the list.

=cut

sub getEmails {
    my( $this, $user ) = @_;
	$this->ASSERT_IS_CANONICAL_USER_ID($user) if DEBUG;

    return $this->{mapping}->getEmails( $user );
}

=pod

---++ ObjectMethod setEmails($user, @emails)

Set the email address(es) for the given user.
The password manager is tried first, and if it doesn't want to know the
user mapping manager is tried.

=cut

sub setEmails {
    my $this = shift;
    my $user = shift;
	$this->ASSERT_IS_CANONICAL_USER_ID($user) if DEBUG;

    return $this->{mapping}->getEmails( $user, @_ );
}

=pod

---++ ObjectMethod isAdmin( $user ) -> $boolean

True if the user is an admin
   * is $TWiki::cfg{SuperAdminGroup}
   * is a member of the $TWiki::cfg{SuperAdminGroup}

=cut

sub isAdmin {
    my( $this, $user ) = @_;
    my $isAdmin = 0;
	$this->ASSERT_IS_CANONICAL_USER_ID($user) if DEBUG;

    if ($user eq $TWiki::cfg{SuperAdminGroup}) {
        $isAdmin = 1;
    } else {
        my $sag = $TWiki::cfg{SuperAdminGroup};
        $isAdmin = $this->{mapping}->isInGroup( $user, $sag );
    }

    return $isAdmin;
}

=pod

---++ ObjectMethod isInList( $user, $list ) -> $boolean

Return true if $user is in a list of user *wikinames* and group ids.

$list is a comma-separated wikiname and group list. The list may contain the
conventional web specifiers (which are ignored).

=cut

sub isInList {
    my( $this, $user, $userlist ) = @_;
	$this->ASSERT_IS_CANONICAL_USER_ID($user) if DEBUG;
	
    return 0 unless $userlist;

    # comma delimited list of users or groups
    # i.e.: "%MAINWEB%.UserA, UserB, Main.UserC  # something else"
    $userlist =~ s/(<[^>]*>)//go;     # Remove HTML tags

    my $wn = getWikiName( $this, $user );
    my $umm = $this->{mapping};

    foreach my $ident ( split( /[\,\s]+/, $userlist )) {
        $ident =~ s/^.*\.//;       # Dump the web specifier
        next unless $ident;
        return 1 if( $ident eq $wn );
        if( $umm->isGroup( $ident )) {
            return 1 if( $umm->isInGroup( $user, $ident ));
        }
    }
    return 0;
}

=pod

---++ ObjectMethod getLoginName($user) -> $string

Get the login name of a user. By convention
users are identified in the core code by their login name, and
never by their wiki name, so this is a nop.

=cut

sub getLoginName {
    my( $this, $user_id) = @_;
	$this->ASSERT_IS_CANONICAL_USER_ID($user_id) if DEBUG;
	
	#only process canonical_ids that are for the currently selected mapper (if none specificed in the canon_id, assume TWikiUserMapping)
    if ( $user_id =~ /^($this->{mapping_id})/ || ($this->{mapping_id} eq 'TWikiUserMapping_')) {
        return $this->{mapping}->getLoginName( $user_id );
    } else {
        return 'unknown_user';
    }
}

=pod

---++ ObjectMethod getWikiName($user) -> $wikiName

Get the wikiname to display for a canonical user identifier.

=cut

sub getWikiName {
    my ($this, $user_id ) = @_;
    ASSERT($user_id) if DEBUG;
	$this->ASSERT_IS_CANONICAL_USER_ID($user_id) if DEBUG;
	
	#only process canonical_ids that are for the currently selected mapper (if none specificed in the canon_id, assume TWikiUserMapping)
    if ( $user_id =~ /^($this->{mapping_id})/ || ($this->{mapping_id} eq 'TWikiUserMapping_')) {
        return $this->{mapping}->getWikiName($user_id);
    } else {
        #TODO: if no mapper is specified, return user_id - as its a pre canon-id UID, otherwise call it unknown
        return $user_id;
    }
}

=pod

---++ ObjectMethod webDotWikiName($user) -> $webDotWiki

Return the fully qualified wikiname of the user

=cut

sub webDotWikiName {
    my( $this, $user ) = @_;
 	$this->ASSERT_IS_CANONICAL_USER_ID($user) if DEBUG;
   return "$TWiki::cfg{UsersWebName}.".getWikiName( $this, $user );
}

=pod

---++ ObjectMethod userExists($login) -> $user

Determine if the user already exists or not. Return a canonical user
identifier if the user is known, or undef otherwise.

=cut

sub userExists {
    my( $this, $loginName ) = @_;
	$this->ASSERT_IS_USER_LOGIN_ID($loginName) if DEBUG;

    return $this->{mapping}->userExists( $loginName );
}

=pod

---++ ObjectMethod eachUser() -> $iterator

Get an iterator over the list of all the registered users *not* including
groups.

list of canonical_ids ???

Use it as follows:
<verbatim>
    my $iterator = $umm->eachUser();
    while ($iterator->hasNext()) {
        my $user = $iterator->next();
        ...
    }
</verbatim>

=cut

sub eachUser {
    return shift->{mapping}->eachUser( @_ );
}

=pod

---++ ObjectMethod eachGroup() -> $iterator

Get an iterator over the list of all the groups.

=cut

sub eachGroup {
    return shift->{mapping}->eachGroup( @_ );
}

=pod

---++ ObjectMethod eachGroupMember($group) -> $iterator

Return a iterator of user ids that are members of this group.
Should only be called on groups.

Note that groups may be defined recursively, so a group may contain other
groups. This method should *only* return users i.e. all contained groups
should be fully expanded.

=cut

sub eachGroupMember {
    return shift->{mapping}->eachGroupMember( @_ );
}

=pod

---++ ObjectMethod isGroup($user) -> boolean

Establish if a user refers to a group or not.

The default implementation is to check if the wikiname of the user ends with
'Group'. Subclasses may override this behaviour to provide alternative
interpretations. The $TWiki::cfg{SuperAdminGroup} is recognized as a
group no matter what it's name is.

QUESTION: is the $user parameter here a string, or a canonical_id??

=cut

sub isGroup {
    return shift->{mapping}->isGroup( @_ );
}

=pod

---++ ObjectMethod isInGroup( $user, $group ) -> $boolean

Test if user is in the given group.

=cut

sub isInGroup {
    return shift->{mapping}->isInGroup( @_ );
}

=pod

---++ ObjectMethod eachMembership($user) -> $iterator

Return an iterator over the groups that $user (an object)
is a member of.

=cut

sub eachMembership {
    return shift->{mapping}->eachMembership( @_ );
}

=pod

---++ ObjectMethod checkPassword( $userName, $passwordU ) -> $boolean

Finds if the password is valid for the given user.

Returns 1 on success, undef on failure.

=cut

sub checkPassword {
    my( $this, $userName, $pw ) = @_;
	$this->ASSERT_IS_USER_LOGIN_ID($userName) if DEBUG;
    return $this->{mapping}->checkPassword($userName, $pw);
}

=pod

---++ ObjectMethod setPassword( $user, $newPassU, $oldPassU ) -> $boolean

If the $oldPassU matches matches the user's password, then it will
replace it with $newPassU.

If $oldPassU is not correct and not 1, will return 0.

If $oldPassU is 1, will force the change irrespective of
the existing password, adding the user if necessary.

Otherwise returns 1 on success, undef on failure.

=cut

sub setPassword {
    my( $this, $user, $newPassU, $oldPassU ) = @_;
	$this->ASSERT_IS_CANONICAL_USER_ID($user) if DEBUG;
    return $this->{mapping}->setPassword($this->getLoginName( $user ), $newPassU, $oldPassU);
}

=pod

---++ ObjectMethod passwordError( ) -> $string

returns a string indicating the error that happened in the password handlers
TODO: these delayed error's should be replaced with Exceptions.

returns undef if no error

=cut

sub passwordError {
    my( $this ) = @_;
    return $this->{mapping}->passwordError();
}

=pod

---++ ObjectMethod removeUser( $user ) -> $boolean

Delete the users entry. Removes the user from the password
manager and user mapping manager. Does *not* remove their personal
topics, which may still be linked.

=cut

sub removeUser {
    my( $this, $user ) = @_;
	$this->ASSERT_IS_CANONICAL_USER_ID($user) if DEBUG;
    $this->{mapping}->removeUser( $user);
}

=pod

---++ ObjectMethod ASSERT_IS_CANONICAL_USER_ID( $user_id ) -> $boolean

used for debugging to ensure we are actually passing a canonical_id

=cut

sub ASSERT_IS_CANONICAL_USER_ID {
    my( $this, $user_id ) = @_;

#print STDERR "ASSERT_IS_CANONICAL_USER_ID: $user_id =~ /^(".$this->{mapping_id}."\n";

	#only process canonical_ids that are for the currently selected mapper (if none specificed in the canon_id, assume TWikiUserMapping)
    if ( $user_id =~ /^($this->{mapping_id})/ || ($this->{mapping_id} eq 'TWikiUserMapping_')) {
        $this->{mapping}->ASSERT_IS_CANONICAL_USER_ID($user_id);
    } else {
        #TODO: warn on not current mapper's Canonical_ID
    }
}

=pod

---++ ObjectMethod ASSERT_IS_USER_LOGIN_ID( $user_login ) -> $boolean

used for debugging to ensure we are actually passing a user login

=cut

sub ASSERT_IS_USER_LOGIN_ID {
    my( $this, $user_login ) = @_;
    $this->{mapping}->ASSERT_IS_USER_LOGIN_ID($user_login);
}


=pod

---++ ObjectMethod ASSERT_IS_USER_DISPLAY_NAME( $user_display ) -> $boolean

used for debugging to ensure we are actually passing a user display_name (commonly a WikiWord Name)

=cut

sub ASSERT_IS_USER_DISPLAY_NAME {
    my( $this, $user_display ) = @_;
    $this->{mapping}->ASSERT_IS_USER_DISPLAY_NAME($user_display);
}

=pod

---++ ObjectMethod ASSERT_IS_GROUP_DISPLAY_NAME( $group_display ) -> $boolean

used for debugging to ensure we are actually passing a group display_name (commonly a WikiWord Name)

#TODO: i fear we'll need to make a canonical_group_id too 

=cut

sub ASSERT_IS_GROUP_DISPLAY_NAME {
    my( $this, $group_display ) = @_;
    $this->{mapping}->ASSERT_IS_GROUP_DISPLAY_NAME($group_display);
}


1;
