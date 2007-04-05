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
just the login name, but it need not be. Some login names have characters that
are illegal in canonical user ids, which are constrained to 7-bit
alphanumerics and underscores.

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

    my $implPasswordManager = $TWiki::cfg{PasswordManager};
    $implPasswordManager = 'TWiki::Users::Password' if( $implPasswordManager eq 'none' );
    eval "use $implPasswordManager";
    die "Password Manager: $@" if $@;
    $this->{passwords} = $implPasswordManager->new( $session );

    my $implUserMappingManager = $TWiki::cfg{UserMappingManager};
    $implUserMappingManager = 'TWiki::Users::TWikiUserMapping'
      if( $implUserMappingManager eq 'none' );
    eval "use $implUserMappingManager";
    die "User Mapping Manager: $@" if $@;
    $this->{mapping} = $implUserMappingManager->new( $session );

    $this->{login} = {};
    $this->{CACHED} = 0;

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
    $this->{passwords}->finish();
    $this->{login}     =  {};
}

# Get a list of *canonical user ids* from a text string containing a
# list of user *wiki* names and *group ids*.
sub _expandUserList {
    my( $this, $names, $expand ) = @_;
    ASSERT($this->isa( 'TWiki::Users')) if DEBUG;

    $names ||= '';
    # comma delimited list of users or groups
    # i.e.: "%MAINWEB%.UserA, UserB, Main.UserC  # something else"
    $names =~ s/(<[^>]*>)//go;     # Remove HTML tags

    my @l;
    foreach my $ident ( split( /[\,\s]+/, $names )) {
        $ident =~ s/^.*\.//;
        next unless $ident;
        push( @l, @{$this->{mapping}->findUserByWikiName( $ident )} );
    }
    return \@l;
}

=pod

---++ ObjectMethod findUserByWikiName( $wn ) -> \@users
   * =$wn= - wikiname to look up
Return a list of users for the users that have this wikiname. Since a single
wikiname might be used by multiple login ids, we need a list.

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
Return a list of users for the users that have this email registered
with the password manager or the user mapping manager.

The password manager is asked first for whether it maps emails.
If it doesn't, then the user mapping manager is asked instead.

=cut

sub findUserByEmail {
    my( $this, $email ) = @_;
    ASSERT($email) if DEBUG;
    my @users;
    my $um = $this->{mapping};
    my $logins = $this->{passwords}->findUserByEmail( $email );
    if ($logins) {
        foreach my $l ( @$logins ) {
            $l = $um->lookupLoginName( $l );
            push( @users, $l ) if $l;
        }
        return \@users;
    }
    # if the password manager didn't want to provide the service, ask
    # the user mapping manager
    push( @users, $um->findUserByEmail( $email ));
    return \@users;
}

=pod

---++ ObjectMethod setEmails($user, @emails)

Set the email address(es) for the given login name.
The password manager is tried first, and if it doesn't want to know the
user mapping manager is tried.

=cut

sub setEmails {
    my $this = shift;
    my $user = shift;

    return if ($this->{passwords}->setEmails( $user, @_ ));

    return $this->{mapping}->setEmails( $user, @_ );
}

=pod

---++ ObjectMethod isAdmin() -> $boolean

True if the user is an admin 
   * is $TWiki::cfg{SuperAdminGroup}
   * is a member of the $TWiki::cfg{SuperAdminGroup}

=cut

sub isAdmin {
    my( $this, $user ) = @_;
    my $isAdmin = 0;

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

Return true $user is in a list of user and group *wikinames*. Groups
are recursively evaluated.

$list is a string representation of a user list.

=cut

sub isInList {
    my( $this, $user, $userlist, $scanning ) = @_;
    $scanning = {} unless $scanning;
    unless( ref( $userlist )) {
        # string parameter
        $userlist = _expandUserList( $this, $userlist );
    }
    my $abuser;
    my $umm = $this->{mapping};
    foreach $abuser ( @$userlist ) {
        # don't check the same user twice
        next if $scanning->{$abuser};
        $scanning->{$abuser} = 1;

        return 1 if $user eq $abuser;
        if( $umm->isGroup($abuser) ) {
            return 1 if $umm->isInGroup($user, $abuser );
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
    my( $this, $user) = @_;

    return $user;
}

=pod

---++ ObjectMethod getEmails($user) -> @emailAddress

If this is a user, return their email addresses. If it is a group,
return the addresses of everyone in the group.

The password manager and user mapping manager are both consulted for emails
for each user (where they are actually found is implementation defined).

=cut

sub getEmails {
    my( $this, $user ) = @_;

    my $um = $this->{mapping};
    my @emails;
    if ( $um->isGroup($user) ) {
        my $it = $um->eachGroupMember($user);
        while( $it->hasNext() ) {
            push( @emails, $this->getEmails($it->next()) );
        }
    } else {
        my $passwordHandler = $this->{session}->{users}->{passwords};
        push( @emails,
              $passwordHandler->getEmails( $user ));
        push(@emails, $um->getEmails($user));
    }

    return @emails;
}

=pod

---++ ObjectMethod getWikiName($user) -> $wikiName

Get the wikiname to display for a canonical user identifier.

=cut

sub getWikiName {
    my ($this, $user ) = @_;
    ASSERT($user) if DEBUG;

    if ($TWiki::cfg{MapUserToWikiName}) {
        my $mapped = $this->{mapping}->lookupLoginName($user);
        return $mapped if $mapped;
    }
    return $user;
}

=pod

---++ ObjectMethod webDotWikiName($user) -> $webDotWiki

Return the fully qualified wikiname of the user

=cut

sub webDotWikiName {
    my( $this, $user ) = @_;
    return "$TWiki::cfg{UsersWebName}.".$this->getWikiName( $user );
}

=pod

---++ ObjectMethod userExists($login) -> $user

Determine if the user already exists or not. Return a canonical user
identifier if the user is known, or undef otherwise.

=cut

sub userExists {
    my( $this, $loginName ) = @_;

    if( $loginName eq $TWiki::cfg{DefaultUserLogin} ) {
        return $loginName;
    }

    # TWiki allows *groups* to log in
    if( $this->{mapping}->isGroup( $loginName )) {
        return $loginName;
    }

    # Look them up in the password manager.
    if( $this->{passwords}->fetchPass( $loginName )) {
        return $loginName;
    }

    return undef;
}

=pod

---++ ObjectMethod eachUser() -> $iterator

Get an iterator over the list of all the registered users *not* including
groups.

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

---++ ObjectMethod checkPassword( $user, $passwordU ) -> $boolean

Finds if the password is valid for the given user.

Returns 1 on success, undef on failure.

=cut

sub checkPassword {
    my( $this, $user, $pw ) = @_;
    return $this->{passwords}->checkPassword($this->getLoginName($user), $pw);
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
    return $this->{passwords}->setPassword(
        $this->getLoginName($user), $newPassU, $oldPassU);
}

=pod

---++ ObjectMethod passwordError( ) -> $string

returns a string indicating the error that happened in the password handlers
TODO: these delayed error's should be replaced with Exceptions.

returns undef if no error

=cut

sub passwordError {
    my( $this ) = @_;
    return $this->{passwords}->error();
}

=pod

---++ ObjectMethod removeUser( $user ) -> $boolean

Delete the users entry. Removes the user from the password
manager and user mapping manager. Does *not* remove their personal
topics, which may still be linked.

=cut

sub removeUser {
    my( $this, $user ) = @_;
    my $ln = $this->getLoginName($user);
    $this->{passwords}->removeUser($ln);
    $this->{mapping}->removeUserFromMapping($this->getWikiName( $user ), $ln);
}

1;
