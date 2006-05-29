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

package TWiki::Plugins::PingBackPlugin::Ping;
use strict;
use Digest::MD5 qw(md5_hex);

use vars qw($debug);
$debug = 0; # toggle me

###############################################################################
sub writeDebug {
  print STDERR '- PingBackPlugin::PingDB - '.$_[0]."\n" if $debug;
}

################################################################################
# constructor
sub new {
  my ($class, $db, $source, $target, $extra) = @_;

  writeDebug("new ping");

  my $this = {
    date=>'',
    db=>$db,
    source=>$source,
    target=>$target,
    extra=>($extra||''),
  };

  $this = bless($this, $class);

  writeDebug($this->toString);

  return $this;
}

###############################################################################
sub timeStamp {
  my ($this, $date) = @_;

  writeDebug('called timeStamp');
  
  unless ($date) {
    # SMELL: lets have it numerical
    my ($sec, $min, $hour, $mday, $mon, $year) = localtime(time());
    $date = sprintf("%.4u/%.2u/%.2u - %.2u:%.2u:%.2u", 
      $year+1900, $mon+1, $mday, $hour, $min, $sec);
  }
  $this->{date} = $date;

  writeDebug($this->toString);

  return $date;
}

###############################################################################
# write w/o locking
sub writePing {
  my ($this, $queueName) = @_;

  writeDebug("called writePing($queueName) for ".$this->toString);

  my $queueDir = $this->{db}->getQueueDir($queueName);

  unless ($this->{key}) {
    $this->{key} = md5_hex($this->{source}."\0".$this->{target});
  }
  my $pingFile = $queueDir.'/'.$this->{key};

  open(FILE, ">$pingFile") || die "cannot append $pingFile - $!\n";

  print FILE 
    'date='.$this->{date}."\n".
    'source='.$this->{source}."\n".
    'target='.$this->{target}."\n".
    $this->{extra}."\n"; 

  close FILE;
}

###############################################################################
# static
# read a ping from a file and constructs a new ping
sub readPing {
  my ($db, $file) = @_;

  writeDebug("called readPing($file)");

  my ($date, $source, $target, $extra) = ('','','','');

  open(FILE, "<$file") || die "cannot open $file - $!";
  writeDebug('opening');
  while (my $line = <FILE>) {
    next if $line =~ /^#/;
    writeDebug("line=$line");
    if (!$date && $line =~ /^date=(.*)$/) {
      $date = $1;
      writeDebug("found date=$date");
      next;
    }
    if (!$source && $line =~ /^source=(.*)$/) {
      $source = $1;
      writeDebug("found source=$source");
      next;
    }
    if (!$target && $line =~ /^target=(.*)$/) {
      $target = $1;
      writeDebug("found target=$target");
      next;
    }
    writeDebug("adding extra");
    $extra .= $line;
  }
  close FILE;
  writeDebug('closing');

  my $ping = $db->newPing($source, $target, $extra);
  $ping->timeStamp($date);

  writeDebug("read ping ".$ping->toString);

  return $ping;
}

###############################################################################
# safe write using locking
sub queuePing {
  my ($this, $queueName) = @_;

  writeDebug("called queuePing($queueName)");
  writeDebug($this->toString);

  $this->{db}->lockQueue($queueName);
  $this->writePing($queueName);
  $this->{db}->unlockQueue($queueName);
}

###############################################################################
sub toString {
  my $this = shift;

  return 
    'date='.$this->{date}.', '.
    'source='.$this->{source}.', '.
    'target='.$this->{target}.', '.
    'extra='.$this->{extra};
}

1;
