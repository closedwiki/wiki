# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2004 Peter Thoeny, peter@thoeny.com
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

=begin twiki

---+ TWiki::Users Package
Singleton object that handles mapping of users to wikinames and
vice versa, and user authentication checking.

=cut

package TWiki::Users;

use strict;
use Assert;
use TWiki::User;

# 'Use locale' for internationalisation of Perl sorting in getTopicNames
# and other routines - main locale settings are done in TWiki::setupLocale
BEGIN {
    # Do a dynamic 'use locale' for this module
    if( $TWiki::cfg{UseLocale} ) {
        eval 'require locale; import locale ();';
    }
}

=pod

---++ new ()
Construct the user management object

=cut

sub new {
    my ( $class, $session, $impl ) = @_;
    ASSERT(ref($session) eq "TWiki") if DEBUG;
    my $this = bless( {}, $class );
    $this->{session} = $session;

    $this->{IMPL} = "TWiki::Users::$impl";
    $this->{CACHED} = 0;

	eval "use $this->{IMPL}";
    if( $@ ) {
        die "$this->{IMPL} compile failed: $@";
    }

    # create the guest user
    $this->findUser( $TWiki::cfg{DefaultUserLogin}, $TWiki::cfg{DefaultUserWikiName} );

    return $this;
}

sub prefs { my $this = shift; return $this->{session}->{prefs}; }
sub store { my $this = shift; return $this->{session}->{store}; }
sub sandbox { my $this = shift; return $this->{session}->{sandbox}; }
sub security { my $this = shift; return $this->{session}->{security}; }
sub templates { my $this = shift; return $this->{session}->{templates}; }
sub renderer { my $this = shift; return $this->{session}->{renderer}; }

# get a list of groups defined in this TWiki 
sub _getListOfGroups {
    my $this = shift;
    ASSERT(ref($this) eq "TWiki::Users") if DEBUG;

    my @list;
    $this->search()->searchWeb
      (
       _callback     => \&_collateGroups,
       _cbdata       => \@list,
       inline        => 1,
       search        => "Set GROUP =",
       web           => "all",
       topic         => "*Group",
       type          => "regex",
       nosummary     => "on",
       nosearch      => "on",
       noheader      => "on",
       nototal       => "on",
       noempty       => "on",
       format	     => "\$web.\$topic",
       separator     => "",
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
    my( $this, $theItems, $expand ) = @_;
    ASSERT(ref($this) eq "TWiki::Users") if DEBUG;

    # comma delimited list of users or groups
    # i.e.: "%MAINWEB%.UserA, UserB, Main.UserC  # something else"
    $theItems =~ s/(<[^>]*>)//go;     # Remove HTML tags
    # TODO: i18n fix for user name
    $theItems =~ s/\s*([a-zA-Z0-9_\.\,\s\%]*)\s*(.*)/$1/go; # Limit list

    my @l = map { $this->findUser( $_ ) } split( /[\,\s]+/, $theItems );
    return \@l;
}

=pod

---+ findUser( $name [, $wikiname] [, $nocreate ] )

Find the user object corresponding to a name, either a
login name or a wiki name. If now user object is found,
the name is assumed to be a login name and a new user
object is created.

If the $wikiname is specified, it is used as the wikiname
of the user, overriding whatever may be in the username
mappings.

If $nocreate is specified, don't create the user if they don't already
exist in the TWikiUsers mapping.

=cut

sub findUser {
    my( $this, $name, $wikiname, $dontCreate ) = @_;
    ASSERT(ref($this) eq "TWiki::Users") if DEBUG;
    my $object;

    if( $name =~ /(.*)\.(.*)/ ) {
        # must be web.wikiname
        $object = $this->{wikiname}{$name};
        return $object if $object;
    }
    # is it a login name?
    $object = $this->{login}{$name};
    return $object if $object;

    # prepend the mainweb and try again in wikinames
    $object = $this->{wikiname}{"$TWiki::cfg{UsersWebName}.$name"};
    return $object if $object;

    # not cached; assume the name was a login name
    # and create the stub for the user. If no wikiname
    # was given, try to infer one from the TWikiUsers topic.
    $wikiname = $this->_lookupTWikiUsers( $name ) unless $wikiname;

    return undef if( !$wikiname && $dontCreate );

    $wikiname = $name unless $wikiname;
    $object = new TWiki::User( $this->{session}, $name, $wikiname );
    ASSERT($object->login()) if DEBUG;
    ASSERT($object->wikiName()) if DEBUG;
    ASSERT($object->webDotWikiName()) if DEBUG;
    $this->{login}{$name} = $object;
    $this->{wikiname}{$object->webDotWikiName()} = $object;

    return $object;
}

# Get the password implementation
sub _getPasswordHandler {
    my $this = shift;
    ASSERT(ref($this) eq "TWiki::Users") if DEBUG;

    unless( $this->{passwordHandler} ) {
        $this->{passwordHandler} = $this->{IMPL}->new( $this->{session} );
    }
    return $this->{passwordHandler};
}

=pod

---++ addUserToTWikiUsersTopic( $user ) ==> $topicName

Add a user to the TWikiUsers topic. This is a topic that
maps from usernames to wikinames. It is maintained by
Register.pm, or manually outside TWiki.

=cut

sub addUserToTWikiUsersTopic {
    my ( $this, $user, $me ) = @_;

    ASSERT(ref($this) eq "TWiki::Users") if DEBUG;
    ASSERT(ref($user) eq "TWiki::User") if DEBUG;
    ASSERT(ref($me) eq "TWiki::User") if DEBUG;

    my( $meta, $text ) =
      $this->store()->readTopic( undef, $TWiki::cfg{UsersWebName},
                                 $TWiki::cfg{UsersTopicName}, undef );
    my $result = "";
    my $entry = "\t* ";
    $entry .= $user->web()."."
      unless $user->web() eq $TWiki::cfg{UsersWebName};
    $entry .= $user->wikiName()." - ";
    $entry .= $user->login() . " - " if $user->login();
    my $today = TWiki::formatTime(time(), "\$day \$mon \$year", "gmtime");

    # add to the cache
    $this->{U2W}{$user->login()} = $user->{web} . "." , $user->wikiName();

    # add name alphabetically to list
    foreach my $line ( split( /\r?\n/, $text) ) {
        # TODO: I18N fix here once basic auth problem with 8-bit user names is
        # solved
        if ( $entry && $line =~ /\t\*\s($TWiki::regex{webNameRegex}\.)?($TWiki::regex{wikiWordRegex})\s\-\s(.*)/ ) {
            my $web = $1 || $TWiki::cfg{UsersWebName};
            my $name = $2;
            my $odate = $3;
            if( $user->wikiName() le $name ) {
                my $isit = ( $user->wikiName() eq $name );
                # found alphabetical position
                if( $isit ) {
                    # adjusting existing user - keep original registration date
                    $entry .= $odate;
                } else {
                    $entry .= $today;
                }
                # don't adjust if unchanged
                return $TWiki::cfg{UsersTopicName} if( $entry eq $line );
                $result .= "$entry\n";
                $entry = "";
                # don't add existing user entry twice
                next if $isit;
            }
        }

        $result .= "$line\n";
    }
    if( $entry ) {
        # brand new file - add to end
        $result .= "$entry$today\n";
    }
    $this->store()->saveTopic( $me, $TWiki::cfg{UsersWebName},
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
    ASSERT(ref($this) eq "TWiki::Users") if DEBUG;

    return if $this->{CACHED};
    $this->{CACHED} = 1;

    %{$this->{U2W}} = ();
    my @list = ();
    if( $TWiki::cfg{MapUserToWikiName} ) {
        my $text = $this->store()->readTopicRaw( undef, $TWiki::cfg{UsersWebName},
                                                 $TWiki::cfg{UsersTopicName},
                                                 undef );
        @list = split( /\n/, $text );
    } else {
        # fix for Codev.SecurityAlertGainAdminRightWithTWikiUsersMapping
        # for .htpasswd authenticated sites ignore user list, but map only
        #guest to TWikiGuest. CODE_SMELL on localization
        @list = ( "\t* $TWiki::cfg{DefaultUserWikiName} - $TWiki::cfg{DefaultUserLogin} - " );
    }

    my $wUser;
    my $lUser;
    foreach( @list ) {
	# Get the WikiName and userid, and build hashes in both directions
        if(  ( /^\s*\* ($TWiki::regex{webNameRegex}\.)?(\S+)\s*\-\s*([^\s]*).*/o ) && $2 ) {
            my $web = $1;
            $web = $TWiki::cfg{UsersWebName} unless $web;
            $wUser = $2;	# WikiName
            $lUser = $3;	# userid
            $lUser =~ s/$TWiki::cfg{NameFilter}//go;	# FIXME: Should filter in for security...
            $this->{U2W}{ $lUser } = "$web.$wUser";
        }
    }
}

=pod

---++ initializeRemoteUser( $remoteUser )

Return value: $remoteUser

Acts as a filter for $remoteUser.  If set, $remoteUser is filtered for
insecure characters and untainted.

If not user is passed, the remote user defaults to $cfg{DefaultUserLogin}
(usually 'guest').

If we got here via an authentication status failure, then the remote user
is set to blank, effectively signalling an illegal access.

If $cfg{RememberUserIPAddress} is set, it looks up the IP address of
the requestor and tries to map it to a username. If the lookup fails,
but a remote user name was passed in (which will happen if the CGI
query contains remote_user()) then it caches the mapping from IP addess to
user. If no remote user name was passed in, the user defaults to
$cfg{DefaultUserLogin}.

SMELL: the association of a user with an IP address is a high
risk strategy that can fail in the following environments:
   1 Multiple users at the same IP address
   1 Short-lease DHCP environments
This is documented sufficiently for a risk assessment to be made
by the installer. However it would be much safer (and more user
friendly) to use cookies.

=cut

sub initializeRemoteUser {
    my( $this, $theRemoteUser ) = @_;

    my $remoteUser = $theRemoteUser || $TWiki::cfg{DefaultUserLogin};
    $remoteUser =~ s/$TWiki::cfg{NameFilter}//go;
    $remoteUser = TWiki::Sandbox::untaintUnchecked( $remoteUser );

    my $remoteAddr = $ENV{'REMOTE_ADDR'} || "";

    if( $ENV{'REDIRECT_STATUS'} && $ENV{'REDIRECT_STATUS'} eq '401' ) {
        # bail out if authentication failed
        $remoteAddr = "";
    }

    if( ! $TWiki::cfg{RememberUserIPAddress} || ! $remoteAddr ) {
        # do not remember IP address
        return $remoteUser;
    }

    my $text =
      $this->store()->readFile( $TWiki::cfg{RemoteUserFileName} );

    # Assume no I18N characters in userids, as for email addresses
    # FIXME: Needs fixing for IPv6?
    my %AddrToName = map { split( /\|/, $_ ) }
      grep { /^[0-9\.]+\|[A-Za-z0-9]+\|$/ }
        split( /\n/, $text );

    my $rememberedUser = "";
    if( exists( $AddrToName{ $remoteAddr } ) ) {
        $rememberedUser = $AddrToName{ $remoteAddr };
    }

    if( $theRemoteUser ) {
        if( $theRemoteUser ne $rememberedUser ) {
            $AddrToName{ $remoteAddr } = $theRemoteUser;
            # create file as "$remoteAddr|$theRemoteUser|" lines
            $text = "# This is a generated file, do not modify.\n";
            foreach my $usrAddr ( sort keys %AddrToName ) {
                my $usrName = $AddrToName{ $usrAddr };
                # keep $userName unique
                if(  ( $usrName ne $theRemoteUser )
                     || ( $usrAddr eq $remoteAddr ) ) {
                    $text .= "$usrAddr|$usrName|\n";
                }
            }
            $this->store()->saveFile( $TWiki::cfg{RemoteUserFileName}, $text );
        }
    } else {
        # get user name from AddrToName table
        $remoteUser = $rememberedUser || $TWiki::cfg{DefaultUserLogin};
    }

    return $remoteUser;
}

# _lookupTWikiUsers( $loginUser, $wantUndef ) --> $wikiName
#
# Translates intranet username (e.g. jsmith) to
# Web.WikiName (e.g. Main.JaneSmith)
#
# if you give an invalid username, we just return that
# unless $wantUndef is set, in which case it returns undef.
#
sub _lookupTWikiUsers {
    my( $this, $loginUser ) = @_;

    if( !$loginUser ) {
        return "";
    }

    $this->_cacheTWikiUsersTopic();

    $loginUser =~ s/$TWiki::cfg{NameFilter}//go;
    my $wUser = $this->{U2W}{ $loginUser };

    return $wUser;
}

1;
