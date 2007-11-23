# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006-2007 Michael Daum http://wikiring.de
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

use vars qw($isLoadedMapping);

@TWiki::Users::LdapUserMapping::ISA = qw(TWiki::Users::TWikiUserMapping);

=pod

---+++ TWiki::Users::LdapUserMapping

This class allows to use user names and groups stored in an LDAP
database inside TWiki in a transparent way. This replaces TWiki's
native way to represent users and groups using topics with
according LDAP records.

=cut

=pod 

---++++ new($session) -> $ldapUserMapping

create a new TWiki::Users::LdapUserMapping object and constructs an <nop>LdapContrib
object to delegate LDAP services to.

=cut

sub new {
  my ($class, $session) = @_;

  my $this = bless($class->SUPER::new( $session ), $class);
  $this->{ldap} = &TWiki::Contrib::LdapContrib::getLdapContrib($session);

  return $this;
}

=pod

---++++ getListOfGroups( ) -> @listOfUserObjects

Get a list of groups defined in the LDAP database. If 
=twikiGroupsBackoff= is defined the set of LDAP and native groups will
merged whereas LDAP groups have precedence in case of a name clash.

=cut

sub getListOfGroups {
  my $this = shift;

  $this->{ldap}->writeDebug("called getListOfGroups()");

  return $this->SUPER::getListOfGroups() 
    unless $this->{ldap}{mapGroups};

  my %groups;
  if ($this->{ldap}{twikiGroupsBackoff}) {
    %groups = map { $_->wikiName() => $_ } $this->SUPER::getListOfGroups();
  } else {
    %groups = ();
  }
  my $groupNames = $this->{ldap}->getGroupNames();
  if ($groupNames) {
    foreach my $groupName (@$groupNames) {
      $groups{$groupName} = $this->{session}->{users}->findUser($groupName, $groupName);
    }
  }

  #$this->{ldap}->writeDebug("got " . (scalar keys %groups) . " overall groups=".join(',',keys %groups));

  return values %groups;
}

=pod 

---++++ groupMembers($group) -> @listOfTWikiUsers

Returns a list of all members of a given group. Members are 
TWiki::User objects.

=cut

sub groupMembers {
  my ($this, $group) = @_;

  return $this->SUPER::groupMembers($group) 
    unless $this->{ldap}{mapGroups};
  return $group->{members} if defined($group->{members});

  my $groupName = $group->wikiName;

  #$this->{ldap}->writeDebug("called groupMembers for $groupName");

  my $ldapMembers;
  $ldapMembers = $this->{ldap}->getGroupMembers($groupName)
    unless $this->{ldap}{excludeMap}{$groupName};

  if (defined($ldapMembers) && @$ldapMembers) {
    my %memberUsers;
    $group->{members} = [];

    foreach my $name (@$ldapMembers) {
      my $wikiName = $this->{ldap}->getWikiNameOfLogin($name) || $name;
      my $memberUser = $this->{session}->{users}->findUser($wikiName); 

      if ($this->isGroup($memberUser)) {
        foreach my $user (@{$this->groupMembers($memberUser)}) {
          $memberUsers{$user->wikiName()} = $user;
        }
      } else {
        $memberUsers{$wikiName} = $memberUser;
      }
    }

    foreach my $name (keys %memberUsers) {
      my $user = $memberUsers{$name};
      push @{$group->{members}}, $user;
      push @{$user->{groups}}, $group;
    }

  } else {
    # fallback to twiki groups,
    # try also to find the SuperAdminGroup
    #$this->{ldap}->writeDebug("fallback to twiki groups");
    if ($this->{ldap}{twikiGroupsBackoff} 
      || $groupName eq $TWiki::cfg{SuperAdminGroup}) {
      return $this->SUPER::groupMembers($group) || [];
    } else {
      $group->{members} = [];
    }
  }

  return $group->{members};
}

=pod 

---++++ addUserToMapping($user, $me)

overrides and thus disables the SUPER method

=cut

sub addUserToMapping {
  my $this = shift;

  return $this->SUPER::addUserToMapping(@_)
    if $this->{ldap}{twikiGroupsBackoff};

  return '';
}

=pod

---++++ lookupLoginName($loginName) -> $wikiName

Map a loginName to the corresponding wikiName. This is used for lookups during
user resolution, and should be as fast as possible.

=cut

sub lookupLoginName {
  my ($this, $thisName) = @_;

  # no login names for groups
  return $thisName if $this->isGroup($thisName);

  #$this->{ldap}->writeDebug("called lookupLoginName($thisName)");

  # make all login names same case for LDAP
  my $name = lc($thisName);
  my $wikiName;
  unless ($this->{ldap}{excludeMap}{$thisName}) {
    $wikiName = $this->{ldap}->getWikiNameOfLogin($name); 
    if (defined($wikiName) && $wikiName ne '_unknown_') {
      #$this->{ldap}->writeDebug("found loginName in cache");
      return $wikiName;
    }
    $wikiName = $this->{ldap}->getLoginOfWikiName($thisName);
    if (defined($wikiName)) {
      #$this->{ldap}->writeDebug("hey, you called lookupLoginName with a wikiName");
      return undef;
    }
  }

  # fallback
  #$this->{ldap}->writeDebug("asking SUPER");
  $wikiName = $this->SUPER::lookupLoginName($thisName);
  
  return undef unless $wikiName;

  #$this->{ldap}->writeDebug("returning $wikiName");
  return $wikiName; 
}

=pod

---++++ lookupWikiName($wikiName) -> $loginName

Map a wikiName to the corresponding loginName. This is used for lookups during
user resolution, and should be as fast as possible.

=cut

sub lookupWikiName {
  my ($this, $wikiName) = @_;

  # removing leading web
  $wikiName =~ s/^.*\.(.*?)$/$1/o;

  # no login names for groups
  return $wikiName if $this->isGroup($wikiName);

  #$this->{ldap}->writeDebug("called lookupWikiName($wikiName)");

  my $loginName;
  unless ($this->{ldap}{excludeMap}{$wikiName}) {
    $loginName = $this->{ldap}->getLoginOfWikiName($wikiName);
    if (defined($loginName) && $loginName ne '_unknown_') {
      #$this->{ldap}->writeDebug("found wikiName in cache");
      return $loginName; 
    }
    $loginName = $this->{ldap}->getWikiNameOfLogin($wikiName);
    if (defined($loginName)) {
      #$this->{ldap}->writeDebug("hey, you called lookupWikiName with a loginName");
      return undef;
    }
  }

  # fallback
  #$this->{ldap}->writeDebug("asking SUPER");
  $loginName = $this->SUPER::lookupWikiName($wikiName) || '_unknown_';

  return undef if $loginName eq '_unknown_';
  return $loginName;
}

=pod

---++++ getListOfAllWikiNames() -> @wikiNames

This function gets called by the
=%<nop>GROUPS%= and the =%<nop>USERINFO{userdebug="1"}%= tags. 

=cut

sub getListOfAllWikiNames {
  my $this = shift;

  return @{$this->{ldap}->getAllWikiNames()};
}

=pod

---++++ isGroup($user) -> $boolean

Establish if a user object refers to a user group or not.
This returns true for the <nop>SuperAdminGroup or
the known LDAP groups. Finally, if =twikiGroupsBackoff= 
is set the native mechanism are used to check if $user is 
a group

=cut

sub isGroup {
  my ($this, $user) = @_;

  # may be called using a user object or a wikiName of a user
  my $wikiName = (ref $user)?$user->wikiName:$user;

  #$this->{ldap}->writeDebug("called isGroup($wikiName)");

  unless ($this->{ldap}{mapGroups}) {
    return $this->SUPER::isGroup($user) if ref $user;
    return $wikiName =~ /Group$/; # SMELL: api overdesign
  }

  # special treatment for build-in groups
  return 1 if $wikiName eq $TWiki::cfg{SuperAdminGroup};

  # ask LDAP
  my $isGroup = $this->{ldap}->isGroup($wikiName);

  # backoff if it does not know
  if (!defined($isGroup) && $this->{ldap}{twikiGroupsBackoff}) {
    $isGroup = $this->SUPER::isGroup($user) if ref $user;
    $isGroup = ($wikiName =~ /Group$/); # SMELL: api overdesign
  }

  return $isGroup;
}

=pod

---++++ getGroupMembers($name) -> \@members

Returns a list of user ids that are in a given group, undef if the group does
not exist.

=cut

sub getGroupMembers {
  my ($this, $groupName) = @_;

}


=pod

---++++ finish()

Complete processing after the client's HTTP request has been responded
to. I.e. it disconnects the LDAP database connection.

=cut

sub finish {
  my $this = shift;
    
  $this->{ldap}->finish() if $this->{ldap};
  $this->{ldap} = undef;
  $this->SUPER::finish();
}

1;
