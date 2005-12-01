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

=pod

---+ package TWiki::Users
Singleton object that handles mapping of users to wikinames and
vice versa, and user authentication checking.

=cut

package TWiki::Users;

use strict;
use Assert;
use TWiki::User;
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

    my $impl = $TWiki::cfg{PasswordManager};
    $impl = 'TWiki::Users::Password' if( $impl eq 'none' );
    eval "use $impl";
    die "Password Manager: $@" if $@;
    $this->{passwords} = $impl->new( $session );

    $this->{CACHED} = 0;

    # create the guest user
    $this->createUser( $TWiki::cfg{DefaultUserLogin},
                       $TWiki::cfg{DefaultUserWikiName} );

    return $this;
}

# get a list of groups defined in this TWiki 
sub _getListOfGroups {
    my $this = shift;
    ASSERT($this->isa( 'TWiki::Users')) if DEBUG;

    my @list;
    $this->{session}->{search}->searchWeb
      (
       _callback     => \&_collateGroups,
       _cbdata       => \@list,
       inline        => 1,
       search        => "Set GROUP =",
       web           => 'all',
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

# callback for search function to collate results
sub _collateGroups {
    my $ref = shift;
    my $group = shift;
    push( @$ref, $group ) if $group;
}

# Get a list of user objects from a text string containing a
# list of user names. Used by User.pm
sub expandUserList {
    my( $this, $names, $expand ) = @_;
    ASSERT($this->isa( 'TWiki::Users')) if DEBUG;

    $names ||= '';
    # comma delimited list of users or groups
    # i.e.: "%MAINWEB%.UserA, UserB, Main.UserC  # something else"
    $names =~ s/(<[^>]*>)//go;     # Remove HTML tags
    # TODO: i18n fix for user name
    $names =~ s/\s*([a-zA-Z0-9_\.\,\s\%]*)\s*(.*)/$1/go; # Limit list

    my @l = map { $this->findUser( $_ ) } split( /[\,\s]+/, $names );
    return \@l;
}

=pod

---++ ObjectMethod findUser( $name [, $wikiname] [, $nocreate ] ) -> $userObject

   * =$name= - login name or wiki name
   * =$wikiname= - optional, wikiname for created user
   * =$nocreate= - optional, disable creation of user object for user not found in TWikiUsers

Find the user object corresponding to =$name=, which may be either a
login name or a wiki name. The name is looked up in the
TWikiUsers topic. If =$name= is found (either in the list
of login names or the list of wiki names) the corresponding
user object is returned. In this case =$wikiname= is ignored.

If they are not found, and =$nocreate= is true, then return undef.

If =$nocreate= is false, then a user object is returned even if
the user is not listed in TWikiUsers.

If =$nocreate= is false, and no =$wikiname= is given, then the
=$name= is used for both login name and wiki name.

If nocreate is off, then a default user will be created with their wikiname
set the same as their login name. This user/wiki name pair can be overridden
by a later createUser call when the correct wikiname is known, if necessary.

=cut

sub findUser {
    my( $this, $name, $wikiname, $dontCreate ) = @_;
    ASSERT($this->isa( 'TWiki::Users')) if DEBUG;
    $name ||= $TWiki::cfg{DefaultUserLogin};
    my $object;

    #$this->{session}->writeDebug("Looking for $name / $wikiname / $dontCreate");

    # is it a cached login name?
    $object = $this->{login}{$name};
    return $object if $object;

    # remove pointless tag; we'll be looking there anyway
    $name =~ s/^%MAINWEB%.//;

    if( $name =~ m/^$TWiki::regex{webNameRegex}\.$TWiki::regex{wikiWordRegex}$/o ) {
        # may be web.wikiname; try the cache
        $object = $this->{wikiname}{$name};
        return $object if $object;
    }

    # prepend the mainweb and try again in the cache
    if( $name =~ /^$TWiki::regex{wikiWordRegex}$/ ) {
        $object = $this->{wikiname}{"$TWiki::cfg{UsersWebName}.$name"};
        return $object if $object;
    }

    # not cached

    # if no wikiname is given, try and recover it from
    # TWikiUsers
    unless( $wikiname ) {
        $wikiname = $this->lookupLoginName( $name );
    }

    if( !$wikiname &&
        $name =~ m/^($TWiki::regex{webNameRegex}\.)?$TWiki::regex{wikiWordRegex}$/o ) {
        my $t = $name;
        $t = "$TWiki::cfg{UsersWebName}.$t" unless $1;
        # not in TWiki users as a login name; see if it is
        # a WikiName
        my $lUser = $this->lookupWikiName( $t );
        if( $lUser ) {
            # it's a wikiname
            $name = $lUser;
            $wikiname = $t;
        }
    }

    # if we haven't matched a wikiname yet and we've been told
    # not to create, then abandon ship
    return undef if ( !$wikiname && $dontCreate );

    unless( $wikiname ) {
        # default to wikiname being the same as name.
        # Commented out because this warning is too common, and tends to
        # flood the logs.
        # $this->{session}->writeWarning("$name does not exist in TWikiUsers - is this a bogus user?") unless( $name =~ /Group$/ );
        $wikiname = $name;
    }

    return $this->createUser( $name, $wikiname );
}

=pod

---++ ObjectMethod createUser( $login, $wikiname ) -> $userobject
Create a user, and insert them in the maps (overwriting any current entry).
Use this instead of findUser when you want to be sure you are not going to
pick up any default user created by findUser. All parameters are required.

=cut

sub createUser {
    my( $this, $name, $wikiname ) = @_;

    my $object = new TWiki::User( $this->{session}, $name, $wikiname );
    $this->{login}{$name} = $object;
    $this->{wikiname}{$object->webDotWikiName()} = $object;

    return $object;
}

=pod

---++ ObjectMethod addUserToTWikiUsersTopic( $user ) -> $topicName

Add a user to the TWikiUsers topic. This is a topic that
maps from usernames to wikinames. It is maintained by
Register.pm, or manually outside TWiki.

=cut

sub addUserToTWikiUsersTopic {
    my ( $this, $user, $me ) = @_;

    ASSERT($this->isa( 'TWiki::Users')) if DEBUG;
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

# Build hash to translate between username (e.g. jsmith)
# and WikiName (e.g. Main.JaneSmith).  Only used for sites where
# authentication is managed by external Apache configuration, instead of
# via TWiki's .htpasswd mechanism.
sub _cacheTWikiUsersTopic {
    my $this = shift;
    ASSERT($this->isa( 'TWiki::Users')) if DEBUG;

    return if $this->{CACHED};
    $this->{CACHED} = 1;

    %{$this->{U2W}} = ();
    %{$this->{W2U}} = ();
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
    while( $text =~ s/^\s*\* ($TWiki::regex{webNameRegex}\.)?(\w+)\s*(?:-\s*(\S+)\s*)?-\s*\d+ \w+ \d+\s*$//om ) {
        my $web = $1 || $TWiki::cfg{UsersWebName};
        $wUser = $2;	# WikiName
        $lUser = $3 || $wUser;	# userid
        $lUser =~ s/$TWiki::cfg{NameFilter}//go;	# FIXME: Should filter in for security...
        my $wwn = $web.'.'.$wUser;
        $this->{U2W}{$lUser} = $wwn;
        $this->{W2U}{$wwn} = $lUser;
    }
}

=pod

---++ ObjectMethod initializeRemoteUser( $remoteUser ) -> $loginName

Return value: $remoteUser

Acts as a filter for $remoteUser.  If set, $remoteUser is filtered for
insecure characters and untainted.

If not user is passed, the remote user defaults to $cfg{DefaultUserLogin}
(usually 'guest').

If we got here via an authentication status failure, then the remote user
is set to blank, effectively signalling an illegal access.

If no remote user name was passed in, the user defaults to
$cfg{DefaultUserLogin}.

=cut

sub initializeRemoteUser {
    my( $this, $theRemoteUser ) = @_;

    my $remoteUser = $theRemoteUser || $TWiki::cfg{DefaultUserLogin};
    $remoteUser =~ s/$TWiki::cfg{NameFilter}//go;
    $remoteUser = TWiki::Sandbox::untaintUnchecked( $remoteUser );

    return $remoteUser;
}

# Translates username (e.g. jsmith) to Web.WikiName
# (e.g. Main.JaneSmith) by lookup in TWikiUsers.
sub lookupLoginName {
    my( $this, $loginUser ) = @_;

    return undef unless $loginUser;

    $this->_cacheTWikiUsersTopic();

    $loginUser =~ s/$TWiki::cfg{NameFilter}//go;
    return $this->{U2W}{$loginUser};
}

# Translates Web.WikiName (e.g. Main.JaneSmith) to
# username (e.g. jsmith) to by lookup in TWikiUsers.
sub lookupWikiName {
    my( $this, $wikiName ) = @_;

    return undef unless $wikiName;

    $this->_cacheTWikiUsersTopic();

    $wikiName =~ s/$TWiki::cfg{NameFilter}//go;
    $wikiName = "$TWiki::cfg{UsersWebName}.$wikiName"
      unless $wikiName =~ /\./;

    return $this->{W2U}{$wikiName};
}

1;
