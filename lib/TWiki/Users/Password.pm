=pod

---+ package TWiki::Users::Password

A pure virtual base class of all password handlers. The interface here is
modelled on Apache::Htpasswd.

In the following description, the convention of an E suffix on a
variable name indicates an _encrypted_ password while a U indicates
an _unencrypted_ password.

---++ ClassMethod new( $session ) -> $object
Constructs a new password handler of this type, referring to $session
for any required TWiki services.

---++ ObjectMethod fetchPass( $login ) -> $passwordE
Returns encrypted password if succeeds.  Returns 0 if login is invalid.
Returns undef otherwise.

---++ ObjectMethod checkPassword( $user, $passwordU ) -> $boolean
Finds if the password is valid for the given login.

Returns 1 if passes.  Returns 0 if fails.

---++ ObjectMethod deleteUser( $user ) -> $boolean
Delete users entry in password file.
Returns 1 on success Returns undef on failure.

---++ ObjectMethod passwd( $user, $newPassU, $oldPassU ) -> $boolean
If the $oldPassU is undef, it will try to add the user, failing
if they are already there.

If the $oldPassU matches matches the login's password, then it will
replace it with $newPassU.

If $oldPassU is not correct and not 1, will return 0.

If $oldPassU is 1, will force the change irrespective of
the existing password, adding the user if necessary.

Otherwise returns 1 if succeeds. Returns undef on failure.

---++ ObjectMethod encrypt( $user, $passwordU, $fresh ) -> $passwordE

Will return an encrypted password. Repeated calls
to encrypt with the same user/passU will return the same passE.

If $fresh is true, then a new password not based on any pre-existing
salt will be used. Set this if you are generating a new password.

---++ ObjectMethod error() -> $string

Return any error raised by the last method call, or undef if the last
method call succeeded.

=cut

1;
