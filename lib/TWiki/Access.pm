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
# As per the GPL, removal of this notice is prohibited.=pod

=pod

---+ package TWiki::Access

A singleton object of this class manages the access control database.

=cut

package TWiki::Access;

use strict;
use Assert;

=pod

---++ ClassMethod new()

Construct a new singleton object to manage the permissions
database.

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( {}, $class );
    ASSERT($session->isa( 'TWiki')) if DEBUG;
    $this->{session} = $session;

    %{$this->{GROUPS}} = ();

    return $this;
}

=pod

---++ ObjectMethod permissionsSet (  $web  ) -> $boolean

Are there any security restrictions for this Web
(ignoring settings on individual pages).

=cut

sub permissionsSet {
    my( $this, $web ) = @_;
    ASSERT($this->isa( 'TWiki::Access')) if DEBUG;

    my $permSet = 0;

    my @types = qw/ALLOW DENY/;
    my @actions = qw/CHANGE VIEW RENAME/;
    my $prefs = $this->{session}->{prefs};

  OUT: foreach my $type ( @types ) {
        foreach my $action ( @actions ) {
            my $pref = $type . 'WEB' . $action;
            my $prefValue = $prefs->getPreferencesValue( $pref, $web ) || '';
            if( $prefValue =~ /\S/ ) {
                $permSet = 1;
                last OUT;
            }
        }
    }

    return $permSet;
}

=pod

---++ ObjectMethod getReason() -> $string

Return a string describing the reason why the last access control failure
occurred.

=cut

sub getReason {
    my $this = shift;

    return $this->{failure};
}

=pod

---++ ObjectMethod checkAccessPermission( $action, $user, $text, $topic, $web ) -> $boolean
Check if user is allowed to access topic
   * =$action=  - 'VIEW', 'CHANGE', 'CREATE', etc.
   * =$user=    - User object
   * =$text=    - If empty: Read '$theWebName.$theTopicName' to check permissions
   * =$topic=   - Topic name to check, e.g. 'SomeTopic'
   * =$web=     - Web, e.g. 'Know'
If the check fails, the reason can be recoveered using getReason

=cut

sub checkAccessPermission {
    my( $this, $mode, $user,
        $theTopicText, $topic, $web ) = @_;
    ASSERT($this->isa( 'TWiki::Access')) if DEBUG;
    ASSERT($user->isa( 'TWiki::User')) if DEBUG;

    undef $this->{failure};

    #print STDERR "Check access ", $user->stringify()," to $web.$topic ";

    # super admin is always allowed
    if( $user->isAdmin() ) {
        #print STDERR " - ADMIN\n";
        return 1;
    }

    $mode = uc( $mode );  # upper case
    $web ||= $this->{session}->{webName};

    if( ! $theTopicText ) {
        # text not supplied as parameter, so read topic. The
        # read is 'Raw' just to hint to store that we want the
        # data _fast_.
        my $store = $this->{session}->{store};
        $theTopicText = $store->readTopicRaw( undef, $web, $topic, undef );
    }

    my $allowText;
    my $denyText;

    # extract the * Set (ALLOWTOPIC|DENYTOPIC)$mode =
    # from the topic text
    foreach( split( /\n/, $theTopicText ) ) {
        if( /^$TWiki::regex{setRegex}(ALLOW|DENY)TOPIC$mode\s*\=\s*(.*)$/ ) {
            my ( $how, $set ) = ( $1, $2 );
            # Note: an empty value is a valid value!
            if( defined( $set )) {
                if( $how eq 'DENY' ) {
                    $denyText = $set;
                } else {
                    $allowText = $set;
                }
            }
        }
    }

    # Check DENYTOPIC
    if( defined( $denyText )) {
        if( $denyText =~ /\S$/ ) {
            if( $user->isInList( $denyText )) {
                $this->{failure} = 'topic is denied';
                #print STDERR $this->{failure},"\n";
                return 0;
            }
        } else {
            # If DENYTOPIC is empty, don't deny _anyone_
            #print STDERR "DENYTOPIC is empty\n";
            return 1;
        }
    }

    # Check ALLOWTOPIC. If this is defined the user _must_ be in it
    if( defined( $allowText )) {
        if( $user->isInList( $allowText )) {
            #print STDERR "in ALLOWTOPIC\n";
            return 1;
        }
        $this->{failure} = 'topic is not allowed';
        #print STDERR $this->{failure},"\n";
        return 0;
    }

    my $prefs = $this->{session}->{prefs};

    # Check DENYWEB, but only if DENYTOPIC is not set (even if it
    # is empty - empty means "don't deny anybody")
    unless( defined( $denyText )) {
        $denyText =
          $prefs->getPreferencesValue( 'DENYWEB'.$mode, $web );
        if( defined( $denyText ) && $user->isInList( $denyText )) {
            $this->{failure} = 'web is denied';
            #print STDERR $this->{failure},"\n";
            return 0;
        }
    }

    # Check ALLOWWEB. If this is defined and not overridden by
    # ALLOWTOPIC, the user _must_ be in it.
    $allowText = $prefs->getPreferencesValue( 'ALLOWWEB'.$mode, $web );

    if( defined( $allowText ) && $allowText =~ /\S/ ) {
        unless( $user->isInList( $allowText )) {
            $this->{failure} = 'web is not allowed';
            #print STDERR $this->{failure},"\n";
            return 0;
        }
    }

    #print STDERR "OK ALLOW $allowText DENY $denyText\n";
    return 1;
}

1;
