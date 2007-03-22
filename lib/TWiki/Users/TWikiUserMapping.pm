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

---+ package TWiki::Users::TWikiUserMapping

User mapping is the process by which TWiki maps from a username (a login name) to a wikiname and back. It is also where groups are maintained.

By default TWiki maintains user topics and group topics in the %MAINWEB% that
define users and group. These topics are
   * !TWikiUsers - stores a mapping from usernames to TWiki names
   * !WikiName - for each user, stores info about the user
   * !GroupNameGroup - for each group, a topic ending with "Group" stores a list of users who are part of that group.

Many sites will want to override this behaviour, for example to get users and groups from a corporate database.

This class implements the basic TWiki behaviour using topics to store users,
but is also designed to be subclassed so that other services can be used.

Subclasses should be named 'XxxxUserMapping' so that configure can find them.

*All* methods in this class should be implemented by subclasses.

=cut

package TWiki::Users::TWikiUserMapping;

use strict;
use Assert;
use Error qw( :try );
use TWiki::User;
use TWiki::Time;
use TWiki::ListIterator;

=pod

---++ ClassMethod new( $session ) -> $object

Constructs a new user mapping handler of this type, referring to $session
for any required TWiki services.

=cut

sub new {
    my( $class, $session ) = @_;

    my $this = bless( {}, $class );
    $this->{session} = $session;

    %{$this->{U2W}} = ();
    %{$this->{W2U}} = ();

    return $this;
}

=pod

---++ ObjectMethod finish

Complete processing after the client's HTTP request has been responded
to.
   1 breaking circular references to allow garbage collection in persistent
     environments

=cut

sub finish {
    my $this = shift;
}

# callback for search function to collate results
sub _collateGroups {
    my $ref = shift;
    my $group = shift;
    return unless $group;
    my $groupObject = $ref->{users}->findUser( $group );
    push (@{$ref->{list}}, $groupObject) if $groupObject;
}

# get a list of groups defined in this TWiki
sub _getListOfGroups {
    my $this = shift;
    ASSERT(ref($this) eq 'TWiki::Users::TWikiUserMapping') if DEBUG;

    unless( $this->{groupsList} ) {
        my $users = $this->{session}->{users};
        $this->{groupsList} = [];

        $this->{session}->{search}->searchWeb
          (
              _callback     => \&_collateGroups,
              _cbdata       =>  { list => $this->{groupsList},
                                  users => $users },
              inline        => 1,
              search        => "Set GROUP =",
              web           => $TWiki::cfg{UsersWebName},
              topic         => "*Group",
              type          => 'regex',
              nosummary     => 'on',
              nosearch      => 'on',
              noheader      => 'on',
              nototal       => 'on',
              noempty       => 'on',
              format	     => '$web.$topic',
              separator     => '',
             );
    }
    return $this->{groupsList};
}

=pod

---++ ObjectMethod addUserToMapping( $user, $addingUser ) -> $topicName

Add a user to the persistant mapping that maps from usernames to wikinames
and vice-versa. The default implementation uses a special topic called
"TWikiUsers" in the users web. Subclasses will provide other implementations
(usually stubs if they have other ways of mapping usernames to wikinames).

Group names must be acceptable to $TWiki::cfg{NameFilter}

$user is the user being added. $addingUser is the user doing the adding.

=cut

sub addUserToMapping {
    my ( $this, $user, $me ) = @_;

    ASSERT($this->isa( 'TWiki::Users::TWikiUserMapping')) if DEBUG;
    ASSERT($user->isa( 'TWiki::User')) if DEBUG;
    ASSERT($me->isa( 'TWiki::User')) if DEBUG;

    my $store = $this->{session}->{store};
    my( $meta, $text ) =
      $store->readTopic( undef, $TWiki::cfg{UsersWebName},
                         $TWiki::cfg{UsersTopicName}, undef );
    my $result = '';
    my $entry = "   * ";
    $entry .= $user->web()."."
      unless $user->web() eq $TWiki::cfg{UsersWebName};
    $entry .= $user->wikiName()." - ";
    $entry .= $user->login() . " - " if $user->login();
    my $today = TWiki::Time::formatTime(time(), '$day $mon $year', 'gmtime');

    # add to the cache
    $this->{U2W}{$user->login()} = $user->{web} . "." . $user->wikiName();

    # add name alphabetically to list
    foreach my $line ( split( /\r?\n/, $text) ) {
        # TODO: I18N fix here once basic auth problem with 8-bit user names is
        # solved
        if ( $entry ) {
            my ( $web, $name, $odate ) = ( '', '', '' );
            if ( $line =~ /^\s+\*\s($TWiki::regex{webNameRegex}\.)?($TWiki::regex{wikiWordRegex})\s*(?:-\s*\w+\s*)?-\s*(.*)/ ) {
                $web = $1 || $TWiki::cfg{UsersWebName};
                $name = $2;
                $odate = $3;
            } elsif ( $line =~ /^\s+\*\s([A-Z]) - / ) {
                #	* A - <a name="A">- - - -</a>^M
                $name = $1;
            }
            if( $name && ( $user->wikiName() le $name ) ) {
                # found alphabetical position
                if( $user->wikiName() eq $name ) {
                    # adjusting existing user - keep original registration date
                    $entry .= $odate;
                } else {
                    $entry .= $today."\n".$line;
                }
                # don't adjust if unchanged
                return $TWiki::cfg{UsersTopicName} if( $entry eq $line );
                $line = $entry;
                $entry = '';
            }
        }

        $result .= $line."\n";
    }
    if( $entry ) {
        # brand new file - add to end
        $result .= "$entry$today\n";
    }
    $store->saveTopic( $me, $TWiki::cfg{UsersWebName},
                       $TWiki::cfg{UsersTopicName},
                       $result, $meta );

    return $TWiki::cfg{UsersTopicName};
}

=pod

---++ ObjectMethod lookupLoginName($username) -> $wikiName

Map a username to the corresponding wikiname. This is used for lookups during
user resolution, and should be as fast as possible.

=cut

sub lookupLoginName {
    my ($this, $loginUser) = @_;

    $this->_loadMapping();
    return $this->{U2W}{$loginUser};
}

=pod

---++ Objectmethod lookupWikiName($wikiname) -> $username

Map a wikiname to the corresponding username. This is used for lookups during
user resolution, and should be as fast as possible.

=cut

sub lookupWikiName {
    my ($this, $wikiName) = @_;

    $this->_loadMapping();
    return $this->{W2U}{$wikiName};
}

=pod

---++ ObjectMethod eachUser() -> $iterator

Get an iterator over the list of all the registered users *not* including
groups. The iterator will return each user object.

Use it as follows:
<verbatim>
    my $iterator = $umm->eachUser();
    while ($it->hasNext()) {
        my $user = $it->next();
        ...
    }
</verbatim>

=cut

sub eachUser {
    my( $this ) = @_;
    ASSERT($this->isa( 'TWiki::Users::TWikiUserMapping')) if DEBUG;

    $this->_loadMapping();
    my $users = $this->{session}->{users};
    my @list = map { $users->findUser($_) } keys(%{$this->{W2U}});
    return new TWiki::ListIterator( \@list );
}

=pod

---++ ObjectMethod eachGroup() -> $iterator

Get an iterator over the list of all the groups. The iterator will return
each group user object.

=cut

sub eachGroup {
    my ( $this ) = @_;
    $this->_getListOfGroups();
    return new TWiki::ListIterator( \@{$this->{groupsList}} );
}

# Build hash to translate between username (e.g. jsmith)
# and WikiName (e.g. Main.JaneSmith).
sub _loadMapping {
    my $this = shift;

    return if $this->{CACHED};
    $this->{CACHED} = 1;

    my $store = $this->{session}->{store};
    if( $store->topicExists($TWiki::cfg{UsersWebName},
                            $TWiki::cfg{UsersTopicName} )) {
        my $text = $store->readTopicRaw( undef,
                                      $TWiki::cfg{UsersWebName},
                                      $TWiki::cfg{UsersTopicName},
                                      undef );
        # Get the WikiNames and userids, and build hashes in both directions
        # This matches:
        #   * TWikiGuest - guest - 10 Mar 2005
        #   * TWikiGuest - 10 Mar 2005
        $text =~ s/^\s*\* ($TWiki::regex{webNameRegex}\.)?($TWiki::regex{wikiWordRegex})\s*(?:-\s*(\S+)\s*)?-.*$/$this->_cacheUser($1,$2,$3)/gome;
    } else {
        # If there is no mapping topic, then
        # map only guest to TWikiGuest.
        $this->_cacheUser(undef, $TWiki::cfg{DefaultUserWikiName},
                          $TWiki::cfg{DefaultUserLogin});
    }
}

sub _cacheUser {
    my($this, $web, $wUser, $lUser) = @_;
    $web ||= $TWiki::cfg{UsersWebName};
    $lUser ||= $wUser;	# userid
    # FIXME: Should filter in for security...
    # SMELL: filter prevents use of password managers with wierd usernames,
    # like the DOMAIN\username used in the swamp of despair.
    $lUser =~ s/$TWiki::cfg{NameFilter}//go;
    my $wwn = $web.'.'.$wUser;
    $this->{U2W}{$lUser} = $wwn;
    $this->{W2U}{$wwn} = $lUser;
}

=pod

---++ ObjectMethod eachGroupMember($group) -> $iterator

Return a iterator of user objects that are members of this group.
Should only be called on groups.

Note that groups may be defined recursively, so a group may contain other
groups. This method should *only* return users i.e. all contained groups
should be fully expanded.

=cut

sub eachGroupMember {
    my $this = shift;
    my $group = shift;
    ASSERT($this->isa( 'TWiki::Users::TWikiUserMapping')) if DEBUG;
    my $store = $this->{session}->{store};

    if( !defined $group->{members} &&
          $store->topicExists( $group->{web}, $group->{wikiname} )) {
        my $text =
          $store->readTopicRaw( undef,
                                $group->{web}, $group->{wikiname},
                                undef );
        foreach( split( /\r?\n/, $text ) ) {
            if( /$TWiki::regex{setRegex}GROUP\s*=\s*(.+)$/ ) {
                next unless( $1 eq 'Set' );
                # Note: if there are multiple GROUP assignments in the
                # topic, only the last will be taken.
                $group->{members} = 
                  $this->{session}->{users}->expandUserList( $2 );
            }
        }
        # backlink the user to the group
        foreach my $user ( @{$group->{members}} ) {
            push( @{$user->{groups}}, $group );
        }
    }

    return new TWiki::ListIterator( \@{$group->{members}} );
}

=pod

---++ ObjectMethod isGroup($user) -> boolean

Establish if a user object refers to a user group or not.

The default implementation is to check if the wikiname of the user ends with
'Group'. Subclasses may override this behaviour to provide alternative
interpretations. The $TWiki::cfg{SuperAdminGroup} is recognized as a
group no matter what it's name is.

=cut

sub isGroup {
    my ($this, $user) = @_;
    ASSERT($user->isa( 'TWiki::User')) if DEBUG;

    return $user->wikiName() =~ /Group$/;
}

=pod

---++ ObjectMethod eachMembership($user) -> $iterator

Return an iterator over the user objects of the groups that $user (an object)
is a member of.

=cut

sub eachMembership {
    my ($this, $user) = @_;
    my @groups = ();

    $this->_getListOfGroups();
    my $it = new TWiki::ListIterator( \@{$this->{groupsList}} );
    $it->{filter} = sub { $this->isInGroup($user, $_[0]) };
    return $it;
}

=pod

---++ ObjectMethod isInGroup( $user, $group ) -> $boolean

Test if user is in the given group. Default implementation loads
the group and checks the members.

=cut

sub isInGroup {
    my( $this, $user, $group, $scanning ) = @_;
    ASSERT(ref($group) eq 'TWiki::User') if DEBUG;
    ASSERT($group->isGroup()) if DEBUG;

    my @users;
    my $it = $group->eachGroupMember();
    while ($it->hasNext()) {
        my $u = $it->next();
        next if $scanning->{$u};
        $scanning->{$u} = 1;
        return 1 if $u->equals($user);
        if( $u->isGroup() ) {
            return 1 if $this->isInGroup( $user, $u, $scanning);
        }
    }
    return 0;
}

1;
