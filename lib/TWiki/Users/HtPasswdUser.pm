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

---+ package TWiki::Users::HtPasswdUser

The HtPasswdUser module seperates out the User Authentication code that is htpasswd and htdigest
specific. 

TODO: User.pm and the impls propbably shouldn't use Store.pm - they are not TWikiTopics..

=cut

package TWiki::Users::HtPasswdUser;

if( 'md5' eq $TWiki::cfg{HtpasswdEncoding} ) {
	require Digest::MD5;
} elsif( 'sha1' eq $TWiki::cfg{HtpasswdEncoding} ) {
    require MIME::Base64;
    import MIME::Base64 qw( encode_base64 );
    require Digest::SHA1;
    import Digest::SHA1 qw( sha1 );
}

use strict;
use Assert;

# 'Use locale' for internationalisation of Perl sorting in getTopicNames
# and other routines - main locale settings are done in TWiki::setupLocale
BEGIN {
    # Do a dynamic 'use locale' for this module
    if( $TWiki::cfg{UseLocale} ) {
        require locale;
	import locale ();
    }
}

sub new {
    my( $class, $session ) = @_;
    ASSERT(ref($session) eq 'TWiki') if DEBUG;
    my $this = bless( {}, $class );
    $this->{session} = $session;

    return $this;
}

#| Description: | (private) implementation method that generates an encrypted password |
#| Parameter: =$user= | userName |
#| Parameter: =$passwd= | unencypted password |
#| Parameter: =$useOldSalt= | if $useOldSalt == 1 then we are attempting to match $passwd an existing one 
#otherwise, we are just creating a new use encrypted passwd |
#| Return: =$value= | returns '' on failure, an encrypted password otherwise |
sub htpasswdGeneratePasswd
{
    my ( $this, $user, $passwd , $useOldSalt ) = @_;

	my $encodedPassword = '';

    if( 'sha1' eq $TWiki::cfg{HtpasswdEncoding} ) {

        $encodedPassword = '{SHA}' . MIME::Base64::encode_base64( Digest::SHA1::sha1( $passwd ) ); 
        chomp $encodedPassword;

    } elsif ( 'crypt' eq $TWiki::cfg{HtpasswdEncoding} ) {
	    # by David Levy, Internet Channel, 1997
	    # found at http://world.inch.com/Scripts/htpasswd.pl.html

		my $salt;

		if ( $useOldSalt ) {
		    my $currentEncryptedPasswordEntry = $this->htpasswdReadPasswd( $user );
	        $salt = substr( $currentEncryptedPasswordEntry, 0, 2 );
		} else {
		    srand( $$|time );
		    my @saltchars = ( 'a'..'z', 'A'..'Z', '0'..'9', '.', '/' );
		    $salt = $saltchars[ int( rand( $#saltchars+1 ) ) ];
		    $salt .= $saltchars[ int( rand( $#saltchars+1 ) ) ];
		}

		if ( ( $salt ) && (2 == length $salt) ) {
			$encodedPassword = crypt( $passwd, $salt );
		}

    } elsif ( 'md5' eq $TWiki::cfg{HtpasswdEncoding} ) {
        # SMELL: what does this do if we are using a htpasswd file?
		my $toEncode= "$user:$TWiki::cfg{AuthRealm}:$passwd";
		$encodedPassword = Digest::MD5::md5_hex( $toEncode );

    } elsif ( 'plain' eq $TWiki::cfg{HtpasswdEncoding} ) {

		$encodedPassword = $passwd;

	}

    return $encodedPassword;
}

#| Description: | gets the encrypted password from the htpasswd / htdigest file |
#| Parameter: =$user= | UserName |
#| Return: =$encryptedPassword= | '' if there is none, the encrypted password otherwise |
sub htpasswdReadPasswd
{
    my ( $this, $user ) = @_;

    if( ! $user ) {
        return '';
    }

    my $store = $this->{session}->{store};
    my $text = $store->readFile( $TWiki::cfg{HtpasswdFileName} );
    if( $text =~ /$user\:(\S+)/ ) {
        return $1;
    }
    return '';
}
 
#| Description: | checks to see if there is a $user in the password system |
#| Parameter: =$user= | the username we are looking for  |
#| Return: =$passwordExists= | '1' if true, '' if not |
sub UserPasswordExists
{
    my ( $this, $user ) = @_;

    if( ! $user ) {
        return '';
    }

    my $store = $this->{session}->{store};
    my $text = $store->readFile( $TWiki::cfg{HtpasswdFileName} );
    if( $text =~ /^${user}:/gm ) {	# mod_perl: don't use /o
        return 1;
    }
    return 0;
}
 
#| Description: | used to change the user's password |
#| Parameter: =$user= | the username we are replacing  |
#| Parameter: =$oldUserPassword= | unencrypted password |
#| Parameter: =$newUserPassword= | unencrypted password |
#| Return: =$success= | '1' if success |
# TODO: needs to fail if it doesw not succed due to file permissions
sub UpdateUserPassword
{
    my ( $this, $user, $oldUserPassword, $newUserPassword ) = @_;

    my $oldUserEntry = htpasswdGeneratePasswd( $user, $oldUserPassword , 1);
    my $newUserEntry = htpasswdGeneratePasswd( $user, $newUserPassword , 0);
 
    # can't use `htpasswd $wikiName` because htpasswd doesn't understand stdin
    # simply add name to file, but this is a security issue
    my $store = $this->{session}->{store};
    my $text = $store->readFile( $TWiki::cfg{HtpasswdFileName} );
    # escape + sign; SHA-passwords can have + signs
    $oldUserEntry =~ s/\+/\\\+/g;
    $text =~ s/$user:$oldUserEntry/$user:$newUserEntry/;
    $store->saveFile( $TWiki::cfg{HtpasswdFileName}, $text );

    return '1';
}

#| Description: |  |
#| Parameter: =$oldEncryptedUserPassword= | formated as in the htpasswd file user:encryptedPasswd |
#| Parameter: =$newEncryptedUserPassword= | formated as in the htpasswd file user:encryptedPasswd |
#| Return: =$success= |  |
#| TODO: | __Needs to go away!__ |
#| TODO: | we be better off generating a new password that we email to the user, and then let them change it? |
#| Note: | used by the htpasswd specific installpasswd & script  |
sub htpasswdUpdateUser
{
    my ( $this, $oldEncryptedUserPassword, $newEncryptedUserPassword ) = @_;

    # can't use `htpasswd $wikiName` because htpasswd doesn't understand stdin
    # simply add name to file, but this is a security issue
    my $store = $this->{session}->{store};
    my $text = $store->readFile( $TWiki::cfg{HtpasswdFileName} );
    # escape + sign; SHA-passwords can have + signs
    $oldEncryptedUserPassword =~ s/\+/\\\+/g;
    $text =~ s/$oldEncryptedUserPassword/$newEncryptedUserPassword/;
    $store->saveFile( $TWiki::cfg{HtpasswdFileName}, $text );

    return '1';
}

#| Description: | creates a new user & password entry |
#| Parameter: =$user= | the username we are replacing  |
#| Parameter: =$newUserPassword= | unencrypted password |
#| Return: =$success= | '1' if success |
#| TODO: | need to improve the error mechanism so TWikiAdmins know what failed |
sub AddUserPassword
{
    my ( $this, $user, $newUserPassword ) = @_;
    my $userEntry = $user.":". htpasswdGeneratePasswd( $user, $newUserPassword , 0);

    # can't use `htpasswd $wikiName` because htpasswd doesn't understand stdin
    # simply add name to file, but this is a security issue
    my $store = $this->{session}->{store};
    my $text = $store->readFile( $TWiki::cfg{HtpasswdFileName} );
    ##$this->{session}->writeDebug "User entry is :$userEntry: before newline";
    $text .= "$userEntry\n";
    $store->saveFile( $TWiki::cfg{HtpasswdFileName}, $text );

	return '1';
}

#| Description: | used to remove the user from the password system |
#| Parameter: =$user= | the username we are replacing  |
#| Return: =$success= | '1' if success |
#| TODO: | need to improve the error mechanism so TWikiAdmins know what failed |
sub RemoveUser
{
    my ( $this, $user ) = @_;
    my $userEntry = $user.":".$this->htpasswdReadPasswd( $user );

    return $this->htpasswdUpdateUser( $userEntry, '');
}

#| Description: | used to check the user's password |
#| Parameter: =$user= | the username we are replacing  |
#| Parameter: =$password= | unencrypted password |
#| Return: =$success= | '1' if success |
#| TODO: | need to improve the error mechanism so TWikiAdmins know what failed |
sub CheckUserPasswd
{
    my ( $this, $user, $password ) = @_;
    my $currentEncryptedPasswordEntry = $this->htpasswdReadPasswd( $user );

    my $encryptedPassword = $this->htpasswdGeneratePasswd($user, $password , 1);

    # OK
    if( $encryptedPassword eq $currentEncryptedPasswordEntry ) {
        return '1';
    }
    # NO
    return '';
}
 
1;

# EOF
