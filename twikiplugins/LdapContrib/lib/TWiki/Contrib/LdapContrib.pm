# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 MichaelDaum@WikiRing.com
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

package TWiki::Contrib::LdapContrib;

use strict;
use Net::LDAP;
use Net::LDAP::Constant qw(LDAP_SUCCESS);
use Digest::MD5 qw( md5_hex );

use vars qw($VERSION $RELEASE);

$VERSION = '$Rev$';
$RELEASE = 'v0.5';

=begin text

---+++ class LdapContrib

General LDAP services for TWiki. This class encapsulates the TWiki-specific
means to integrate an LDAP directory service.  Used by TWiki::Users::LdapUser
for authentication, TWiki::Users::LdapUserMapping for group definitions and
TWiki::Plugins::LdapNgPlugin to interface general query services.

Typical usage:
<verbatim>
my $ldap = new TWiki::Contrib::LdapContrib;

my $result = $ldap->search('mail=*@gmx*');
my $errorMsg = $ldap->getError();

my $count = $result->count();

my @entries = $result->sorted('sn');
my $entry = $result->entry(0);

my $value = $entry->get_value('cn');
my @emails = $entry->get_value('mail');
</verbatim>

=cut

# static method to write debug messages.
sub writeDebug {
  # comment me in/out
  #print STDERR "LdapContrib - $_[0]\n";
}


=begin text

---++++ new(host=>'...', base=>'...', ...)

Construct a new LdapContrib object

Possible options are:
   * host: ip address (or hostname) 
   * base: the base DN to use in searches
   * port: port address used when binding to the LDAP server
   * version: protocol version 
   * basePasswd: sub-tree DN of user accounts
   * baseGroup: sub-tree DN of group definitions
   * loginAttribute: user login name attribute
   * loginFilter: filter to be used to find login accounts
   * groupAttribute: the group name attribute 
   * groupFilter: filter to be used to find groups
   * memberAttribute: the attribute that should be used to collect group members
   * bindDN: the dn to use when binding to the LDAP server
   * bindPassword: the password used when binding to the LDAP server
   * ssl: negotiate ssl when binding to the server

Options not passed to the constructor are taken from the global settings
in =lib/LocalSite.cfg=.

=cut

sub new {
  my $class = shift;

  writeDebug("called LdapUser constuctor");

  my $this = {
    ldap=>undef,# connect later
    error=>undef,
    host=>$TWiki::cfg{Ldap}{Host} || 'localhost',
    base=>$TWiki::cfg{Ldap}{Base} || '',
    port=>$TWiki::cfg{Ldap}{Port} || 389,
    version=>$TWiki::cfg{Ldap}{Version} || 3,
    basePasswd=>$TWiki::cfg{Ldap}{BasePasswd} || '',
    baseGroup=>$TWiki::cfg{Ldap}{BaseGroup} || '',
    loginAttribute=>$TWiki::cfg{Ldap}{LoginAttribute} || 'uid',
    wikiNameAttribute=>$TWiki::cfg{Ldap}{WikiNameAttribute} || 'cn',
    wikiNameRemoveWhiteSpace=>$TWiki::cfg{Ldap}{WikiNameRemoveWhiteSpace},
    loginFilter=>$TWiki::cfg{Ldap}{LoginFilter} || 'objectClass=posixAccount',
    groupAttribute=>$TWiki::cfg{Ldap}{GroupAttribute} || 'cn',
    groupFilter=>$TWiki::cfg{Ldap}{GroupFilter} || 'objectClass=posixGroup',
    memberAttribute=>$TWiki::cfg{Ldap}{MemberAttribute} || 'memberUid',
    memberIndirection=>$TWiki::cfg{Ldap}{MemberIndirection} || 0,
    twikiGroupsBackoff=>$TWiki::cfg{Ldap}{TWikiGroupsBackoff} || 0,
    bindDN=>$TWiki::cfg{Ldap}{BindDN} || '',
    bindPassword=>$TWiki::cfg{Ldap}{BindPassword} || '',
    ssl=>$TWiki::cfg{Ldap}{SSL} || 0,
    @_
  };

  $this->{basePasswd} = 'ou=people,'.$this->{base} unless $this->{basePasswd};
  $this->{baseGroup} = 'ou=group,'.$this->{base} unless $this->{baseGroup};
  %{$this->{groupNames}} = (); # caches known groups
  $this->{cachedGroupNames} = 0; # flag to indicate that the cache is filled

  return bless($this, $class);
}

=begin text

---++++ connect($login, $passwd)

Connect to LDAP server. If a $login name and a $passwd is given then a bind is done.
Otherwise the communication is anonymous. You don't have to connect() explicitely
by calling this method. The methods below will do that automatically when needed.

=cut

sub connect {
  my ($this, $login, $passwd) = @_;
  return if $this->{ldap};

  #writeDebug("called connect");

  $this->{ldap} = Net::LDAP->new($this->{host},
    port=>$this->{port},
    version=>$this->{version},
  );
  die $@ if $@;
  unless ($this->{ldap}) {
    $this->{error} = "failed to connect to $this->{host}";
    return 0;
  }

  # authenticated bind
  if (defined($login)) {
    die "illegal call to connect()" unless defined($passwd);
    my $msg = $this->{ldap}->bind(
      "$this->{loginAttribute}=$login,$this->{basePasswd}", 
      password=>$passwd
    );
    #writeDebug("bind for $login");
    return ($this->_checkError($msg) == LDAP_SUCCESS)?1:0;
  } 

  # proxy user 
  if ($this->{bindDN} && $this->{bindPassword}) {
    my $msg = $this->{ldap}->bind($this->{bindDN},password=>$this->{bindPassword});
    #writeDebug("proxy bind");
    return ($this->_checkError($msg) == LDAP_SUCCESS)?1:0;
  }
  
  # anonymous bind
  #writeDebug("anonymous bind");
  return 1
}

=begin text

---++++ disconnect()

Unbind the LDAP object from the server. This method can be used to force
a reconnect and possibly rebind as a different user.

=cut

sub disconnect {
  my $this = shift;

  #writeDebug("called disconnect()");
  return unless $this->{ldap};

  $this->{ldap}->unbind();
  $this->{ldap} = undef;
}


=begin text

---++++ _checkError($msg)

Private method to check a Net::LDAP::Message object for an error, sets
$ldap->{error} and returns the ldap error code. This method is called
internally whenever a message object is returned by the server. Use
$ldap->getError() to return the actual error message.

=cut

sub _checkError {
  my ($this, $msg) = @_;

  my $code = $msg->code();
  if ($code == LDAP_SUCCESS) {
    $this->{error} = undef;
  } else {
    $this->{error} = $code.': '.$msg->error();
    #writeDebug('LdapUser - '.$this->{error});
  } 
 
  return $code;
}

=begin text

---++++ getError()

Returns the error message of the last LDAP action or undef it no
error occured.

=cut

sub getError {
  my $this = shift;
  return $this->{error};
}


=begin text

---+++ getAccount($login)

Fetches an account entry from the database and returns a Net::LDAP::Entry
object on success and undef otherwise. Note, the login name is match against
the attribute defined in $ldap->{loginAttribute}. Account records are 
search using $ldap->{loginFilter} in the subtree defined by $ldap->{basePasswd}.

=cut

sub getAccount {
  my ($this, $login) = @_;

  my $filter = '(&('.$this->{loginFilter}.')('.$this->{loginAttribute}.'='.$login.'))';
  my $msg = $this->search($filter, $this->{basePasswd});
  return undef unless $msg;
  if ($msg->count() != 1) {
    $this->{error} = 'Login invalid';
    return undef;
  }

  return $msg->entry(0);
}

=begin text

---++++ getAccount()

Returns a Net::LDAP::Search object searching for all user accounts in the database.

=cut

sub getAccounts {
  my $this = shift;
  return $this->search($this->{loginFilter}, $this->{basePasswd});
}


=begin text

---++++ getGroup($name)

Returns the named group as a NET::LDAP::Entry object on success and undef otherwise.
Check the error message using $ldap->getError().

=cut

sub getGroup {
  my ($this, $wikiname) = @_;

  writeDebug("called getGroup($wikiname)");

  my $filter = '(&('.$this->{groupFilter}.')('.$this->{groupAttribute}.'='.$wikiname.'))';
  my $msg = $this->search($filter, $this->{baseGroup});
  return undef unless $msg;
  return $msg->entry(0);
}

=begin text

---++++ getGroupMembers($name)

Returns a list of user ids that are in a given group, undef if the group does
not exist.

=cut

sub getGroupMembers {
  my ($this, $groupName) = @_;

  writeDebug("called getGroupMembers($groupName)");

  my $groupEntry = $this->getGroup($groupName);
  return undef unless $groupEntry;

  writeDebug("this is an ldap group");

  # fetch all members
  my @members = ();
  foreach my $member ($groupEntry->get_value($this->{memberAttribute})) {

    writeDebug("found member=$member");

    # groups may store DNs to members instead of a memberUid, in this case we
    # have to query the member objects again and get their id
    if ($this->{memberIndirection}) {
      writeDebug("following indirection");
      my $msg = $this->search(
	'objectClass=*', $member, 'base', 1, [$this->{loginAttribute}]);
      my $memberEntry = $msg->entry(0);
      if ($memberEntry) {
	$member = $memberEntry->get_value($this->{loginAttribute});
	writeDebug("found indirect member=$member");
      } else {
	# inconsistent ldap data: the group points to an object that is not
	# there, only warning about this error case
	TWiki::Func::writeWarning("inconsistent ldap data: object '$member' not found");
      }
    }
    push @members,$member;
  }

  return \@members;
}

=begin text

---++++ getGroups();

Returns a Net::LDAP::Search object searching for all groups defined in the database.

CAUTION: this can get expensive, if you are only interested in the groups' ids
the use getGroupNames()

=cut

sub getGroups {
  my $this = shift;
  return $this->search($this->{groupFilter}, $this->{baseGroup});
}

=begin text

---++++ getGroupNames();

Returns a list of known group names.

=cut

sub getGroupNames {
  my $this = shift;

  writeDebug("called getGroupNames");
  return keys %{$this->{groupNames}} if $this->{cachedGroupNames};

  $this->{cachedGroupNames} = 1;

  my $groupAttribute = $this->{groupAttribute};
  my $msg = $this->search(
    $this->{groupFilter}, 
    $this->{baseGroup}, 
    undef, 
    0, 
    [$groupAttribute]);
  
  return undef unless $msg;

  while (my $entry = $msg->pop_entry()) {
    $this->{groupNames}{$entry->get_value($groupAttribute)} = 1;
  }

  return keys %{$this->{groupNames}};
}

=begin text

check if a given user is an ldap group actually

=cut

sub isGroup {
  my ($this, $user) = @_;

  $this->getGroupNames(); # populate cache
  return defined($this->{groupNames}{$user->wikiName})?1:0;
}


=begin text

---++++ search($filter, $base, $scope, $limit)

Returns an Net::LDAP::Search object for the given query on success and undef
otherwise. If $base is not defined $ldap->{base} is used.  If $scope is not
defined 'sub' is used (searching down the subtree under $base. If no $limit is
set all matching records are returned.  The $attrs is a reference to an array
of all those attributes that matching entries should contain.  If no $attrs is
defined all attributes are returned.

If undef is returned as an error occured use $ldap->getError() to get the
cleartext message of this search() operation.

Typical usage:
<verbatim>
my $result = $ldap->search('uid=TestUser');
</verbatim>

=cut

sub search {
  my ($this, $filter, $base, $scope, $limit, $attrs) = @_;

  $base = $this->{base} unless $base;
  $limit = 0 unless $limit;
  $scope = 'sub' unless $scope; # TODO: make scope configurable
  $attrs = ['*'] unless $attrs;

  #writeDebug("called search($filter, $base, $scope, $limit, $attrs)");

  $this->connect();
  my $msg = $this->{ldap}->search(
    base=>$base,
    filter=>$filter,
    scope=>$scope,
    sizelimit=>$limit,
    attrs=>$attrs,
  );
  
  if ($this->_checkError($msg) != LDAP_SUCCESS) {
    return undef;
  }
  return $msg;
}

=begin text

---++++ cacheBlob($entry, $attribute, $refresh)

Takes an Net::LDAP::Entry and an $attribute name, and stores its value into a
file. Returns the pubUrlPath to it. This can be used to store binary large
objects like images (jpegPhotos) into the filesystem accessible to the httpd
which can serve it in return to the client browser. 

Filenames containing the blobs are named using a hash value that is generated
using its DN and the actual attribute name whose value is extracted from the 
database. If the blob already exists in the cache it is _not_ extracted once
again except the $refresh parameter is defined.

Typical usage:
<verbatim>
my $blobUrlPath = $ldap->cacheBlob($entry, $attr);
</verbatim>

=cut

sub cacheBlob {
  my ($this, $entry, $attr, $refresh) = @_;

  writeDebug("called cacheBlob()");

  my $twikiWeb = &TWiki::Func::getTwikiWebname();
  my $dir = &TWiki::Func::getPubDir().'/'.$twikiWeb.'/LdapContrib';
  my $key = md5_hex($entry->dn().$attr);
  my $fileName = $dir.'/'.$key;

  if ($refresh || !-f $fileName) {
    writeDebug("caching blob");
    my $value = $entry->get_value($attr);
    return undef unless defined $value;
    mkdir($dir, 0775) unless -e $dir;

    open (FILE, ">$fileName");
    binmode(FILE);
    print FILE $value;
    close (FILE);
  } else {
    writeDebug("already got blob");
  }
  
  writeDebug("done cacheBlob()");

  return &TWiki::Func::getPubUrlPath().'/'.$twikiWeb.'/LdapContrib/'.$key;
}


1;
