#
# Copyright (C) 2004 WindRiver Ltd.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
use strict;
use TDB_File;
use Fcntl;
use TWiki;
use TWiki::Func;

# Permissions DB object. Processes protections info out of topic text
# and maintains a database of protections, using TDB. TDB is used because
# unlike DBM it affords record locking.
package WebDAVPlugin::Permissions;

my $setGroupRE = qr/^\s+\*\s+Set\s+GROUP\s+=\s+(.+?)\s*$/;
my $setWebRE = qr/^\s+\*\s+Set\s+(ALLOW|DENY)WEB([A-Z]+?)\s+=\s+(.+?)\s*$/;
my $setTopicRE = qr/^\s+\*\s+Set\s+(ALLOW|DENY)TOPIC([A-Z]+?)\s+=\s+(.+?)\s*$/;

# Constructor for a DB. Does not connect to the DB until actually required.
sub new {
  my ( $class, $dbdir ) = @_;
  my $this = {};

  $this->{dbfile} = "$dbdir/TWiki";
  $this->{db} = undef;

  return bless( $this, $class );
}

# Refresh permissions everywhere in a twiki installation. Call from cron.
sub recache {
  my ( $this, $web, $topic ) = @_;
  if ( !$web ) {
	my @webs = TWiki::Store::getAllWebs();

	foreach my $web ( @webs ) {
	  $this->_processWeb( $web, undef );
	}
  } else {
	$this->_processWeb( $web, $topic );
  }
}

# Extract and store permissions settings in a single web
# We should really clean out old entries for this web before we
# start, but because the keys are topic specific and not web
# specific this is tricky and would be slow. However the memory
# leakage that results from _not_ doing it is so small that it's
# really not worth bothering about.
sub _processWeb {
  my ( $this, $web, $topic ) = @_;
  my $npr = 0;
  my $dataDir = TWiki::Func::getDataDir();
  my $cmd = "$TWiki::egrepCmd ";
  $cmd .= $TWiki::cmdQuote;
  $cmd .= "\* Set (ALLOW|DENY)(TOPIC|WEB)(VIEW|CHANGE)";
  $cmd .= $TWiki::cmdQuote;

  if ( $topic ) {
    $this->_processTopic( $web, $topic );
	$npr++;
  } else {
	my @topics = TWiki::Func::getTopicList( $web );
	my %processed;
	while ( scalar( @topics )) {
	  my $p = "";;
	  my $ninset = 50;
	  while ( scalar( @topics ) && $ninset-- ) {
		$p .= " $dataDir/$web/" . pop( @topics ) . ".txt";
	  }
	  foreach my $topic ( split( /\n/, `$cmd $p` )) {
		if ( $topic =~ /^.*[\/\\](.*?)\.txt:/o ) {
		  if ( !$processed{$1} ) {
			$this->_processTopic( $web, $1 );
			$npr++;
			$processed{$1} = 1;
		  }
		}
	  }
	}
  }
  print "Processed $npr topics from $web\n";
}

# Extract and store permissions settings in a single topic
sub _processTopic {
  my ( $this, $web, $topic ) = @_;

  my ( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );
  print "Processing topic $web.$topic\n";
  $this->processText( $web, $topic, $text );
}

# Process TWiki text from a topic to extract permissions info
# from it, and add them to the DB.
sub processText {
  my ( $this, $web, $topic, $text ) = @_;

  my @lines =
    grep { /($setGroupRE)|($setWebRE)|($setTopicRE)/ }
      split /[\r\n]+/, $text;

  # If this is a group def topic, extract the group
  if ( $web eq TWiki::Func::getMainWebname() && $topic =~ /Group$/ ) {
    my ( $firstLine ) = grep { /$setGroupRE/ } @lines;
    if ( $firstLine && $firstLine =~ m/$setGroupRE/o ) {
      my @users;
      foreach my $who ( split( /[,\s]+/, $1 )) {
        $who = TWiki::Func::wikiToUserName($who) || $who;
        push( @users, $who );
      }
      if ( @users ) {
		$this->_defineGroup( $topic, "|" . join( '|', @users ) . "|");
	  }
    }
  }

  my $path = '';
  if ( $topic eq $TWiki::wikiPrefsTopicname &&
       $web eq TWiki::Func::getTwikiWebname()) {
    $path = "/";
  } elsif ( $topic eq $TWiki::webPrefsTopicname ) {
    $path = "/$web/";
  }

  if ($path) {
    # first handle (ALLOW|DENY)WEB... (only if it's a XXXPreference topic)
	$this->_clearPath( $path );
    map {
      /$setWebRE/;
      $this->_defineAccessRights( $path, $1, $2, $3 )
    } grep { /$setWebRE/ } @lines;
  }

  $path = "/$web/$topic";
  # then handle (ALLOW|DENY)TOPIC...
  $this->_clearPath( $path );
  map  {
    /$setTopicRE/;
    $this->_defineAccessRights( $path, $1, $2, $3 )
  } grep { /$setTopicRE/ } @lines;
}

# Define acces rights for a list of wikinames and groups.
sub _defineAccessRights {
  my ( $this, $path, $ad, $action, $names ) = @_;

  # ALLOW => A, DENY => D
  $ad =~ s/^(\w).*$/$1/o;
  # CHANGE => C, VIEW => V, RENAME => R
  $action =~ s/^(\w).*$/$1/o;

  my @users;
  foreach my $who ( split( /[,\s]+/, $names )) {
	my $whow = TWiki::Func::wikiToUserName($who);
	if ($whow) {
	  $who = $whow;
	} else {
	  $who =~ s/^\w+\.(\w+)$/$1/o;
	}
    push( @users, $who );
  }

  $this->_setAccessRights( '|' . join( '|', @users ) . '|',
						   $path, $ad, $action );
}

# Clear the database entries for a path; we are about to re-define them.
sub _clearPath {
  my ( $this, $path ) = @_;

  my %db;
  $this->_tieDB(\%db);
  #print STDERR "Clear P:$path\n";
  delete($db{"P:$path:V:D"});
  delete($db{"P:$path:V:A"});
  delete($db{"P:$path:C:D"});
  delete($db{"P:$path:C:A"});
  delete($db{"P:$path:R:D"});
  delete($db{"P:$path:R:A"});
  untie(%db);
}

# Set access rights for a list of usernames.
# $path is the twiki path to the resource i.e. /$web/$topic
# $mode is ALLOW or DENY depending on whether this is an allow or a deny
# $action is the controlled action e.g. VIEW, CHANGE
sub _setAccessRights {
  my ( $this, $users, $path, $allow, $action ) = @_;
  my $key = "P:${path}:${action}:${allow}";
  my %db;
  $this->_tieDB(\%db);
  $db{$key} = $users;
  #print STDERR "Stored $key => $users\n";
  untie(%db);
}

# Define a new group (or redefine an existing one)
sub _defineGroup {
  my ( $this, $group, $members ) = @_;
  my $key = "G:$group";
  my %db;
  $this->_tieDB(\%db);
  $db{$key} = $members;
  #print STDERR "Stored $key => $members\n";
  untie(%db);
}

# PRIVATE get the DB, opening it if required. The DB will persist
# until all references to this Permissions object have been lost.
# We tie and untie on a per-access basis. This is expensive, but since
# the number of accesses per topic save is small. If this is a problem,
# we can always shift to keeping the DB open while we are working on
# it, because TDB has record locking so multiple readers and writers
# can operate on it.
sub _tieDB {
  my ( $this, $hash ) = @_;

  tie(%$hash,'TDB_File', $this->{dbfile}, TDB_File::TDB_DEFAULT,
	  Fcntl::O_RDWR | Fcntl::O_CREAT, 0700) ||
		  die $this->{dbfile} . " DB open failure: $!";
}

1;
