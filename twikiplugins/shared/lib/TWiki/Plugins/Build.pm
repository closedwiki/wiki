#
# Copyright (C) 2004 C-Dot Consultants - All rights reserved
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
package TWiki::Plugins::Build;

=begin text

---+ Package TWiki::Plugins::Build
Base class of build objects for TWiki packages. Creates a build environment
that addresses most of the common requirements for building plugins.

Works by defining targets as functions that can then be subclassed and added
to. Just about as simple a build system as you could get.

The list of files to be installed is determined from the MANIFEST.
Only these files will get into the release zip.

The following help information is cursory; for full details, look at an example or read the code.
---++ Targets
The following targets will always exist:
   1 build - check that everything is perl
   1 test - run unit tests
   1 install - install on local installation defined by $TWIKI_HOME
   1 uninstall - uninstall from local installation defined by $TWIKI_HOME
   1 pod - build POD documentation
   1 release - build, pod and package a release zip
   1 upload - build, pod, package and upload to twiki.org
Note: if you orverride any of these targets it is generally wise to call the SUPER version of the target!
---++ Standard directory structure
The standard module directory structure mirrors the TWiki installation directory structure, so each file in the development directory structure is in the place it will be in in the actual installation. From the root, these are the key files:
   * MANIFEST - required - list of files and descriptions to include in release zip
      * each file is given by the full path to the file relative to the build TWiki installation directory. Wildcards may NOT be used.
   * DEPENDENCIES - optional list of dependencies on other modules and descriptions
      * Dependencies should be expressed as "name type description" where name is the name of the module, type is its type (CPAN, perl, C etc) and description is a short description of the module and where to get it.
      *  The special type "shared" is used to refer to a module from the plugins shared code repository.
   * lib/ - as you expect to see in installation. Should also contain other Perl modules.
      * lib/TWiki/
         * lib/TWiki/Plugins/ - this is where your <plugin name>.pm file goes for plugins
            * lib/TWiki/Plugins/<plugin name>/ - directory containing sub-modules used by your plugin, and your build script.
   * data/ - as you expect to see in the installation
   * pub/ - as you expect to see in the installation. You must list required directories, even if they are initially empty.
   * templates/ - as you expect to see in installation
      * templates/<skin name>/ - this is where templates for your skin go
---++ Token expansion
The build supports limited token expansion in =.txt= files. It expands the following tokens by default when the release target is built.
| =%$<nop>MANIFEST%= | Expands to a TWiki table of MANIFEST contents |
| =%$<nop>DEPENDENCIES%= | Expands to a comma-separated list of dependencies |
| =%$<nop>DATE%= | Expands to today's date |
| =%$<nop>VERSION%= | Expands to the VERSION number set in the plugin main .pm topic |
| =%$<nop>POD%= | Expands POD text in all =.pm= files in the MANIFEST. Pod is generated for each module in the order of the MANIFEST. |
---++ Methods

=cut

use strict;
use File::Copy;
use File::Spec;
use Pod::Text;
use POSIX;
use diagnostics;
use vars qw( $basedir $shared $twiki_home);

BEGIN {
  use File::Spec;
  my $cwd = `dirname $0`; chop($cwd);
  $basedir = File::Spec->rel2abs("../../../..", $cwd);
  $shared = $ENV{"TWIKI_SHARED"};
  $twiki_home = $ENV{"TWIKI_HOME"};
  unshift @INC, $basedir;
  unshift @INC, '.';
}

=begin text

---+++ new($project)
| $project | the plugin/addon/skin name |
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
  $this->{lib_plugins} = "lib/TWiki/Plugins";

  # where the plugin sub-modules live
  $this->{plugin_libdir} = $this->{lib_plugins}."/".$this->{project};

  # the .pm module for this plugin
  $this->{plugin_pm} = $this->{plugin_libdir}.".pm";

  # where data files live
  $this->{data_twiki} = "data/TWiki";

  # the root of the name of data files for this plugin
  $this->{data_twiki_plugin} = $this->{data_twiki}."/".$this->{project};

  # read the manifest
  my $manifest = "$basedir/MANIFEST";
  open(PF, "<$manifest") ||
	die "$manifest missing";
  my $line;
  while ($line = <PF>) {
	if ( $line =~ /^(\S+)(\s+(\S.*))?\s*$/o ) {
	  push(@{$this->{files}},
		   { name => $1, description => ($3 || "") });
	}
  }
  close(PF);
  my $mantable = "";
  foreach my $file (@{$this->{files}}) {
	$mantable .= "\t| ==" . $file->{name} . "== | " .
	  $file->{description} . " |\n";
  }
  $this->{MANIFEST} = $mantable;

  my $deps = "$basedir/DEPENDENCIES";
  if (-f $deps) {
	open(PF, "<$deps") ||
	  die "$deps open failed";
	while ($line = <PF>) {
	  if ($line =~ m/^(\w+)\s+(\w*)\s*(.*)$/o) {
		push(@{$this->{dependencies}},
			 { name=>$1, type=>$2, description=>$3 });
	  }
	}
  }
  close(PF);
  my $deptable = "";
  foreach my $dep (@{$this->{dependencies}}) {
	$deptable .= " ==" . $dep->{name} . "== (" . $dep->{type} . " " .
	  $dep->{description} . ")";
  }
  $this->{DEPENDENCIES} = $deptable;

  my $version = "Unknown";
  if (open(IF, $this->{plugin_pm})) {
	while (<IF>) {
	  if (/\$VERSION\s*=\s*['"](.*)['"]/o) {
		$version = $1;
		last;
	  }
	}
	close(IF);
  }
  $this->{VERSION} = $version;

  $this->{DATE} = POSIX::strftime("%d %B %Y", localtime);

  return bless( $this, $class );
}

=begin text

---+++ cd($dir)
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
	unlink($file) || warn "Warning: Failed to delete $file";
  }
}

=begin text

---+++ makepath($to)
Make a directory and all directories leading to it.

=cut
sub makepath {
  my ($this, $to) = @_;

  chop($to) if ($to =~ /\n$/o);

  return if (-d $to || $this->{made_dir}->{$to});
  $this->{made_dir}->{$to} = 1;

  if (! -e $to) {
	$this->makepath(`dirname $to`);
	if ($this->{-v} || $this->{-n}) {
	  print "mkdir $to\n";
	}
	unless ($this->{-n}) {
	  mkdir($to) || warn "Warning: Failed to make $to: $!";
	}
  } else {
	warn "Warning: $to exists and is not a directory; cannot create a dir over it";
  }
}

=begin text

---+++ cp($from, $to)
Copy a single file from - to. Will automatically make intervening
directories in the target. Also works for target directories.

=cut
sub cp {
  my ($this, $from, $to) = @_;

  die "Source file $from does not exist " unless ( $this->{-n} || -e $from);

  $this->makepath(`dirname $to`);

  if ($this->{-v} || $this->{-n}) {
	print "cp $from $to\n";
  }
  unless ($this->{-n}) {
	if ( -d $from ) {
	  mkdir($to) || warn "Warning: Failed to make $to: $!";;
	} else {
	  File::Copy::copy($from, $to) ||
		warn "Warning: Failed to copy $from to $to: $!";
	}
  }
}

=begin text

---+++ prot($perms, $file)
Set permissions on a file. Permissions should be expressed using POSIX
chmod notation.

=cut
sub prot {
  my ($this, $perms, $file) = @_;
  
  $this->sys_action("chmod $perms $file");
}

=begin text

---+++ run_tests($module)
Run a Test::Unit test module, using TestRunner

=cut
sub run_tests {
  my ($this, $module) = @_;
  $this->sys_action("perl -w -I$basedir/lib -I$shared/lib -I$shared/test/fixtures -I. $shared/test/TestRunner.pl $module");
}

=begin text

---+++ sys_action($cmd)
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

=begin text

---+++ target_build
Basic build target. By default does nothing, but subclasses may want to
extend on that.

=cut
sub target_build {
  my $this = shift;
  # does nothing
}

=begin text

---+++ target_test
Basic Test::Unit test target, runs <project>Suite.

=cut

sub target_test {
  my $this = shift;
  $this->build("build");
  $this->cd("$basedir/".$this->{plugin_libdir}."/test");
  $this->run_tests($this->{project}."Suite");
}

=begin text

---+++ filter
Expands tokens in a documentation topic.Four tokens are supported:
   * %$MANIFEST% - TWiki table of files in MANIFEST
   * %$DEPENDENCIES% - list of dependencies from DEPENDENCIES
   * %$VERSION% version from $VERSION in plugin main .pm
   * %$DATE% - local date
   * %$POD% - expands to the POD documentation for the package, excluding test modules.

=cut

sub filter {
  my ($this, $from, $to) = @_;

  return unless (-f $from);

  open(IF, "<$from") || die "No source topic $from for filter";
  unless ($this->{-n}) {
	open(OF, ">$to") || die "No dest topic $to for filter";
  }
  my $line;	
  while ($line = <IF>) {
	$line =~ s/%\$(\w+)%/&_expand($this,$1)/geo;
	print OF $line unless ($this->{-n});
  }
  close(IF);
  close(OF) unless ($this->{-n});
}

sub _expand {
  my ($this, $tok) = @_;
  if (!$this->{$tok} && $tok eq "POD") {
	$this->build("pod");
  }
  if (defined($this->{$tok})) {
	if ($this->{-v} || $this->{-n}) {
	  print "expand %\$$tok% to ".$this->{$tok}."\n";
	}
	return $this->{$tok};
  } else {
	return "%\$".$tok."%";
  }
}

=begin text

---+++ target_release
Release target, builds release zip by creating a full release directory
structure in /tmp and then zipping it in one go. Only files explicitly listed
in the MANIFEST are released. Automatically runs =filter= on all =.txt= files
in the MANIFEST.

=cut
sub target_release {
  my $this = shift;
  my $plugin = $this->{project};

  $this->build("tests_zip");

  my $tmpdir = "/tmp/$$";
  $this->makepath($tmpdir);

  $this->copy_fileset($this->{files}, $basedir, $tmpdir);
  foreach my $file (@{$this->{files}}) {
	if ($file->{name} =~ /\.txt$/) {
	  my $txt = $file->{name};
print "Filtering $txt\n";
	  $this->filter("$basedir/$txt", "$tmpdir/$txt");
	}
  }
  $this->cp("$tmpdir/".$this->{data_twiki_plugin}.".txt",
			"$basedir/$plugin.txt");
  $this->cd($tmpdir);
  $this->sys_action("zip -r $plugin.zip *");
  $this->sys_action("mv $tmpdir/$plugin.zip $basedir/$plugin.zip");
  print "Release ZIP is $basedir/$plugin.zip\n";
  print "Release TOPIC is $basedir/$plugin.txt\n";
  $this->sys_action("rm -rf $tmpdir");;
}

=begin text

---+++ copy_fileset
Copy all files in a file set from on directory root to another.

=cut
sub copy_fileset {
  my ($this, $set, $from, $to) = @_;

  my $uncopied = scalar(@$set);
  print "Copying $uncopied files to $to\n";
  foreach my $file (@$set) {
	my $name = $file->{name};
	if (! -e "$from/$name") {
	  die "$from/$name does not exist - cannot copy\n";
	}
	$this->cp("$from/$name", "$to/$name");
	#$this->prot("a+rx,u+w", "$to/$name");
	$uncopied--;
  }
  die "Files left uncopied" if ($uncopied);
}

=begin text

---+++ target_install
Install target, installs to local twiki pointed at by TWIKI_HOME.

=cut
sub target_install {
  my $this = shift;
  $this->build("build");

  my $twiki = $ENV{TWIKI_HOME};
  die "TWIKI_HOME not set" unless $twiki;
  $this->copy_fileset($this->{files}, $basedir, $twiki);
}

=begin text

---+++ target_uninstall
Uninstall target, uninstall from local twiki pointed at by TWIKI_HOME.

=cut
sub target_uninstall {
  my $this = shift;
  my $twiki = $ENV{TWIKI_HOME};
  die "TWIKI_HOME not set" unless $twiki;
  foreach my $file (@{$this->{files}}) {
	$this->rm("$twiki/".$file->{name});
  }
}

=begin text

---+++ target_test_zip
Make the tests zip file for inclusion in the release package.

=cut
sub target_tests_zip {
  my $this = shift;

  $this->cd("$basedir/".$this->{plugin_libdir});
  $this->rm("test.zip");
  if (-d 'test') {
	$this->sys_action("zip -r test.zip test -x '*~' -x '*/CVS*' -x '*/testdata*'");
  }
}

=begin text

---+++ target_upload
Upload to twiki.org. Prompts for username and password. Uploads the zip and
the text topic to the appropriate places. Creates the topic on twiki.org if
necessary. Requires curl.

=cut

sub target_upload {
  my $this = shift;
  $this->build("release");

  my $user;
  my $pass;
  do {
	print "Username on TWiki.org: ";
	$user = <STDIN>;
  } while ( !$user || $user =~ /^\s*$/ );
  chop($user);
  do {
	print "Password: ";
	$pass = <STDIN>;
  } while (!$pass || $pass =~ /^\s*$/);
  chop($pass);
  my $curl = "curl -s -S -u $user:$pass";
  my $to = $this->{project};
  print `$curl -F text=\\<$basedir/$to.txt http://TWiki.org/cgi-bin/save/Plugins/$to`;
  die "Update of topic failed: $?" if ( $?);
  print `$curl -F filepath=\\\@$basedir/$to.zip -F filename=$to.zip http://TWiki.org/cgi-bin/upload/Plugins/$to`;
  die "Update of zip failed: $?" if ( $?);
}

=begin text

---+++ target_pod

Build POD documentation. This target defines =%$POD%= - it
does not generate any output files. The target will be invoked
automatically if =%$POD%= is used in a .txt file. POD documentation
is intended for use by developers only.

POD test in =.pm= files should use TWiki syntax or HTML. Packages should be
introduced with a level 0 header, and each method in the package by
a second level header. Make sure you document any global variables used
by the module.

=cut

sub target_pod {
  my $this = shift;
  my $tmpfile = "/tmp/buildpod";
  $this->{POD} = "";

  foreach my $file (@{$this->{files}}) {
	my $pmfile = $file->{name};
	if ($pmfile =~ /\.pm$/o) {
	  $pmfile = "$basedir/$pmfile";
	  my $parser = new Pod::Text(indent => 0);
	  $parser->parse_from_file($pmfile, $tmpfile);
	  open(TMP, $tmpfile);
	  while (<TMP>) {
		$this->{POD} .= $_;
	  }
	  close(TMP);
	}
  }
  unlink($tmpfile);
}

=begin text

---+++ build($target)
Build the given target

=cut
no strict "refs";
sub build {
  my $this = shift;
  my $target = shift;
  print "Building $target\n";
  eval "\$this->target_$target()";
  if ($@) {
	print "Failed to build $target: $@\n";
	die $@;
  }
  print "Built $target\n";
}
use strict "refs";

1;
