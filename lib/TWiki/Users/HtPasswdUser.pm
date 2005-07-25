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

Support for htpasswd and htdigest format password files.

=cut

package TWiki::Users::HtPasswdUser;

use strict;
use Assert;
use Error qw( :try );

# 'Use locale' for internationalisation of Perl sorting in getTopicNames
# and other routines - main locale settings are done in TWiki::setupLocale
BEGIN {
    # Do a dynamic 'use locale' for this module
    if( $TWiki::cfg{UseLocale} ) {
        require locale;
        import locale ();
    }
	# no point calling rand() without this 
    # See Camel-3 pp 800.  "Do not call =srand()= multiple times in your
    # program ... just do it once at the top of your program or you won't
    # get random numbers out of =rand()=
    srand( time() ^ ($$ + ($$ << 15)) );
}

=pod

---++ ClassMethod new() -> $object
Constructs a new password handler of this type.

=cut

sub new {
    my $class = shift;
    my $this = bless( {}, $class );
    $this->{error} = undef;
    if( $TWiki::cfg{Htpasswd}{Encoding} eq 'md5' ) {
        require Digest::MD5;
    } elsif( $TWiki::cfg{Htpasswd}{Encoding} eq 'sha1' ) {
        require MIME::Base64;
        import MIME::Base64 qw( encode_base64 );
        require Digest::SHA1;
        import Digest::SHA1 qw( sha1 );
    }
    return $this;
}

sub _readPasswd {
    open( IN_FILE, "<$TWiki::cfg{Htpasswd}{FileName}" ) ||
      throw Error::Simple( "$TWiki::cfg{Htpasswd}{FileName}: $!" );
    my $s = $/;
    undef $/; # set to read to EOF
    my $data = <IN_FILE>;
    $/ = $s;
    close( IN_FILE ) ||
      throw Error::Simple( "$TWiki::cfg{Htpasswd}{FileName}: $!" );
    return $data;
}

sub _savePasswd {
    my $text = shift;

    umask( 077 );
    open( FILE, ">$TWiki::cfg{Htpasswd}{FileName}" ) ||
      throw Error::Simple( "$TWiki::cfg{Htpasswd}{FileName}: $!" );

    print FILE $text;
    close( FILE) ||
      throw Error::Simple( "$TWiki::cfg{Htpasswd}{FileName}: $!" );
}

=pod

---++ encrypt( $user, $passwordU, $fresh ) -> $passwordE
Will return an encrypted password. Repeated calls
to encrypt with the same user/passU will return the same passE.

If $fresh is true, then a new password not based on any pre-existing
salt will be used. Set this if you are generating a new password.

=cut

sub encrypt {
    my ( $this, $user, $passwd, $fresh ) = @_;
    ASSERT($this->isa( 'TWiki::Users::HtPasswdUser')) if DEBUG;

    if( $TWiki::cfg{Htpasswd}{Encoding} eq 'sha1') {
        my $encodedPassword = '{SHA}'.
          MIME::Base64::encode_base64( Digest::SHA1::sha1( $passwd ) );
        chomp $encodedPassword;
        return $encodedPassword;

    } elsif ( $TWiki::cfg{Htpasswd}{Encoding} eq 'crypt' ) {
	    # by David Levy, Internet Channel, 1997
	    # found at http://world.inch.com/Scripts/htpasswd.pl.html

        my $salt;
        $salt = $this->fetchPass( $user ) unless $fresh;
        if ( $fresh || !$salt ) {
            my @saltchars = ( 'a'..'z', 'A'..'Z', '0'..'9', '.', '/' );
            $salt = $saltchars[int(rand($#saltchars+1))] .
              $saltchars[int(rand($#saltchars+1)) ];
        }
        return crypt( $passwd, substr( $salt, 0, 2 ) );

    } elsif ( $TWiki::cfg{Htpasswd}{Encoding} eq 'md5' ) {
        # SMELL: what does this do if we are using a htpasswd file?
		my $toEncode= "$user:$TWiki::cfg{AuthRealm}:$passwd";
		return Digest::MD5::md5_hex( $toEncode );

    } elsif ( $TWiki::cfg{Htpasswd}{Encoding} eq 'plain' ) {
		return $passwd;

	}
    die 'Unsupported password encoding '.
      $TWiki::cfg{Htpasswd}{Encoding};
}

=pod

---++ ObjectMethod fetchPass( $login ) -> $pass
Returns encrypted password if succeeds.  Returns 0 if login is invalid. 
Returns undef otherwise.

=cut

sub fetchPass {
    my ( $this, $user ) = @_;
    ASSERT($this->isa( 'TWiki::Users::HtPasswdUser')) if DEBUG;

    if( $user ) {
        try {
            my $text = _readPasswd();
            if( $text =~ m/^$user\:(\S+)/m ) {
                return $1;
            }
            $this->{error} = 'Login invalid';
            return 0;
        } catch Error::Simple with {
            $this->{error} = $!;
            return undef;
        };
    } else {
        $this->{error} = 'No user';
        return 0;
    }
}

=pod

---++ ObjectMethod passwd( $user, $newPassU, $oldPassU ) -> $boolean
If the $oldPassU is undef, it will try to add the user, returning 0
if they are already there.

If the $oldPassU matches matches the login's password, then it will
replace it with $newPassU.

If $oldPassU is not correct and not 1, will return 0.

If $oldPassU is 1, will force the change irrespective of
the existing password, adding the user if necessary.

Otherwise returns 1 if succeeds. Returns undef on failure.

=cut

sub passwd {
    my ( $this, $user, $newUserPassword, $oldUserPassword ) = @_;
    ASSERT($this->isa( 'TWiki::Users::HtPasswdUser')) if DEBUG;

    if( defined( $oldUserPassword )) {
        unless( $oldUserPassword eq '1') {
            return 0 unless $this->checkPassword( $user, $oldUserPassword );
        }
    } else {
        if( $this->fetchPass( $user )) {
            $this->{error} = $user.' already exists';
            return 0;
        }
    }
    try {
        my $text = '';
        if( -e $TWiki::cfg{Htpasswd}{FileName} ) {
            $text = _readPasswd();
        }
        $text =~ s/^$user:.*?\r?\n//m;
        $text .= $user.':'.
          $this->encrypt( $user, $newUserPassword, 1 )."\n";
        _savePasswd( $text );
    } catch Error::Simple with {
        $this->{error} = $!;
        return undef;
    };

    $this->{error} = undef;
    return 1;
}

=pod

---++ ObjectMethod deleteUser( $user ) -> $boolean
Delete users entry in password file.
Returns 1 on success Returns undef on failure.

=cut

sub deleteUser {
    my ( $this, $user ) = @_;
    ASSERT($this->isa( 'TWiki::Users::HtPasswdUser')) if DEBUG;
    my $result = undef;
    $this->{error} = undef;

    try {
        my $text = _readPasswd();
        unless( $text =~ s/^$user:.*?\r?\n//m ) {
            $this->{error} = 'No such user '.$user;
        } else {
            _savePasswd( $text );
            $result = 1;
        }
    } catch Error::Simple with {
        $this->{error} = shift->{-text};
    };
    return $result;
}

=pod

---++ ObjectMethod checkPassword( $user, $passwordU ) -> $boolean
Finds if the password is valid for the given login.

Returns 1 if passes.  Returns 0 if fails.

=cut

sub checkPassword {
    my ( $this, $user, $password ) = @_;
    ASSERT($this->isa( 'TWiki::Users::HtPasswdUser')) if DEBUG;

    my $encryptedPassword = $this->encrypt( $user, $password );

    $this->{error} = undef;

    my $pw = $this->fetchPass( $user );
    return 1 if( defined($pw) && ($encryptedPassword eq $pw) );

    $this->{error} = 'Invalid user/password';
    return 0;
}

sub error {
    my $this = shift;

    return $this->{error};
}

1;

