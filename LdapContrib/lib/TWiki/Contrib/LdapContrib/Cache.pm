# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006-2007 Michael Daum http://wikiring.de
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

package TWiki::Contrib::LdapContrib::Cache;

use strict;
use Unicode::MapUTF8 qw(from_utf8);
use Storable qw(lock_store lock_retrieve);
use Net::LDAP::Control::Paged;
use Net::LDAP::Constant qw(LDAP_CONTROL_PAGED);

=pod

---+++ new() -> $cache

create a new cache object

indexes:
   * U2W, W2U: hash to map login name to wikiname
   * U2EMAILS: login -> array ref of email addr
   * DN2U, U2DN: hash to map dn to login name

   * GROUPMEMBERS: group name - array ref
   * GROUPS: hash of all groups

=cut

sub new {
  my $class = shift;
  my $ldap = shift;

  my $workingDir = $ldap->{session}->{store}->getWorkArea('LdapContrib');
  my $this = {
    ldap => $ldap,
    cacheFile => $workingDir.'/LdapCache',
  };
  bless($this, $class);

  # load
  if (-f $this->{cacheFile})  {
    $ldap->writeDebug("loading ldap cache from $this->{cacheFile}");
    $this->{data} = lock_retrieve($this->{cacheFile});
  } else {
    mkdir $workingDir unless -d $workingDir;
  }

  my $refresh = $ldap->{session}->{cgiQuery}->param('refreshldap') || '';
  $refresh = $refresh eq 'on'?1:0;

  my $maxCacheAge = $TWiki::cfg{Ldap}{MaxCacheAge};
  $maxCacheAge = 86400 unless defined $maxCacheAge; # defaults to one day

  my $cacheAge = 9999999999;
  my $now = time();
  $cacheAge = $now - $this->{data}{lastUpdate} if $this->{data};

  # clear to reload it
  if (!$this->{data} || 
      ($maxCacheAge > 0 && $cacheAge > $maxCacheAge) || 
      $refresh) {
    $ldap->writeDebug("updating cache");
    $this->refresh(1)
  }
  $ldap->writeDebug("cacheAge=$cacheAge");

  return $this;
}

=pod 

---++++ stringify() -> $string

returns a stringified version of the cache content

=cut

sub stringify {
  my $this = shift;
  use Data::Dumper;
  return Data::Dumper->Dump([$this->{data}],['cache']);
}

=pod

---++++ refresh() -> $boolean

download all relevant records from the LDAP server and
store it into a database

=cut

sub refresh {
  my ($this, $force) = @_;

  $this->{data} = {};
  $this->{data}{lastUpdate} = time();

  my $doSave = $this->refreshUsers($force);
  if ($this->{ldap}{mapGroups}) {
    $doSave = $this->refreshGroups($force) || $doSave;
  }

  return 0 unless $doSave;

  # store it
  $this->{ldap}->writeDebug("writing ldap cache to file");
  lock_store($this->{data}, $this->{cacheFile});

  return 1;
}

=pod

---++++ refreshUsers($force) -> $boolean

download all user records from the LDAP server

returns true if new records have been loaded

=cut

sub refreshUsers {
  my ($this, $force) = @_;

  $force ||= 0;
  return 0 if defined($this->{data}{U2W}) && !$force;

  $this->{ldap}->writeDebug("called refreshUsers($force)");

  # prepare search
  my $page = Net::LDAP::Control::Paged->new(size=>$this->{ldap}{pageSize});
  my $cookie;
  my @args = (
    filter=>$this->{ldap}{loginFilter}, 
    base=>$this->{ldap}{userBase},
    attrs=>[$this->{ldap}{loginAttribute}, 
            $this->{ldap}{mailAttribute},
            @{$this->{ldap}{wikiNameAttributes}}
          ],
    control=>[$page],
  );

  # read pages
  my $nrRecords = 0;
  while (1) {

    # perform search
    my $mesg = $this->{ldap}->search(@args);
    unless ($mesg) {
      $this->{ldap}->writeDebug("oops, no result");
      last;
    }

    # process each entry on a page
    while (my $entry = $mesg->pop_entry()) {
      my $loginName = $entry->get_value($this->{ldap}{loginAttribute});
      my $dn = $entry->dn();
      $loginName = lc($loginName);
      $loginName = from_utf8(-string=>$loginName, -charset=>$TWiki::cfg{Site}{CharSet})
        unless $TWiki::cfg{Site}{CharSet} =~ /^utf-?8$/i;

      # construct the wikiName
      my $wikiName;
      foreach my $attr (@{$this->{ldap}{wikiNameAttributes}}) {
        my $value = $entry->get_value($attr);
        next unless $value;
        $value = from_utf8(-string=>$value, -charset=>$TWiki::cfg{Site}{CharSet})
          unless $TWiki::cfg{Site}{CharSet} =~ /^utf-?8$/i;

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

      # get email addrs
      my $emails;
      @{$emails} = $entry->get_value($this->{ldap}{mailAttribute});

      # store it
      #$this->{ldap}->writeDebug("adding wikiName=$wikiName, loginName=$loginName");
      $this->{data}{U2W}{$loginName} = $wikiName;
      $this->{data}{W2U}{$wikiName} = $loginName;
      $this->{data}{DN2U}{$dn} = $loginName;
      $this->{data}{U2DN}{$loginName} = $dn;
      $this->{data}{U2EMAILS}{$loginName} = $emails;
      $nrRecords++;

    } # end reading entries

    # get cookie from paged control to remember the offset
    my ($resp) = $mesg->control(LDAP_CONTROL_PAGED) or last;
    $cookie = $resp->cookie or last;
    if ($cookie) {
      # set cookie in paged control
      $page->cookie($cookie);
    } else {
      # found all
      #$this->{ldap}->writeDebug("ok, no more cookie");
      last;
    }
  } # end reading pages

  # clean up
  if ($cookie) {
    $page->cookie($cookie);
    $page->size(0);
    $this->{ldap}->search(@args);
  }

  $this->{ldap}->writeDebug("got $nrRecords keys in cache");

  return 1;
}

=pod

---++++ refreshGroups($force) -> $boolean

download all group records from the LDAP server

returns true if new records have been loaded

=cut

sub refreshGroups {
  my ($this, $force) = @_;

  $force ||= 0;
  return 0 if defined($this->{data}{GROUPS}) && !$force;

  # prepare search
  my $page = Net::LDAP::Control::Paged->new(size=>$this->{ldap}{pageSize});
  my $cookie;
  my $groupAttribute = $this->{ldap}{groupAttribute};
  my $memberAttribute = $this->{ldap}{memberAttribute};
  my @args = (
    filter=>$this->{ldap}{groupFilter}, 
    base=>$this->{ldap}{groupBase}, 
    attrs=>[$groupAttribute, $memberAttribute],
    control=>[$page],
  );

  # read pages
  my $nrRecords = 0;
  while (1) {

    # perform search
    my $mesg = $this->{ldap}->search(@args);
    unless ($mesg) {
      $this->{ldap}->writeDebug("oops, no result");
      last;
    }

    # process each entry on a page
    while (my $entry = $mesg->pop_entry()) {

      my $groupName = $entry->get_value($groupAttribute);
      $groupName = from_utf8(-string=>$groupName, -charset=>$TWiki::cfg{Site}{CharSet})
        unless $TWiki::cfg{Site}{CharSet} =~ /^utf-?8$/i;

      # fetch all members of this group
      my %members;
      my $members;
      foreach my $member ($entry->get_value($memberAttribute)) {

        # groups may store DNs to members instead of a memberUid, in this case we
        # have to lookup the corresponding loginAttribute
        if ($this->{ldap}{memberIndirection}) {
          my $found = 0;
          $this->{ldap}->writeDebug("following indirection for $member");
          $member = $this->{data}{DN2U}{$member};
          unless ($member) {
            $this->{ldap}->writeDebug("oops, member not found");
            next;
          }
        }
        $members{$member} = 1;
      }
      @{$members} = sort keys %members;
      $this->{data}{GROUPS}{$groupName} = $members;

      # store it
      $nrRecords++;
    } # end reading entries

    # get cookie from paged control to remember the offset
    my ($resp) = $mesg->control(LDAP_CONTROL_PAGED) or last;
    $cookie = $resp->cookie or last;
    if ($cookie) {
      # set cookie in paged control
      $page->cookie($cookie);
    } else {
      # found all
      #$this->{ldap}->writeDebug("ok, no more cookie");
      last;
    }
  } # end reading pages

  # clean up
  if ($cookie) {
    $page->cookie($cookie);
    $page->size(0);
    $this->{ldap}->search(@args);
  }

  $this->{ldap}->writeDebug("got $nrRecords keys in cache");

  return 1;
}

1;
