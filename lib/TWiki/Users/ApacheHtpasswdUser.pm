# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution.
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

package TWiki::Users::ApacheHtpasswdUser;

use Apache::Htpasswd;
use Assert;
use strict;

=begin twiki

---+ package TWiki::Users::ApacheHtpasswdUser

Use Apache::HtPasswd to manage users and passwords.

=cut

=pod

---++ ClassMethod new( $session ) -> $object
Implements TWiki::Password

Constructs a new password handler of this type, referring to $session
for any required TWiki services.

=cut

sub new {
    my( $class, $session ) = @_;

    my $this = bless( {}, $class );
    $this->{apache} = new Apache::Htpasswd
      ( { passwdFile => $TWiki::cfg{Htpasswd}{FileName} } );

    return $this;
}

=pod

---++ ObjectMethod fetchPass( $login ) -> $passwordE
Implements TWiki::Password

Returns encrypted password if succeeds.  Returns 0 if login is invalid.
Returns undef otherwise.

=cut

sub fetchPass {
    my( $this, $login ) = @_;
    ASSERT( $login ) if DEBUG;

    return $this->{apache}->fetchPass( $login );
}

=pod

---++ ObjectMethod checkPassword( $user, $passwordU ) -> $boolean
Implements TWiki::Password

Finds if the password is valid for the given login.

Returns 1 if passes.  Returns 0 if fails.

=cut

sub checkPassword {
    my( $this, $login, $passU ) = @_;
    ASSERT( $login ) if DEBUG;

    return $this->{apache}->htCheckPassword( $login, $passU );
}

=pod

---++ ObjectMethod deleteUser( $user ) -> $boolean
Delete users entry in password file.
Returns 1 on success Returns undef on failure.

=cut

sub deleteUser {
    my( $this, $login ) = @_;
    ASSERT( $login ) if DEBUG;

    return $this->{apache}->htDelete( $login );
}

=pod

---++ ObjectMethod passwd( $user, $newPassU, $oldPassU ) -> $boolean
Implements TWiki::Password

If the $oldPassU is undef, it will try to add the user, failing
if they are already there.

If the $oldPassU matches matches the login's password, then it will
replace it with $newPassU.

If $oldPassU is not correct and not 1, will return 0.

If $oldPassU is 1, will force the change irrespective of
the existing password, adding the user if necessary.

Otherwise returns 1 if succeeds. Returns undef on failure.

=cut

sub passwd {
    my( $this, $user, $newPassU, $oldPassU ) = @_;
    ASSERT( $user ) if DEBUG;

    return $this->{apache}->htpasswd( $user, $newPassU, $oldPassU );
}

=pod

---++ encrypt( $user, $passwordU, $fresh ) -> $passwordE
Implements TWiki::Password


Will return an encrypted password. Repeated calls
to encrypt with the same user/passU will return the same passE.

If $fresh is true, then a new password not based on any pre-existing
salt will be used. Set this if you are generating a new password.

=cut

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

=pod

---++ ObjectMethod error() -> $string
Implements TWiki::Password


Return any error raised by the last method call, or undef if the last
method call succeeded.

=cut

sub error {
    my $this = shift;

    return $this->{apache}->error();
}

1;
