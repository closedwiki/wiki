# Module of TWiki - The Free and Open Source Wiki, http://twiki.org/
#
# Copyright (C) 2007-2010 Michael Daum http://michaeldaumconsulting.com
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
package TWiki::LoginManager::LdapApacheLogin;

use strict;
use Assert ();
use TWiki::LoginManager::ApacheLogin ();
use TWiki::Contrib::LdapContrib ();
use TWiki::Sandbox ();

@TWiki::LoginManager::LdapApacheLogin::ISA = qw( TWiki::LoginManager::ApacheLogin );

sub new {
  my ($class, $session) = @_;

  my $this = bless( $class->SUPER::new($session), $class );

  $this->{ldap} = TWiki::Contrib::LdapContrib::getLdapContrib($session);
  return $this;
}

sub loadSession {
  my $this = shift;

  my $authUser = $this->SUPER::loadSession(@_);

  # explicitly untaint it as this string comes from LDAP, and all strings
  # from LDAP are tainted, even if they come via mod_ldap
  $authUser = TWiki::Sandbox::untaintUnchecked($authUser);

  # process authUser login name
  if (defined $authUser) {

    #print STDERR "before authUser=$authUser\n";

    $authUser =~ s/^\s+//o;
    $authUser =~ s/\s+$//o;
    $authUser = $this->{ldap}->fromUtf8($authUser);

    $authUser = $this->{ldap}->normalizeLoginName($authUser) if $this->{ldap}{normalizeLoginName};

    #print STDERR "after authUser=$authUser\n";

    unless ($this->{ldap}{excludeMap}{$authUser}) {
      $this->{ldap}->checkCacheForLoginName($authUser);
    }
  }

  return $authUser;
}

1;
