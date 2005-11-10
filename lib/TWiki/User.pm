# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
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

---++ ClassMethod new( $session, $loginname, $wikiname )

Construct a new user object for the given login name, wiki name.

The wiki name can either be a wiki word or it can be a web-
qualified wiki word. If the wiki name is not web qualified, the
user is assumed to have their home topic in the
$TWiki::cfg{UsersWebName} web.

=cut

sub new {
    my( $class, $session, $name, $wikiname ) = @_;
    ASSERT($session->isa( 'TWiki')) if DEBUG;
    ASSERT($name) if DEBUG;
    ASSERT($wikiname) if DEBUG;

    my $this = bless( {}, $class );
    $this->{session} = $session;

    $this->{login} = $name;
    my( $web, $topic ) =
      $session->normalizeWebTopicName( $TWiki::cfg{UsersWebName}, $wikiname );
    $this->{web} = $web;
    $this->{wikiname} = $topic;
    return $this;
}

=pod

---++ ObjectMethod wikiName() -> $wikiName

Return the wikiname of the user (without the web!)

=cut

sub wikiName {
    my $this = shift;
    ASSERT($this->isa( 'TWiki::User')) if DEBUG;
    return $this->{wikiname};
}

=pod

---++ ObjectMethod webDotWikiName() -> $webDotWiki

Return the fully qualified wikiname of the user

=cut

sub webDotWikiName {
    my $this = shift;
    ASSERT($this->isa( 'TWiki::User')) if DEBUG;
    return "$this->{web}.$this->{wikiname}";
}

=pod

---++ ObjectMethod login() -> $loginName

Return the login name of the user

=cut

sub login {
    my $this = shift;
    ASSERT($this->isa( 'TWiki::User')) if DEBUG;
    return $this->{login};
}

=pod

---++ ObjectMethod web() -> $webName

Return the registration web of the user

=cut

sub web {
    my $this = shift;
    ASSERT($this->isa( 'TWiki::User')) if DEBUG;
    return $this->{web};
}

=pod

---++ ObjectMethod equals() -> $boolean

Test is this is the same user as another user object

=cut

sub equals {
    my( $this, $other ) = @_;
    ASSERT($this->isa( 'TWiki::User')) if DEBUG;
    ASSERT($other->isa( 'TWiki::User')) if DEBUG;

    return ( $this->{login} eq $other->{login} );
}

=pod

---++ ObjectMethod stringify() -> $string

Generate a string representation of this object, suitable for debugging

=cut

sub stringify {
    my $this = shift;
    ASSERT($this->isa( 'TWiki::User')) if DEBUG;

    return "$this->{login}/$this->{web}.$this->{wikiname}";
}

=pod

---++ ObjectMethod passwordExists( ) -> $boolean

Checks to see if there is an entry in the password system
Return '1' if true, '' if not

=cut

sub passwordExists {
    my $this  = shift;
    ASSERT($this->isa( 'TWiki::User')) if DEBUG;

    my $passwordHandler = $this->{session}->{users}->{passwords};
    return $passwordHandler->fetchPass($this->{login});
}

=pod

---++ ObjectMethod checkPassword( $password ) -> $boolean

used to check the user's password

=$password= unencrypted password

=$success= '1' if success

TODO: need to improve the error mechanism so TWikiAdmins know what failed

=cut

sub checkPassword {
    my ( $this, $password ) = @_;
    ASSERT($this->isa( 'TWiki::User')) if DEBUG;

    my $passwordHandler = $this->{session}->{users}->{passwords};
    return $passwordHandler->checkPassword($this->{login}, $password);
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
    ASSERT($this->isa( 'TWiki::User')) if DEBUG;

    my $passwordHandler = $this->{session}->{users}->{passwords};
    return $passwordHandler->deleteUser( $this->{login} );
}

=pod

---++ ObjectMethod changePassword( $user, $oldUserPassword, $newUserPassword ) -> $boolean

used to change the user's password
=$oldUserPassword= unencrypted password
=$newUserPassword= unencrypted password
'1' if success

=cut

# TODO: need to improve the error mechanism so TWikiAdmins know what failed |
sub changePassword {
    my ( $this, $oldUserPassword, $newUserPassword ) = @_;
    ASSERT($this->isa( 'TWiki::User')) if DEBUG;
    ASSERT($newUserPassword) if DEBUG;

    my $passwordHandler = $this->{session}->{users}->{passwords};
    my $success = $passwordHandler->passwd($this->{login}, $newUserPassword, $oldUserPassword);
    if ($success) {return $success};

    die $passwordHandler->{error};
}

=pod

---++ ObjectMethod addPassword( $newPassword ) -> $boolean
creates a password entry
=$newUserPassword= unencrypted password
'1' if success
TODO: need to improve the error mechanism so TWikiAdmins know what failed

=cut

sub addPassword {
    my ( $this, $newUserPassword ) = @_;
    ASSERT($this->isa( 'TWiki::User')) if DEBUG;

    my $passwordHandler = $this->{session}->{users}->{passwords};
    return $passwordHandler->passwd($this->{login}, $newUserPassword);
}

=pod

---++ ObjectMethod resetPassword() -> $newPassword

Reset the users password, returning the new generated password.

=cut

sub resetPassword {
    my $this = shift;
    ASSERT($this->isa( 'TWiki::User')) if DEBUG;

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
    ASSERT($this->isa( 'TWiki::User')) if DEBUG;

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
    my $store = $this->{session}->{store};

    my ($meta, $text) =
      $store->readTopic( undef, $this->{web}, $this->{wikiname}, undef );
    my @fieldValues;
    my $entry = $meta->get('FIELD', 'Email');
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
    ASSERT($this->isa( 'TWiki::User')) if DEBUG;

    unless( $this->{isKnownAdmin} ) {
        my $sag = $this->{session}->{users}->findUser( $TWiki::cfg{SuperAdminGroup} );
        ASSERT($sag->isa( 'TWiki::User')) if DEBUG;
        $this->{isKnownAdmin} = $this->isInList( $sag->groupMembers());
    }
    return $this->{isKnownAdmin};
}

=pod

---++ ObjectMethod getGroups( ) -> @groups

Get a list of user objects for the groups a user is in

=cut

sub getGroups {
    my $this = shift;
    ASSERT($this->isa( 'TWiki::User')) if DEBUG;

    return @{$this->{groups}};
}

=pod

---++ ObjectMethod isInList( $list ) -> $boolean

Return true we are in the list of user objects passed.

$list is a string representation of a user list.

=cut

sub isInList {
    my( $this, $userlist, $scanning ) = @_;
    ASSERT($this->isa( 'TWiki::User')) if DEBUG;

    unless( ref( $userlist )) {
        # string parameter
        $userlist = $this->{session}->{users}->expandUserList( $userlist );
    }
    my $user;
    foreach $user ( @$userlist ) {
        if( !$user->isGroup() ) {
            return 1 if $this->equals( $user );
        }
    }
    foreach $user ( @$userlist ) {
        if( $user->isGroup() ) {
            $scanning = {} unless $scanning;
            next if $scanning->{$user};
            $scanning->{$user} = 1;
            return 1 if $this->isInList( $user->groupMembers(), $scanning );
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
    ASSERT($this->isa( 'TWiki::User')) if DEBUG;

    return $this->wikiName() =~ /Group$/;
}

=pod

---++ ObjectMethod groupMembers() -> @members

Return a list of members of this group. Should only be
called on groups.

=cut

sub groupMembers {
    my $this = shift;
    ASSERT($this->isa( 'TWiki::User')) if DEBUG;
    ASSERT( $this->isGroup()) if DEBUG;
    my $store = $this->{session}->{store};

    if( !defined $this->{members} &&
          $store->topicExists( $this->{web}, $this->{wikiname} )) {
        my $text =
          $store->readTopicRaw( undef,
                                $this->{web}, $this->{wikiname},
                                undef );
        foreach( split( /\r?\n/, $text ) ) {
            if( /$TWiki::regex{setRegex}GROUP\s*=\s*(.+)$/ ) {
                next unless( $1 eq 'Set' );
                # Note: if there are multiple GROUP assignments in the
                # topic, only the last will be taken.
                $this->{members} = 
                  $this->{session}->{users}->expandUserList( $2 );
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
