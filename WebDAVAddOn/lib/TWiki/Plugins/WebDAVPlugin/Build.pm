#
# Simple build and uninstall for plugin packages. Resides in the plugins
# submodules directory. Normally used by developers for installing,
# but also has uninstall target.
#
# The list of files to be installed is determined from the table in
# the plugin topic.
#
# The following targets should always exist:
# 1. build - check that everything is perl
# 2. test - run unit tests
# 3. install - install on local installation defined by $TWIKI_HOME
# 4. release - package a release zip
#
{ package Build;

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
	
	chdir("$basedir/".$this->{plugin_libdir});
	$this->{test_files} = `find test -name '*.pm' -print` . " " .
	  `find test -name '*.pl' -print` . " " .
		`find test -name '*.c' -print`;
	
	return bless( $this, $class );
  }

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

  sub prot {
	my ($this, $perms, $file) = @_;
	
	$this->sys_action("chmod $perms $file");
  }

  sub run_tests {
	my ($this, $module) = @_;
	$this->sys_action("perl -w -I../../../.. -I. TestRunner.pl $module");
  }

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

  sub target_build {
	my $this = shift;
	# does nothing
  }

  sub target_test {
	my $this = shift;
	$this->build("build");
	$this->cd("$basedir/".$this->{plugin_libdir}."/test");
	$this->sys_action("make");
	$this->run_tests($this->{project}."Suite");
  }

  sub target_release {
	my $this = shift;
	$this->build("tests_zip");
	my $plugin = $this->{project};
	$this->cd("$basedir");
	$this->rm("$plugin.zip");
	$this->sys_action("zip $plugin.zip ".$this->{file_list});
  }
  sub target_install {
	my $this = shift;
	$this->build("build");
	my $twiki = $ENV{TWIKI_HOME};
	die "TWIKI_HOME not set" unless $twiki;
	foreach my $file (split(/\s+/, $this->{file_list})) {
	  $this->cp("$basedir/$file", "$twiki/$file");
	  $this->prot("a+rx,u+w", "$twiki/$file");
	}
  }

  sub target_uninstall {
	my $this = shift;
	my $twiki = $ENV{TWIKI_HOME};
	die "TWIKI_HOME not set" unless $twiki;
	foreach my $file (split(/\s+/, $this->{file_list})) {
	  $this->rm("$twiki/$file");
	}
  }

  sub target_tests_zip {
	my $this = shift;
	$this->build("test");
	
	$this->cd("$basedir/".$this->{plugin_libdir});
	$this->rm("test.zip");
	$this->sys_action("zip -r test.zip ".$this->{test_files});
  }

  no strict "refs";
  sub build {
	my $this = shift;
	my $target = shift;
	print "Build $target\n";
	eval "\$this->target_$target()";
  }
  use strict "refs";
}

1;
