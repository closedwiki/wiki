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

=pod

---+ package TWiki::Client::OpenIDLogin



This is a login manager that you can specify in the security setup section of [[%SCRIPTURL%/configure%SCRIPTSUFFIX%][configure]].
 It provides users with a template-based form to enter usernames and passwords, and works with the PasswordManager that you specify to verify those passwords.

Subclass of TWiki::Client; see that class for documentation of the
methods of this class.

=cut

package TWiki::Client::OpenIDLogin;

use strict;
use Assert;
use TWiki::Client::TemplateLogin;
use Net::OpenID::Consumer;
use LWPx::ParanoidAgent;

@TWiki::Client::OpenIDLogin::ISA = ( 'TWiki::Client::TemplateLogin' );

sub new {
    my( $class, $session ) = @_;

    my $this = bless( $class->SUPER::new($session), $class );
    $session->enterContext( 'can_login' );
    return $this;
}

=pod

---++ ObjectMethod loadSession()



=cut

sub loadSession {
    my $this = shift;
    my $twiki = $this->{twiki};
    my $query = $twiki->{cgiQuery};

    ASSERT($this->isa( 'TWiki::Client::OpenIDLogin')) if DEBUG;

	#not an openID login attempt
	return $this->SUPER::loadSession() unless (defined($twiki->{cgiQuery}->param('oic.time')));
    
    my $authUser = '';
  my $csr = Net::OpenID::Consumer->new(
#    ua    => LWPx::ParanoidAgent->new,
#    cache => Some::Cache->new,
    args  => $twiki->{cgiQuery},
    consumer_secret => 'notverysecret',
    required_root => $twiki->{urlHost},
  );

print STDERR 'OKOK(loadSession)'.$csr->args;
 

  # so you send the user off there, and then they come back to
  # openid-check.app, then you see what the identity server said;
  if (my $setup_url = $csr->user_setup_url) {
       # redirect/link/popup user to $setup_url
       print STDERR "why are se setting up? ".$csr->user_setup_url;
       
	$twiki->redirect($csr->user_setup_url);
die "I obviously have no clue (AGAIN)";	
       
  } elsif ($csr->user_cancel) {
       # restore web app state to prior to check_url
  } elsif (my $vident = $csr->verified_identity) {
       my $verified_url = $vident->url;
       print STDERR "You are $verified_url - also known as (".$vident->display.") !";
       $authUser = $vident->display;
       $authUser =~ s/([^.]*)\..*/$1/;
       print STDERR "hello : $authUser";
  } else {
  	 $authUser = $this->SUPER::loadSession();
#       die "Error validating identity: " . $csr->err;
  }
    
    return $authUser;
}

1;
