use strict;
use TDB_File;

package PluginTests;

use base qw(BaseFixture);

use TWiki::Plugins::WebDAVPlugin;

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

my $tmpdir;
my $testdb;

# Set up the test fixture
sub set_up {
  my $this = shift;

  $this->SUPER::set_up();
  $tmpdir = "$BaseFixture::testDir/$$";
  $testdb = "$tmpdir/TWiki";
  mkdir($tmpdir);
}

my $dv = "   IdiotChild";
my $dvtest = "|IdiotChild|";
my $av = "SpawnOfAsses,  SonOfSwine,MadGroup        ";
my $avtest = "|SpawnOfAsses|SonOfSwine|MadGroup|";
my $dt = "   BrainlessGit,   Thicko         ";
my $dttest = "|BrainlessGit|Thicko|";

sub test__bad_DB {
  my $this = shift;

  BaseFixture::setPreference("WEBDAVPLUGIN_LOCK_DB", "*");

  TWiki::Plugins::WebDAVPlugin::initPlugin("Topic", "Web", "dweeb");
  TWiki::Plugins::WebDAVPlugin::beforeSaveHandler("", "Web", "Topic");

}

sub test__beforeSaveHandler {
  my $this = shift;

  BaseFixture::setPreference("WEBDAVPLUGIN_LOCK_DB", $tmpdir);

  TWiki::Plugins::WebDAVPlugin::initPlugin("Topic", "Web", "dweeb");
  TWiki::Plugins::WebDAVPlugin::beforeSaveHandler("\t* Set DENYTOPICVIEW = $dv\n\t* Set ALLOWTOPICVIEW = $av\n\t* Set DENYTOPICCHANGE = $dt", "Web", "Topic");
}
