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
| DEPENDENCIES | optional list of dependencies on other modules and descriptions. Dependencies should be expressed as "name,version,type,description" where name is the name of the module, version is the version constraint (e.g. ">1.5"), type is its type (CPAN, perl, C etc) and description is a short description of the module and where to get it. Perl modules also referenced in the dependencies list in the stub topic should be listed using their perl package name (e.g. TWiki::Contrib::MyContrib) and use the type 'perl'. The instructions should describe where to get the module. |
| lib/TWiki/Plugins/ | this is where your <plugin name>.pm file goes for plugins |
| lib/TWiki/Plugins/<plugin name>/ | directory containing sub-modules used by your plugin, and your build.pl script. |
| lib/TWiki/Contrib/ | this is where your <contrib name>.pm file goes for contribs |
| lib/TWiki/Contrib/<contrib name>/ | directory containing sub-modules used by your contrib, and your build.pl script. |
| data/ | as you expect to see in the installation |
| pub/ | as you expect to see in the installation. You must list required directories, even if they are initially empty. |
| templates/ | as you expect to see in installation |
| templates/<skin name>/ | this is where templates for your skin go |
| contrib/ | this is where non-TWiki, non-web-accessible files associated with a Contrib or plugin go |
---+++ Token expansion
The build supports limited token expansion in =.txt= files. It expands the following tokens by default when the release target is built.
| =%$<nop>MANIFEST%= | Expands to a TWiki table of MANIFEST contents |
| =%$<nop>DEPENDENCIES%= | Expands to a comma-separated list of dependencies |
| =%$<nop>DATE%= | Expands to today's date |
| =%$<nop>VERSION%= | Expands to the VERSION number set in the plugin/contrib main .pm topic |
| =%$<nop>POD%= | Expands POD text in all =.pm= files in the MANIFEST. Pod is generated for each module in the order of the MANIFEST. |
| =%$<nop>STUB%= | Expands to the name of the package stub for this module |
---+++ Methods

=cut

use strict;
use File::Copy;
use File::Spec;
use Pod::Text;
use POSIX;
use diagnostics;
use vars qw( $VERSION $basedir $twiki_home $buildpldir $libpath );

$VERSION = 1.00;

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
    if (-f $deps) {
        open(PF, "<$deps") ||
          die "$deps open failed";
        while ($line = <PF>) {
            if ($line =~ m/^(\w+)\s+(\w*)\s*(.*)$/o) {
                push(@{$this->{dependencies}},
                     { name=>$1, type=>$2, version=>"", description=>$3 });
            } elsif ($line =~ m/^([^,]+),([^,]*),\s*(\w*)\s*,\s*(.+)$/o) {
                push(@{$this->{dependencies}},
                     { name=>$1, version=>$2, type=>$3, description=>$4 });
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
                if ($name !~ /^TWiki::(Plugins|Contrib)$/) {
                    foreach my $dep (@{$this->{dependencies}}) {
                        if ($dep->{name} eq $name) {
                            $dep->{version} = $ver;
                            $found = 1;
                            last;
                        }
                    }
                    unless ($found || $name eq "TWiki::Plugins") {
                        push(@{$this->{dependencies}},
                             { name=>$name, version=>$ver, type=>'perl', description=>$name });
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
Expands tokens in a documentation topic.Four tokens are supported:
   * %$MANIFEST% - TWiki table of files in MANIFEST
   * %$DEPENDENCIES% - list of dependencies from DEPENDENCIES
   * %$VERSION% version from $VERSION in main .pm
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

    $this->checkin_fileset($this->{files}, $basedir);
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

---++++ checkin_fileset
If any of the files in the fileset have a corresponding ,v file next
to them, then check in the file.

=cut
sub checkin_fileset {
    my ($this, $set, $from, $to) = @_;
    
    foreach my $file (@$set) {
        my $name = $file->{name};
        if (-e "$from/$name,v") {
            my $safetynet = "$from/$name$$";
            $this->sys_action("mv $from/$name $safetynet");
            $this->sys_action("co -l -q $from/$name");
            $this->sys_action("mv $safetynet $from/$name");
            $this->sys_action("ci -q -u -mAutomatic $from/$name");
        }
    }
}

=begin text

---++++ target_install
Install target, installs to local twiki pointed at by TWIKI_HOME.

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

=begin text

---++++ target_upload
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
    # Get the old form data and attach it to the update
    my $oldform = `$curl http://TWiki.org/cgi-bin/view/Plugins/$to`;
    my $opts = "";
    foreach my $line ( split(/\n/, $oldform)) {
        if ( $line =~ m/(TopicClassification|CVSModificationPolicy|DeveloperVersionInCVS|InstalledOnTWikiOrg|DemoUrl).*?<\/td><td.*?>(.*)<\/td>/o ) {
            my $val = _unhtml($2);
            if ($val && $val ne "") {
                $opts .= " -F $1=$val";
            }
        } elsif ( $line =~ m/(TestedOnTWiki|TestedOnOS|ShouldRunOnOS).*?<\/td><td.*?>(.*?)<\/td>/o ) {
            my $func = $1;
            foreach my $plaf ( split( /,/, _unhtml($2))) {
                if ($plaf ne "") {
                    $opts .= " -F $func$plaf=Yes";
                }
            }
        }
    }
    print `$curl -F text=\\<$basedir/$to.txt $opts http://TWiki.org/cgi-bin/save/Plugins/$to`;
    die "Update of topic failed: $?" if ( $?);
    print `$curl -F filepath=\\\@$basedir/$to.zip -F filename=$to.zip http://TWiki.org/cgi-bin/upload/Plugins/$to`;
    die "Update of zip failed: $?" if ( $?);
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

Write an install script that checks dependencies, tries (using curl, wget
and geturl in that order) to find a program to download and install required
zips. If it fails, generates a message.

At present there is no support for a caller-provided post-install script, but
this would be straightforward to invoke if it were required.

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
        push(@sats, "{ name=>\"$dep->{name}\", type=>\"$dep->{type}\",version=>\"$dep->{version}\",description=>\"$descr\" }");
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
    my $is = "";
    open(IS, "<$template") or die "Could not open $template";
    while (<IS>) {
        $is .= $_;
    }
    close(IS);
    $is =~ s/%\$MODULE%/$this->{project}/g;
    $is =~ s/%\$DEPENDENCIES%/$satisfies/g;
    $is =~ s/%\$MANIFEST%/$mantable/g;

    unless ($this->{-n}) {
        open(IS, ">$installScript") or die "Could not open $installScript";
        print IS $is;
        close(IS);
    }
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
    print "Here's a rough guess at $extensionName 's MANIFEST list (from $basedir)\n";
    chdir("$basedir") || die "can't cd to $basedir - $!";
    print `find . -type f | grep -v CVS | egrep -v '~$' | egrep $extensionName`;
    print "\n";
    print "Save this as $basedir/MANIFEST and check it manually!\n";
}

1;
