use strict;
use TDB_File;

package WriteReadTest;

use base qw(BaseFixture);

use TWiki::Plugins::WebDAVPlugin;
use TWiki::Plugins::WebDAVPlugin::Permissions;

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

my $tmpdir;
my $testdb;

# Set up the test fixture
sub set_up {
  my $this = shift;

  $tmpdir = "$BaseFixture::testDir/$$";
  $testdb = "$tmpdir/TWiki";

  $this->SUPER::set_up();
  mkdir($tmpdir);
}

my $dv = "   IdiotChild";
my $dvtest = "|IdiotChild|";
my $av = "SpawnOfAsses,  SonOfSwine,MadGroup        ";
my $avtest = "|SpawnOfAsses|SonOfSwine|MadGroup|";
my $dt = "   BrainlessGit,   Thicko         ";
my $dttest = "|BrainlessGit|Thicko|";

sub checkdb {
  my $this = shift;
#  $this->assert(-f "$testdb.dir", `ls $testdb*`);
#  $this->assert(-f "$testdb.pag", `ls $testdb*`);
  $this->assert(-f $testdb, `ls $testdb*`);
}

sub test__topic_controls {
  my $this = shift;

  my $db = new WebDAVPlugin::Permissions($tmpdir);
  $db->processText("Web", "Topic", "\t* Set DENYTOPICVIEW = $dv\n\t* Set ALLOWTOPICVIEW = $av\n\t* Set DENYTOPICCHANGE = $dt");
  $db = undef; # force close
  $this->checkdb();

  my %hash;
  tie(%hash,'TDB_File',$testdb,TDB_File::TDB_DEFAULT,Fcntl::O_RDONLY,0666) || die "$testdb $!";
  $this->assert_str_equals
	($dvtest,
	 $hash{"P:/Web/Topic:V:D"});
  $this->assert_str_equals
	($avtest,
	 $hash{"P:/Web/Topic:V:A"});
  $this->assert_str_equals
	($dttest,
	 $hash{"P:/Web/Topic:C:D"});
  untie(%hash);

  $db = new WebDAVPlugin::Permissions($tmpdir);
  $db->processText("Web", "Topic", "");
  $db = undef; # force close
  tie(%hash,'TDB_File',$testdb,TDB_File::TDB_DEFAULT,Fcntl::O_RDONLY,0666) || die "$testdb $!";
  $this->assert_null($hash{"P:/Web/Topic:V:D"});
  $this->assert_null($hash{"P:/Web/Topic:V:A"});
  $this->assert_null($hash{"P:/Web/Topic:C:D"});
}

sub test__web_preferences {
  my $this = shift;
  my $db = new WebDAVPlugin::Permissions($tmpdir);

  $db->processText("Web", "WebPreferences",
				   "\t* Set DENYWEBVIEW = $dv\n\t* Set ALLOWWEBVIEW = $av\n\t* Set DENYTOPICCHANGE = $dt");
  $db = undef; # force close
  $this->checkdb();

  my %hash;
  tie(%hash,'TDB_File',$testdb,TDB_File::TDB_DEFAULT,Fcntl::O_RDONLY,0666) || die "$testdb $!";
  $this->assert_str_equals
	($dvtest,
	 $hash{"P:/Web/:V:D"});
  $this->assert_str_equals
	($avtest,
	 $hash{"P:/Web/:V:A"});
  $this->assert_str_equals
	($dttest,
	 $hash{"P:/Web/WebPreferences:C:D"});
  untie(%hash);

  $db = new WebDAVPlugin::Permissions($tmpdir);
  $db->processText("Web", "WebPreferences", "");
  $db = undef; # force close
  tie(%hash,'TDB_File',$testdb,TDB_File::TDB_DEFAULT,Fcntl::O_RDONLY,0666) || die "$testdb $!";
  $this->assert_null($hash{"P:/Web/:V:D"});
  $this->assert_null($hash{"P:/Web/:V:A"});
  $this->assert_null($hash{"P:/Web/WebPreferences:C:D"});
  untie(%hash);
}

sub test__rewrite {
  my $this = shift;
  my $db = new WebDAVPlugin::Permissions($tmpdir);
  $db->processText("Web", "WebPreferences",
				   "\t* Set DENYWEBVIEW = $dt\n\t* Set ALLOWWEBVIEW = $dv\n\t* Set DENYTOPICCHANGE = $av");
  $db->processText("Web", "WebPreferences",
				   "\t* Set DENYWEBVIEW = $dv\n\t* Set ALLOWWEBVIEW = $av\n\t* Set DENYTOPICCHANGE = $dt");
  $db = undef; # force close
  $this->checkdb();

  my %hash;
  tie(%hash,'TDB_File',$testdb,TDB_File::TDB_DEFAULT,Fcntl::O_RDONLY,0666) || die "$testdb $!";
  $this->assert_str_equals
	($dvtest,
	 $hash{"P:/Web/:V:D"});
  $this->assert_str_equals
	($avtest,
	 $hash{"P:/Web/:V:A"});
  $this->assert_str_equals
	($dttest,
	 $hash{"P:/Web/WebPreferences:C:D"});
}

sub test__twiki_preferences {
  my $this = shift;
  my $db = new WebDAVPlugin::Permissions($tmpdir);

  $db->processText("TWiki", "TWikiPreferences",
				   "\t* Set DENYWEBVIEW = $dv\n\t* Set ALLOWWEBVIEW = $av\n\t* Set DENYTOPICCHANGE = $dt");
  $db = undef; # force close
  $this->checkdb();

  my %hash;
  tie(%hash,'TDB_File',$testdb,TDB_File::TDB_DEFAULT,Fcntl::O_RDONLY,0666) || die "$testdb $!";
  $this->assert_str_equals
	($dvtest,
	 $hash{"P:/:V:D"});
  $this->assert_str_equals
	($avtest,
	 $hash{"P:/:V:A"});
  $this->assert_str_equals
	($dttest,
	 $hash{"P:/TWiki/TWikiPreferences:C:D"});
  untie(%hash);

  $db = new WebDAVPlugin::Permissions($tmpdir);
  $db->processText("TWiki", "TWikiPreferences", "");
  $db = undef; # force close

  tie(%hash,'TDB_File',$testdb,TDB_File::TDB_DEFAULT,Fcntl::O_RDONLY,0666) || die "$testdb $!";
  $this->assert_null($hash{"P:/:V:D"});
  $this->assert_null($hash{"P:/:V:A"});
  $this->assert_null($hash{"P:/TWiki/TWikiPreferences:C:D"});
  untie(%hash);
}

sub test__group {
  my $this = shift;
  my $db = new WebDAVPlugin::Permissions($tmpdir);

  $db->processText("TWiki", "TWikiPreferences",
				   "\t* Set DENYWEBVIEW = TurfGroup\n\t* Set ALLOWWEBVIEW = Main.SodGroup\n");
  $db->processText("Main", "SodGroup",
				   "\t* Set GROUP = $av\n");

  $db = undef; # force close
  $this->checkdb();

  my %hash;
  tie(%hash,'TDB_File',$testdb,TDB_File::TDB_DEFAULT,Fcntl::O_RDONLY,0666) ||
	die "$testdb $!";
  $this->assert_str_equals
	("|SodGroup|",
	 $hash{"P:/:V:A"});
  $this->assert_str_equals
	("|TurfGroup|",
	 $hash{"P:/:V:D"});
  $this->assert_str_equals
	($avtest,
	 $hash{"G:SodGroup"});
}

sub test__open_nonexistent {
  my $this = shift;

  # use illegal pathname
  my $db = new WebDAVPlugin::Permissions("*");

  eval {
	$db->processText("Web", "Topic", "empty");
  };

  $this->assert_not_null($@);
}

1;
