# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# For licensing info read license.txt file in the TWiki root.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#

package TWiki::User;

use strict;
use Assert;
use TWiki;

=pod

---+ package TWiki::User

A User object is an internal representation of a user in the real world.
The object knows about users having login names, wiki names, personal
topics, and email addresses.

=cut

=pod

Groups are also handled here. A group is really a subclass of a user,
in that it is a user with a set of users within it.

The User package also provides methods for managing the passwords of the
user.

=cut

# global used by test harness to give predictable results
use vars qw( $password );

# STATIC function that returns a random password
sub randomPassword {
    return $password || int( rand(9999) );
}

=pod

---++ ClassMethod new( $users, $name, $wikiname )

Construct a new user object for the given login name, wiki name.

The wiki name can either be a wiki word or it can be a web-
qualified wiki word. If the wiki name is not web qualified, the
user is assumed to have their home topic in the
$TWiki::cfg{UsersWebName} web.

=cut

sub new {
    my( $class, $session, $name, $wikiname ) = @_;
    ASSERT(ref($session) eq "TWiki") if DEBUG;
    ASSERT($name) if DEBUG;
    ASSERT($wikiname) if DEBUG;

    my $this = bless( {}, $class );
    $this->{session} = $session;

    $this->{login} = $name;
    my( $web, $topic ) =
      $session->normalizeWebTopicName( "", $wikiname );
    $this->{web} = $web;
    $this->{wikiname} = $topic;
    return $this;
}

sub store { my $this = shift; return $this->{session}->{store}; }
sub users { my $this = shift; return $this->{session}->{users}; }

=pod

---++ ObjectMethod wikiName() -> $wikiName

Return the wikiname of the user (without the web!)

=cut

sub wikiName {
    my $this = shift;
    ASSERT(ref($this) eq "TWiki::User") if DEBUG;
    return $this->{wikiname};
}

=pod

---++ ObjectMethod webDotWikiName() -> $webDotWiki

Return the fully qualified wikiname of the user

=cut

sub webDotWikiName {
    my $this = shift;
    ASSERT(ref($this) eq "TWiki::User") if DEBUG;
    return "$this->{web}.$this->{wikiname}";
}

=pod

---++ ObjectMethod login() -> $loginName

Return the login name of the user

=cut

sub login {
    my $this = shift;
    ASSERT(ref($this) eq "TWiki::User") if DEBUG;
    return $this->{login};
}

=pod

---++ ObjectMethod web() -> $webName

Return the registration web of the user

=cut

sub web {
    my $this = shift;
    ASSERT(ref($this) eq "TWiki::User") if DEBUG;
    return $this->{web};
}

=pod

---++ ObjectMethod equals() -> $boolean

Test is this is the same user as another user object

=cut

sub equals {
    my( $this, $other ) = @_;
    ASSERT(ref($this) eq "TWiki::User") if DEBUG;
    ASSERT(ref($other) eq "TWiki::User") if DEBUG;

    return ( $this->{login} eq $other->{login} );
}

=pod

---++ ObjectMethod stringify() -> $string

Generate a string representation of this object, suitable for debugging

=cut

sub stringify {
    my $this = shift;
    ASSERT(ref($this) eq "TWiki::User") if DEBUG;

    return "$this->{login}/$this->{web}.$this->{wikiname}";
}

=pod

---++ ObjectMethod passwordExists( ) -> $boolean

Checks to see if there is an entry in the password system
Return "1" if true, "" if not

=cut

sub passwordExists {
    my $this  = shift;
    ASSERT(ref($this) eq "TWiki::User") if DEBUG;

    my $passwordHandler = $this->users()->_getPasswordHandler();
    return $passwordHandler->UserPasswordExists($this->{login});
}

=pod

---++ ObjectMethod checkPassword( $password ) -> $boolean

used to check the user's password

=$password= unencrypted password

=$success= "1" if success

TODO: need to improve the error mechanism so TWikiAdmins know what failed

=cut

sub checkPassword {
    my ( $this, $password ) = @_;
    ASSERT(ref($this) eq "TWiki::User") if DEBUG;

    my $passwordHandler = $this->users()->_getPasswordHandler();
    return $passwordHandler->CheckUserPasswd($this->{login}, $password);
}

=pod

---++ ObjectMethod removePassword() -> $boolean

Used to remove the user and password from the password system.
Returns true if success

=cut

# TODO: need to improve the error mechanism so TWikiAdmins know what failed
# SMELL - should this not also delete the user topic?
sub removePassword {
    my $this = shift;
    ASSERT(ref($this) eq "TWiki::User") if DEBUG;

    my $passwordHandler = $this->users()->_getPasswordHandler();
    return $passwordHandler->RemoveUser($this->{login});
}

=pod

---++ ObjectMethod changePassword( $user, $oldUserPassword, $newUserPassword ) -> $boolean

used to change the user's password
=$oldUserPassword= unencrypted password
=$newUserPassword= unencrypted password
"1" if success

=cut

# TODO: need to improve the error mechanism so TWikiAdmins know what failed |
sub changePassword {
    my ( $this, $oldUserPassword, $newUserPassword ) = @_;
    ASSERT(ref($this) eq "TWiki::User") if DEBUG;

    my $passwordHandler = $this->users()->_getPasswordHandler();
    return $passwordHandler->UpdateUserPassword($this->{login}, $oldUserPassword, $newUserPassword);
}

=pod

---++ ObjectMethod addPassword( $newPassword ) -> $boolean
creates a password entry
=$newUserPassword= unencrypted password
"1" if success
TODO: need to improve the error mechanism so TWikiAdmins know what failed

=cut

sub addPassword {
    my ( $this, $newUserPassword ) = @_;
    ASSERT(ref($this) eq "TWiki::User") if DEBUG;

    my $passwordHandler = $this->users()->_getPasswordHandler();
    return $passwordHandler->AddUserPassword($this->{login}, $newUserPassword);
}

=pod

---++ ObjectMethod resetPassword() -> $newPassword

Reset the users password, returning the new generated password.

=cut

sub resetPassword {
    my $this = shift;
    ASSERT(ref($this) eq "TWiki::User") if DEBUG;

    my $password = randomPassword();

    if( $this->passwordExists() ) {
        $this->removePassword();
    }

    $this->addPassword( $password );

    return $password;
}

sub isDefaultUser {
# email must be empty string
}

=pod

---++ ObjectMethod emails() -> @emailAddress

If this is a user, return their email addresses. If it is a group,
return the addresses of everyone in the group.

=cut

sub emails {
    my $this = shift;
    ASSERT(ref($this) eq "TWiki::User") if DEBUG;

    unless( defined $this->{emails} ) {
        if ( $this->isGroup() ) {
            foreach my $member ( @{$this->groupMembers()} ) {
                push( @{$this->{emails}}, $member->emails() );
            }
        } else {
            @{$this->{emails}} =
              $this->_getEmailsFromUserTopic();
        }
    }

    return @{$this->{emails}};
}

sub _getEmailsFromUserTopic {
    my $this = shift;

    my ($meta, $text) =
      $this->store()->readTopic( undef,
                                 $this->{web}, $this->{wikiname}, undef );
    my @fieldValues;
    my $entry = $meta->get("FIELD", "Email");
    if ($entry) {
        push(@fieldValues, $entry->{value});
    } else {
        foreach my $l (split ( /\r?\n/, $text  )) {
            if ($l =~ /^\s+\*\s+E-?mail:\s+([\w\-\.\+]+\@[\w\-\.\+]+)/i) {
                push @fieldValues, $1;
            }
        }
    }
    return @fieldValues;
}

=pod

---++ ObjectMethod isAdmin() -> $boolean

True if the user is an admin (is a member of the $TWiki::cfg{SuperAdminGroup})

=cut

sub isAdmin {
    my $this = shift;
    ASSERT(ref($this) eq "TWiki::User") if DEBUG;

    my $sag = $this->users()->findUser( $TWiki::cfg{SuperAdminGroup} );
    ASSERT(ref($sag) eq "TWiki::User") if DEBUG;
    return $this->isInList( $sag->groupMembers());
}

=pod

---++ ObjectMethod getGroups( ) -> @groups

Get a list of user objects for the groups a user is in

=cut

sub getGroups {
    my $this = shift;
    ASSERT(ref($this) eq "TWiki::User") if DEBUG;

    return @{$this->{groups}};
}

=pod

---++ ObjectMethod isInList( @list ) -> $boolean

Return true we are in the list of user objects passed.

=cut

sub isInList {
    my( $this, $userlist ) = @_;
    ASSERT(ref($this) eq "TWiki::User") if DEBUG;

    unless( ref( $userlist )) {
        # string parameter
        $userlist = $this->users()->expandUserList( $userlist );
    }
    my $user;
    foreach $user ( @$userlist ) {
        if( !$user->isGroup() ) {
            return 1 if $this->equals( $user );
        }
    }
    foreach $user ( @$userlist ) {
        if( $user->isGroup() ) {
            return 1 if $this->isInList( $user->groupMembers() );
        }
    }
    return 0;
}

=pod

---++ ObjectMethod isGroup() -> $boolean

Test if this is a group user or not

=cut

sub isGroup {
    my $this = shift;
    ASSERT(ref($this) eq "TWiki::User") if DEBUG;

    return $this->wikiName() =~ /Group$/;
}

=pod

---++ ObjectMethod groupMembers() -> @members

Return a list of members of this group. Should only be
called on groups.

=cut

sub groupMembers {
    my $this = shift;
    ASSERT(ref($this) eq "TWiki::User") if DEBUG;
    ASSERT( $this->isGroup()) if DEBUG;

    unless( defined $this->{members} ) {
        my $text =
          $this->store()->readTopicRaw( undef,
                                        $this->{web}, $this->{wikiname},
                                        undef );
        foreach( split( /\n/, $text ) ) {
            if( /^\s+\*\sSet\sGROUP\s*\=\s*(.+)$/ ) {
                # Note: if there are multiple GROUP assignments in the
                # topic, the last will be taken.
                $this->{members} = $this->users()->expandUserList( $1 );
            }
        }
        # backlink the user to the group
        foreach my $user ( @{$this->{members}} ) {
            push( @{$user->{groups}}, $this );
        }
    }

    return $this->{members};
}

1;
