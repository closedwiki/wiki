use strict;
use TDB_File;

package PluginTests;

use TWiki::Plugins::WebDAVPlugin;

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
my $testdb = "$tmpdir/TWiki";

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

sub test__bad_DB {
  my $this = shift;

  TWiki::Func::TESTsetPreference("WEBDAVPLUGIN_LOCK_DB", "*");

  TWiki::Plugins::WebDAVPlugin::initPlugin("Topic", "Web", "dweeb");
  TWiki::Plugins::WebDAVPlugin::beforeSaveHandler("", "Web", "Topic");

}

sub test__beforeSaveHandler {
  my $this = shift;

  TWiki::Func::TESTsetPreference("WEBDAVPLUGIN_LOCK_DB", $tmpdir);

  TWiki::Plugins::WebDAVPlugin::initPlugin("Topic", "Web", "dweeb");
  TWiki::Plugins::WebDAVPlugin::beforeSaveHandler("\t* Set DENYTOPICVIEW = $dv\n\t* Set ALLOWTOPICVIEW = $av\n\t* Set DENYTOPICCHANGE = $dt", "Web", "Topic");
}
