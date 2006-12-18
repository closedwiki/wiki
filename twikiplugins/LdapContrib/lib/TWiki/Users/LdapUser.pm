# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 Michael Daum http://wikiring.com
# Portions Copyright (C) 2006 Spanlink Communications
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

package TWiki::Users::LdapUser;

use strict;
use TWiki::Users::Password;
use TWiki::Contrib::LdapContrib;

use vars qw(%U2DN %U2EMAILS $debug);

@TWiki::Users::LdapUser::ISA = qw( TWiki::Users::Password );
$debug = 0; # toggle me

=pod

---+++ TWiki::Users::LdapUser

Password manager that uses Net::LDAP to manage users and passwords.

Subclass of [[TWikiUsersPasswordDotPm][ =TWiki::Users::Password= ]].

This class does not grant any write access to the ldap server for security reasons. 
So you need to use your ldap tools to create user accounts or change passwords.

Configuration: add the following variables to your <nop>LocalSite.cfg 
   * $TWiki::cfg{Ldap}{server} = &lt;ldap-server uri>, defaults to localhost
   * $TWiki::cfg{Ldap}{base} = &lt;base dn> subtree that holds the user accounts
     e.g. ou=people,dc=your,dc=domain,dc=com

Implemented Interface:
   * checkPassword(login, password)
   * error()
   * fetchPass(login)
   * getEmails(login)
   * setEmails(login, @emails)
   
=cut

sub writeDebug {
  # comment me in/out
  print STDERR "LdapUser - $_[0]\n" if $debug;
}

=pod

---++++ new($session) -> $ldapUser

Takes a session object, creates an LdapContrib object used to
delegate LDAP calls and returns a new TWiki::User::LdapUser object

=cut

sub new {
  my ($class, $session) = @_;

  my $this = bless($class->SUPER::new( $session ), $class);
  $this->{ldap} = &TWiki::Contrib::LdapContrib::getLdapContrib();

  # explicitly refresh the ldap cache
  my $refresh = $session->{cgiQuery}->param('refreshldap') || '';
  if ($refresh eq 'on') {
    %U2DN = ();
    %U2EMAILS = ();
  }

  return $this;
}

=pod

---++++ error() -> $errorMsg

return the last error during LDAP operations

=cut

sub error {
  my $this = shift;
  return $this->{ldap}->getError();
}

=pod 

---++++ fetchPass($login) -> $passwd

SMELL: this method is used most of the time to detect if a given
login user is known to the database. the concrete (encrypted) password 
is of no interest: so better would be to implement an interface like
existsUser() or the like

=cut

sub fetchPass {
  my ($this, $login) = @_;

  #writeDebug("called fetchPass($login)");

  my $entry = $this->{ldap}->getAccount($login);
  return $entry->get_value('userPassword') if $entry;
  return 0;
}

=pod 

---++++ checkPassword($login, $password) -> $boolean

check passwd by binding to the ldap server

=cut

sub checkPassword {
  my ($this, $login, $passU) = @_;

  #writeDebug("called checkPassword($login, passU)");

  # guest has no password
  return 1 if $login eq $TWiki::cfg{DefaultUserWikiName};


  # lookup cache
  if (defined($U2DN{$login})) {
    #writeDebug("found dn for $login in cache: $U2DN{$login}");
  } else {
    $U2DN{$login} = '';
    my $entry = $this->{ldap}->getAccount($login);
    if ($entry) {
      $U2DN{$login} = $entry->dn();
    } else {
      return 0;
    }
  }
  return $this->{ldap}->connect($U2DN{$login}, $passU);
}

=pod 

---++++ getEmails($login) -> @emails

emails might be stored in the ldap account as well if
the record is of type possixAccount and inetOrgPerson.
if this is not the case we fallback to twiki's default behavior

=cut

sub getEmails {
  my ($this, $login) = @_;

  #writeDebug("getEmails($login)");

  # guest has no email addrs
  return () if $login eq $TWiki::cfg{DefaultUserWikiName};

  # lookup cache
  if (defined($U2EMAILS{$login})) {
    #writeDebug("found emails for $login in cache: ".join(',',@{$U2EMAILS{$login}}));
  } else {
    $U2EMAILS{$login} = [];
    my $entry = $this->{ldap}->getAccount($login);
    if ($entry) {
      @{$U2EMAILS{$login}} = $entry->get_value('mail');
    }
  }
  return @{$U2EMAILS{$login}} if $U2EMAILS{$login};

  # fall back to the default approach
  return $this->SUPER::getEmails($login);
}

=pod ObjectMethod finish()

Complete processing after the client's HTTP request has been responded.
i.e. destroy the ldap object.

=cut

sub finish {
  my $this = shift;

  $this->{ldap}->disconnect() if $this->{ldap};
  $this->{ldap} = undef;

  # for safety call the SUPER finisher
  $this->SUPER::finish();
}

1;
