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
# Notes:
# - Latest version at http://twiki.org/
# - Installation instructions in $dataDir/Main/TWikiDocumentation.txt
# - Customize variables in TWiki.cfg when installing TWiki.
# - Optionally change TWiki.pm for custom extensions of rendering rules.
# - Upgrading TWiki is easy as long as you do not customize TWiki.pm.
# - Check web server error logs for errors, i.e. % tail /var/log/httpd/error_log
#

=begin twiki

---+ TWiki::User::NoPasswdUser Package

The NoPasswdUser module is an implementation of the User Authentication code that has no passwords / users

   * currently it is implemented to always succeed (so anyone can be anyone they like)
      * which is how users os the UserCookiePlugin often work
      
__Note:___ this _is_ untested

=cut

package TWiki::User::NoPasswdUser;

use strict;

# 'Use locale' for internationalisation of Perl sorting in getTopicNames
# and other routines - main locale settings are done in TWiki::setupLocale
BEGIN {
    # Do a dynamic 'use locale' for this module
    if( $TWiki::useLocale ) {
        require locale;
	import locale ();
    }
}

# ======================
sub new
{
   my( $proto ) = @_;
   my $class = ref($proto) || $proto;
   my $self = {};
   bless( $self, $class );
#   $self->_init();
#   $self->{head} = 0;
   return $self;
}

#========================= 
=pod

---+++ UserPasswordExists( $user ) ==> $passwordExists
| Description: | checks to see if there is a $user in the password system |
| Parameter: =$user= | the username we are looking for  |
| Return: =$passwordExists= | "" as there is no password in NoPasswdUser (this allows the registration script (and others) register new users) |

=cut
sub UserPasswordExists
{
    my ( $self, $user ) = @_;

    return "";
}
 
#========================= 
=pod

---+++ UpdateUserPassword( $user, $oldUserPassword, $newUserPassword ) ==> $success
| Description: | used to change the user's password |
| Parameter: =$user= | the username we are replacing  |
| Parameter: =$oldUserPassword= | unencrypted password |
| Parameter: =$newUserPassword= | unencrypted password |
| Return: =$success= | "1" always |

=cut
# TODO: needs to fail if it doesw not succed due to file permissions
sub UpdateUserPassword
{
    my ( $self, $user, $oldUserPassword, $newUserPassword ) = @_;

    return "1";
}

#===========================
=pod

---+++ AddUserPassword( $user, $newUserPassword ) ==> $success
| Description: | creates a new user & password entry |
| Parameter: =$user= | the username we are replacing  |
| Parameter: =$newUserPassword= | unencrypted password |
| Return: =$success= | "1" if success |
| TODO: | not sure if this should be true / false |

=cut
sub AddUserPassword
{
    my ( $self, $user, $newUserPassword ) = @_;
    my $userEntry = $user.":". _htpasswdGeneratePasswd( $user, $newUserPassword , 0);

	return "1";
}

#===========================
=pod

---+++ RemoveUser( $user ) ==> $success
| Description: | used to remove the user from the password system |
| Parameter: =$user= | the username we are replacing  |
| Return: =$success= | "1" if success |

=cut
#i'm a wimp - comment out the password entry
sub RemoveUser
{
    my ( $self, $user ) = @_;

    return "1";
}

# =========================
=pod

---+++ CheckUserPasswd( $user, $password ) ==> $success
| Description: | used to check the user's password |
| Parameter: =$user= | the username we are replacing  |
| Parameter: =$password= | unencrypted password |
| Return: =$success= | "1" if success |

=cut
sub CheckUserPasswd
{
    my ( $self, $user, $password ) = @_;

    # OK
    return "1";
}
 
1;

# EOF
