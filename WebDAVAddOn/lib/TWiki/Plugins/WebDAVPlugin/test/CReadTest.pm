use strict;

package CReadTest;

use TWiki::Plugins::WebDAVPlugin;
use TWiki::Plugins::WebDAVPlugin::Permissions;

require 'FuncFixture.pm';
require 'StoreFixture.pm';
import TWiki::Func;
import TWiki::Store;

# Base ourselves on the "Func" fixture. This makes set-up and
# tear-down easier - though we could equally create and use a
# FuncFixture object to do the same thing.
use base qw(TWiki::Func);
my $query;

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

my $tmpdir = "/tmp/$$";

# Set up the test fixture
sub set_up {
  my $this = shift;

  $this->SUPER::set_up();
  mkdir($tmpdir);
}

sub tear_down {
  my $this = shift;

  $this->SUPER::set_up();
  `rm -rf $tmpdir`;
}

my $dv = "   IdiotChild";
my $dvtest = "|IdiotChild|";
my $av = "SpawnOfAsses,  SonOfSwine,MadGroup        ";
my $avtest = "|SpawnOfAsses|SonOfSwine|MadGroup|";
my $dt = "   BrainlessGit,   Thicko         ";
my $dttest = "|BrainlessGit|Thicko|";

sub check {
  my ( $this, $check, $exp ) = @_;

print STDERR "./accesscheck $check $tmpdir\n";
  my $status = `./accesscheck $check $tmpdir`;
  if ($status !~ /$exp\s*$/) {
	print STDERR "WHOOOOPS: $status\n";
  }

  $this->assert_matches(qr/$exp\s*$/, $status, $check);
}

sub dumpdb {
  my %hash;
  tie(%hash,'TDB_File',"$tmpdir/TWiki",Fcntl::O_RDONLY,0666) || die "$!";
  print STDERR "DB DUMP:\n";
  foreach my $key (keys %hash) {
	print STDERR "$key => $hash{$key}\n";
  }
  untie(%hash);
}

sub test__open_access {
  my $this = shift;
  my $db = new WebDAVPlugin::Permissions($tmpdir);

  $db->processText("Web", "Topic", "");
  $db = undef;

  $this->check("- - V atv1", "permitted");
  $this->check("Web - V atv1", "permitted");
  $this->check("Web Topic V -", "permitted");
}

sub test__topic {
  my $this = shift;
  my $db = new WebDAVPlugin::Permissions($tmpdir);

  $db->processText("Web", "Topic",
				   "\t* Set DENYTOPICVIEW = dtv\n".
				   "\t* Set ALLOWTOPICVIEW = atv1,atv2");

  $db = undef; # force close
  $this->check("Web Topic V atv1", "permitted");
  $this->check("Web Topic V atv2", "permitted");
  $this->check("Web Topic V dtv", "denied");
  $this->check("Web Topic V atv", "denied");
}

sub test__web_topic {
  my $this = shift;
  my $db = new WebDAVPlugin::Permissions($tmpdir);

  $db->processText("Web", "Topic",
				   "\t* Set DENYTOPICVIEW = dtv\n".
				   "\t* Set ALLOWTOPICVIEW = atv1,atv2,atv3");
  $db->processText("Web", "WebPreferences",
				   "\t* Set DENYWEBVIEW = atv1\n");

  $db = undef; # force close
  $this->check(" Web Topic V atv1", "denied");
  $this->check(" Web Topic V atv2", "permitted");
}

sub test__all_web_topic {
  my $this = shift;
  my $db = new WebDAVPlugin::Permissions($tmpdir);

  $db->processText("Web", "Topic",
				   "\t* Set DENYTOPICVIEW = dtv\n".
				   "\t* Set ALLOWTOPICVIEW = atv1,atv2,atv3");
  $db->processText("Web", "WebPreferences",
				   "\t* Set DENYWEBVIEW = atv1\n");
  $db->processText("TWiki", "TWikiPreferences",
				   "\t* Set DENYWEBVIEW = atv2\n");
  $db = undef; # force close

  $this->check("Web Topic V atv1", "denied");
  $this->check("Web Topic V atv2", "denied");
  $this->check("Web Topic V atv3", "permitted");
}

sub test__deny_global_group {
  my $this = shift;
  my $db = new WebDAVPlugin::Permissions($tmpdir);

  $db->processText("TWiki", "TWikiPreferences",
				   "\t* Set DENYWEBVIEW = UsGroup\n");
  $db->processText("Main", "UsGroup",
				   "\t* Set GROUP = me,us,ThemGroup\n");
  $db->processText("Main", "ThemGroup",
				   "\t* Set GROUP = her,him\n");
  $db = undef; # force close
dumpdb();
  $this->check("Web Topic V agent", "permitted");
dumpdb();
  $this->check("Web Topic V her", "denied");
  $this->check("Web Topic V him", "denied");
  $this->check("Web Topic V me", "denied");
  $this->check("Web Topic V us", "denied");
dumpdb();
}

1;
