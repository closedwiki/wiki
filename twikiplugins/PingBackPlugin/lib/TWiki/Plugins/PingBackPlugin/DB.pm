# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 MichaelDaum@WikiRing.com
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
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

package TWiki::Plugins::PingBackPlugin::DB;
use strict;
use Fcntl qw(:flock);
use TWiki::Plugins::PingBackPlugin::Ping;

use vars qw($debug);
$debug = 0; # toggle me

###############################################################################
sub writeDebug {
  print STDERR '- PingBackPlugin::DB - '.$_[0]."\n" if $debug;
}

################################################################################
# constructor
sub new {
  my ($class) = @_;

  writeDebug("called constructor");

  my $workarea = TWiki::Func::getWorkArea('PingBackPlugin');
  my $this = {
    inQueueDir=>$workarea.'/in',
    outQueueDir=>$workarea.'/out',
    curQueueDir=>$workarea.'/cur',
  };

  # check and create db skelleton
  mkdir $this->{inQueueDir} unless -d $this->{inQueueDir};
  mkdir $this->{outQueueDir} unless -d $this->{outQueueDir};
  mkdir $this->{curQueueDir} unless -d $this->{curQueueDir};

  return bless($this, $class);
}

###############################################################################
sub lockInQueue {
  my $this = shift;

  my $lockfile = $this->{inQueueDir}.'/lock';
  open(INQUEUE, ">$lockfile") || die "cannot create lock $lockfile - $!\n";
  flock(INQUEUE, LOCK_EX); # wait for exclusive rights
}

###############################################################################
sub unlockInQueue {
  flock(INQUEUE, LOCK_UN);
  close INQUEUE;
}

###############################################################################
sub lockOutQueue {
  my $this = shift;

  my $lockfile = $this->{outQueueDir}.'/lock';
  open(OUTQUEUE, ">$lockfile") || die "cannot create lock $lockfile - $!\n";
  flock(OUTQUEUE, LOCK_EX); # wait for exclusive rights
}

###############################################################################
sub unlockOutQueue {
  flock(OUTQUEUE, LOCK_UN);
  close OUTQUEUE;
}

###############################################################################
sub lockCurQueue {
  my $this = shift;

  my $lockfile = $this->{curQueueDir}.'/lock';
  open(CURQUEUE, ">$lockfile") || die "cannot create lock $lockfile - $!\n";
  flock(CURQUEUE, LOCK_EX); # wait for exclusive rights
}

###############################################################################
sub unlockCurQueue {
  flock(CURQUEUE, LOCK_UN);
  close CURQUEUE;
}

###############################################################################
sub getQueueDir {
  my ($this, $queueName) = @_;
  
  return $this->{inQueueDir} if $queueName eq 'in';
  return $this->{outQueueDir} if $queueName eq 'out';
  return $this->{curQueueDir} if $queueName eq 'cur';

  die "unknown queue name $queueName";
}

###############################################################################
sub lockQueue {
  my ($this, $queueName) = @_;

  return $this->lockInQueue() if $queueName eq 'in';
  return $this->lockOutQueue() if $queueName eq 'out';
  return $this->lockCurQueue() if $queueName eq 'cur';

  die "unknown queue name $queueName";
}

###############################################################################
sub unlockQueue {
  my ($this, $queueName) = @_;
  
  return $this->unlockInQueue() if $queueName eq 'in';
  return $this->unlockOutQueue() if $queueName eq 'out';
  return $this->unlockCurQueue() if $queueName eq 'cur';

  die "unknown queue name $queueName";
}

###############################################################################
sub queuePings {
  my ($this, $queueName, @pings) = @_;

  return unless @pings;

  # lock queue
  $this->lockQueue($queueName);

  # write all pings
  foreach my $ping (@pings) {
    $ping->writePing($queueName);
  }

  # unlock queue
  $this->unlockQueue($queueName);
}

###############################################################################
sub readQueue {
  my ($this, $queueName) = @_;

  writeDebug("called readQueue($queueName)");

  # lock queue
  $this->lockQueue($queueName);

  # read all pings
  my @pings = ();
  my $queueDir = $this->getQueueDir($queueName);
  opendir(DIR, $queueDir) || die "cannot open directory $queueDir - $!\n";
  foreach my $file (grep(!/^(\.|\.\.|lock)/, readdir(DIR))) {
    push @pings, TWiki::Plugins::PingBackPlugin::Ping::readPing($this, $queueDir.'/'.$file);
  }
  closedir DIR;

  # unlock queue
  $this->unlockQueue($queueName);

  #writeDebug("found ".(scalar @pings)." pings");
  writeDebug("done readQueue($queueName)");

  return @pings;
}

###############################################################################
sub newPing {
  my $this = shift;
  return TWiki::Plugins::PingBackPlugin::Ping->new($this, @_);
}

1;
