# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007 Sven Dowideit, SvenDowideit@distributedINFORMATION.com
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

---+ package TWiki::Users::BaseUserMapping

User mapping is the process by which TWiki maps from a username (a login name)
to a display name and back. It is also where groups are maintained.

The BaseMapper provides support for a small number of predefined users.
No registration - this is a read only usermapper. It uses the mapper
prefix 'BaseUserMapping_'.

---++ Users
   * TWikiAdmin - uses the password that was set in Configure (IF its not null)
   * TWikiGuest
   * UnknownUser
   * TWikiContributor - 1 Jan 2005
   * TWikiRegistrationAgent - 1 Jan 2005

---+++ Groups
   * $TWiki::cfg{SuperAdminGroup}
   * TWikiBaseGroup

=cut

package TWiki::Users::BaseUserMapping;
use base 'TWiki::UserMapping';

use strict;
use Assert;
use Error;

=pod

---++ ClassMethod new ($session)

Construct the BaseUserMapping object

=cut

# Constructs a new user mapping handler of this type, referring to $session
# for any required TWiki services.
sub new {
    my( $class, $session ) = @_;

    my $this = $class->SUPER::new($session, 'BaseUserMapping_');

    # set up our users
    $this->{L2U} = {
        $TWiki::cfg{AdminUserLogin}=>$this->{mapping_id}.'333', 
        $TWiki::cfg{DefaultUserLogin}=>$this->{mapping_id}.'666', 
        unknown=>$this->{mapping_id}.'999',
        TWikiContributor=>$this->{mapping_id}.'111',
        TWikiRegistrationAgent=>$this->{mapping_id}.'222'
    };
    $this->{U2L} = {
        $this->{mapping_id}.'333'=>$TWiki::cfg{AdminUserLogin}, 
        $this->{mapping_id}.'666'=>$TWiki::cfg{DefaultUserLogin}, 
        $this->{mapping_id}.'999'=>'unknown',
        $this->{mapping_id}.'111'=>'TWikiContributor',
        $this->{mapping_id}.'222'=>'TWikiRegistrationAgent'
    };
    $this->{U2W} = {
        $this->{mapping_id}.'333'=>$TWiki::cfg{AdminUserWikiName}, 
        $this->{mapping_id}.'666'=>$TWiki::cfg{DefaultUserWikiName}, 
        $this->{mapping_id}.'999'=>'UnknownUser',
        $this->{mapping_id}.'111'=>'TWikiContributor',
        $this->{mapping_id}.'222'=>'TWikiRegistrationAgent'
    };
    $this->{W2U} = {
        $TWiki::cfg{AdminUserWikiName}=>$this->{mapping_id}.'333', 
        $TWiki::cfg{DefaultUserWikiName}=>$this->{mapping_id}.'666', 
        UnknownUser=>$this->{mapping_id}.'999',
        TWikiContributor=>$this->{mapping_id}.'111',
        TWikiRegistrationAgent=>$this->{mapping_id}.'222'
    };
    $this->{U2E} = {$this->{mapping_id}.'333'=>$TWiki::cfg{WebMasterEmail}};
    $this->{U2P} = {$this->{mapping_id}.'333'=>$TWiki::cfg{Password}};

    $this->{GROUPS} = {
        $TWiki::cfg{SuperAdminGroup} => [$this->{mapping_id}.'333'],
        TWikiBaseGroup => [$this->{mapping_id}.'333',
                           $this->{mapping_id}.'666',
                           $this->{mapping_id}.'999',
                           $this->{mapping_id}.'111',
                           $this->{mapping_id}.'222'],
    };

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
    undef $this->{U2L};
    undef $this->{U2W};
    undef $this->{U2P};
    undef $this->{U2E};
    undef $this->{L2U};
    undef $this->{W2U};
    undef $this->{GROUPS};
    $this->SUPER::finish();
}

=pod

---++ ObjectMethod loginTemplateName () -> templateFile

allows UserMappings to come with customised login screens - that should preffereably only over-ride the UI function

=cut

sub loginTemplateName {
    return 'login.sudo';
}



=pod

---++ ObjectMethod handlesUser ( $cUID, $login, $wikiname) -> $boolean

Called by the TWiki::User object to determine which loaded mapping to use
for a given user (must be fast). In the BaseUserMapping case, we know all
the details of the users we specialise in.

=cut

sub handlesUser {
    my ($this, $cUID, $login, $wikiname) = @_;

    return 1 if (defined($cUID) && defined($this->{U2L}{$cUID}));
    return 1 if (defined($login) && defined($this->{L2U}{$login}));
    return 1 if (defined($wikiname) && defined($this->{W2U}{$wikiname}));

    return 0;
}


=pod

---++ ObjectMethod getCanonicalUserID ($login) -> cUID

Convert a login name to the corresponding canonical user name. The
canonical name can be any string of 7-bit alphanumeric and underscore
characters, and must correspond 1:1 to the login name.
(undef on failure)

=cut

sub getCanonicalUserID {
    my( $this, $login ) = @_;

    my $cUID;
    $this->ASSERT_IS_USER_LOGIN_ID($login) if DEBUG;
    $cUID = $this->{L2U}{$login};

    #alternative impl - slower, but more re-useable
    #my @list = findUserByWikiName($this, $login);
    #$cUID = shift @list;

    return $cUID;
}


=pod

---++ ObjectMethod getLoginName ($cUID) -> login

converts an internal cUID to that user's login
(undef on failure)

=cut

sub getLoginName {
    my( $this, $user ) = @_;
    ASSERT($user) if DEBUG;

    #print STDERR "getCanonicalUserID($user) = $this->{U2L}->{$user}\n";

    return $this->{U2L}{$user};
}

=pod

---++ ObjectMethod getWikiName ($cUID) -> wikiname

# Map a canonical user name to a wikiname

=cut

sub getWikiName {
    my ($this, $cUID) = @_;
    
    return $this->{U2W}->{$cUID} || getLoginName( $this, $cUID );
}

=pod

---++ ObjectMethod userExists( $user ) -> $boolean

Determine if the user already exists or not.

=cut

sub userExists {
    my( $this, $cUID ) = @_;
    $this->ASSERT_IS_CANONICAL_USER_ID($cUID) if DEBUG;

    return $this->{U2L}{$cUID};
}

=pod

---++ ObjectMethod eachUser () -> listIterator of cUIDs

Called from TWiki::Users. See the documentation of the corresponding
method in that module for details.

=cut

sub eachUser {
    my( $this ) = @_;

    my @list = keys(%{$this->{U2W}});
    require TWiki::ListIterator;
    return new TWiki::ListIterator( \@list );
}


=pod

---++ ObjectMethod eachGroupMember ($group) ->  listIterator of cUIDs

Called from TWiki::Users. See the documentation of the corresponding
method in that module for details.

The basemapper implementation assumes that there are no nested groups in the
basemapper.

=cut

sub eachGroupMember {
    my $this = shift;
    my $group = shift;

    my $members = $this->{GROUPS}{$group};
#print STDERR "eachGroupMember($group): ".join(',', @{$members});

    require TWiki::ListIterator;
    return new TWiki::ListIterator( $members );
}


=pod

---++ ObjectMethod isGroup ($user) -> boolean
TODO: what is $user - wikiname, UID ??
Called from TWiki::Users. See the documentation of the corresponding
method in that module for details.

=cut

sub isGroup {
    my ($this, $user) = @_;
#TODO: what happens to the code if we implement this using an iterator too?
    return grep(/$user/, $this->eachGroup());
}


=pod

---++ ObjectMethod eachGroup () -> ListIterator of groupnames

Called from TWiki::Users. See the documentation of the corresponding
method in that module for details.

=cut

sub eachGroup {
    my ( $this ) = @_;
    my @groups = keys(%{$this->{GROUPS}});

    require TWiki::ListIterator;
    return new TWiki::ListIterator( \@groups );
}


=pod

---++ ObjectMethod eachMembership ($cUID) -> ListIterator of groups this user is in

Called from TWiki::Users. See the documentation of the corresponding
method in that module for details.

=cut

sub eachMembership {
    my ($this, $cUID) = @_;

    my $it = $this->eachGroup();
    $it->{filter} = sub {
        $this->isInGroup($cUID, $_[0]);
    };
    return $it;
}

=pod

---++ ObjectMethod isAdmin( $cUID ) -> $boolean

True if the user is an admin
   * is a member of the $TWiki::cfg{SuperAdminGroup}

=cut

sub isAdmin {
    my( $this, $cUID ) = @_;
    my $isAdmin = 0;
    $this->ASSERT_IS_CANONICAL_USER_ID($cUID) if DEBUG;

    my $sag = $TWiki::cfg{SuperAdminGroup};
    $isAdmin = $this->isInGroup( $cUID, $sag );

    return $isAdmin;
}


=pod

---++ ObjectMethod isInGroup ($user, $group, $scanning) -> bool

Called from TWiki::Users. See the documentation of the corresponding
method in that module for details.

=cut

sub isInGroup {
    my( $this, $user, $group, $scanning ) = @_;
    ASSERT($user) if DEBUG;

    my @users;
    my $it = $this->eachGroupMember($group);
    while ($it->hasNext()) {
        my $u = $it->next();
        next if $scanning->{$u};
        $scanning->{$u} = 1;
        return 1 if $u eq $user;
        if( $this->isGroup($u) ) {
            return 1 if $this->isInGroup( $user, $u, $scanning);
        }
    }
    return 0;
}

=pod

---++ ObjectMethod getEmails($user) -> @emailAddress

If this is a user, return their email addresses. If it is a group,
return the addresses of everyone in the group.

=cut

sub getEmails {
    my( $this, $user ) = @_;

    return $this->{U2E}{$user} || ();
}

=pod

---++ ObjectMethod findUserByWikiName ($wikiname) -> list of cUIDs associated with that wikiname

Called from TWiki::Users. See the documentation of the corresponding
method in that module for details.

=cut

sub findUserByWikiName {
    my( $this, $wn ) = @_;
    my @users = ();

    if( $this->isGroup( $wn )) {
        push( @users, $wn);
    } else {
        # Add additional mappings defined in TWikiUsers
        if( $this->{W2U}->{$wn} ) {
            push( @users, $this->{W2U}->{$wn} );
        } else {
            # Bloody compatibility!
            # The wikiname is always a registered user for the purposes of this
            # mapping. We have to do this because TWiki defines access controls
            # in terms of mapped users, and if a wikiname is *missing* from the
            # mapping there is "no such user".
            push( @users, getCanonicalUserID( $this, $wn ));
        }
#    } else {
        # The wikiname is also the login name, so we can just convert
        # it to a canonical user id
#        push( @users, getCanonicalUserID( $this, $wn ));
    }
    return \@users;
}

=pod

---++ ObjectMethod checkPassword( $userName, $passwordU ) -> $boolean

Finds if the password is valid for the given user.

Returns 1 on success, undef on failure.

=cut

sub checkPassword {
    my( $this, $login, $pass ) = @_;

    $this->ASSERT_IS_USER_LOGIN_ID($login) if DEBUG;
    my $cUID = getCanonicalUserID( $this, $login );
    return unless ($cUID);  #user not found

    my $hash = $this->{U2P}->{$cUID};
    if ($hash && (crypt($pass, $hash) eq $hash)) {
        return 1;   #yay, you've passed
    }
    #be a little more helpful to the admin
    if (($cUID eq $this->{mapping_id}.'333') && (!$hash)) {
        $this->{error} = 'To login as '.$login.', you must set {Password} in configure';
    }
    return 0;
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
    throw Error::Simple(
          'cannot change user passwords using TWiki::BaseUserMapping');
}

=pod

---++ ObjectMethod passwordError( ) -> $string

returns a string indicating the error that happened in the password handlers
TODO: these delayed error's should be replaced with Exceptions.

returns undef if no error

=cut

sub passwordError {
    my $this = shift;

    return $this->{error};
}

1;
