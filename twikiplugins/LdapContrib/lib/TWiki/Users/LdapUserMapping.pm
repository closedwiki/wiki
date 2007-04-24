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
use Unicode::MapUTF8 qw(from_utf8);

use Net::LDAP::Constant qw( LDAP_CONTROL_PAGED );

use vars qw(%LDAP_U2W %LDAP_W2U %LDAP_DN2U %ISMEMBEROF %ISGROUP %GROUPMEMBERS 
  $cacheHits $isLoadedMapping
);

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
  $this->{ldap} = &TWiki::Contrib::LdapContrib::getLdapContrib();

  $this->{maxCacheHits} = defined($TWiki::cfg{Ldap}{MaxCacheHits})?
    $TWiki::cfg{Ldap}{MaxCacheHits}:-1;

  my $refresh = $session->{cgiQuery}->param('refreshldap') || '';
    # explicitly refresh the ldap cache

  if (defined $cacheHits && $cacheHits != 0 && $refresh ne 'on') {
    $cacheHits--; 
  } else {
    # resetting cache
    $isLoadedMapping = 0;
    $cacheHits = $this->{maxCacheHits};
    %LDAP_U2W = (); # mapping of loginNames to WikiNames
    %LDAP_W2U = (); # mapping of WikiNames to loginNames
    %LDAP_DN2U = (); # mapping of DistinguishedNames to loginNames
    %ISMEMBEROF = ();
    %GROUPMEMBERS = ();
    %ISGROUP = ();
  }

  $this->{ldap}->writeDebug("cacheHits=$cacheHits");

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

  unless ($this->{ldap}{mapGroups}) {
    return $this->SUPER::getListOfGroups();
  }

  $this->{ldap}->writeDebug("called getListOfGroups()");
  my %groups;
  if ($this->{ldap}{twikiGroupsBackoff}) {
    %groups = map { $_->wikiName() => $_ } $this->SUPER::getListOfGroups();
  } else {
    %groups = ();
  }
  foreach my $groupName ($this->{ldap}->getGroupNames()) {
    $groups{$groupName} = $this->{session}->{users}->findUser($groupName, $groupName);
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

  unless ($this->{ldap}{mapGroups}) {
    return $this->SUPER::groupMembers($group);
  }

  unless (defined($group->{members})) {
    $this->{ldap}->writeDebug("called groupMembers(".$group->wikiName().")");

    my $members = $this->getGroupMembers($group->wikiName);
    if (defined($members)) {
      $group->{members} = [];
      #$this->{ldap}->writeDebug("found ".scalar(@$members)." members:".join(', ', @$members));
      foreach my $member (@$members) {
        my $memberUser = $this->{session}->{users}->findUser($member); ## provide the wikiName
        push @{$group->{members}}, $memberUser if $memberUser;
	push @{$memberUser->{groups}}, $group; # backlink the user to the group
      }
    } else {
      # fallback to twiki groups
      if ($this->{ldap}{twikiGroupsBackoff}) {
        return $this->SUPER::groupMembers($group) || [];
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

---++++ lookupLoginName($loginName) -> $wikiName

Map a loginName to the corresponding wikiName. This is used for lookups during
user resolution, and should be as fast as possible.

=cut

sub lookupLoginName {
  my ($this, $name) = @_;

  $this->{ldap}->writeDebug("called lookupLoginName($name)");

  unless ($this->{ldap}{excludeMap}{$name}) {
    # load the mapping in parts as long as needed
    while (1) {
      if (defined($LDAP_U2W{$name}) && $LDAP_U2W{$name} ne '_unknown_') {
	$this->{ldap}->writeDebug("found loginName in cache");
	return $LDAP_U2W{$name};
      }
      if (defined($LDAP_W2U{$name})) {
	$this->{ldap}->writeDebug("hey, you called lookupLoginName with a wikiName");
	return $name;
      }
      last if $isLoadedMapping;
      $this->loadLdapMapping();
    }
  }

  if (defined($LDAP_U2W{$name}) && $LDAP_U2W{$name} ne '_unknown_') {
    $this->{ldap}->writeDebug("found loginName in cache again");
    return $LDAP_U2W{$name};
  }
  if (defined($LDAP_W2U{$name})) {
    $this->{ldap}->writeDebug("hey, you called lookupLoginName with a wikiName again");
    return $name;
  }
  
  $this->{ldap}->writeDebug("asking SUPER");
  my $wikiName = $this->SUPER::lookupLoginName($name) || $name;
  $wikiName =~ s/^(.*)\.(.*?)$/$2/;
  $this->{ldap}->writeDebug("got wikiName=$wikiName and loginName=$name");
  $LDAP_U2W{$name} = $wikiName;
  $LDAP_W2U{$wikiName} = $name;

  return undef if $wikiName eq '_unknown_';
  return $wikiName; 
}

=pod

---++++ lookupWikiName($wikiName) -> $loginName

Map a wikiName to the corresponding loginName. This is used for lookups during
user resolution, and should be as fast as possible.

=cut

sub lookupWikiName {
  my ($this, $name) = @_;

  # removing leading web
  $name =~ s/^.*\.(.*?)$/$1/o;

  $this->{ldap}->writeDebug("called lookupWikiName($name)");

  unless ($this->{ldap}{excludeMap}{$name}) {
    while (1) {
      # load the mapping in parts as long as needed
      if (defined($LDAP_W2U{$name}) && $LDAP_W2U{$name} ne '_unknown_') {
	$this->{ldap}->writeDebug("found wikiName in cache");
        return $LDAP_W2U{$name} 
      }
      if (defined($LDAP_U2W{$name})) {
	$this->{ldap}->writeDebug("hey, you called lookupWikiName with a loginName");
        return $name
      }
      last if $isLoadedMapping;
      $this->loadLdapMapping();
    }
  }

  if (defined($LDAP_W2U{$name}) && $LDAP_W2U{$name} ne '_unknown_') {
    $this->{ldap}->writeDebug("found wikiName in cache again");
    return $LDAP_W2U{$name};
  }
  if (defined($LDAP_U2W{$name})) {
    $this->{ldap}->writeDebug("hey, you called lookupWikiName with a loginName again");
    return $name
  }

  $this->{ldap}->writeDebug("asking SUPER");
  my $loginName = $this->SUPER::lookupWikiName($name) || '_unknown_';
  $this->{ldap}->writeDebug("got wikiName=$name and loginName=$loginName");
  $LDAP_U2W{$loginName} = $name;
  $LDAP_W2U{$name} = $loginName;

  return undef if $loginName eq '_unknown_';
  return $loginName;
}

=pod

---++++ lookupDistinguishedName($dn) -> $loginName

Map a DN to the corresponding loginName. This is used for getting
members of a group where their membership is stored as a DN but we need
the loginName.

=cut

sub lookupDistinguishedName {
  my ($this, $dn) = @_;

  $this->{ldap}->writeDebug("called lookupDistinguishedName($dn)");

  while (1) {
    # load the mapping in parts as long as needed
    return $LDAP_DN2U{$dn} if defined($LDAP_DN2U{$dn});
    last if $isLoadedMapping;
    $this->loadLdapMapping();
  }

  return undef; # not found
}

=pod

---++++ loadLdapMapping() -> $boolean

This is the workhorse of this module, loading user objects on demand
and harvest the needed information into internal caches.
Returns true if an additional page of results was fetched, and
false if the search result has been cached completely.

=cut

sub loadLdapMapping {
  my $this = shift;

  $this->{ldap}->writeDebug("called loadLdapMapping()");
  if ($isLoadedMapping) {
    $this->{ldap}->writeDebug("already loaded");
    return 0;
  } 
  $this->{ldap}->writeDebug("need to fetch mapping");

  # prepare search
  $this->{_page} = $this->{ldap}->getPageControl() 
    unless $this->{_page}; 

  my @args = (
    filter=>$this->{ldap}{loginFilter}, 
    base=>$this->{ldap}{userBase},
    attrs=>[$this->{ldap}{loginAttribute}, @{$this->{ldap}{wikiNameAttributes}}],
    control=>[$this->{_page}],
  );

  # do it
  my $mesg = $this->{ldap}->search(@args);
  unless ($mesg) {
    $this->{ldap}->writeDebug("oops, no result");
    $isLoadedMapping = 1;
  } else {

    # insert results into the mapping
    while (my $entry = $mesg->pop_entry()) {
      my $loginName = $entry->get_value($this->{ldap}{loginAttribute});
      $loginName = from_utf8(-string=>$loginName, -charset=>$TWiki::cfg{Site}{CharSet});
      my $dn = $entry->dn();

      # construct the wikiName
      my $wikiName;
      foreach my $attr (@{$this->{ldap}{wikiNameAttributes}}) {
        my $value = $entry->get_value($attr);
        next unless $value;
        $value = from_utf8(-string=>$value, -charset=>$TWiki::cfg{Site}{CharSet});
        unless ($this->{ldap}{normalizeWikiName}) {
          $wikiName .= $value;
          next;
        }

        # normalize the parts of the wikiName
        $value =~ s/@.*//o if $attr eq 'mail'; 
          # remove @mydomain.com part for special mail attrs
          # SMELL: you may have a different attribute name for the email address
        
        # replace umlaute
        $value =~ s/ä/ae/go;
        $value =~ s/ö/oe/go;
        $value =~ s/ü/ue/go;
        $value =~ s/Ä/Ae/go;
        $value =~ s/Ö/Oe/go;
        $value =~ s/Ü/Ue/go;
        $value =~ s/ß/ss/go;
        foreach my $part (split(/[^$TWiki::regex{mixedAlphaNum}]/, $value)) {
          $wikiName .= ucfirst($part);
        }
      }
      $wikiName ||= $loginName;

      $this->{ldap}->writeDebug("adding wikiName=$wikiName, loginName=$loginName");
      $LDAP_U2W{$loginName} = $wikiName;
      $LDAP_W2U{$wikiName} = $loginName;
      $LDAP_DN2U{$dn} = $loginName;
    }

    # get cookie from paged control to remember the offset
    my ($resp) = $mesg->control(LDAP_CONTROL_PAGED);
    if ($resp) {

      $this->{_cookie} = $resp->cookie;
      if ($this->{_cookie}) {
        # set cookie in paged control
        $this->{_page}->cookie($this->{_cookie});
      } else {

        # found all
        #$this->{ldap}->writeDebug("ok, no more cookie");
        $isLoadedMapping = 1;
      }
    } else {

      # never reach
      $this->{ldap}->writeDebug("oops, no resp");
      $isLoadedMapping = 1;
    }
  }

  # clean up error cases
  if ($isLoadedMapping && $this->{_cookie}) {
    $this->{ldap}->writeDebug("cleaning up page");
    $this->{_page}->cookie($this->{_cookie});
    $this->{_page}->size(0);
    $this->{ldap}->search(@args);
    return 0;
  }

  if ($this->{ldap}{debug}) {
    $this->{ldap}->writeDebug("got ".scalar(keys %LDAP_U2W)." keys in cache");
  }

  return 1;
}

=pod

---++++ getListOfAllWikiNames() -> @wikiNames

CAUTION: This function is rarely used if at all. Asking large LDAP directories
for all of their content is insane anyway.  This function gets called by the
=%<nop>GROUPS%= and the =%<nop>USERINFO{userdebug="1"}%= tags. These should be avoided,
i.e. better remove the =%<nop>GROUPS%= tag from the Main.TWikiGroups topic in such cases.
Better use a TWikiApplication build on top of the TWiki:Plugins/LdapNgPlugin
that is able to display groups and members in a paginated way.

=cut

sub getListOfAllWikiNames {
  my $this = shift;

  $this->{ldap}->writeDebug("called getListOfAllWikiNames");
  while($this->loadLdapMapping()) {}
  return keys %LDAP_W2U;
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

  unless ($this->{ldap}{mapGroups}) {
    return $this->SUPER::isGroup($user) if ref $user;
    return $wikiName =~ /Group$/; # SMELL: api overdesign
  }

  # special treatment for build-in groups
  return 1 if $wikiName eq $TWiki::cfg{SuperAdminGroup};

  # check cache
  unless ($ISGROUP{user}) {
    # check ldap groups
    $ISGROUP{$user} = $this->{ldap}->isGroup($user) || 0;
  }

  # backoff
  if (!$ISGROUP{$user} && $this->{ldap}{twikiGroupsBackoff}) {
    return $this->SUPER::isGroup($user)  if ref $user;
    return $wikiName =~ /Group$/; # SMELL: api overdesign
  }

  return $ISGROUP{$user};
}

=pod

---++++ isMemberOf($user, $group) -> $boolean

Returns true if the $user is a member of the $group. Note, that both
$user and $group can either be a WikiName or a reference to a User object

=cut

sub isMemberOf {
    my ($this, $user, $group) = @_;

    unless ($this->{ldap}{mapGroups}) {
      # don't use ldap groups 
      return $this->SUPER::isMemberOf($user, $group);
    }

    # get names
    my $loginName;
    if (ref $user) {
      $loginName = $user->login;
    } else {
      $loginName = $this->lookupWikiName($user) || $user;
    }

    my $groupName = (ref $group)?$group->login:$group;
    return $this->SUPER::isMemberOf($user, $group) 
      if $this->{ldap}{excludeMap}{$loginName} || 
         $this->{ldap}{excludeMap}{$groupName};

    # lookup the membership cache first
    my $key = "$loginName:$groupName";
    return $ISMEMBEROF{$key} if defined $ISMEMBEROF{$key};

    # get membership info
    $ISMEMBEROF{$key} = 0;
    my $groupMembers = $this->getGroupMembers($groupName);
    if ($groupMembers) {
      foreach my $member (@$groupMembers) {
        if ($member eq $loginName) {
          $ISMEMBEROF{$key} = 1;
          last;
        }
      }
    }

    # backoff
    if (!$ISMEMBEROF{$key} && $this->{ldap}{twikiGroupsBackoff}) {
      $ISMEMBEROF{$key} = $this->SUPER::isMemberOf($user, $group);
    }

    return $ISMEMBEROF{$key};
}

=pod

---++++ getGroupMembers($name) -> \@members

Returns a list of user ids that are in a given group, undef if the group does
not exist.

=cut

sub getGroupMembers {
  my ($this, $groupName) = @_;

  $this->{ldap}->writeDebug("called getGroupMembers($groupName)");
  return undef if $this->{ldap}{excludeMap}{$groupName};

  # lookup cache
  return $GROUPMEMBERS{$groupName} if defined($GROUPMEMBERS{$groupName});

  my $groupEntry = $this->{ldap}->getGroup($groupName);
  return undef unless $groupEntry;

  $this->{ldap}->writeDebug("this is an ldap group");

  # fetch all members
  my @members = ();
  foreach my $member ($groupEntry->get_value($this->{ldap}{memberAttribute})) {
    $member = from_utf8(-string=>$member, -charset=>$TWiki::cfg{Site}{CharSet});

    $this->{ldap}->writeDebug("found member=$member");

    # groups may store DNs to members instead of a memberUid, in this case we
    # have to lookup the corresponding loginAttribute
    if ($this->{ldap}{memberIndirection}) {
      my $found = 0;
      $this->{ldap}->writeDebug("following indirection");
      while(1) {
        if (defined($LDAP_DN2U{$member})) {
          $found = 1;
          $member = $LDAP_DN2U{$member};
          last;
        }
        last unless $this->loadLdapMapping();
      }
      next unless $found;
    }
    push @members,$member;
  }

  $GROUPMEMBERS{$groupName} = \@members;
  return \@members;
}


=pod

---++++ finish()

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
