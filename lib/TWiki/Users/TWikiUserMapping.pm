# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 Sven Dowideit, SvenDowideit@home.org.au
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

Base class of all user handlers. Default behaviour is to use TWiki Topics for user and group info

The methods of this class should be overridded by subclasses that want
to implement other user mapping handling methods.

=cut

package TWiki::Users::TWikiUserMapping;

use strict;
use strict;
use Assert;
use TWiki::User;
use TWiki::Time;
use Error qw( :try );

=pod

---++ ClassMethod new( $session ) -> $object

Constructs a new password handler of this type, referring to $session
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


# callback for search function to collate results
sub _collateGroups {
    my $ref = shift;
    my $group = shift;
    push( @$ref, $group ) if $group;
}

# get a list of groups defined in this TWiki 
# TODO: i'm guessing a list of strings, Web.Topic even?
sub getListOfGroups {
    my $this = shift;
    ASSERT($this->isa( 'TWiki::Users::TWikiUserMapping')) if DEBUG;
    
    my @list;

    $this->{session}->{search}->searchWeb
      (
       _callback     => \&_collateGroups,
       _cbdata       => \@list,
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
       format	     => "\$web.\$topic",
       separator     => '',
      );

    return @list;
}

=pod

---++ ObjectMethod addUserToMapping( $user ) -> $topicName

Add a user to the persistant mapping that maps from usernames to wikinames
and vice-versa. The default implementation uses a special topic called
"TWikiUsers" in the users web. Subclasses will provide other implementations
(usually stubs if they have other ways of mapping usernames to wikinames).

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
    my $entry = "\t* ";
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


#API func to be used for User systems that are faster in single request mode
sub lookupLoginName {
    my ($this, $loginUser) = @_;

    $this->loadMapping();
    return $this->{U2W}{$loginUser};
}

#API func to be used for User systems that are faster in single request mode
sub lookupWikiName {
    my ($this, $wikiName) = @_;

    $this->loadMapping();
    return $this->{W2U}{$wikiName};
}

sub getListOfAllWikiNames {
    my ( $this ) = @_;
    ASSERT($this->isa( 'TWiki::Users::TWikiUserMapping')) if DEBUG;

    $this->loadMapping();
    return keys(%{$this->{W2U}});
}

# Build hash to translate between username (e.g. jsmith)
# and WikiName (e.g. Main.JaneSmith).
sub loadMapping {
    my $this = shift;
    ASSERT($this->isa( 'TWiki::Users::TWikiUserMapping')) if DEBUG;

    return if $this->{CACHED};
    $this->{CACHED} = 1;

    my $text;
    my $store = $this->{session}->{store};
    if( $TWiki::cfg{MapUserToWikiName} &&
       $store->topicExists($TWiki::cfg{UsersWebName},
                           $TWiki::cfg{UsersTopicName} )) {
        $text = $store->readTopicRaw( undef,
                                      $TWiki::cfg{UsersWebName},
                                      $TWiki::cfg{UsersTopicName},
                                      undef );
    } else {
        # fix for Codev.SecurityAlertGainAdminRightWithTWikiUsersMapping
        # map only guest to TWikiGuest. CODE_SMELL on localization
        $text = "\t* $TWiki::cfg{DefaultUserWikiName} - $TWiki::cfg{DefaultUserLogin} - 01 Apr 1970";
    }

    my $wUser;
    my $lUser;
    # Get the WikiName and userid, and build hashes in both directions
    # This matches:
    #   * TWikiGuest - guest - 10 Mar 2005
    #   * TWikiGuest - 10 Mar 2005
    $text =~ s/^\s*\* ($TWiki::regex{webNameRegex}\.)?(\w+)\s*(?:-\s*(\S+)\s*)?-\s*\d+ \w+ \d+\s*$/_cacheUser($this,$1,$2,$3)/gome;
}

sub _cacheUser {
    my($cacheHolder, $web, $wUser, $lUser) = @_;
    $web ||= $TWiki::cfg{UsersWebName};
    $lUser ||= $wUser;	# userid
    # FIXME: Should filter in for security...
    # SMELL: filter prevents use of password managers with wierd usernames,
    # like the DOMAIN\username used in the swamp of despair.
    $lUser =~ s/$TWiki::cfg{NameFilter}//go;
    my $wwn = $web.'.'.$wUser;
    $cacheHolder->{U2W}{$lUser} = $wwn;
    $cacheHolder->{W2U}{$wwn} = $lUser;
}

=pod

---++ ObjectMethod groupMembers($group) -> @members

Return a list of  user objects that are members of this group. Should only be
called on groups.

=cut

sub groupMembers {
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

    return $group->{members};
}

=pod

---++ ObjectMethod isGroup($user) -> boolean

Establish if a user object refers to a user group or not.

The default implementation is to check if the wikiname of the user ends with
'Group'. Subclasses may override this behaviour to provide alternative
intepretations. The SuperAdminGroup is recognized as a group no matter
what it's name is.

=cut

sub isGroup {
    my ($this, $user) = @_;
    ASSERT($user->isa( 'TWiki::User')) if DEBUG;

    return $user->wikiName() =~ /Group$/;
}

1;
