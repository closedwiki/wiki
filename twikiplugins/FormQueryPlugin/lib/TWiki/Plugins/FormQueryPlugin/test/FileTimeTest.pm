use strict;

package FileTimeTest;

use TWiki::Plugins::FormQueryPlugin::WebDB;
use TWiki::Plugins::FormQueryPlugin::Archive;
use TWiki::Plugins::FormQueryPlugin::FileTime;
use Storable;

require 'FuncFixture.pm';
import TWiki::Func;

use base qw(TWiki::Func);

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

  my $dbt = TWiki::Func::TESTreadFile("./testDB.dat");
  $root = TWiki::Func::getDataDir() . "/$web";
  FormQueryPlugin::FileTime::setRoot($root);
  $files = new FormQueryPlugin::Array();
  foreach my $t ( split(/\<TOPIC\>/,$dbt)) {
    if ( $t =~ m/\"(.*?)\"/o ) {
      TWiki::Func::TESTwriteTopic($web, $1, $t);
      $files->add(new FormQueryPlugin::FileTime( $1 ));
    }
  }
  $acache = "$root/cache.Archive";
  $scache = "$root/cache.Storable";
}

sub test_OK {
  my $this = shift;
  # Make sure the file times reflect what's on disc
  foreach my $ft ( $files->getValues() ) {
    eval { $ft->_check(); };
    $this->assert_null( "Error: $@" ) if $@;
  }
}

sub test_touchOne {
  my $this = shift;
  sleep(1);# make sure file times are different
  `touch $root/Dir4.txt`;

  foreach my $ft ( $files->getValues() ) {
    if ( $ft->{file} eq "Dir4") {
      eval { $ft->_check(); };
      $this->assert_null( "Error: $@" ) unless $@;
    } else {
      eval { $ft->_check(); };
      $this->assert_null( "Error: $@" ) if $@;
    }
  }
}

sub test_delOne {
  my $this = shift;
  `rm $root/Dir2.txt`;

  foreach my $ft ( $files->getValues() ) {
    if ( $ft->{file} eq "Dir2") {
      eval { $ft->_check(); };
      $this->assert_null( "Error: $@" ) unless $@;
    } else {
      eval { $ft->_check(); };
      $this->assert_null( "Error: $@" ) if $@;
    }
  }
}

sub test_StorableOK {
  my $this = shift;
  Storable::lock_store($files, $scache);
  my $newFiles = Storable::lock_retrieve($scache);
  $this->assert_equals($files->size(), $newFiles->size());
}

sub test_StorableTouchOne {
  my $this = shift;
  Storable::lock_store($files, $scache);
  sleep(1);# make sure file times are different
  my $afile = TWiki::Func::getDataDir() . "/$web/Dir4.txt";
  `touch $afile`;
  eval { Storable::lock_retrieve($scache) };
  $this->assert_null( "Error: $@" ) unless $@;
}

sub test_StorableDelOne {
  my $this = shift;
  Storable::lock_store($files, $scache);
  my $afile = TWiki::Func::getDataDir() . "/$web/Dir2.txt";
  `rm $afile`;
  eval { Storable::lock_retrieve($scache) };
  $this->assert_null( "Error: $@" ) unless $@;
}

sub test_ArchiveOK {
  my $this = shift;
  my $archive = new FormQueryPlugin::Archive( $acache, "w" );
  $archive->writeObject( $files );
  $archive->close();
  $archive = new FormQueryPlugin::Archive( $acache, "r" );
  my $newFiles = $archive->readObject();
  $archive->close();
  $this->assert_equals($files->size(), $newFiles->size());
}

sub test_ArchiveTouchOne {
  my $this = shift;
  my $archive = new FormQueryPlugin::Archive( $acache, "w" );
  $archive->writeObject( $files );
  $archive->close();
  sleep(1);# make sure file times are different
  my $afile = TWiki::Func::getDataDir() . "/$web/Dir4.txt";
  `touch $afile`;
  $archive = new FormQueryPlugin::Archive( $acache, "r" );
  eval { my $newFiles = $archive->readObject(); };
  $this->assert_null( "Error: $@" ) unless $@;
  $archive->close();
}

sub test_ArchiveDelOne {
  my $this = shift;
  my $archive = new FormQueryPlugin::Archive( $acache, "w" );
  $archive->writeObject( $files );
  $archive->close();
  my $afile = TWiki::Func::getDataDir() . "/$web/Dir2.txt";
  `rm $afile`;
  $archive = new FormQueryPlugin::Archive( $acache, "r" );
  eval { my $newFiles = $archive->readObject(); };
  $this->assert_null( "Error: $@" ) unless $@;
  $archive->close();
}

1;
