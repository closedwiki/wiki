# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004-2006 TWiki Contributors. All Rights Reserved. 
# TWiki Contributors are listed in the AUTHORS file in the root of 
# this distribution. NOTE: Please extend that file, not this notice.
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

package TWiki::Users::ApacheHtpasswdUser;

use Apache::Htpasswd;
use Assert;
use strict;
use TWiki::Users::Password;

@TWiki::Users::ApacheHtpasswdUser::ISA = qw( TWiki::Users::Password );

=begin twiki

---+ package TWiki::Users::ApacheHtpasswdUser

Password manager that uses Apache::HtPasswd to manage users and passwords.

Subclass of [[TWikiUsersPasswordDotPm][ =TWiki::Users::Password= ]].
See documentation of that class for descriptions of the methods of this class.

Duplicates functionality of
[[TWikiUsersHtPasswdUserDotPm][ =TWiki::Users::HtPasswdUser=]];
provided mainly as an example of how to write a new password manager.

=cut

sub new {
    my( $class, $session ) = @_;

    my $this = bless( $class->SUPER::new( $session ), $class );
    $this->{apache} = new Apache::Htpasswd
      ( { passwdFile => $TWiki::cfg{Htpasswd}{FileName} } );

    return $this;
}

sub fetchPass {
    my( $this, $login ) = @_;
    ASSERT( $login ) if DEBUG;

    return $this->{apache}->fetchPass( $login );
}

sub checkPassword {
    my( $this, $login, $passU ) = @_;
    ASSERT( $login ) if DEBUG;

    return $this->{apache}->htCheckPassword( $login, $passU );
}

sub deleteUser {
    my( $this, $login ) = @_;
    ASSERT( $login ) if DEBUG;

    return $this->{apache}->htDelete( $login );
}

sub passwd {
    my( $this, $user, $newPassU, $oldPassU ) = @_;
    ASSERT( $user ) if DEBUG;

    return $this->{apache}->htpasswd( $user, $newPassU, $oldPassU );
}

sub encrypt {
    my( $this, $user, $passwordU, $fresh ) = @_;
    ASSERT( $user ) if DEBUG;

    my $salt = '';
    unless( $fresh ) {
        my $epass = $this->fetchPass( $user );
        $salt = substr( $epass, 0, 2 ) if ( $epass );
    }
    return $this->{apache}->CryptPasswd( $passwordU, $salt );
}

sub error {
    my $this = shift;

    return $this->{apache}->error();
}

1;
