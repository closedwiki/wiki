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
use TWiki::Time;
use TWiki::ListIterator;

# Constructs a new user mapping handler of this type, referring to $session
# for any required TWiki services.
sub new {
    my( $class, $session ) = @_;

    my $this = bless( {}, $class );
    $this->{session} = $session;

    #$this->{U2L} = {};
    $this->{L2U} = {};
    $this->{U2W} = {};
    $this->{W2U} = {};

    return $this;
}

# Complete processing after the client's HTTP request has been responded
# to by breaking references (if any)
sub finish {
    my $this = shift;
    #delete $this->{U2L};
    delete $this->{L2U};
    delete $this->{U2W};
    delete $this->{W2U};
}

# Convert a login name to the corresponding canonical user name. The
# canonical name can be any string of 7-bit alphanumeric and underscore
# characters, and must correspond 1:1 to the login name.
sub login2canonical {
    my( $this, $login ) = @_;

    use bytes;
    # use bytes to ignore character encoding
    $login =~ s/([^a-zA-Z0-9])/'_'.sprintf('%02d', ord($1))/ge;
    no bytes;
    # further uniquify the UID in test mode, to increase the fragility
    return "UID${login}UID" if DEBUG;
    return $login;
}

# See login2 canonical
sub canonical2login {
    my( $this, $user ) = @_;
    ASSERT($user) if DEBUG;
    $user =~ s/^UID// if DEBUG;
    $user =~ s/UID$// if DEBUG;
    use bytes;
    # use bytes to ignore character encoding
    $user =~ s/_(\d\d)/chr($1)/ge;
    no bytes;
    return $user;
}

# PRIVATE
sub _cacheUser {
    my($this, $wikiname, $login) = @_;
    ASSERT($wikiname) if DEBUG;

    $login ||= $wikiname;

    my $user = login2canonical( $this, $login );

    #$this->{U2L}->{$user}     = $login;
    $this->{U2W}->{$user}     = $wikiname;
    $this->{L2U}->{$login}    = $user;
    $this->{W2U}->{$wikiname} = $user;

    return $user;
}

# PRIVATE callback for search function to collate results
sub _collateGroups {
    my $ref = shift;
    my $group = shift;
    return unless $group;
    push (@{$ref->{list}}, $group);
}

# PRIVATE get a list of groups defined in this TWiki
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
              format	     => '$topic',
              separator     => '',
             );
    }
    return $this->{groupsList};
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
sub addUser {
    my ( $this, $login, $wikiname ) = @_;

    ASSERT($login) if DEBUG;

    # SMELL: really ought to be smarter about this e.g. make a wikiword
    $wikiname ||= $login;

    my $store = $this->{session}->{store};
    my( $meta, $text ) = $store->readTopic(
        undef, $TWiki::cfg{UsersWebName}, $TWiki::cfg{UsersTopicName}, undef );

    my $result = '';
    my $entry = "   * $wikiname - ";
    $entry .= $login . " - " if $login;
    my $today = TWiki::Time::formatTime(time(), '$day $mon $year', 'gmtime');

    # add to the mapping caches
    my $user = _cacheUser( $this, $wikiname, $login );

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
            if( $name && ( $wikiname le $name ) ) {
                # found alphabetical position
                if( $wikiname eq $name ) {
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
    $store->saveTopic( $TWiki::cfg{SuperAdminGroup},
                       $TWiki::cfg{UsersWebName},
                       $TWiki::cfg{UsersTopicName},
                       $result, $meta );

    return $user;
}

# Remove a user from the mapping
# Called by TWiki::Users
sub removeUser {
    # SMELL: currently a nop, needs someone to implement it
}

# Map a canonical user name to a wikiname
sub getWikiName {
    my ($this, $user) = @_;
    if( $TWiki::cfg{MapUserToWikiName} ) {
        _loadMapping( $this );
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

    _loadMapping( $this );
    return $this->{L2U}->{$login};
}

# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
sub eachUser {
    my( $this ) = @_;
    ASSERT($this->isa( 'TWiki::Users::TWikiUserMapping')) if DEBUG;

    _loadMapping( $this );
    my @list = keys(%{$this->{U2W}});
    return new TWiki::ListIterator( \@list );
}

# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
sub eachGroup {
    my ( $this ) = @_;
    _getListOfGroups( $this );
    return new TWiki::ListIterator( \@{$this->{groupsList}} );
}

# Build hash to translate between username (e.g. jsmith)
# and WikiName (e.g. Main.JaneSmith).
# PRIVATE subclasses should *not* implement this.
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
        $text =~ s/^\s*\* (?:$TWiki::regex{webNameRegex}\.)?($TWiki::regex{wikiWordRegex})\s*(?:-\s*(\S+)\s*)?-.*$/_cacheUser( $this, $1, $2)/gome;
    }
    # Always map the guest user (even though they may not be able to
    # log in, we still need them as a default).
    unless ($this->{L2U}->{$TWiki::cfg{DefaultUserLogin}}) {
        _cacheUser( $this, $TWiki::cfg{DefaultUserWikiName},
                    $TWiki::cfg{DefaultUserLogin});
    }
}

my %expanding;
# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
sub eachGroupMember {
    my $this = shift;
    my $group = shift;
    ASSERT($this->isa( 'TWiki::Users::TWikiUserMapping')) if DEBUG;
    my $store = $this->{session}->{store};
    my $users = $this->{session}->{users};

    my $members = [];

    if( !$expanding{$group} &&
          $store->topicExists( $TWiki::cfg{UsersWebName}, $group )) {

        $expanding{$group} = 1;
        my $text =
          $store->readTopicRaw( undef,
                                $TWiki::cfg{UsersWebName}, $group,
                                undef );

        foreach( split( /\r?\n/, $text ) ) {
            if( /$TWiki::regex{setRegex}GROUP\s*=\s*(.+)$/ ) {
                next unless( $1 eq 'Set' );
                # Note: if there are multiple GROUP assignments in the
                # topic, only the last will be taken.
                my $f = $2;
                $members = TWiki::Users::_expandUserList( $users, $f );
            }
        }
        delete $expanding{$group};
    }

    return new TWiki::ListIterator( $members );
}

# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
sub isGroup {
    my ($this, $user) = @_;

    # Groups have the same username as wikiname as canonical name
    return 1 if $user eq $TWiki::cfg{SuperAdminGroup};

    return $user =~ /Group$/;
}

# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
sub eachMembership {
    my ($this, $user) = @_;
    my @groups = ();

    _getListOfGroups( $this );
    my $it = new TWiki::ListIterator( \@{$this->{groupsList}} );
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
sub getEmails {
    my( $this, $user ) = @_;

    my ($meta, $text) =
      $this->{session}->{store}->readTopic(
          undef, $TWiki::cfg{UsersWebName},
          $this->{session}->{users}->getWikiName($user) );

    my @addresses;

    # Try the form first
    my $entry = $meta->get('FIELD', 'Email');
    if ($entry) {
        push( @addresses, split( /;/, $entry->{value} ) );
    } else {
        # Now try the topic text
        foreach my $l (split ( /\r?\n/, $text  )) {
            if ($l =~ /^\s+\*\s+E-?mail:\s*(.*)$/mi) {
                push @addresses, split( /;/, $1 );
            }
        }
    }

    return @addresses;
}

# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
sub setEmails {
    my $this = shift;
    my $user = shift;

    my $mails = join( ';', @_ );

    $user = $this->{session}->{users}->getWikiName( $user );

    my ($meta, $text) =
      $this->{session}->{store}->readTopic(
          undef, $TWiki::cfg{UsersWebName},
          $user);

    if ($meta->get('FORM')) {
        # use the form if there is one
        $meta->putKeyed( 'FIELD',
                         { name => 'Email',
                           value => $mails,
                           title => 'Email',
                           attributes=> 'h' } );
    } else {
        # otherwise use the topic text
        unless( $text =~ s/^(\s+\*\s+E-?mail:\s*).*$/$1$mails/mi ) {
            $text .= "\n   * Email: $mails\n";
        }
    }

    $this->{session}->{store}->saveTopic(
        $user, $TWiki::cfg{UsersWebName}, $user, $text, $meta );
}

# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
sub findUserByEmail {
    my( $this, $email ) = @_;

    unless( $this->{_MAP_OF_EMAILS} ) {
        $this->{_MAP_OF_EMAILS} = {};
        my $it = $this->eachUser();
        while( $it->hasNext() ) {
            my $uo = $it->next();
            map { push( @{$this->{_MAP_OF_EMAILS}->{$_}}, $uo); }
              $this->{session}->{users}->getEmails( $uo );
        }
    }
    return $this->{_MAP_OF_EMAILS}->{$email};
}

# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
sub findUserByWikiName {
    my( $this, $wn ) = @_;

    _loadMapping( $this );
    my @users = ();
    if( $this->{W2U}->{$wn} ) {
        push( @users, $this->{W2U}->{$wn} );
    }
    return \@users;
}

1;
