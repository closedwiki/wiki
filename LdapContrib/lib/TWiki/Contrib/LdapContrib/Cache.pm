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

package TWiki::Contrib::LdapContrib::Cache;

use strict;
use Storable qw(lock_store lock_retrieve);

use vars qw ($cache $doneInit);

=pod

---+++ init() -> $cache

initializes the cache. 

=cut

sub init {
  my ($session) = @_;

  return $cache if $doneInit;
  $doneInit = 1;

  # load
  unless ($cache) {
    my $cacheFile = 
      $session->{store}->getWorkArea('LdapContrib').
      '/LdapCache';
    if (-f $cacheFile)  {
      writeDebug("loading ldap cache from $cacheFile");
      $cache = lock_retrieve($cacheFile);
    }
  }
  my $refresh = $session->{cgiQuery}->param('refreshldap') || '';
  $refresh = $refresh eq 'on'?1:0;

  my $maxCacheHist = $TWiki::cfg{Ldap}{MaxCacheHits};
  $maxCacheHist = -1 unless defined $maxCacheHist;
  my $cacheAge = time() - $cache->{lastUpdate};
  my $maxCacheAge = $TWiki::cfg{Ldap}{MaxCacheAge};
  $maxCacheAge = 600 unless defined $maxCacheAge;

  # clear to reload it
  if (!$cache || 
    $cache->{cacheHits} == 0 || 
    $cacheAge > $maxCacheAge ||
    $refresh) {
    $cache = {};
    $cache->{cacheHits} = $maxCacheHist;
    $cache->{lastUpdate} = time();
  } else {
    $cache->{cacheHits}--;
  }

  writeDebug("cacheHits=".abs($cache->{cacheHits}));
  writeDebug("cacheAge=$cacheAge");


  return $cache;
}

=pod

finalize the ldap cache. this is the last action the
ldap cache does when finishing a request. it is only
performed if there was at least one call to init()
during this request.

=cut

sub finish {
  return unless $doneInit;
  return unless $TWiki::Plugins::SESSION;

  if ($TWiki::cfg{Ldap}{Debug}) {
    writeDebug("finishing");
    #writeDebug(stringify());
  }

  my $dir = TWiki::Func::getWorkArea('LdapContrib');
  mkdir $dir unless -d $dir;
  my $file = $dir.'/LdapCache';
  lock_store($cache, $file);

  $doneInit = 0;
}

=pod 

returns a stringified version of the cache content

=cut

sub stringify {
  use Data::Dumper;
  return Data::Dumper->Dump([$cache],['cache']);
}

sub writeDebug {
  print STDERR "Ldap::Contrib - $_[0]\n" if $TWiki::cfg{Ldap}{Debug};
}


1;
