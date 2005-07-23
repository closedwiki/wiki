use strict;

package FileTimeTest;

use base qw(BaseFixture);

use TWiki::Contrib::Archive;
use TWiki::Contrib::FileTime;
use TWiki::Func;
use Storable;

my $files; # fixture
my $web = "FT"; # fixture
my $root;
my $acache;
my $scache;

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

sub set_up {
  my $this = shift;

  $this->SUPER::set_up();

  my $dbt = BaseFixture::readFile("./testDB.dat");
  $root = TWiki::Func::getDataDir() . "/$web";
  $files = new TWiki::Contrib::Array();
  foreach my $t ( split(/\<TOPIC\>/,$dbt)) {
    if ( $t =~ m/\"(.*?)\"/o ) {
      BaseFixture::writeTopic($web, $1, $t);
      $files->add(new TWiki::Contrib::FileTime( "$root/$1.txt" ));
    }
  }
  $acache = "$root/cache.Archive";
  $scache = "$root/cache.Storable";
}

sub test_OK {
  my $this = shift;
  # Make sure the file times reflect what's on disc
  foreach my $ft ( $files->getValues() ) {
    $this->assert($ft->uptodate());
  }
}

sub test_touchOne {
  my $this = shift;
  sleep(1);# make sure file times are different
  `touch $root/Dir4.txt`;

  foreach my $ft ( $files->getValues() ) {
    if ( $ft->{file} eq "$root/Dir4.txt") {
      $this->assert(!$ft->uptodate());
    } else {
      $this->assert($ft->uptodate());
    }
  }
}

sub test_delOne {
  my $this = shift;
  `rm $root/Dir2.txt`;

  foreach my $ft ( $files->getValues() ) {
    if ( $ft->{file} eq "$root/Dir2.txt") {
      $this->assert(!$ft->uptodate());
    } else {
      $this->assert($ft->uptodate());
    }
  }
}

1;
