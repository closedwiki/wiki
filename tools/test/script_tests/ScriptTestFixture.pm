use strict;

#
# Base fixture for script tests. Provides some URL manipulation, and
# set-up for the test configuration.
#

package ScriptTestFixture;

use base qw(Test::Unit::TestCase);
use vars qw($urlroot $old $new $olddata $newdata
			$oldpub $newpub $user $pass $wget $ab);

BEGIN {
##############################################################
# Test environment setup
# Note that for correct operation, the runner has to be able to delete
# files from the data areas belonging to the two test installations
$urlroot = "http://localhost";
$old = "svn";
$new = "mine";
$olddata = "/windows/C/twiki/data";
$newdata = $olddata;
$oldpub = "/windows/C/twiki/pub";
$newpub = $oldpub;
$user = "TWikiGuest";
$pass = "";
$wget = "/usr/bin/wget";
$ab = "/usr/sbin/ab";
#############################################################

  print STDERR "Sanitising fixtures.....\n";
  `rm -rf $oldpub/Sandbox/AutoCreated*`;
  `rm -f $olddata/Sandbox/AutoCreated*.*`;
  `rm -rf $newpub/Sandbox/AutoCreated*`;
  `rm -f $newdata/Sandbox/AutoCreated*.*`;
}

sub set_up {
}

sub tear_down {
}

sub getUrl {
  my ($this, $install, $func, $web, $topic, $opts) = @_;
  if ($opts) {
    $opts =~ s/&/\\&/go;
    $opts = "?$opts";
  } else {
    $opts = "";
  }
  #print "WGet $urlroot/$install/bin/$func/$web/$topic$opts\n";
  my $result = `$wget -q -O - $urlroot/$install/bin/$func/$web/$topic$opts`;
  $this->assert(!$?, "WGet $urlroot/$install/bin/$func/$web/$topic$opts failed, $result");
  if ( $func ne "oops" ) {
      $this->assert_does_not_match(qr/\(oops\)/, $result, "FAILED RESULT\n$result");
  }

  $result =~ s/\/$install\//\/URL\//g;
  $result =~ s/\?t=[0-9]+\b/?t=0/go;
  $result =~ s/-\s+\d+:\d+\s+-/- DATE -/go;
  return $result;
}

# Get a url from the old installation
sub getOld {
  my $this = shift;
  return $this->getUrl($old, @_);
}

# Get a url from the new installation
sub getNew {
  my $this = shift;
  return $this->getUrl($new, @_);
}

# Compare the results of the same URL in old and new
sub compareOldAndNew {
  my ($this, $func, $web, $topic, $opts, $ignorenl) = @_;
  my $old = $this->getOld($func, $web, $topic, $opts);
  my $new = $this->getNew($func, $web, $topic, $opts);
  $this->diff($old, $new, $ignorenl);
}

sub oldLocked {
  my ($this, $web, $topic) = @_;
  return -e "$olddata/$web/$topic.lock";
}

sub newLocked {
  my ($this, $web, $topic) = @_;
  return -e "$newdata/$web/$topic.lock";
}

# Diff two blocks of text
sub diff {
  my ($this, $old, $new, $ignorenl) = @_;
  open(WF,">/tmp/old") || die;
  $old =~ s/\n/ /g if ( $ignorenl );
  print WF $old;
  close(WF) || die;
  open(WF,">/tmp/new") || die;
  $new =~ s/\n/ /g if ( $ignorenl );
  print WF $new;
  close(WF) || die;
  print STDERR `diff -b -B -w -u /tmp/old /tmp/new`;
  $this->assert(!$?, "Difference detected");
}

# Unlock a topic in the old and new fixtures
sub unlock {
  my ($this, $web, $topic) = @_;

  $this->_unlock($olddata, $web, $topic);
  $this->_unlock($newdata, $web, $topic);
}

sub _unlock {
  my ($this, $data, $web, $topic) = @_;

  chmod 777, "$data/$web/$topic.lock";
  if (-e "$data/$web/$topic.lock" && !unlink("$data/$web/$topic.lock")) {
    print STDERR "WARNING! FAILED TO UNLOCK $web/$topic in $data\n";
    print STDERR `ls -l $data/$web/$topic.lock`;
    print STDERR "TEST FIXTURE IS DAMAGED - REMOVE LOCK MANUALLY\n";
  }
}

sub _deleteData {
  my ($this, $data, $web, $topic) = @_;

  chmod 777, "$data/$web/$topic.txt", "$data/$web/$topic.txt,v",
    "$data/$web/$topic.lock";

  if (-e "$data/$web/$topic.txt" && !unlink("$data/$web/$topic.txt")) {
    print STDERR "WARNING! FAILED TO DELETE TOPIC $web/$data in $data\n";
    print STDERR `ls -l $data/$web/$topic.*`;
    print STDERR "TEST FIXTURE IS DAMAGED - REMOVE TOPIC MANUALLY\n";
  }

  if (-e "$data/$web/$topic.txt" && !unlink("$data/$web/$topic.lock")) {
    print STDERR "WARNING! FAILED TO DELETE LOCK $web/$data in $data\n";
    print STDERR `ls -l $data/$web/$topic.*`;
    print STDERR "TEST FIXTURE IS DAMAGED - REMOVE TOPIC MANUALLY\n";
  }

  if (-e "$data/$web/$topic.txt" && !unlink("$data/$web/$topic.txt,v")) {
    print STDERR "WARNING! FAILED TO DELETE TOPIC $web/$data in $data\n";
    print STDERR `ls -l $data/$web/$topic.*`;
    print STDERR "TEST FIXTURE IS DAMAGED - REMOVE TOPIC MANUALLY\n";
  }
}

sub _deletePub {
  my ($this, $data, $web, $topic) = @_;

  if (-e "$data/$web/$topic") {
    `chmod -R 777 $data/$web/$topic`;
    `rm -rf $data/$web/$topic`;
  }
}

# Delete a topic from the old and new fixtures
sub deleteTopic {
  my ($this, $web, $topic) = @_;

  $this->_deleteData($olddata, $web, $topic);
  $this->_deletePub($oldpub, $web, $topic);
  $this->_deleteData($newdata, $web, $topic);
  $this->_deletePub($newpub, $web, $topic);
}

sub newExists {
  my ($this, $web, $topic) = @_;

  return -e "$newdata/$web/$topic.txt";
}

sub oldExists {
  my ($this, $web, $topic) = @_;

  return -e "$olddata/$web/$topic.txt";
}

sub newPubExists {
  my ($this, $web, $topic, $file) = @_;

  return -e "$newpub/$web/$topic/$file";
}

sub oldPubExists {
  my ($this, $web, $topic, $file) = @_;

  return -e "$oldpub/$web/$topic/$file";
}

sub createTempForUpload {
  `cp ScriptTestFixture.pm /tmp/robot.gif`
}

1;
