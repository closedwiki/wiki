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
package TWiki::Contrib::Build;

=begin text

---++ Package TWiki::Contrib::Build
Base class of build objects for TWiki packages. Creates a build environment
that addresses most of the common requirements for building plugins and
contrib modules.

Use by writing a subclass in a script that you then run. Targets are defined as functions, so adding new targets or dependencies between targets is done by subclassing the base class. When used to generate a build script, this class will interpret the following command-line options:
| -n | Do nothing |
| -v | Be verbose |

The list of files to be installed is determined from the MANIFEST.
Only these files will get into the release zip.

Requires the environment variable TWIKI_LIBS (a colon-separated path
list) to be set to point at any required dependencies.

The following help information is cursory; for full details, look at an example or read the code.

---+++ Targets
The following targets will always exist:
| build | check that everything is perl |
| test | run unit tests |
| install | install on local installation defined by $TWIKI_HOME |
| uninstall | uninstall from local installation defined by $TWIKI_HOME |
| pod | build POD documentation |
| release | build, pod and package a release zip |
| upload | build, pod, package and upload to twiki.org |
| manifest | print to STDOUT a default manifest file |
Note: if you override any of these targets it is generally wise to call the SUPER version of the target!
---+++ Standard directory structure
The standard module directory structure mirrors the TWiki installation directory structure, so each file in the development directory structure is in the place it will be in in the actual installation. From the root, these are the key files:
| MANIFEST | required - list of files and descriptions to include in release zip. Each file is given by the full path to the file relative to the build TWiki installation directory. Wildcards may NOT be used. |
| DEPENDENCIES | optional list of dependencies on other modules and descriptions. See below |
| PREINSTALL, POSTINSTALL, PREUNINSTALL, POSTUNINSTALL | these optional files _may_ contain Perl fragments that must execute at the given stage of the process. The script fragments will be inserted into the generated installer script. Read contrib/TEMPLATE_installer.pl to see how they fit in. |
| lib/TWiki/Plugins/ | this is where your <plugin name>.pm file goes for plugins |
| lib/TWiki/Plugins/<plugin name>/ | directory containing sub-modules used by your plugin, and your build.pl script. |
| lib/TWiki/Contrib/ | this is where your <contrib name>.pm file goes for contribs |
| lib/TWiki/Contrib/<contrib name>/ | directory containing sub-modules used by your contrib, and your build.pl script. |
| data/ | as you expect to see in the installation |
| pub/ | as you expect to see in the installation. You must list required directories, even if they are initially empty. |
| templates/ | as you expect to see in installation |
| templates/<skin name>/ | this is where templates for your skin go |
| contrib/ | this is where non-TWiki, non-web-accessible files associated with a Contrib or plugin go |
---+++ Dependencies
The DEPENDENCIES file contains a list of lines, each of which is a comma-separated tuple
<verbatim>
name, version, type, description
</verbatim>
where
   * name is the name of the module,
   * version is the version constraint (e.g. ">1.5"),
   * type is its type (CPAN, perl, C etc) and
   * description is a short description of the module and where to get it.
Perl modules also referenced in the dependencies list in the stub topic should be listed using their perl package name (e.g. TWiki::Contrib::MyContrib) and use the type 'perl'.
A dependency may optionally be preceded by a condition that limits the cases where the dependency applies. The condition is give on a line that contains <code>ONLYIF ( _condition_ )</code>, where _condition_ is a Perl conditional. This is most useful for enabling dependencies only for certain versions of TWiki. For example,
<verbatim>
TWiki::Contrib::Attrs,>=1.000,perl,Required. Download from TWiki:Plugins/AttrsContrib and install.
ONLYIF ($TWiki::Plugins::VERSION < 1.025)
TWiki::Plugins::CairoContrib, >=1.000, perl, Optional, only required if the plugin is to be run with versions of TWiki before Cairo. Available from the TWiki:Plugins/CairoContrib repository.
</verbatim>
Thus <nop>CairoContrib is only a dependency if the installation is being done on a TWiki version before Cairo. The ONLYIF only applies to the next dependency in the file.

---+++ Token expansion
The build supports limited token expansion in =.txt= files. See the documentation on the =filter= method for more detail.
---+++ Methods

=cut

use strict;
use File::Copy;
use File::Spec;
use Pod::Text;
use POSIX;
use diagnostics;
use vars qw( $VERSION $basedir $twiki_home $buildpldir $libpath );

$VERSION = 1.004;

BEGIN {
    use File::Spec;
    $buildpldir = `dirname $0`; chop($buildpldir);
    $buildpldir = File::Spec->rel2abs($buildpldir);
    $basedir = $buildpldir;
    # Find the lib root
    unless ($basedir =~ s/^(.*)[\\\/](lib[\\\/]TWiki[\\\/].*)$/$1/) {
        die "Couldn't find lib/TWiki in $basedir";
    }
    $libpath = $2;
    $libpath =~ s/[\\\/][^\\\/]*$//;

    $twiki_home = $ENV{"TWIKI_HOME"};
    if ($ENV{TWIKI_LIBS}) {
        foreach my $pc (split(/:/,$ENV{TWIKI_LIBS})) {
            unless(grep(/$pc/,@INC)) {
                unshift(@INC, $pc);
            }
        }
    }
    unless(grep(/$basedir\/lib/,@INC)) {
        unshift(@INC, "$basedir/lib");
    }
}

=begin text

---++++ new($project)
| $project | Name of plugin, addon, contrib or skin |
| $rootModule | Optional, if defined gives the name of the root .pm module that carries the VERSION and dependencies. Defaults to $project |
Construct a new build object. Define the basic directory
paths to places in the build/release. Read the manifest topic
and build file and dependency lists. Parse command line to get
target and options.

=cut
sub new {
    my ( $class, $project, $rootModule ) = @_;
    my $this = {};

    $this->{project} = $project;
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
    if ($this->{-v}) {
        print "Building in $buildpldir\n";
        print "Basedir is $basedir\nComponent dir is $libpath\n";
        print "Using path ".join(":",@INC)."\n";
    }

    chdir($basedir);
    $basedir = `pwd`;
    chop($basedir);
    $this->{basedir} = $basedir;

    # The following paths are all relative to the root of the twiki
    # installation

    # where the sub-modules live
    $this->{libdir} = $libpath;

    # the .pm module
    if ($rootModule) {
        $this->{pm} = "$libpath/$rootModule.pm";
    } else {
        $this->{pm} = "$libpath/$project.pm";
    }

    my $stubpath = $this->{pm};
    $stubpath =~ s/.*[\\\/](TWiki[\\\/].*)\.pm/$1/;
    $stubpath =~ s/[\\\/]/::/g;
    $this->{STUB} = $stubpath;

    # where data files live
    $this->{data_twiki} = "data/TWiki";

    # the root of the name of data files
    $this->{data_twiki_module} = "$this->{data_twiki}/$this->{project}";

    # read the manifest
    my $manifest = "$basedir/MANIFEST";
    unless (open(PF, "<$manifest")) {
        target_manifest(); #CodeSmell - calling package sub not object method
        die "$manifest missing";
    }
    my $line;
    while ($line = <PF>) {
        if ( $line =~ /^(\S+)(\s+(\S.*))?\s*$/o ) {
            push(@{$this->{files}},
                 { name => $1, description => ($3 || "") });
        }
    }
    close(PF);

    my $deps = "$basedir/DEPENDENCIES";
    my $condition = "";
    if (-f $deps) {
        open(PF, "<$deps") ||
          die "$deps open failed";
        while ($line = <PF>) {
            if ($line =~ /^ONLYIF\s*(\(.*\))\s*$/) {
                $condition = $1;
            } elsif ($line =~ m/^(\w+)\s+(\w*)\s*(.*)$/o) {
                push(@{$this->{dependencies}},
                     { name=>$1, type=>$2, version=>"",
                       description=>$3, trigger=>$condition});
                $condition="";
            } elsif ($line =~ m/^([^,]+),([^,]*),\s*(\w*)\s*,\s*(.+)$/o) {
                push(@{$this->{dependencies}},
                     { name=>$1, version=>$2, type=>$3, description=>$4,
                       trigger=>$condition });
                $condition="";
            } elsif ($line !~ /^\s*$/ && $line !~ /^\s*#/) {
                warn "WARNING: LINE $line IN $basedir/DEPENDENCIES IGNORED\n";
            }
        }
    } else {
        warn "WARNING: no $deps; dependencies will only be extracted from code\n";
    }
    close(PF);

    my $version = "Unknown";
    if (open(PF,"<$basedir/$this->{pm}")) {
        my $text = "";
        while ($line = <PF>) {
            $line =~ s/\s+//g;
            $text .= "$line\n";
        }
        if ($text =~ /^\$VERSION=(.*?);$/m) {
            $version = $1;
        }
        if ($text =~ /\@dependencies=\((.*?)\)/o ) {
            $text = $1;
            while ($text =~ s/package=>['"](.*?)['"],constraint=>['"](.*?)['"]//) {
                my ($name,$ver,$found) = ($1,$2,0);
                if ($name !~ /^TWiki::(Plugins|Contrib|AddOn)$/) {
                    foreach my $dep (@{$this->{dependencies}}) {
                        if ($dep->{name} eq $name) {
                            $dep->{version} = $ver;
                            $found = 1;
                            last;
                        }
                    }
                    unless ($found || $name eq "TWiki::Plugins") {
                        push(@{$this->{dependencies}},
                             { name=>$name, version=>$ver, type=>'perl',
                               description=>$name, trigger=>"" });
                    }
                }
            }
        }
    } else {
        warn "WARNING: $this->{pm} not found; cannot extract VERSION or in-code dependencies\n";
    }
    close(PF);

    # Add the install script to the manifest, unless it is already there
    unless( grep(/^$this->{project}_installer.pl$/,
                 map {$_->{name}} @{$this->{files}})) {
        push(@{$this->{files}},
             { name => "$this->{project}_installer.pl",
               description => "Install script" });
        print "Auto-adding install script to manifest\n";
    }

    my $mantable = "";
    foreach my $file (@{$this->{files}}) {
        $mantable .= "\t| ==" . $file->{name} . "== | " .
          $file->{description} . " |\n";
    }
    $this->{MANIFEST} = $mantable;

    my $deptable = "";
    my $a = " align=\"left\"";
    foreach my $dep (@{$this->{dependencies}}) {
        my $v = $dep->{version};
        $v =~ s/&/&amp;/go;
        $v =~ s/>/&gt;/go;
        $v =~ s/</&lt;/go;
        $deptable .= "<tr><td$a>" .
          $dep->{name} . "</td><td$a>" .
            $v . "</td><td$a>" .
              $dep->{description} . "</td></tr>";
    }
    $this->{DEPENDENCIES} = "None";
    if ($deptable ne "") {
        $this->{DEPENDENCIES} = "<table border=1><tr><th$a>Name</th><th$a>Version</th><th$a>Description</th></tr>$deptable</table>";
    }
    $this->{VERSION} = $version;
    $this->{DATE} = POSIX::strftime("%T %d %B %Y", localtime);

    undef $/;
    foreach my $stage ( "PREINSTALL", "POSTINSTALL", "PREUNINSTALL", "POSTUNINSTALL" ) {
        $this->{$stage} = "# No $stage script";
        my $file = "$basedir/$stage";
        if (-f $file) {
            open(PF, "<$file") ||
              die "$file open failed";
            $this->{$stage} = <PF>;
        }
    }
    $/ = "\n";

    $this->{MODULE} = $this->{project};

    return bless( $this, $class );
}

=begin text

---++++ cd($dir)
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
    if (-e $file && !$this->{-n}) {
        unlink($file) || warn "WARNING: Failed to delete $file";
    }
}

=begin text

---++++ makepath($to)
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

---++++ cp($from, $to)
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

---++++ prot($perms, $file)
Set permissions on a file. Permissions should be expressed using POSIX
chmod notation.

=cut

sub prot {
    my ($this, $perms, $file) = @_;

    $this->sys_action("chmod $perms $file");
}

=begin text

---++++ sys_action($cmd)
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

---++++ target_build
Basic build target. By default does nothing, but subclasses may want to
extend on that.

=cut

sub target_build {
    my $this = shift;
    # does nothing
}

=begin text

---++++ target_test
Basic Test::Unit test target, runs <project>Suite.

=cut

sub target_test {
    my $this = shift;
    $this->build("build");
    my $testrunner;

    # find testrunner
    foreach my $d ( @INC ) {
        my $dir = `dirname $d`;
        chop($dir);
        $dir .= "/contrib";
        if (-f "$dir/TestRunner.pl") {
            $testrunner = "-I $dir/fixtures $dir/TestRunner.pl";
            last;
        }
    }

    my $testdir = "$basedir/$this->{libdir}/$this->{project}/test";
    my $testsuite = $this->{project}."Suite";
    if (!-f "$testdir/$testsuite.pm") {
        warn "WARNING: COULD NOT FIND ANY TESTS FOR '$this->{project}' IN $testdir/$testsuite.pm\n";
        return;
    }
    unless($testrunner) {
        warn "WARNING: CANNOT RUN TESTS; ../contrib/TestRunner.pl not found in path\n";
        return;
    }
    $this->cd($testdir);
    my $inc = join(" -I", @INC);
    $this->sys_action("perl -w -I$inc $testrunner $testsuite");
}

=begin text

---++++ filter
Expands tokens. The following tokens are supported:
   * %$MANIFEST% - TWiki table of files in MANIFEST
   * %$DEPENDENCIES% - list of dependencies from DEPENDENCIES
   * %$VERSION% version from $VERSION in main .pm
   * %$DATE% - local date
   * %$POD% - expands to the POD documentation for the package, excluding test modules.
   * %$PREINSTALL% - inserts script from PREINSTALL (alongside MANIFEST etc)
   * %$POSTINSTALL% - inserts script from POSTINSTALL (alongside MANIFEST etc)
   * %$PREUNINSTALL% - inserts script from PREUNINSTALL (alongside MANIFEST etc)
   * %$POSTUNINSTALL% - inserts script from POSTINSTALL (alongside MANIFEST etc)
Three spaces is automatically translated to tab.

The filter is used in the generation of documentation topics and the installer
=cut

sub filter {
    my ($this, $from, $to) = @_;
    
    return unless (-f $from);
    
    open(IF, "<$from") || die "No source topic $from for filter";
    undef $/;
    my $text = <IF>;
    close(IF);
    $/ = "\n";
    $text =~ s/%\$(\w+)%/&_expand($this,$1)/geo;
    $text =~ s/ {3}/\t/g;

    unless ($this->{-n}) {
        open(OF, ">$to") || die "No dest topic $to for filter";
    }
    print OF $text unless ($this->{-n});
    print OF "<!-- Do _not_ attempt to edit this topic; it is auto-generated. Please add comments/questions/remarks to the Dev topic instead. -->\n";
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

---++++ target_release
Release target, builds release zip by creating a full release directory
structure in /tmp and then zipping it in one go. Only files explicitly listed
in the MANIFEST are released. Automatically runs =filter= on all =.txt= files
in the MANIFEST.

=cut
sub target_release {
    my $this = shift;
    my $project = $this->{project};

    $this->build("tests_zip");
    $this->build("installer");

    my $tmpdir = "/tmp/$$";
    $this->makepath($tmpdir);

    $this->copy_fileset($this->{files}, $basedir, $tmpdir);
    foreach my $file (@{$this->{files}}) {
        if ($file->{name} =~ /\.txt$/) {
            my $txt = $file->{name};
            $this->filter("$basedir/$txt", "$tmpdir/$txt");
        }
    }
    $this->cp("$tmpdir/".$this->{data_twiki_module}.".txt",
              "$basedir/$project.txt");
    $this->cd($tmpdir);
    $this->sys_action("zip -r -q $project.zip *");
    $this->sys_action("mv $tmpdir/$project.zip $basedir/$project.zip");
    print "Release ZIP is $basedir/$project.zip\n";
    print "Release TOPIC is $basedir/$project.txt\n";
    $this->sys_action("rm -rf $tmpdir");
}

=begin text

---++++ copy_fileset
Copy all files in a file set from on directory root to another.

=cut
sub copy_fileset {
    my ($this, $set, $from, $to) = @_;
    
    my $uncopied = scalar(@$set);
    if ($this->{-v} || $this->{-n}) {
        print "Copying $uncopied files to $to\n";
    }
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

---++++ target_install
Install target, installs to local twiki pointed at by TWIKI_HOME.

Uses the installer script written by target_installer

=cut
sub target_install {
    my $this = shift;
    $this->build("release");
    
    my $twiki = $ENV{TWIKI_HOME};
    die "TWIKI_HOME not set" unless $twiki;
    $this->cd($twiki);
    $this->sys_action("unzip -u -o $basedir/$this->{project}.zip");
    $this->sys_action("perl $this->{project}_installer.pl install");
}

=begin text

---++++ target_uninstall
Uninstall target, uninstall from local twiki pointed at by TWIKI_HOME.

Uses the installer script written by target_installer

=cut
sub target_uninstall {
    my $this = shift;
    my $twiki = $ENV{TWIKI_HOME};
    die "TWIKI_HOME not set" unless $twiki;
    $this->cd($twiki);
    $this->sys_action("perl $this->{project}_installer.pl uninstall");
}

=begin text

---++++ target_test_zip
Make the tests zip file for inclusion in the release package.

=cut
sub target_tests_zip {
    my $this = shift;
    my $where = "$basedir/$this->{libdir}/$this->{project}";
    $this->rm("$where/test.zip");
    $this->cd($where);
    if (-d 'test') {
        $this->sys_action("zip -r -q test.zip test -x '*~' -x '*/CVS*' -x '*/testdata*'");
    } else {
        warn "WARNING: no test subdirectory of $where\n";
    }
}

{   package TWiki::Contrib::Build::UserAgent;
    @TWiki::Contrib::Build::UserAgent::ISA = qw(LWP::UserAgent);

    my ( $knownUser, $knownPass );

    sub get_basic_credentials {
        my($self, $realm, $uri) = @_;
        unless ( $knownUser ) {
            print "Logon to ",$uri->host_port,"\n";
            print "Enter $realm: ";
            $knownUser = <STDIN>;
            chomp($knownUser);
            return (undef, undef) unless length $knownUser;
            print "Password on ",$uri->host_port,": ";
            system("stty -echo");
            $knownPass = <STDIN>;
            system("stty echo");
            print "\n";  # because we disabled echo
            chomp($knownPass);
        }
        return ($knownUser, $knownPass);
    }
}

=begin text

---++++ target_upload
Upload to twiki.org. Prompts for username and password. Uploads the zip and
the text topic to the appropriate places. Creates the topic on twiki.org if
necessary.

=cut

sub target_upload {
    my $this = shift;
    $this->build("release");

    eval 'use LWP';
    if ( $@ ) {
        print STDERR "LWP is not installed; cannot upload\n";
        return 0;
    }

    my $userAgent = TWiki::Contrib::Build::UserAgent->new();
    $userAgent->agent( "TWikiContribBuild/$VERSION " );

    my $to = $this->{project};

    # Get the old form data and attach it to the update
    print "Downloading old topic to recover form\n";
    my $response = $userAgent->get( "http://twiki.org/cgi-bin/view/Plugins/$to?raw=debug" );

    die "Failed to GET old plugins topic ", $response->request->uri,
      " -- ", $response->status_line, "\nAborting"
        unless $response->is_success;
    my %newform;
    foreach my $line ( split(/\n/, $response->content() )) {
        if ( $line =~ m/META:FIELD{name=\"(.*?)\".*?value=\"(.*?)\"}/ ) {
            my $val = $2;
            if ($val && $val ne "") {
                $newform{$1} = $val;
            }
        }
    }
    undef $/; # set to read to EOF
    open( IN_FILE, "<$basedir/$to.txt" ) or
      die "Failed to reopen topic: $@";
    $newform{'text'} = <IN_FILE>;
    $/ = "\n";
    close( IN_FILE );

    print "Uploading new topic\n";
    $response = $userAgent->post( "http://twiki.org/cgi-bin/save/Plugins/$to",
                                  \%newform );

    die "Update of topic failed ", $response->request->uri,
      " -- ", $response->status_line, "\nAborting"
        unless $response->is_redirect &&
          $response->headers->header('Location') =~ /view([\.\w]*)\/Plugins\/$to/;

    print "Uploading zip\n";
    $response =
      $userAgent->post( "http://twiki.org/cgi-bin/upload/Plugins/$to",
                        [
                         'filename' => "$to.zip",
                         'filepath' => [ "$basedir/$to.zip" ],
                         'filecomment' => "Unzip in the root directory of your TWiki installation"
                        ],
                        'Content_Type' => "form-data" );

    die "Update of zip failed ", $response->request->uri,
      " -- ", $response->status_line, "\nAborting\n", $response->as_string
        unless $response->is_redirect &&
          $response->headers->header('Location') =~ /view([\.\w]*)\/Plugins\/$to/;
}

sub _unhtml {
    my $html = shift;
    
    $html =~ s/<[^<>]*>//og;
    $html =~ s/&\w+;//go;
    $html =~ s/\s//go;
    
    return $html;
}

=begin text

---++++ target_pod

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

---++++ target_installer

Write an install/uninstall script that checks dependencies, and optionally
downloads and installs required zips from twiki.org.

The install script is templated from =contrib/TEMPLATE_installer= and
is always named =module_installer.pl= (where module is your module). It is
added to the release zip and is always shipped in the root directory.
It will automatically be added to the manifest if it doesn't appear in
MANIFEST.

The install script works using the dependency type and version fields.
It will try to download from twiki.org to satisfy any missing dependencies.
Downloaded modules are automatically installed.

Note that the dependencies will only work if the module depended on follows
the naming standards for zips i.e. it must be attached to the topic in
twiki.org and have the same name as the topic, and must be a zip file.

Dependencies on CPAN modules are also checked (type perl) but no attempt
is made to install them.

The install script also acts as an uninstaller.

__Note__ that =target_install= builds and invokes this install script.

At present there is no support for a caller-provided post-install script, but
this would be straightforward to do if it were required.

=cut

sub target_installer {
    my $this = shift;

    # Find the template on @INC
    my $template;
    foreach my $d ( @INC ) {
        my $dir = `dirname $d`;
        chop($dir);
        $dir .= "/contrib";
        if ( -f "$dir/TEMPLATE_installer.pl" ) {
            $template = "$dir/TEMPLATE_installer.pl";
            last;
        }
    }
    unless($template) {
        die "COULD NOT LOCATE TEMPLATE_installer.pl - required for install script generation";
    }

    my @sats;
    foreach my $dep (@{$this->{dependencies}}) {
        my $descr = $dep->{description};
        $descr =~ s/"/\\\"/g;
        $descr =~ s/\$/\\\$/g;
        $descr =~ s/\@/\\\@/g;
        $descr =~ s/\%/\\\%/g;
        my $trig = $dep->{trigger};
        $trig = 1 unless ( $trig );
        push(@sats, "{ name=>\"$dep->{name}\", type=>\"$dep->{type}\",version=>\"$dep->{version}\",description=>\"$descr\", trigger=>$trig }");
    }
    my $satisfies = join("\n,", @sats);

    my $mantable = "";
    foreach my $file (@{$this->{files}}) {
        $mantable .= "\t\"$file->{name}\", # $file->{description}\n";
    }

    my $installScript = "$basedir/$this->{project}_installer.pl";
    if ($this->{-v} || $this->{-n}) {
        print "Generating installer in $installScript\n";
    }

    # override the default filter expansions
    my $t1 = $this->{DEPENDENCIES};
    $this->{DEPENDENCIES} = $satisfies;
    my $t2 = $this->{MANIFEST};
    $this->{MANIFEST} = $mantable;

    $this->filter( $template, $installScript );

    $this->{DEPENDENCIES} = $t1;
    $this->{MANIFEST} = $t2;

    $this->prot("a+rx,u+w", $installScript);
}

=begin text

---++++ build($target)
Build the given target

=cut

sub build {
    my $this = shift;
    my $target = shift;
    if ($this->{-v}) {
        print "Building $target\n";
    }
    no strict "refs";
    eval "\$this->target_$target()";
    use strict "refs";
    if ($@) {
        print "Failed to build $target: $@\n";
        die $@;
    }
    if ($this->{-v}) {
        print "Built $target\n";
    }
}

=begin text

---++++ target_manifest
Generate and print to STDOUT a rough guess at the MANIFEST listing

=cut

sub target_manifest {
    my $this = shift;
    my $extensionName = `basename $basedir`;
    chomp($extensionName);
    print "Here's a rough guess at ${extensionName}'s MANIFEST list (from $basedir)\n";
    chdir("$basedir") || die "can't cd to $basedir - $!";
    print `find . -type f | grep -v CVS | egrep -v '~\$' | egrep $extensionName`;
    print "\n";
    print "Save this as $basedir/MANIFEST and check it manually!\n";
}

1;
