=pod

---+ package TWiki::Plugins::AuthPagePlugin::Validator

Example implementation of a validator using TWiki's
HtPasswdUser module.

To activate this example, copy this file to Validator.pm

=cut

package TWiki::Plugins::AuthPagePlugin::Validator;

use strict;

=pod

---++ StaticMethod validate( $user, $pass )
   * =$user= - username
   * =$pass= - password
Validate the passed username/password pair using TWiki::User::HtPasswdUser.

=cut

sub validate {
    my( $user, $pass ) = @_;

    use TWiki::User::HtPasswdUser;

    if( TWiki::User::HtPasswdUser::CheckUserPasswd(undef, $user, $pass)) {
        return "SUCCESS";
    }
}
