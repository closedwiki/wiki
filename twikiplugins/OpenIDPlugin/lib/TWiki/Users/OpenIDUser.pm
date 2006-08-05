# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 Sven Dowideit, SvenDowideit@home.org.au
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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

---+ package TWiki::Users::OpenIDUser

implements an OpenID Consumer module for TWiki

=cut

package TWiki::Users::OpenIDUser;

use strict;
use Assert;
use Error qw( :try );
use TWiki::Users::Password;
use Net::OpenID::Consumer;
use LWPx::ParanoidAgent;
  
@TWiki::Users::OpenIDUser::ISA = qw( TWiki::Users::Password );

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

sub new {
    my( $class, $session) = @_;
    my $this = bless( $class->SUPER::new($session), $class );
    $this->{session} = $session;
    $this->{error} = undef;
    return $this;
}

=pod

---++ ObjectMethod finish
Complete processing after the client's HTTP request has been responded
to.
   1 breaking circular references to allow garbage collection in persistent
     environments

=cut

sub finish {
    my $this = shift;
    
    $this->SUPER::finish();
}

sub encrypt {
    my ( $this, $user, $passwd, $fresh ) = @_;

    ASSERT($this->isa( 'TWiki::Users::OpenIDUser')) if DEBUG;

	die 'not implemented';
}

sub fetchPass {
    my ( $this, $user ) = @_;
    ASSERT($this->isa( 'TWiki::Users::OpenIDUser')) if DEBUG;

	die 'not implemented';
}

sub passwd {
    my ( $this, $user, $newUserPassword, $oldUserPassword ) = @_;
    ASSERT($this->isa( 'TWiki::Users::OpenIDUser')) if DEBUG;

	die 'not implemented';
}

sub deleteUser {
    my ( $this, $user ) = @_;
    ASSERT($this->isa( 'TWiki::Users::OpenIDUser')) if DEBUG;

	die 'not implemented';
}

# $user == login name, not the user object
sub checkPassword {
    my ( $this, $user, $password, $encrypted) = @_;
    ASSERT($this->isa( 'TWiki::Users::OpenIDUser')) if DEBUG;
print STDERR "checkPassword";
  my $csr = Net::OpenID::Consumer->new(
#    ua    => LWPx::ParanoidAgent->new,
#    cache => Some::Cache->new,
    args  => $this->{session}->{cgiQuery},
    consumer_secret => 'notverysecret',
    required_root => $this->{session}->{urlHost}
  );

  # a user entered, say, "bradfitz.com" as their identity.  The first
  # step is to fetch that page, parse it, and get a
  # Net::OpenID::ClaimedIdentity object:

  my $claimed_identity = $csr->claimed_identity("svendowideit.myopenid.com");
print STDERR "checkPassword2: $csr->errcode\n\n";
die $csr->errcode unless (defined($claimed_identity));

  # now your app has to send them at their identity server's endpoint
  # to get redirected to either a positive assertion that they own
  # that identity, or where they need to go to login/setup trust/etc.
  
print STDERR "origurl: ".$this->{session}->getScriptUrl( 1, 'view')."\n\n";

  my $check_url = $claimed_identity->check_url(
    return_to  => $this->{session}->getScriptUrl( 1, 'view'),
    trust_root => $this->{session}->{urlHost}
  );
print STDERR "redirect to : $check_url\n\n";
	$this->{session}->redirect($check_url);
die "I obviously have no clue";	
################################	
  # so you send the user off there, and then they come back to
  # openid-check.app, then you see what the identity server said;

  if (my $setup_url = $csr->user_setup_url) {
       # redirect/link/popup user to $setup_url
  } elsif ($csr->user_cancel) {
       # restore web app state to prior to check_url
  } elsif (my $vident = $csr->verified_identity) {
       my $verified_url = $vident->url;
       print "You are $verified_url !";
  } else {
       die "Error validating identity: " . $csr->err;
  }
    
    
    
####################    
    my $encryptedPassword;
    if ((defined($encrypted)) && ($encrypted == 1)) {
        $encryptedPassword = $password;
    } else {
        $encryptedPassword = $this->encrypt( $user, $password );
    }

    $this->{error} = undef;

    my $pw = $this->fetchPass( $user );
    # $pw will be 0 if there is no pw

    return 1 if( $pw && ($encryptedPassword eq $pw) );
    # pw may validly be '', and must match an unencrypted ''. This is
    # to allow for sysadmins removing the password field in .htpasswd in
    # order to reset the password.
    return 1 if ( $pw eq '' && $password eq '' );

    $this->{error} = 'Invalid user/password';
    return 0;
}

sub error {
    my $this = shift;

    return $this->{error};
}

sub getEmails {
    my( $this, $user ) = @_;

    if( $user ) {
            my $dataset = $this->dbSelect('select * from jos_users where username = ?', $user );
            if( exists $$dataset[0] ) {
                return $$dataset[0]{email};
            }
            $this->{error} = 'Login invalid';
            return 0;
    } else {
        $this->{error} = 'No user';
        return 0;
    }

}

sub setEmails {
    my $this = shift;
    my $user = shift;
    die unless ($user);

	return 0;
}

#returns an array of user objects that relate to a email address
sub findUserByEmail {
    my $this = shift;
    my $email = shift;

    if( $email ) {
            my $dataset = $this->dbSelect('select * from jos_users where email = ?', $email );
            if( exists $$dataset[0] ) {
                my @userList = ();
                for my $row (@$dataset) {
                    push(@userList, $this->{session}->{users}->findUser( $$row{username} ));
                }
                return @userList;
            }
            $this->{error} = 'Login invalid';
            return 0;
    } else {
        $this->{error} = 'No user';
        return 0;
    }
}


1;

