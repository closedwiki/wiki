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

=begin twiki

---+ package TWiki::Users::NoPasswdUser

This class is an implementation of the TWiki::Password interface
that has no passwords / users. It is implemented to always succeed
(so anyone can be anyone they like)

=cut

package TWiki::Users::NoPasswdUser;

use strict;

=pod

---++ ClassMethod new( $session ) -> $object
Implements TWiki::Password

Constructs a new password handler of this type, referring to $session
for any required TWiki services.

=cut

sub new {
   return bless( {}, shift );
}

=pod

---++ ObjectMethod fetchPass( $login ) -> $passwordE
Implements TWiki::Password

Returns encrypted password if succeeds.  Returns 0 if login is invalid.
Returns undef otherwise.

=cut

sub fetchPass {
    return '';
}

=pod

---++ ObjectMethod checkPassword( $user, $passwordU ) -> $boolean
Implements TWiki::Password

Finds if the password is valid for the given login.

Returns 1 if passes.  Returns 0 if fails.

=cut

sub checkPassword {
    return 1;
}

=pod

---++ ObjectMethod deleteUser( $user ) -> $boolean
Delete users entry in password file.
Returns 1 on success Returns undef on failure.

=cut

sub deleteUser {
    return 1;
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
    return 1;
}

=pod

---++ encrypt( $user, $passwordU ) -> $passwordE
Implements TWiki::Password


Will return an encrypted password. Repeated calls
to encrypt with the same user/passU will return the same passE.
However if the passU is changed, and subsequently changed _back_
to the old user/passU pair, then the old passE is no longer valid.

=cut

sub encrypt {
    return '';
}

=pod

---++ ObjectMethod error() -> $string
Implements TWiki::Password


Return any error raised by the last method call, or undef if the last
method call succeeded.

=cut

sub error {
    return '';
}

1;
