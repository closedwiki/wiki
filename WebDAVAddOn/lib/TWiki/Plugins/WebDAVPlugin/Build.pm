package Build;

=begin twiki

---+ package Build
Base class of build objects for TWiki packages.

Works by defining targets as functions that can then be subclasses and added
to. Just about as simple a build system as you could get.

The list of files to be installed is determined from the table in
the plugin topic (the "manifest"). Only these files will get into
the release zip.

The following targets should always exist:
1. build - check that everything is perl
2. test - run unit tests
3. install - install on local installation defined by $TWIKI_HOME
4. release - package a release zip

=cut

use strict;
use File::Copy;
use File::Spec;
use diagnostics;
use vars qw( $basedir );

BEGIN {
  use File::Spec;
  my $cwd = `dirname $0`; chop($cwd);
  $basedir = File::Spec->rel2abs("../../../..", $cwd);
  unshift @INC, $basedir;
  unshift @INC, '.';
}

=pod

---++ new($plugin)
$project is the plugin/addon/skin name
Construct a new build object. Define the basic directory
paths to places in the build/release. Read the manifest topic
and build file and dependency lists. Parse command line to get
target and options.

=cut
sub new {
  my ( $class, $plugin ) = @_;
  my $this = {};
  
  $this->{project} = $plugin;
  $this->{target} = "test";
  
  my $n = 0;
  my $done = 0;
  while ($n <= $#ARGV) {
	if ($ARGV[$n] =~ /^-/o) {
	  $this->{$ARGV[$n]} = 1;
	} else {
	  $this->{target} = $ARGV[$n];
	}
	$n++;
  }
  
  chdir($basedir);
  $basedir = `pwd`;
  chop($basedir);
  $this->{basedir} = $basedir;
  
  # The following paths are all relative to the root of the twiki
  # installation
  
  # lib/TWiki/Plugins, where the plugin.pm file lives
  $this->{lib_plugins}="lib/TWiki/Plugins";
  
  # where the plugin sub-modules live
  $this->{plugin_libdir}=$this->{lib_plugins}."/".$this->{project};
  
  # where data files live
  $this->{data_twiki}="data/TWiki";
  
  # the root of the name of data files for this plugin
  $this->{data_twiki_plugin}=$this->{data_twiki}."/".$this->{project};
  
  my $dtpt = $basedir."/".$this->{data_twiki_plugin}.".txt";
  
  # the file list, determined from the plugin topic
  my @files;
  open(PF, "<$dtpt") ||
	die "Plugin topic $dtpt missing";
  my $line;
  while ($line = <PF>) {
	if ($line =~ /^\s+\|\s+==(.*?)==\s+\|\s*(.*?)\s*\|$/o) {
	  my $file = $1;
	  my $descr = $2;
	  $file =~ s/%TOPIC%/$plugin/go;
	  push(@files, $file);
	} elsif ($line =~ /^\s+\|\s+\*Module\*\s+\|\s+\*Type\*\s+\|\s+\*Version\*\s+\|/o) {
	  $line = <PF>;
	  while ($line =~ /^\s+\|(.*)\|(.*)\|(.*)\|(.*)\|$/) {
		my $mod = $1;
		my $type = $2;
		if ($type =~ /perl/o) {
		  eval "use $mod";
		  if ($@) {
			warn "Perl module $mod not found";
		  }
		}
		$line = <PF>;
	  }
	}
  }
  close(PF);
  $this->{file_list} = join(" ", @files);
  
  return bless( $this, $class );
}

=pod
  
---++ cd($dir)
  Change to the given directory

=cut
sub cd {
  my ($this, $file) = @_;
  
  if ($this->{-v} || $this->{-n}) {
	print "cd $file\n";
  }
  if (!$this->{-n}) {
	chdir($file) || die "Failed to cd to $file";
  }
}

sub rm {
  my ($this, $file) = @_;
  
  if ($this->{-v} || $this->{-n}) {
	print "rm $file\n";
  }
  unless ($this->{-n}) {
	unlink($file) || warn "Failed to delete $file";
  }
}

=pod

---+ makepath($to)
Make a directory and all directories leading to it.

=cut
sub makepath {
  my ($this, $to) = @_;
  
  chop($to) if ($to =~ /\n$/o);
  
  return if (-d $to);
  if (! -e $to) {
	$this->makepath(`dirname $to`);
	if ($this->{-v} || $this->{-n}) {
	  print "mkdir $to\n";
	}
	unless ($this->{-n}) {
	  mkdir($to) || warn "Failed to make $to: $!";
	}
  } else {
	warn "$to exists and is not a directory; cannot create a dir over it";
  }
}

=pod

---++ cp($from, $to)
Copy a single file from - to. Will automatically make intervening
directories in the target.

=cut
sub cp {
  my ($this, $from, $to) = @_;
  
  $this->makepath(`dirname $to`);
  
  if ($this->{-v} || $this->{-n}) {
	print "cp $from $to\n";
  }
  unless ($this->{-n}) {
	File::Copy::copy($from, $to) ||
		warn "Failed to copy $from to $to: $!";
  }
}

=pod

---++ prot($perms, $file)
Set permissions on a file. Permissions should be expressed using POSIX
chmod notation.

=cut
sub prot {
  my ($this, $perms, $file) = @_;
  
  $this->sys_action("chmod $perms $file");
}

=pod

---++ run_tests($module)
Run a Test::Unit test module, using TestRunner

=cut
sub run_tests {
  my ($this, $module) = @_;
  $this->sys_action("perl -w -I../../../.. -I. TestRunner.pl $module");
}

=pod

---++ sys_action($cmd)
Perform a "system" command.

=cut
sub sys_action {
  my ($this, $cmd) = @_;
  
  if ($this->{-v} || $this->{-n}) {
	print "$cmd\n";
  }
  unless ($this->{-n}) {
	system($cmd);
	die "Failed to $cmd\n" if ($?);
  }
}

=pod

---++ target_build
Basic build target

=cut
sub target_build {
  my $this = shift;
  # does nothing
}

=pod

---++ target_test
Basic Test::Unit test target, runs <project>Suite

=cut
sub target_test {
  my $this = shift;
  $this->build("build");
  $this->cd("$basedir/".$this->{plugin_libdir}."/test");
  $this->sys_action("make");
  $this->run_tests($this->{project}."Suite");
}

=pod

---++ target_release
Release target, builds release zip

=cut
sub target_release {
  my $this = shift;
  $this->build("tests_zip");
  my $plugin = $this->{project};
  $this->cd("$basedir");
  $this->rm("$plugin.zip");
  foreach my $file (split/\s+/, $this->{file_list}) {
	if (! -e $file) {
	  die "$file does not exist - cannot build release\n";
	}
  }
  $this->sys_action("zip $plugin.zip ".$this->{file_list});
}

=pod

---++ target_install
Install target, installs to local twiki pointed at by TWIKI_HOME

=cut
sub target_install {
  my $this = shift;
  $this->build("build");
  
  my $twiki = $ENV{TWIKI_HOME};
  die "TWIKI_HOME not set" unless $twiki;
  my @files = split(/\s+/, $this->{file_list});
  print "Installing " . scalar(@files) . " in $twiki\n";
  foreach my $file (@files) {
	$this->cp("$basedir/$file", "$twiki/$file");
	$this->prot("a+rx,u+w", "$twiki/$file");
  }
}

=pod

---++ target_uninstall
Uninstall target, uninstall from local twiki (part of a clean)
pointed at by TWIKI_HOME

=cut
sub target_uninstall {
  my $this = shift;
  my $twiki = $ENV{TWIKI_HOME};
  die "TWIKI_HOME not set" unless $twiki;
  foreach my $file (split(/\s+/, $this->{file_list})) {
	$this->rm("$twiki/$file");
  }
}

=pod

---++ target_test_zip
Make the tests zip file

=cut
sub target_tests_zip {
  my $this = shift;
  
  $this->cd("$basedir/".$this->{plugin_libdir});
  $this->rm("test.zip");
  $this->sys_action("zip -r test.zip test -x '*~' -x '*/CVS*' -x '*/testdata*' -x \*/accesscheck");
}

=pod

---++ build($target)
Build the given target

=cut
no strict "refs";
sub build {
  my $this = shift;
  my $target = shift;
  print "Building $target\n";
  eval "\$this->target_$target()";
  print "Built $target\n";
}
use strict "refs";

1;
