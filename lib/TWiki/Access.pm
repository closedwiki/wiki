# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2004 Peter Thoeny, peter@thoeny.com
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
=pod

---+ TWiki::Access Object

This object manages the access control database.

=cut

package TWiki::Access;

use strict;
use Assert;

=pod

---++ new()
Construct a new singleton object to manage the permissions
database.

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( {}, $class );
    ASSERT(ref($session) eq "TWiki") if DEBUG;
    $this->{session} = $session;

    %{$this->{GROUPS}} = ();

    return $this;
}

sub users { my $this = shift; return $this->{session}->{users}; }
sub prefs { my $this = shift; return $this->{session}->{prefs}; }
sub store { my $this = shift; return $this->{session}->{store}; }
sub sandbox { my $this = shift; return $this->{session}->{sandbox}; }
sub security { my $this = shift; return $this->{session}->{security}; }
sub templates { my $this = shift; return $this->{session}->{templates}; }
sub renderer { my $this = shift; return $this->{session}->{renderer}; }
sub search { my $this = shift; return $this->{session}->{search}; }

=pod

---++ sub permissionsSet (  $web  )

Are there any security restrictions for this Web
(ignoring settings on individual pages).

=cut

sub permissionsSet {
    my( $this, $web ) = @_;
    ASSERT(ref($this) eq "TWiki::Access") if DEBUG;

    my $permSet = 0;

    my @types = qw/ALLOW DENY/;
    my @actions = qw/CHANGE VIEW RENAME/;

  OUT: foreach my $type ( @types ) {
        foreach my $action ( @actions ) {
            my $pref = $type . "WEB" . $action;
            my $prefValue = $this->prefs()->getPreferencesValue( $pref, $web ) || "";
            if( $prefValue =~ /\S/ ) {
                $permSet = 1;
                last OUT;
            }
        }
    }

    return $permSet;
}

=pod

---++ getReason() -> $string

Return a string describing the reason why the last access control failure
occurred.

=cut

sub getReason {
    my $this = shift;

    return $this->{failure};
}

=pod

---++ checkAccessPermission( $action, $user, $text, $topic, $web ) ==> $ok
| Description:          | Check if user is allowed to access topic |
| Parameter: =$action=  | "VIEW", "CHANGE", "CREATE", etc. |
| Parameter: =$user=    | User object |
| Parameter: =$text=    | If empty: Read "$theWebName.$theTopicName" to check permissions |
| Parameter: =$topic=   | Topic name to check, e.g. "SomeTopic" |
| Parameter: =$web=     | Web, e.g. "Know" |
| Return:    undef if access is OK, an explanation otherwise  |

=cut

sub checkAccessPermission {
    my( $this, $theAccessType, $user,
        $theTopicText, $theTopicName, $theWebName ) = @_;
    ASSERT(ref($this) eq "TWiki::Access") if DEBUG;
    ASSERT(ref($user) eq "TWiki::User") if DEBUG;

    undef $this->{failure};

    # super admin is always allowed
    return 1 if $user->isAdmin();

    $theAccessType = uc( $theAccessType );  # upper case
    if( ! $theWebName ) {
        $theWebName = $this->{session}->{webName};
    }

    if( ! $theTopicText ) {
        # text not supplied as parameter, so read topic. The
        # read is "Raw" just to hint to store that we want the
        # data _fast_.
        $theTopicText = $this->store()->readTopicRaw( undef, $theWebName,
                                                      $theTopicName,
                                                      undef );
    }

    my $allowText;
    my $denyText;

    # extract the * Set (ALLOWTOPIC|DENYTOPIC)$theAccessType =
    # from the topic text
    foreach( split( /\n/, $theTopicText ) ) {
        if( /^\s+\*\sSet\s(ALLOWTOPIC|DENYTOPIC)$theAccessType\s*\=\s*(.*)/ ) {
            my ( $how, $set ) = ( $1, $2 );
            # Note: an empty value is a valid value!
            if( defined( $set )) {
                if( $how eq "DENYTOPIC" ) {
                    $denyText = $set;
                } else {
                    $allowText = $set;
                }
            }
        }
    }

    my $control = "topic";
    # DENYTOPIC overrides DENYWEB, even if it is empty
    unless( defined( $denyText )) {
        $control = "web";
        $denyText =
          $this->prefs()->getPreferencesValue( "DENYWEB$theAccessType", $theWebName );
    }

    if( defined( $denyText )) {
        if( $user->isInList( $denyText )) {
            $this->{failure} = "$control is denied";
            return 0;
        }
    }

    if( defined( $allowText ) ) {
        unless( $user->isInList( $allowText )) {
            $this->{failure} = "topic is not allowed";
            return 0;
        }
    } else {
        # ALLOWTOPIC overrides ALLOWWEB, even if it is empty
        $allowText =
          $this->prefs()->getPreferencesValue( "ALLOWWEB$theAccessType",
                                             $theWebName );

        if( defined( $allowText ) && $allowText =~ /\S/ ) {
            unless( $user->isInList( $allowText )) {
                $this->{failure} = "web is not allowed";
                return 0;
            }
        }
    }

    return 1;
}

1;
