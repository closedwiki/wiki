=pod

---+ package TWiki::Plugins::AuthPagePlugin::Validator

Example implementation of a validator using Apache::Htpasswd
Note that the result of the validate method is stored in the
cookie under the "VALIDATION" key, and can be recovered in
later sessions (e.g. using the SessionPlugin
!%GETSESSIONVARIABLE{ VALIDATION }% )

Note that there can only be one Validator implementation.

To activate this example, copy this file to Validator.pm and
edit the path to htpasswd as appropriate.

=cut

package TWiki::Plugins::AuthPagePlugin::Validator;

use strict;

=pod

---++ StaticMethod validate( $user, $pass )
   * =$user= - username
   * =$pass= - password
Validate the passed username/password pair using Apache::Htpasswd.
The return value must either be undef (validation failed) or a
validation key. The validation key will be stored in the cookie
for later recovery, so it should not be possible to reverse-engineer
the authentication from it.

=cut

sub validate {
    my( $user, $pass ) = @_;

    require Apache::Htpasswd;

    my $apache = new Apache::Htpasswd
      (
       {
         passwdFile => "path-to-htpasswd-file",
         ReadOnly => 1
        }
      );
    return $apache->htCheckPassword($user, $pass);
}

1;
