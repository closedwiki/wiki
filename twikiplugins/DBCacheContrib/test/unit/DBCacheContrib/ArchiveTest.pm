package ArchiveTest;

use TWiki::Contrib::DBCacheContrib::Archive;
use TWiki::Contrib::DBCacheContrib::Map;
use TWiki::Contrib::DBCacheContrib::Array;
use base qw(Test::Unit::TestCase);

sub new {
  my $self = shift()->SUPER::new(@_);
  # your state for fixture here
  return $self;
}

my $submap;
my $array;
my $map;

sub set_up {
  $submap = new TWiki::Contrib::DBCacheContrib::Map("a=1 b=2");
  $array = new TWiki::Contrib::DBCacheContrib::Array();
  $map = new TWiki::Contrib::DBCacheContrib::Map();

  $array->add("string in array");
  $array->add(-22348957);
  $array->add(undef);
  $array->add($map);
  $array->add($array);

  $map->set("string", "A String");
  $map->set("integer", 1949);
  $map->set("map", $submap);
  $map->set("self", $map);
  $map->set("array", $array);
  $map->set("undef", undef);
  # make sure we don't infinite recurse in debug print
  $map->toString();
}

sub tear_down {
  unlink("data.dat") if ( -e "data.dat" );
}

# Simple writing and reading
sub test_writeRead {
  my $this = shift;

  my $a = new TWiki::Contrib::DBCacheContrib::Archive("data.dat", "w");
  $a->writeInt(1949);
  $a->writeObject($map);
  $a->close();

  $a = new TWiki::Contrib::DBCacheContrib::Archive("data.dat", "r");
  $this->assert_equals(1949,$a->readInt());
  my $m = $a->readObject();
  $a->close();

  $this->checkmap( $m );
}

sub checkmap {
  my ( $this, $map ) = @_;

  $this->assert_str_equals("A String", $map->get("string"));
  $this->assert_str_equals(1949, $map->get("integer"));
  $this->assert_null($map->get("undef"));

  my $submap = $map->get("map");
  $this->assert_str_equals("1", $submap->get("a"));
  $this->assert_str_equals("2", $submap->get("b"));

  my $self = $map->get("self");
  $this->assert_equals($map, $self);

  my $array = $map->get("array");
  $this->assert_str_equals("string in array", $array->get(0));
  $this->assert_equals(-22348957, $array->get(1));
  $this->assert_null($array->get(2));
  $this->assert_equals($map, $array->get(3));
  $this->assert_equals($array, $array->get(4));
}

# Make sure a file opened for read gets the old data even when
# another process is trying to write
sub test_writeDuringRead {
  my $this = shift;
  my $a1 = new TWiki::Contrib::DBCacheContrib::Archive("data.dat", "w");
  $a1->writeByte('Y');
  $a1->close();

  $a1 = new TWiki::Contrib::DBCacheContrib::Archive("data.dat", "r");
  $this->assert_str_equals("Y",$a1->readByte());
  $a1->close();

  $a1 = new TWiki::Contrib::DBCacheContrib::Archive("data.dat", "r");
  # should now have a LOCK_SH, so a LOCK_EX should be blocked.
  # This open for write should block.
  my $inc = join(" ",@INC);
  my $cmd = <<DONE;
| perl -e 'BEGIN{ \@INC=qw($inc); };
require TWiki::Contrib::DBCacheContrib::Archive;
\$a = new TWiki::Contrib::DBCacheContrib::Archive(\"data.dat\",
\"w\");\$a->writeByte(\"X\");
\$a->close();
1;'
DONE
  $cmd =~ s/\n//go;
  my $pid = open SUB, $cmd;
  sleep(1);
  # OK, the child process has had plenty of time to wake up and should be
  # waiting to get LOCK_EX, because we have it open for read.
  # Finish the read and check the contents.
  my $m = $a1->readByte();
  $this->assert_str_equals("Y", $m);
  $a1->close();
  # That should have unleashed the child process, so it will now write
  waitpid($pid,0);
  close(SUB);
  $a1 = new TWiki::Contrib::DBCacheContrib::Archive("data.dat", "r");
  $m = $a1->readByte();
  $a1->close();
  $this->assert_str_equals("X", $m);
}

sub test_multipleReads {
  # make sure we can open the same file multiple times for read
  my $this = shift;
  my $a1 = new TWiki::Contrib::DBCacheContrib::Archive("data.dat", "w");
  $a1->writeByte('X');
  $a1->writeByte('Y');
  $a1->writeByte('Z');
  $a1->close();

  my $inc = join(" ",@INC);
  my $cmd = <<DONE;
| perl -e '
BEGIN{ \@INC=qw($inc); }
require TWiki::Contrib::DBCacheContrib::Archive;
\$a = new TWiki::Contrib::DBCacheContrib::Archive(\"data.dat\", \"r\");
die unless(\$a->readByte() eq \"X\");
sleep(1);
die unless(\$a->readByte() eq \"Y\");
sleep(1);
die unless(\$a->readByte() eq \"Z\");
\$a->close();
1;'
DONE
  $cmd =~ s/\n//go;
  my $p1 = open P1, $cmd;
  my $p2 = open P2, $cmd;
  my $p3 = open P3, $cmd;
  my $p4 = open P4, $cmd;
  my $p5 = open P5, $cmd;
  waitpid($p1,0);
  $this->assert_equals(0, $?);
  close(P1);
  waitpid($p2,0);
  $this->assert_equals(0, $?);
  close(P2);
  waitpid($p3,0);
  $this->assert_equals(0, $?);
  close(P3);
  waitpid($p4,0);
  $this->assert_equals(0, $?);
  close(P4);
  waitpid($p5,0);
  $this->assert_equals(0, $?);
  close(P5);
}

sub test_writeLock {
  my $this = shift;
  # make sure a file open for write can't be opened for write again
  my $a1 = new TWiki::Contrib::DBCacheContrib::Archive("data.dat", "w");
  $a1->writeByte('Y');

  # Spawn a subprocess that tries to write
  my $inc = join(" ",@INC);
  my $cmd = <<DONE;
| perl -e 'BEGIN{ \@INC=qw($inc); };
require TWiki::Contrib::DBCacheContrib::Archive;
\$a = new TWiki::Contrib::DBCacheContrib::Archive("data.dat", "w");
\$a->writeByte("X");\$a->close(); 1;'
DONE
  $cmd =~ s/\n//go;
  my $pid = open SUB, $cmd;
  sleep(1);
  # OK, the child process has had plenty of time to wake up and should be
  # blocking on the exclusive LOCK_EX, because we have it open for write.
  $a1->close();
  # That should have unleashed the child process, so it will now write
  waitpid($pid,0);
  close(SUB);

  # Now we expect the child process to have dominated
  $a1 = new TWiki::Contrib::DBCacheContrib::Archive("data.dat", "r");
  $m = $a1->readByte();
  $this->assert_str_equals("X", $m);
  $a1->close();
}


  # make sure a file opened for write can be opened for read and
  # that it gets the old data

1;
