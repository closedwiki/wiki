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

package TWiki::Users::LdapUserMapping;

use strict;
use TWiki::Users::TWikiUserMapping;
use TWiki::Contrib::LdapContrib;

@TWiki::Users::LdapUserMapping::ISA = qw(TWiki::Users::TWikiUserMapping);

=pod

---+++ class TWiki::Users::LdapUserMapping

This class allows to use user names and groups stored in an LDAP
database inside TWiki in a transparent way. This replaces TWiki's
native way to represent users and groups using topics with
according LDAP records.

=cut

sub writeDebug {
  # comment me in/out
  #print STDERR "LdapUserMapping - $_[0]\n";
}

=pod 

---++++ new($session)

create a new <nop>LdapUserMapping object and constructs an <nop>LdapContrib
object to delegate LDAP services to.

=cut

sub new {
  my ($class, $session) = @_;

  my $this = bless($class->SUPER::new( $session ), $class);
  $this->{ldap} = new TWiki::Contrib::LdapContrib;

  return $this;
}

=pod

---++++ Object Method getListOfGroups( ) -> @listOfUserObjects

Get a list of groups defined in the LDAP database. If 
=twikiGroupsBackoff= is defined the set of LDAP and native groups will
merged whereas LDAP groups have precedence in case of a name clash.

=cut

sub getListOfGroups {
  my $this = shift;

  #writeDebug("called getListOfGroups()");
  my %groups;
  if ($this->{ldap}->{twikiGroupsBackoff}) {
    %groups = map { $_->wikiName() => $_ } $this->SUPER::getListOfGroups();
    #writeDebug("got " . (scalar @$groups) . " twiki groups=".join(',',@$groups));
  }
  foreach my $groupName ($this->{ldap}->getGroupNames()) {
    $groups{$groupName} = $this->{session}->{users}->findUser($groupName);
  }

  #writeDebug("got " . (scalar keys %groups) . " overall groups=".join(',',keys %groups));

  return values %groups;
}

=pod 

---++++ Object Method groupMembers($group)

Returns a list of all members of a given group. Members are 
TWiki::User objects.

=cut

sub groupMembers {
  my ($this, $group) = @_;

  #writeDebug("called groupMembers(".$group->wikiName().")");

  if (!defined $group->{members}) {
    my $members = $this->{ldap}->getGroupMembers($group->wikiName);
    if (defined($members)) {
      $group->{members} = [];
      foreach my $member (@$members) {
	push @{$group->{members}},$this->{session}->{users}->findUser($member);
      }
    } else {
      # fallback to twiki groups
      if ($this->{ldap}->{twikiGroupsBackoff}) {
	return $this->SUPER::groupMembers($group);
      }
    }
  }

  return $group->{members};
}

=pod 

---++++ addUserToMapping($user, $me)

overrides and thus disables the SUPER method

=cut

sub addUserToMapping {
    my ( $this, $user, $me ) = @_;

    return '';
}

=pod 

---++++ _loadMapping()

overrides internal SUPER method called by 
TWiki::Users::TWikiUserMapping::lookupWikiName and
TWiki::Users::TWikiUserMapping::lookupLoginName while
filling the internal mapping cache.

=cut

sub _loadMapping {
  my $this = shift;

  return if $this->{CACHED};
  $this->{CACHED} = 1;

  my $accounts = $this->{ldap}->getAccounts();
  return unless $accounts;

  my $web = $TWiki::cfg{UsersWebName};
  while (my $entry = $accounts->pop_entry()) {
    my $loginName = $entry->get_value($this->{ldap}{loginAttribute});
    my $wikiName = $entry->get_value($this->{ldap}{wikiNameAttribute});
    if ($this->{ldap}->{wikiNameRemoveWhiteSpace}) {
      $wikiName =~ s/ //go;
    }
    my $wikiUserName = $web.'.'.$wikiName;
    $this->{U2W}{$loginName} = $wikiUserName;
    $this->{W2U}{$wikiUserName} = $loginName;
  }
}

=pod

---++++ isGroup($user)

Establish if a user object refers to a user group or not.
This returns true for the <nop>SuperAdminGroup or
the known LDAP groups. Finally, if =twikiGroupsBackoff= 
is set the native mechanism are used to check if $user is 
a group

=cut

sub isGroup {
  my ($this, $user) = @_;

  # special treatment for build-in groups
  return 1 
    if $user->wikiName eq $TWiki::cfg{SuperAdminGroup};

  # check ldap groups
  return 1 
    if $this->{ldap}->isGroup($user);

  # backoff
  return $this->SUPER::isGroup($user) 
    if $this->{ldap}->{twikiGroupsBackoff};

  return 0;
}

=pod

---++ Object Method finish

Complete processing after the client's HTTP request has been responded
to. I.e. it disconnects the LDAP database connection.

=cut

sub finish {
  my $this = shift;
    
  $this->{ldap}->disconnect() if $this->{ldap};
  $this->{ldap} = undef;
  $this->SUPER::finish();
}

1;
