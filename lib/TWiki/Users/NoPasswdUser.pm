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

The NoPasswdUser module is an implementation of the User Authentication code that has no passwords / users

   * currently it is implemented to always succeed (so anyone can be anyone they like)
      * which is how users os the UserCookiePlugin often work
      
__Note:___ this _is_ untested

=cut

package TWiki::Users::NoPasswdUser;

use strict;

# 'Use locale' for internationalisation of Perl sorting in getTopicNames
# and other routines - main locale settings are done in TWiki::setupLocale
BEGIN {
    # Do a dynamic 'use locale' for this module
    if( $TWiki::cfg{UseLocale} ) {
        require locale;
	import locale ();
    }
}

# ======================
sub new
{
   my( $proto ) = @_;
   my $class = ref($proto) || $proto;
   my $this = {};
   bless( $this, $class );
#   $this->_init();
#   $this->{head} = 0;
   return $this;
}

#| Description: | checks to see if there is a $user in the password system |
#| Parameter: =$user= | the username we are looking for  |
#| Return: =$passwordExists= | '' as there is no password in NoPasswdUser (this allows the registration script (and others) register new users) |
sub UserPasswordExists
{
    my ( $this, $user ) = @_;

    return '';
}
 
#| Description: | used to change the user's password |
#| Parameter: =$user= | the username we are replacing  |
#| Parameter: =$oldUserPassword= | unencrypted password |
#| Parameter: =$newUserPassword= | unencrypted password |
#| Return: =$success= | '1' always |
# TODO: needs to fail if it doesw not succed due to file permissions
sub UpdateUserPassword
{
    my ( $this, $user, $oldUserPassword, $newUserPassword ) = @_;

    return '1';
}

#| Description: | creates a new user & password entry |
#| Parameter: =$user= | the username we are replacing  |
#| Parameter: =$newUserPassword= | unencrypted password |
#| Return: =$success= | '1' if success |
#| TODO: | not sure if this should be true / false |
sub AddUserPassword
{
    my ( $this, $user, $newUserPassword ) = @_;
    my $userEntry = $user.":". _htpasswdGeneratePasswd( $user, $newUserPassword , 0);

	return '1';
}

#| Description: | used to remove the user from the password system |
#| Parameter: =$user= | the username we are replacing  |
#| Return: =$success= | '1' if success |
#i'm a wimp - comment out the password entry
sub RemoveUser
{
    my ( $this, $user ) = @_;

    return '1';
}

#| Description: | used to check the user's password |
#| Parameter: =$user= | the username we are replacing  |
#| Parameter: =$password= | unencrypted password |
#| Return: =$success= | '1' if success |
sub CheckUserPasswd
{
    my ( $this, $user, $password ) = @_;

    # OK
    return '1';
}
 
1;

# EOF
