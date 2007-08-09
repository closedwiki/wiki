# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution.
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

---+ package TWiki::UserMapping

This is a virtual base class (a.k.a an interface) for all user mappers. It is
*not* useable as a mapping in TWiki - use the BaseUserMapping for default
behaviour.

User mapping is the process by which TWiki maps from a username (a login name)
to a display name and back. It is also where groups are maintained.

See TWiki::Users::BaseUserMapping and TWiki::Users::TWikiUserMapping for
the default implementations of this interface.

If you want to write a user mapper, you will need to implement the methods
described in this class.

User mappings work by mapping both login names and display names to a
_canonical user id_. This user id is composed from a prefix that defines
the mapper in use (something like 'BaseUserMapping_' or 'LdapUserMapping_')
and a unique user id that the mapper uses to identify the user.

The null prefix is reserver for the TWikiUserMapping for compatibility
with old TWiki releases.

__Note:__ in all the following documentation, =$user= refers to a
*canonical user id*.

=cut

package TWiki::UserMapping;

use Assert;
use Error;

=pod

---++ PROTECTED ClassMethod new ($session, $mapping_id)

Construct a user mapping object, using the given mapping id.

=cut

sub new {
    my ($class, $session, $mid) = @_;
    my $this = bless( {
        mapping_id => $mid,
        session => $session,
    }, $class );
    return $this;
}

=begin twiki

---++ ObjectMethod finish()
Break circular references.

=cut

sub finish {
    my $this = shift;
    undef $this->{mapping_id};
    undef $this->{session};
}

=pod

---++ ObjectMethod loginTemplateName () -> $templateFile

Allows UserMappings to come with customised login screens - that should
preferably only over-ride the UI function

Default is "login"

=cut

sub loginTemplateName {
    return 'login';
}

=pod

---++ ObjectMethod supportsRegistration() -> $boolean

Return true if the UserMapper supports registration (ie can create new users)

Default is *false*

=cut

sub supportsRegistration {
    return 0; # NO, we don't
}

=pod

---++ ObjectMethod handlesUser ( $cUID, $login, $wikiname) -> $boolean

Called by the TWiki::Users object to determine which loaded mapping
to use for a given user (must be fast).

Default is *false*

=cut

sub handlesUser {
    return 0;
}

=pod

---++ ObjectMethod getCanonicalUserID ($login) -> cUID

Convert a login name to the corresponding canonical user name. The
canonical name can be any string of 7-bit alphanumeric and underscore
characters, and must correspond 1:1 to the login name.
(undef on failure)

Subclasses *must* implement this method.

=cut

sub getCanonicalUserID {
    ASSERT(0);
}

=pod

---++ ObjectMethod getLoginName ($cUID) -> login

Converts an internal cUID to that user's login
(undef on failure)

Subclasses *must* implement this method.

=cut

sub getLoginName {
    ASSERT(0);
}

=pod

---++ ObjectMethod addUser ($login, $wikiname, $password, $emails) -> cUID

Add a user to the persistant mapping that maps from usernames to wikinames
and vice-versa, via a *canonical user id* (cUID).

$login and $wikiname must be acceptable to $TWiki::cfg{NameFilter}.
$login must *always* be specified. $wikiname may be undef, in which case
the user mapper should make one up.

This function must return a canonical user id that it uses to uniquely
identify the user. This can be the login name, or the wikiname if they
are all guaranteed unigue, or some other string consisting only of 7-bit
alphanumerics and underscores.

If you fail to create a new user (for eg your Mapper has read only access),
<pre>
    throw Error::Simple('Failed to add user: '.$error);
</pre>
where $error is a descriptive string.

Throws an Error::Simple if user adding is not supported (the default).

=cut

sub addUser {
    throw Error::Simple('Failed to add user: adding users is not supported');
}

=pod

---++ ObjectMethod removeUser( $user ) -> $boolean

Delete the users entry from this mapper. Throws an Error::Simple if
user removal is not supported (the default).

=cut

sub removeUser {
    throw Error::Simple(
        'Failed to remove user: user removal is not supported');
}

=pod

---++ ObjectMethod getWikiName ($cUID) -> wikiname

Map a canonical user name to a wikiname.

Returns the $cUID by default.

=cut

sub getWikiName {
    my ($this, $cUID) = @_;
    return $cUID;
}

=pod

---++ ObjectMethod userExists($cUID) -> $boolean

Determine if the user already exists or not. Whether a user exists
or not is determined by the password manager.

Subclasses *must* implement this method.

=cut

sub userExists {
    ASSERT(0);
}

=pod

---++ ObjectMethod eachUser () -> listIterator of cUIDs

Called from TWiki::Users. See the documentation of the corresponding
method in that module for details.

Subclasses *must* implement this method.

=cut

sub eachUser {
    ASSERT(0);
}

=pod

---++ ObjectMethod eachGroupMember ($group) ->  TWiki::ListIterator of cUIDs

Called from TWiki::Users. See the documentation of the corresponding
method in that module for details.

Subclasses *must* implement this method.

=cut

sub eachGroupMember {
    ASSERT(0);
}

=pod

---++ ObjectMethod isGroup ($user) -> boolean

Called from TWiki::Users. See the documentation of the corresponding
method in that module for details.

Subclasses *must* implement this method.

=cut

sub isGroup {
    ASSERT(0);
}

=pod

---++ ObjectMethod eachGroup () -> ListIterator of groupnames

Called from TWiki::Users. See the documentation of the corresponding
method in that module for details.

Subclasses *must* implement this method.

=cut

sub eachGroup {
    ASSERT(0);
}

=pod

---++ ObjectMethod eachMembership($cUID) -> ListIterator of groups this user is in

Called from TWiki::Users. See the documentation of the corresponding
method in that module for details.

Subclasses *must* implement this method.

=cut

sub eachMembership {
    ASSERT(0);
}

=pod

---++ ObjectMethod isAdmin( $user ) -> $boolean

True if the user is an administrator. Default is *false*

=cut

sub isAdmin {
    return 0;
}

=pod

---++ ObjectMethod isInGroup ($user, $group, $scanning) -> bool

Called from TWiki::Users. See the documentation of the corresponding
method in that module for details.

Default is *false*

=cut

sub isInGroup {
    return 0;
}

=pod

---++ ObjectMethod findUserByEmail( $email ) -> \@users
   * =$email= - email address to look up
Return a list of canonical user names for the users that have this email
registered with the password manager or the user mapping manager.

Returns an empty list by default.

=cut

sub findUserByEmail {
    return [];
}

=pod

---++ ObjectMethod getEmails($user) -> @emailAddress

If this is a user, return their email addresses. If it is a group,
return the addresses of everyone in the group.

Duplicates should be removed from the list.

By default, returns the empty list.

=cut

sub getEmails {
    return ();
}

=pod

---++ ObjectMethod setEmails($user, @emails)

Set the email address(es) for the given user. Does nothing by default.

=cut

sub setEmails {
}

=pod

---++ ObjectMethod findUserByWikiName ($wikiname) -> list of cUIDs associated with that wikiname

Called from TWiki::Users. See the documentation of the corresponding
method in that module for details.

Subclasses *must* implement this method.

=cut

sub findUserByWikiName {
    ASSERT(0);
}

=pod

---++ ObjectMethod checkPassword( $userName, $passwordU ) -> $boolean

Finds if the password is valid for the given user.

Returns 1 on success, undef on failure.

Default behaviour is to return 1.

=cut

sub checkPassword {
    return 1;
}

=pod

---++ ObjectMethod setPassword( $user, $newPassU, $oldPassU ) -> $boolean

If the $oldPassU matches matches the user's password, then it will
replace it with $newPassU.

If $oldPassU is not correct and not 1, will return 0.

If $oldPassU is 1, will force the change irrespective of
the existing password, adding the user if necessary.

Otherwise returns 1 on success, undef on failure.

Default behaviour is to fail.

=cut

sub setPassword {
    return undef;
}

=pod

---++ ObjectMethod passwordError( ) -> $string

Returns a string indicating the error that happened in the password handlers
TODO: these delayed errors should be replaced with Exceptions.

returns undef if no error 9the default)

=cut

sub passwordError {
    return undef;
}

=pod

---++ ObjectMethod ASSERT_IS_CANONICAL_USER_ID( $user_id ) -> $boolean

Used for debugging to ensure we are actually passing a canonical_id

=cut

sub ASSERT_IS_CANONICAL_USER_ID {
#    my( $this, $user_id ) = @_;
#    print STDERR "ASSERT_IS_CANONICAL_USER_ID($user_id)";
#    ASSERT( $user_id =~/^$this->{mapping_id}/e );
}

=pod

---++ ObjectMethod ASSERT_IS_USER_LOGIN_ID( $user_login ) -> $boolean

Used for debugging to ensure we are actually passing a user login

=cut

sub ASSERT_IS_USER_LOGIN_ID {
}

=pod

---++ ObjectMethod ASSERT_IS_USER_DISPLAY_NAME( $user_display ) -> $boolean

Used for debugging to ensure we are actually passing a user display_name
(commonly a WikiWord Name)

Returns true by default.

=cut

sub ASSERT_IS_USER_DISPLAY_NAME {
}

1;
