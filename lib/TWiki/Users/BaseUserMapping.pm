# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007 Sven Dowideit, SvenDowideit@home.org.au
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

=begin twiki

---+ package TWiki::Users::BaseUserMapping

User mapping is the process by which TWiki maps from a username (a login name) to a wikiname and back. It is also where groups are maintained.

The BaseMapper provides the interface that other mappers should inherit from, and defines 3 users and 1 group

No registration - this is a read only usermapper

---+++ Users
   * TWikiAdmin - uses the password that was set in Configure (IF its not null)
   * TWikiGuest - password guest
   * UnknownUser
---+++ Users
   * $TWiki::cfg{SuperAdminGroup}
   
Their names and logins will probably become configurable, 

=cut

package TWiki::Users::BaseUserMapping;

use strict;
use Assert;
use Error qw( :try );
use TWiki::Time;
use TWiki::ListIterator;

# Constructs a new user mapping handler of this type, referring to $session
# for any required TWiki services.
sub new {
    my( $class, $session ) = @_;

    my $this = bless( {}, $class );
    $this->{session} = $session;

#set up our users
    $this->{L2U} = {admin=>'BaseUserMapping_333', $TWiki::cfg{DefaultUserLogin}=>'BaseUserMapping_666', unknown=>'BaseUserMapping_999'};
    $this->{U2L} = {'BaseUserMapping_333'=>'admin', 'BaseUserMapping_666'=>$TWiki::cfg{DefaultUserLogin}, 'BaseUserMapping_999'=>'unknown'};
    $this->{U2W} = {'BaseUserMapping_333'=>$TWiki::cfg{AdminUserWikiName}, 'BaseUserMapping_666'=>$TWiki::cfg{DefaultUserWikiName}, 'BaseUserMapping_999'=>'UnknownUser'};
    $this->{W2U} = {$TWiki::cfg{AdminUserWikiName}=>'BaseUserMapping_333', $TWiki::cfg{DefaultUserWikiName}=>'BaseUserMapping_666', UnknownUser=>'BaseUserMapping_999'};
    $this->{U2E} = {'BaseUserMapping_333'=>'not@home.org.au'};
    
    $this->{GROUPS} = {$TWiki::cfg{SuperAdminGroup}=>['BaseUserMapping_333']};

    return $this;
}

# Complete processing after the client's HTTP request has been responded
# to by breaking references (if any)
sub finish {
    my $this = shift;
    delete $this->{U2L};
    delete $this->{L2U};
    delete $this->{U2W};
    delete $this->{W2U};
    delete $this->{GROUPS};
}

#return 1 if the UserMapper supports registration (ie can create new users)
sub supportsRegistration {
    return; #NO, we don't
}

# Convert a login name to the corresponding canonical user name. The
# canonical name can be any string of 7-bit alphanumeric and underscore
# characters, and must correspond 1:1 to the login name.
sub login2canonical {
    my( $this, $login ) = @_;

#print STDERR "login2canonical($login) = ";
#print STDERR $this->{L2U}->{$login};    

    return $this->{L2U}{$login};
}

# See login2 canonical
sub canonical2login {
    my( $this, $user ) = @_;
    ASSERT($user) if DEBUG;
    
#print STDERR "login2canonical($user) = ";
#print STDERR $this->{U2L}->{$user};
    
    return $this->{U2L}{$user};
}

# Add a user to the persistant mapping that maps from usernames to wikinames
# and vice-versa. The default implementation uses a special topic called
# "TWikiUsers" in the users web. Subclasses will provide other implementations
# (usually stubs if they have other ways of mapping usernames to wikinames).
#
# Names must be acceptable to $TWiki::cfg{NameFilter}
#
# $login must *always* be specified. $wikiname may be undef, in which case
# the user mapper should make one up.
#
# This function must return a *canonical user id* that it uses to uniquely
# identify the user. This can be the login name, or the wikiname if they
# are all guaranteed unigue, or some other string consisting only of 7-bit
# alphanumerics and underscores.
#
# if you fail to create a new user (for eg your Mapper has read only access), 
#             throw Error::Simple(
#                'Failed to add user: '.$ph->error());
sub addUser {
    my ( $this, $login, $wikiname ) = @_;

    ASSERT($login) if DEBUG;

    throw Error::Simple(
          'user creation is not supported by the BaseUserMapper');
    return 0;
}

# Remove a user from the mapping
# Called by TWiki::Users
sub removeUser {
    # SMELL: currently a nop, needs someone to implement it
    throw Error::Simple(
          'user removal is not supported by the BaseUserMapper');
    return 0;    
}

# Map a canonical user name to a wikiname
sub getWikiName {
    my ($this, $user) = @_;
    
    if( $TWiki::cfg{Register}{AllowLoginName} ) {
#print STDERR "getWikiName($user) = ".$this->{U2W}->{$user};    
        return $this->{U2W}->{$user} || canonical2login( $this, $user );
    } else {
        # If the mapping isn't enabled there's no point in loading it
        return canonical2login( $this, $user );
    }
}

# Map a canonical user name to a login name
sub getLoginName {
    my ($this, $user) = @_;
    return canonical2login( $this, $user );
}

# Map a login name to the corresponding canonical user name. This is used for
# lookups, and should be as fast as possible. Returns undef if no such user
# exists. Called by TWiki::Users
sub lookupLoginName {
    my ($this, $login) = @_;

    return $this->{L2U}->{$login};
}

# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
sub eachUser {
    my( $this ) = @_;
    ASSERT($this->isa( 'TWiki::Users::BaseUserMapping')) if DEBUG;

    my @list = keys(%{$this->{U2W}});
    return new TWiki::ListIterator( \@list );
}

# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
sub eachGroupMember {
    my $this = shift;
    my $group = shift;
    ASSERT($this->isa( 'TWiki::Users::BaseUserMapping')) if DEBUG;

#TODO: implemend expanding of nested groups
    my $members = $this->{GROUPS}{$group};
#print STDERR "eachGroupMember($group): ".join(',', @{$members});

    return new TWiki::ListIterator( $members );
}

# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
sub isGroup {
    my ($this, $user) = @_;
#TODO: what happens to the code if we implement this using an iterator too?
    return grep(/$user/, $this->eachGroup());
}

# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
sub eachGroup {
    my ( $this ) = @_;
    my @groups = keys(%{$this->{GROUPS}});
    
#print STDERR "eachGroup = ".join(',', @groups);

    return new TWiki::ListIterator( \@groups );
}

# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
sub eachMembership {
    my ($this, $user) = @_;

    my $it = $this->eachGroup();
    $it->{filter} = sub {
        $this->isInGroup($user, $_[0]);
    };
    return $it;
}

# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
sub isInGroup {
    my( $this, $user, $group, $scanning ) = @_;
    ASSERT($user) if DEBUG;

    my @users;
    my $it = $this->eachGroupMember($group);
    while ($it->hasNext()) {
        my $u = $it->next();
#print STDERR "isInGroup($u)";
        next if $scanning->{$u};
        $scanning->{$u} = 1;
        return 1 if $u eq $user;
        if( $this->isGroup($u) ) {
            return 1 if $this->isInGroup( $user, $u, $scanning);
        }
    }
    return 0;
}

# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
# Only used if =passwordManager->isManagingEmails= = =false=.
sub getEmails {
    my( $this, $user ) = @_;

    return $this->{U2E}{$user};
}

# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
# Only used if =passwordManager->isManagingEmails= = =false=.
sub setEmails {
    my $this = shift;
    my $user = shift;

    throw Error::Simple(
          'setting emails is not supported by the BaseUserMapper');
    return 0;
}

# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
# Only used if =passwordManager->isManagingEmails= = =false=.
sub findUserByEmail {
    my( $this, $email ) = @_;

    throw Error::Simple(
          'IMPLEMENT ME BaseUserMapper');
    return $this->{_MAP_OF_EMAILS}->{$email};
}

# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
sub findUserByWikiName {
    my( $this, $wn ) = @_;
    my @users = ();

    if( $this->isGroup( $wn )) {
        push( @users, $wn);
    } elsif( $TWiki::cfg{Register}{AllowLoginName} ) {
        # Add additional mappings defined in TWikiUsers
        if( $this->{W2U}->{$wn} ) {
            push( @users, $this->{W2U}->{$wn} );
        } else {
            # Bloody compatibility!
            # The wikiname is always a registered user for the purposes of this
            # mapping. We have to do this because TWiki defines access controls
            # in terms of mapped users, and if a wikiname is *missing* from the
            # mapping there is "no such user".
            push( @users, login2canonical( $this, $wn ));
        }
    } else {
        # The wikiname is also the login name, so we can just convert
        # it to a canonical user id
        push( @users, login2canonical( $this, $wn ));
    }
    return \@users;
}



=pod

---++ ObjectMethod ASSERT_IS_CANONICAL_USER_ID( $user_id ) -> $boolean

used for debugging to ensure we are actually passing a canonical_id

=cut

sub ASSERT_IS_CANONICAL_USER_ID {
    my( $this, $user_id ) = @_;
#print STDERR "ASSERT_IS_CANONICAL_USER_ID($user_id)";
#    ASSERT($user_id =~/^UID$(\s+)UID$/) if DEBUG;
    ASSERT( $user_id =~/^BaseUserMapping_/ );	#refine with more specific regex

}

=pod

---++ ObjectMethod ASSERT_IS_USER_LOGIN_ID( $user_login ) -> $boolean

used for debugging to ensure we are actually passing a user login

=cut

sub ASSERT_IS_USER_LOGIN_ID {
    my( $this, $user_login ) = @_;
    
}


=pod

---++ ObjectMethod ASSERT_IS_USER_DISPLAY_NAME( $user_display ) -> $boolean

used for debugging to ensure we are actually passing a user display_name (commonly a WikiWord Name)

=cut

sub ASSERT_IS_USER_DISPLAY_NAME {
    my( $this, $user_display ) = @_;
    
}

=pod

---++ ObjectMethod ASSERT_IS_GROUP_DISPLAY_NAME( $group_display ) -> $boolean

used for debugging to ensure we are actually passing a group display_name (commonly a WikiWord Name)

#TODO: i fear we'll need to make a canonical_group_id too 

=cut

sub ASSERT_IS_GROUP_DISPLAY_NAME {
    my( $this, $group_display ) = @_;
    
}




1;
