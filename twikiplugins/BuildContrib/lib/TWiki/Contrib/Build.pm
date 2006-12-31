
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

use TWiki::Contrib::BuildContrib::BaseBuild;
use Error qw(:try);

=pod

---++ Package TWiki::Contrib::Build

This is a base class used for making build scripts for TWiki packages.
This class is derived from to create a build script for a specific module.

The resulting build script works a bit like make and a bit like Ant.
Build targets are Perl functions, which operate on various data defined
in control files to build the various targets. Perl is used rather than
make for portability reasons.

By default, the resulting build script will interpret the targets described
below, and the following options:
| -n | Do nothing |
| -v | Be verbose |
| -topiconly | with target 'upload', only upload the topic (not the zip) |

---+++ Targets

The following targets will always exist:
| build | *internal target* check that everything is perl |
| test | run unit tests |
| install | install on local installation defined by $TWIKI_HOME |
| uninstall | uninstall from local installation defined by $TWIKI_HOME |
| pod | build POD documentation of the package |
| release | build, pod and package a release zip |
| upload | build, pod, package and upload |
| manifest | print a guess at the MANIFEST |
| history | Update the history in the topic for an extension |
| dependencies | Find and print missing dependencies (for DEPENDENCIES) |
Note: if you override any of these targets it is generally wise to call the SUPER version of the target!

---+++ Standard directory structure
The standard module directory structure mirrors the TWiki installation directory structure, so each file in the development directory structure is in the place it will be in in the actual installation. From the _root directory_, these are the key areas:
| lib/TWiki/Plugins/ | this is where your <code><i>name</i>.pm</code> file goes for plugins |
| lib/TWiki/Plugins/<i>name</i>/ | directory containing sub-modules used by your plugin, and your build.pl script. It is referred to below as the "module directory" |
Contribs are held in the =lib/TWiki/Contrib= directory instead of =lib/TWiki/Plugins= but otherwise work the same way.
| data/ | as you expect to see in the installation |
| pub/ | as you expect to see in the installation. You must list required directories, even if they are initially empty. |
| templates/ | as you expect to see in installation |
| templates/<skin name>/ | this is where templates for your skin go |
| contrib/ | this is where non-TWiki, non-web-accessible files associated with a Contrib or plugin go |

---+++ Environment Variables
During development you might use a single directory tree to do all of developemnt, development testing and release testing. Alternatively you might use:
   1 A subversion checkout tree for the sources
   1 A test installation
   1 An installation of the latest released TWiki for final release testing
Or you might use some other combination in between - it depends on what you are developing. To make the build as flexible as possible, !BuildContrib supports a number of environment variables that can be used to point to your different components.

The build process requires access to the TWiki libraries, so it can pick up the components of the build system. There are two ways to point to the required perl libraries:
   1 Set =PERL5LIB= (as described in =man perlrun=) to point to the =lib= directory in your development area. You may also want to point to your =lib/CPAN/lib= directory to pick up CPAN dependencies, if you are using a local install.
      * The *advantage* of setting =PERL5LIB= is that you only need to set it once, in your login script.
      * The *disadvantage* of setting it is that any TWiki scripts you run during testing will *also* pick up these libs, which may mask problems elsewhere in your configuration.
   1 Set =TWIKI_LIBS= (which is a path, same as PERL5LIB) to point to your =lib= directory in your development area. =$TWIKI_LIBS= is used to extend @INC _for the duration of the build only_, so it won't mask problems during testing.
The approach we _recommend_ is to set =TWIKI_LIBS= in your login script (e.g. =.login=, =.csh=, =.profile= depending on what shell you prefer).

The build scripts support the =install= target. if you are developing a TWiki extension, you can use the =install= target to automatically install your package in a test installation. The environment variable =TWIKI_HOME= should be pointed to the *root* of your *test* TWiki installation. It is not needed if you never use the =install= target (for example, if you use =pseudo-install.pl= to install in your development system.

---+++ Manifest
The main driving file for the build is the MANIFEST file. This contains a list of all the files that are wanted in the zip file. It is located at build time by looking in the current directory, and if there is no file there looking up a level, and so on. It will normally be held in your _module directory_. The MANIFEST file consists of a list of file paths, each relative to the root of the installation. Wildcards may NOT be used. Each file has an optional octal permissions mask and a description; for example,
<verbatim>
data/TWiki/MyPlugin.txt 0664 Plugin description topic
</verbatim>
If no permissions are given, permissions are guessed from the permissions on the file in the source tree. These permissions are used by the installer script generated by the builder to set file permissions in the installation.

MANIFESTs can trigger the inclusion of other modules that have been wrapped using BuildContrib. For example,
<verbatim>
!include twikiplugins/WysiwygPlugin/lib/TWiki/Plugins/WysiwygPlugin
</verbatim>
This will use 'perl build.pl handsoff_install' to build and install the module in the release tree being built.

---+++ Dependencies
The DEPENDENCIES file specifies module dependencies, for example dependencies on other TWiki modules and on CPAN modules. It is found in the same way as the MANIFEST file. The DEPENDENCIES file contains a list of lines, each of which is a single dependency:
<verbatim>
name, version, type, description
</verbatim>
where
   * name is the name of the module,
   * version is the version constraint (e.g. ">1.5"),
   * type is its type (CPAN, perl, C etc) and
   * description is a short description of the module and where to get it.
---++++ Calculating DEPENDENCIES
When your module (the _depender_) depends on another module (a _dependee_), it is important to think carefully about what version of the dependee your module requires.

When you are working with TWiki modules (such as contribs and plugins) you should list the version number of the module that you tested with. Normally you will want to use a <code>&gt;</code> condition, so that more recent versions will also work. If a dependency on a TWiki module fails (because the module isn't installed, for example) then the installer script will pull *the latest version* of the module from TWiki.org, whether that is the required version or not. This is a limitation of the way plugins are stored on TWiki.org.

When you are working with CPAN modules, you need to take account of the fact that there are *two types* of CPAN modules; _built-ins_ and _add-ons_.

*Built-ins* are perl modules that are pre-installed in the perl distribution. Since these modules are usually very stable, it is generally safe to express the version dependency as ">0" (i.e. "any version of the module will do").

Note however that the list of built-in modules is constantly growing with each new release of perl. So your module may be installed with a perl version that doesn't have the required module pre-installed. In this case, CPAN will *automatically try to upgrade the perl version*! There is no way around this, other than for the admin on the target system to *manually* install the module (download frm CPAN and build locally). You can help out the dmin by expressing the dependency clearly, thus:
File::Find,>0,cpan,This module is shipped as part of standard perl from perl 5.8.0 onwards. If your perl installation is older than this, you should either upgrade perl, or *manually* install this module. If you allow this installer to continue, it will *automatically upgrade your perl installation* which is probably not what you want!

---++++ ONLYIF
A dependency may optionally be preceded by a condition that limits the cases where the dependency applies. The condition is specified using a line that contans <code>ONLYIF ( _condition_ )</code>, where _condition_ is a Perl conditional. This is most useful for enabling dependencies only for certain versions of TWiki. For example,
<verbatim>
TWiki::Rhinos,>=1.000,perl,Required. Download from TWiki:Plugins/RhinosContrib and install.
ONLYIF ($TWiki::Plugins::VERSION < 1.025)
TWiki::Plugins::CairoContrib, >=1.000, perl, Optional, only required if the plugin is to be run with versions of TWiki before Cairo. Available from the TWiki:Plugins/CairoContrib repository.
</verbatim>
Thus <nop>CairoContrib is only a dependency if the installation is being done on a TWiki version before Cairo. The =ONLYIF= only applies to the next dependency in the file.

The condition is included in the installer script generated by the builder.

---+++ Installer
The installer script generated by the builder when target =release= is used is based on a template installer. This template is populated with lists of files and dependencies to make the package-specific installer.

You can extend the installer by providing PREINSTALL, POSTINSTALL, PREUNINSTALL, and/or POSTUNINSTALL files. These optional files can contain Perl fragments that must execute at the given stage of the installation. The script fragments will be inserted into the generated installer script. Read contrib/TEMPLATE_installer.pl to see how they fit in. The POD comments in that module indicate the functions that are most likely to be useful to anyone writing a script extension. The files are found in the same was as the MANIFEST and DEPENDENCIES files.

---+++ Upload
The =upload= target will upload your package to TWiki.org. This is a two-stage process, because the forms on TWiki.org are edited there and are not part of the uploaded package. So the upload process first build a release package, then downloads the existing form from TWiki.org. Once the real topic is assembled it is uploaded again, and the new zip & tgz is attached.

---+++ Testing
The way tests are shipped in this version of BuildContrib has changed radically since TWiki 'Cairo' release. It is now possible to use a TWiki installation as a test fixture. CPAN:Test::Unit tests are expected to be found in the =test/unit= directory in the root directory. Tests are run using the =tests/bin/TestRunner.pl= script (which is simply the =TestRunner.pl= script from the CPAN:Test::Unit distribution, and will be present in any subversion checkout of TWiki). Tests will normally need a TWiki installation; normally you should use the TWiki pointed at by =$TWIKI_HOME= by including the following in the test module:
<verbatim>
BEGIN{
    push( @INC, "$ENV{TWIKI_HOME}/lib" );
}
</verbatim>

However this _only_ works with the 'Dakar' release (and later) of TWiki. Tests are bundled by the BuildContrib in a zip in the plugin directory, called tests.zip. This zip has to be unzipped from the root of the target installation before the tests can be run.

---+++ Token expansion
The build supports limited token expansion in =.txt= files. See the documentation on the =filter= method for more detail.

---+++ Methods

=cut

use strict;
use File::Copy;
use File::Spec;
use File::Find;
use File::Path;
use POSIX;
use CGI ( -any );
use diagnostics;
use Carp;
use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $basedir $twiki_home $buildpldir $libpath );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'TWiki-4';

$SHORTDESCRIPTION ='Automate build process for Plugins, Add-ons and Contrib modules';
my $NL = "\n";

my $TWIKIORGPUB = 'http://twiki.org/p/pub';
my $TWIKIORGSCRIPT = 'http://twiki.org/cgi-bin';
my $TWIKIORGSUFFIX = '';
my $TWIKIORGBUGS = 'http://develop.twiki.org/~develop/cgi-bin/view/Bugs';
my $TWIKIORGEXTENSIONSWEB = "Plugins";

$SIG{__DIE__} = sub { Carp::confess $_[0] };

sub _findRelativeTo {
    my( $startdir, $name ) = @_;

    my @path = split( /\/+/, $startdir );

    while (scalar(@path) > 0) {
        my $found = join( '/', @path).'/'.$name;
        return $found if -e $found;
        pop( @path );
    }
    return undef;
}

BEGIN {
    use File::Spec;
    $buildpldir = `dirname $0`; chop($buildpldir);
    $buildpldir = File::Spec->rel2abs($buildpldir);

    # Find the lib root
    $libpath = _findRelativeTo( $buildpldir, 'lib/TWiki' );
    die 'Could not find lib/TWiki' unless $libpath;
    $libpath =~ s#/[^/]*$##;

    $basedir = $libpath;
    $basedir =~ s#/[^/]*$##;

    $twiki_home = $ENV{'TWIKI_HOME'};
    if ($ENV{TWIKI_LIBS}) {
        my %known;
        map{ $known{$_} = 1 } split( /:/, @INC);
        foreach my $pc (reverse split(/:/,$ENV{TWIKI_LIBS})) {
            unless( $known{$pc} ) {
                unshift(@INC, $pc);
            }
        }
    }
    unless(grep(/$basedir\/lib/,@INC)) {
        unshift(@INC, $basedir.'/lib');
    }
}

=pod

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
    my $this = bless({}, $class);

    # Constants with internet paths
    $this->{UPLOADTARGETPUB} = $TWIKIORGPUB;
    $this->{UPLOADTARGETSCRIPT} = $TWIKIORGSCRIPT;
    $this->{UPLOADTARGETSUFFIX} = $TWIKIORGSUFFIX;
    $this->{UPLOADTARGETWEB} = $TWIKIORGEXTENSIONSWEB;
    $this->{BUGSURL} = $TWIKIORGBUGS;

    $this->{project} = $project;
    $this->{target} = 'test';

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
        print 'Building in ',$buildpldir,$NL;
        print 'Root module is  ',$rootModule,$NL if $rootModule;
        print 'Basedir is ',$basedir,$NL;
        print 'Component dir is ',$libpath,$NL;
        print 'Using path '.join(':',@INC).$NL;
    }

    $this->{basedir} = $basedir;

    # The following paths are all relative to the root of the twiki
    # installation

    #SMELL: Hardcoded project classification
    # where the sub-modules live
    $this->{libdir} = $libpath;
    if( $this->{project} =~ /Plugin$/ ) {
        $this->{libdir} .= '/TWiki/Plugins';
    } elsif( $this->{project} =~ /(Contrib|Skin)$/ ) {
        $this->{libdir} .= '/TWiki/Contrib';
    }

    # the .pm module
    $this->{ROOTMODULE} = $rootModule || $project;
    $this->{pm} = $this->{libdir}.'/'.$this->{ROOTMODULE}.'.pm';

    my $stubpath = $this->{pm};
    $stubpath =~ s/.*[\\\/](TWiki[\\\/].*)\.pm/$1/;
    $stubpath =~ s/[\\\/]/::/g;
    $this->{STUB} = $stubpath;

    # where data files live
    $this->{data_twiki} = 'data/TWiki';

    # the root of the name of data files
    $this->{data_twiki_module} = $this->{data_twiki}.'/'.$this->{project};

    ##############################################################
    # Read the manifest

    my $manifest = _findRelativeTo( $buildpldir, 'MANIFEST' );
    ($this->{files}, $this->{other_modules}) =
      readManifest($this->{basedir},'',$manifest,sub{exit(1)});

    # Generate a TWiki table representing the manifest contents
    # and a hash table representing the files
    my $mantable = '';
    my $hashtable = '';
    foreach my $file (@{$this->{files}}) {
        $mantable .= "   | ==" . $file->{name} . '== | ' .
          $file->{description} . ' |'.$NL;
        $hashtable .= "'$file->{name}'=>$file->{permissions},";
    }
    $this->{MANIFEST} = $mantable;
    $this->{FILES} = $hashtable;

    ##############################################################
    # Work out the dependencies

    $this->_loadDependenciesFrom($buildpldir);

    # Pull in dependencies from other modules
    if( $this->{other_modules} ) {
        foreach my $module (@{$this->{other_modules}}) {
            try {
                $this->_loadDependenciesFrom("$basedir/$module");
            } catch Error::Simple with {
                warn "WARNING: no dependencies in $basedir/$module ".shift;
            };
        }
    }

    my $deptable = '';
    my $a = ' align="left"';
    foreach my $dep (@{$this->{dependencies}}) {
        my $v = $dep->{version};
        $v =~ s/&/&amp;/go;
        $v =~ s/>/&gt;/go;
        $v =~ s/</&lt;/go;
        my $cells = CGI::td({align=>'left'}, $dep->{name} ).
           CGI::td({align=>'left'}, $v ).
          CGI::td({align=>'left'}, $dep->{description});
        $deptable .= CGI::Tr( $cells );
    }
    $this->{DEPENDENCIES} = 'None';
    if ($deptable) {
        my $cells = CGI::th('Name').CGI::th('Version').CGI::th('Description');
        $this->{DEPENDENCIES} =
          CGI::table({ border=>1}, CGI::Tr($cells).$deptable );
    }

    $this->{VERSION} = $this->_get_svn_version();
    $this->{DATE} = POSIX::strftime('%T %d %B %Y', localtime);

    local $/ = undef;
    foreach my $stage ( 'PREINSTALL', 'POSTINSTALL', 'PREUNINSTALL', 'POSTUNINSTALL' ) {
        $this->{$stage} = '# No '.$stage.' script';
        my $file = _findRelativeTo($buildpldir, $stage);
        if ($file && open(PF, '<'.$file)) {
            $this->{$stage} = <PF>;
        }
    }

    $this->{MODULE} = $this->{project};

    $this->{INSTALL_INSTRUCTIONS} = <<HERE;
You do not need to install anything in the browser to use this extension. The following instructions are for the administrator who installs the extension on the server where TWiki is running.

Like many other TWiki extensions, this module is shipped with a fully automatic installer script written using the Build<nop>Contrib.
   * If you have TWiki 4.1 or later, and Perl 5.8, you can install from the =configure= interface (Go to Plugins->Find More Extensions)
      * The webserver user has to have permission to write to all areas of your installation for this to work.
   * If you have a permanent connection to the internet (and Perl 5.8), you are recommended to use the automatic installer script
      * Just download the =$this->{MODULE}_installer= perl script and run it.
   * *Notes:*
      * The installer script will:
         * Automatically resolve dependencies,
         * Copy files into the right places in your local install (even if you have renamed data directories),
         * check in new versions of any installed files that have existing RCS histories files in your existing install (such as topics).
         * If the \$TWIKI_PACKAGES environment variable is set to point to a directory, the installer will try to get archives from there. Otherwise it will try to download from twiki.org or cpan.org, as appropriate.
         * (Developers only: the script will look for twikiplugins/$this->{MODULE}/$this->{MODULE}.tgz before downloading from TWiki.org)
      * If you don't have a permanent connection, you can still use the automatic installer, by downloading all required TWiki archives to a local directory.
         * Point the environment variable =\$TWIKI_PACKAGES= to this directory, and the installer script will look there first for required TWiki packages.
            * =\$TWIKI_PACKAGES= is actually a path; you can list several directories separated by :
         * If you are behind a firewall that blocks access to CPAN, you can build a local CPAN mini-mirror, as described at http://twiki.org/cgi-bin/view/Codev/BuildingDakar#CPAN_local_minimirror
   * If you don't want to use the installer script, or have problems on your platform (e.g. you don't have Perl 5.8), then you can still install manually:
      1 Download and unpack one of the =.zip= or =.tgz= archives to a temporary directory.
      1 Manually copy the contents across to the relevant places in your TWiki installation.
      1 Check in any installed files that have existing =,v= files in your existing install (take care *not* to lock the files when you check in)
      1 Manually edit !LocalSite.cfg to set any configuration variables.
      1 Run =configure= and enable the module, if it is a plugin.
      1 Repeat from step 1 for any missing dependencies.
HERE
    return $this;
}

sub DESTROY {
    my $self = shift;
    File::Path::rmtree( $self->{tmpDir} ) if $self->{tmpDir};
}

sub _addDependency {
    my $this = shift;
    my %dep = @_;
    my @existing = grep {$_->{name} eq $dep{name}} @{$this->{dependencies}};
    if (scalar @existing) {
        # SMELL: this is a crude merge of conditions, and probably not
        # correct in some cases, but it will have to do
        my $a = $existing[0]->{version};
        my $b = $dep{version};
        $a =~ s/[<>=]//g;
        $b =~ s/[<>=]//g;
        if ($a =~ /^[0-9.]+$/ && $b =~ /^[0-9.]+$/) {
            if ($a < $b) {
                $existing[0]->{version} = $dep{version};
            }
            return;
        }
    }
    # New dependency
    push(@{$this->{dependencies}}, \%dep);
}

sub _loadDependenciesFrom {
    my( $this, $module) = @_;

    my $deps = _findRelativeTo($module, 'DEPENDENCIES');
    die 'Failed to find DEPENDENCIES for '.$module unless $deps && -f $deps;
    my $condition = '';
    if (-f $deps) {
        open(PF, '<'.$deps) || die 'Failed to open '.$deps;
        while (my $line = <PF>) {
            if ($line =~ /^\s*$/ || $line =~ /^\s*#/) {
            } elsif ($line =~ /^ONLYIF\s*(\(.*\))\s*$/) {
                $condition = $1;
            } elsif ($line =~ m/^(\w+)\s+(\w*)\s*(.*)$/o) {
                $this->_addDependency(
                    name=>$1,
                    type=>$2,
                    version=>'',
                    description=>$3,
                    trigger=>$condition);
                $condition='';
            } elsif ($line =~ m/^([^,]+),([^,]*),\s*(\w*)\s*,\s*(.+)$/o) {
                $this->_addDependency(
                    name=>$1,
                    version=>$2,
                    type=>$3,
                    description=>$4,
                    trigger=>$condition);
                $condition='';
            } else {
                warn 'WARNING: LINE '.$line.' IN '.$deps.' IGNORED';
            }
        }
    } else {
        warn 'WARNING: no '.$deps.'; dependencies will only be extracted from code';
    }
    close(PF);
}

sub _get_svn_version {
    my $this = shift;
    unless( $this->{VERSION} ) {
        # svn info all the files in the manifest
        my $files = join(" ", map { "$this->{basedir}/$_->{name}" } @{$this->{files}});
        my $log = `svn info $files`;
        my $max = 0;
        foreach my $line ( split(/\n/, $log )) {
            if( $line =~ /^Last Changed Rev: (.*)$/ ) {
                $max = $1 if $1 > $max;
            }
        }
        $this->{VERSION} = $max;
    }
    return $this->{VERSION};
}

sub ask {
    my ($q, $default) = @_;
    my $reply;
    local $/ = "\n";

    $q .= '?' unless $q =~ /\?\s*$/;

    my $yorn = 'y/n';
    if (defined $default) {
        if ($default =~ /y/i) {
            $default = 'yes';
            $yorn = 'Y/n';
        } elsif( $default =~ /n/i) {
            $default = 'no';
            $yorn = 'y/N';
        } else {
            $default = undef;
        }
    }
    print $q.' ['.$yorn.'] ';

    while ( ( $reply = <STDIN> ) !~ /^[yn]/i ) {
        if ($reply =~ /^\s*$/ && defined($default)) {
            $reply = $default;
            last;
        }
        print "Please answer yes or no\n";
    }
    return ( $reply =~ /^y/i ) ? 1 : 0;
}

sub prompt {
    my( $q, $default) = @_;
    local $/ = "\n";
    my $reply = '';
    while( !$reply ) {
        print $q;
        print " ($default)" if defined $default;
        print ': ';
        $reply = <STDIN>;
        chomp($reply);
        $reply ||= $default;
    }
    return $reply;
}

=pod

---++++ pushd($dir)
  Change to the given directory

=cut

sub pushd {
    my ($this, $file) = @_;

    if ($this->{-v} || $this->{-n}) {
        print 'pushd '.$file.$NL;
    }
    if (!$this->{-n}) {
        push( @{$this->{dirStack}}, Cwd::cwd());
        chdir($file) || die 'Failed to pushd to '.$file;
    }
}

=pod

---++++ popd()
  Pop a dir level, previously pushed by pushd

=cut

sub popd {
    my $this = shift;

    die unless scalar(@{$this->{dirStack}});

    my $dir = pop( @{$this->{dirStack}} );
    if ($this->{-v} || $this->{-n}) {
        print 'popd '.$dir.$NL;
    }
    if (!$this->{-n}) {
        chdir($dir) || die 'Failed to popd to '.$dir;
    }
}

=pod

---++++ rm($file)
Remove the given file (or directory)

=cut

sub rm {
    my ($this, $file) = @_;

    if ($this->{-v} || $this->{-n}) {
        print 'rm '.$file.$NL;
    }
    if (-e $file && !$this->{-n}) {
        if( -d $file ) {
            File::Path::rmtree( $file );
        } else {
            unlink($file) || warn 'WARNING: Failed to delete '.$file;
        }
    }
}

=pod

---++++ makepath($to)
Make a directory and all directories leading to it.

=cut

sub makepath {
    my ($this, $to) = @_;

    # SMELL: what's wrong with File::Path::mkpath ?

    chop($to) if ($to =~ /\n$/o);

    return if (-d $to || $this->{made_dir}->{$to});
    $this->{made_dir}->{$to} = 1;

    if (! -e $to) {
        $this->makepath(`dirname $to`);
        if ($this->{-v} || $this->{-n}) {
            print 'mkdir '.$to.$NL;
        }
        unless ($this->{-n}) {
            mkdir($to) || warn 'Warning: Failed to make '.$to.': '.$!;
        }
    } else {
        warn 'Warning: '.$to.' exists and is not a directory; cannot create a dir over it';
    }
}

=pod

---++++ cp($from, $to)
Copy a single file from - to. Will automatically make intervening
directories in the target. Also works for target directories.

=cut

sub cp {
    my ($this, $from, $to) = @_;

    die 'Source file '.$from.' does not exist ' unless ( $this->{-n} || -e $from);

    $this->makepath(`dirname $to`);

    if ($this->{-v} || $this->{-n}) {
        print 'cp '.$from.' '.$to.$NL;
    }
    unless ($this->{-n}) {
        if ( -d $from ) {
            mkdir($to) || warn 'Warning: Failed to make '.$to.': '.$!;
        } else {
            File::Copy::copy($from, $to) ||
                warn 'Warning: Failed to copy '.$from.' to '.$to.': '.$!;
        }
    }
}

=pod

---++++ prot($perms, $file)
Set permissions on a file. Permissions should be expressed using POSIX
chmod notation.

=cut

sub prot {
    my ($this, $perms, $file) = @_;
    $this->perl_action("chmod($perms,'$file')");
}

=pod

---++++ sys_action($cmd)
Perform a "system" command.

=cut

sub sys_action {
    my ($this, $cmd) = @_;

    if ($this->{-v} || $this->{-n}) {
        print $cmd.$NL;
    }
    unless ($this->{-n}) {
        system($cmd);
        die 'Failed to '.$cmd.': '.$? if ($?);
    }
}

=pod

---++++ perl_action($cmd)
Perform a "perl" command.

=cut

sub perl_action {
    my ($this, $cmd) = @_;

    if ($this->{-v} || $this->{-n}) {
        print $cmd.$NL;
    }
    unless ($this->{-n}) {
        eval $cmd;
        die 'Failed to '.$cmd.': '.$@ if ($@);
    }
}

=pod

---++++ target_build
Basic build target. By default does nothing, but subclasses may want to
extend on that.

=cut

sub target_build {
    my $this = shift;
    # does nothing
}

=pod

---++++ target_test
Basic CPAN:Test::Unit test target, runs <project>Suite.

=cut

sub target_test {
    my $this = shift;
    $this->build('build');

    # find testrunner
    my $testrunner = _findRelativeTo($this->{basedir},
                                     'test/bin/TestRunner.pl');

    my $tests = _findRelativeTo($this->{basedir}, 'test/unit/'.
                                  $this->{project}.'/'.
                                    $this->{project}.'Suite.pm');
    unless( $tests ) {
        $tests = _findRelativeTo($this->{basedir}, '/test/unit/'.
                                   $this->{project}.'Suite.pm');
        unless( $tests ) {
            warn 'WARNING: COULD NOT FIND ANY UNIT TESTS FOR '.
              $this->{project};
            return;
        }
    }
    unless($testrunner) {
        warn 'WARNING: CANNOT RUN TESTS; TestRunner.pl not found';
        return;
    }
    my $inc = join(' -I', @INC);
    my $testdir = $tests;
    $testdir =~ s/\/[^\/]*$//;
    print "Running tests in $tests\n";
    my $cmd = 'perl -w -I'.$inc.' '.$testrunner.' '.$tests;
    print "$cmd\n";
    $this->pushd($testdir);
    $this->sys_action($cmd);
    $this->popd();
    shift( @INC );
}

=pod

---++++ filter_txt
Expands tokens. The following tokens are supported:
   * %$MANIFEST% - TWiki table of files in MANIFEST
   * %$FILES% - hash keyed on file name mapping to permissions i.e. 'data/TWiki/ThsiTopic.txt' => 0664, 'lib/TWiki/Plugins/BlahPlugin.pm' => 0775
   * %$DEPENDENCIES% - list of dependencies from DEPENDENCIES
   * %$VERSION% version from $VERSION in main .pm
   * %$DATE% - local date
   * %$POD% - expands to the POD documentation for the package, excluding test modules.
   * %$PREINSTALL% - inserts script from PREINSTALL
   * %$POSTINSTALL% - inserts script from POSTINSTALL
   * %$PREUNINSTALL% - inserts script from PREUNINSTALL
   * %$POSTUNINSTALL% - inserts script from POSTINSTALL
   * %$UPLOADTARGETSCRIPT% - URL of upload scripts dir
   * %$UPLOADTARGETSUFFIX% - Suffix for upload scripts
   * %$UPLOADTARGETPUB% - URL of upload pub dir
   * %$UPLOADTARGETWEB% - name f upload web dir
   * %$BUGSURL% - URL of bugs web
   * %$INSTALL_INSTRUCTIONS% - basic instructions for installing
Three spaces is automatically translated to tab.

The filter is used in the generation of documentation topics and the installer

=cut

sub filter_txt {
    my ($this, $from, $to) = @_;

    return unless (-f $from);

    open(IF, '<'.$from) || die 'No source topic '.$from.' for filter';
    local $/ = undef;
    my $text = <IF>;
    close(IF);
    # Replace the SVN revision with rev 1.
    # In TWiki builds this gets replaced by latest revision later.
    $text =~ s/^(%META:TOPICINFO{.*)\$Rev:.*\$(.*}%)$/${1}1$2/m;
    $text =~ s/%\$(\w+)%/&_expand($this,$1)/geo;

    unless ($this->{-n}) {
        open(OF, '>'.$to) || die 'No dest topic '.$to.' for filter';
    }
    print OF $text unless ($this->{-n});
    close(OF) unless ($this->{-n});
}

sub _expand {
    my ($this, $tok) = @_;
    if (!$this->{$tok} && $tok eq 'POD') {
        $this->build('POD');
    }
    if (defined($this->{$tok})) {
        if ($this->{-v} || $this->{-n}) {
            print 'expand %$'.$tok.'% to '.$this->{$tok}.$NL;
        }
        return $this->{$tok};
    } else {
        return '%$'.$tok.'%';
    }
}

=pod

---++++ filter_pm($from, $to)
Filters expanding SVN rev number with correct version from repository
Note: unlike subversion, this puts in the version number of the whole
repository, not just this file.
=cut

sub filter_pm {
    my ($this, $from, $to) = @_;

    open(IF, '<'.$from) || die 'No source topic '.$from.' for filter';
    local $/ = undef;
    my $text = <IF>;
    close(IF);

    $text =~ s/\$Rev(: \d+)?\$/\$Rev: $this->{VERSION}\$/gso;

    unless ($this->{-n}) {
        open(OF, '>'.$to) || die 'Bad dest topic '.$to.' for filter:'.$!;
        print OF $text;
        close(OF);
    }
}

=pod

---++++ target_release
Release target, builds release zip by creating a full release directory
structure in /tmp and then zipping it in one go. Only files explicitly listed
in the MANIFEST are released. Automatically runs =filter= on all =.txt= files
in the MANIFEST.

=cut

sub target_release {
    my $this = shift;

    print "Building a release\n";
    print "Version $this->{VERSION} of $this->{project}\n";
    print 'Package name will be ',$this->{project},$NL;
    print 'Topic name will be ',$this->_getTopicName(),$NL;

    $this->build('build');
    $this->build('installer');
    $this->build('stage');
    $this->build('archive');
}

=pod

---++++ target_stage
stages all the files to be in the release in a tmpDir, ready for target_archive

=cut

sub target_stage {
    my $this = shift;
    my $project = $this->{project};

    $this->{tmpDir} = '/tmp/'.$$;
    $this->makepath($this->{tmpDir});

    $this->copy_fileset($this->{files}, $this->{basedir}, $this->{tmpDir});
    foreach my $file (@{$this->{files}}) {
        my $txt;
        if ($file->{name} =~ /\.txt$/) {
            $txt = $file->{name};
            $this->filter_txt($this->{basedir}.'/'.$txt,
                              $this->{tmpDir}.'/'.$txt);
        } elsif (
            $file->{name} =~ /\.pm$/) {
            $txt = $file->{name};
            $this->filter_pm($this->{basedir}.'/'.$txt,
                             $this->{tmpDir}.'/'.$txt);
        }
    }
    if( -e $this->{tmpDir}.'/'.$this->{data_twiki_module}.'.txt' ) {
        $this->cp($this->{tmpDir}.'/'.$this->{data_twiki_module}.'.txt',
                  $this->{basedir}.'/'.$project.'.txt');
    }
    $this->apply_perms($this->{files}, $this->{tmpDir} );

    if( $this->{other_modules} ) {
        my $libs = join(':',@INC);
        foreach my $module (@{$this->{other_modules}}) {
            print STDERR "Installing $module in $this->{tmpDir}\n";
            print `export TWIKI_HOME=$this->{tmpDir}; export TWIKI_LIBS=$libs; cd $basedir/$module; perl build.pl handsoff_install`;
        }
    }
}

=pod

---++++ target_archive
Makes zip and tgz archives of the files in tmpDir. Also copies the installer.

=cut

sub target_archive {
    my $this = shift;
    my $project = $this->{project};

    die 'no tmpDir set' unless defined ($this->{tmpDir});
    die 'no project set' unless defined ($project);
    die 'tmpDir ('.$this->{tmpDir}.') not found' unless ( -e $this->{tmpDir} );

    $this->pushd($this->{tmpDir});

    $this->apply_perms($this->{files}, $this->{tmpDir} );

    $this->sys_action('zip -r -q ' . $project . '.zip *');
    $this->perl_action('File::Copy::move("'.$project.'.zip", "'.
                         $this->{basedir}.'/'.$project.'.zip");');

    $this->sys_action('tar czpf '  . $project . '.tgz *');
    $this->perl_action('File::Copy::move("'.$project.'.tgz", "'.
                         $this->{basedir}.'/'.$project.'.tgz")');

    $this->perl_action('File::Copy::move("'.
                         $this->{tmpDir}.'/'.$project.'_installer","'.
                         $this->{basedir}.'/'.$project.'_installer")');

    $this->pushd($this->{basedir});
    my @fs;
    foreach my $f qw(.tgz _installer .zip) {
        push (@fs, "$project$f") if (-e "$project$f");
    }
    $this->sys_action('md5sum ' . join(' ', @fs) .' > ' . "$project.md5");
    $this->popd();
    $this->popd();

    foreach my $f qw(.tgz .zip .txt _installer) {
        print "Release $f is $this->{basedir}/$project$f\n";
    }
    print "MD5 checksums are in $this->{basedir}/$project.md5\n";
}

=pod

---++++ copy_fileset
Copy all files in a file set from on directory root to another.

=cut

sub copy_fileset {
    my ($this, $set, $from, $to) = @_;

    my $uncopied = scalar(@$set);
    if ($this->{-v} || $this->{-n}) {
        print 'Copying '.$uncopied.' files to '.$to.$NL;
    }
    foreach my $file (@$set) {
        my $name = $file->{name};
        if (! -e $from.'/'.$name) {
            die $from.'/'.$name.' does not exist - cannot copy';
        }
        $this->cp($from.'/'.$name, $to.'/'.$name);
        $uncopied--;
    }
    die 'Files left uncopied' if ($uncopied);
}

=pod

---++++ apply_perms
Apply perms to a fileset

=cut

sub apply_perms {
    my ($this, $set, $to) = @_;

    foreach my $file (@$set) {
        my $name = $file->{name};
        if( defined $file->{permissions} ) {
            $this->prot($file->{permissions}, $to.'/'.$name);
        }
    }
}

=pod

---++++ target_handsoff_install
Install target, installs to local twiki pointed at by TWIKI_HOME.

Does not run the installer script.

=cut

sub target_handsoff_install {
    my $this = shift;
    $this->build('release');

    my $twiki = $ENV{TWIKI_HOME};
    die 'TWIKI_HOME not set' unless $twiki;
    $this->pushd($twiki);
    $this->sys_action('tar zxpf '.
                        $this->{basedir}.'/'.$this->{project}.'.tgz');
    # kill off the module installer
    $this->rm($twiki.'/'.$this->{project}.'_installer');
    $this->popd();
}

=pod

---++++ target_install
Install target, installs to local twiki pointed at by TWIKI_HOME.

Uses the installer script written by target_installer

=cut

sub target_install {
    my $this = shift;
    $this->build('handsoff_install');
    $this->sys_action('perl '.$this->{project}.'_installer install');
}

=pod

---++++ target_uninstall
Uninstall target, uninstall from local twiki pointed at by TWIKI_HOME.

Uses the installer script written by target_installer

=cut

sub target_uninstall {
    my $this = shift;
    my $twiki = $ENV{TWIKI_HOME};
    die 'TWIKI_HOME not set' unless $twiki;
    $this->pushd($twiki);
    $this->sys_action('perl '.$this->{project}.'_installer uninstall');
    $this->popd();
}

{
    package TWiki::Contrib::Build::UserAgent;

    use base qw(LWP::UserAgent);

    sub new {
        my ($class, $id) = @_;
        my $this = $class->SUPER::new();
        $this->{domain} = $id;
        return $this;
    }

    use vars qw($VAR1);

    sub get_basic_credentials {
        my($this, $realm, $uri) = @_;
        unless ($this->{passwords}) {
            $this->{passwords} = {};
            do $ENV{HOME}.'/.buildcontriblogin';
            unless ($@) {
                $this->{passwords} = $VAR1;
            }
        }
        my $pws = $this->{passwords}->{$this->{domain}};
        if ($pws) {
            print "Using credentials for $this->{domain} saved in $ENV{HOME}/.buildcontriblogin\n";
        } else {
            local $/ = "\n";
            print 'Logon to ',$uri->host_port(),$NL;
            print 'Enter username for ',$realm,': ';
            my $knownUser = <STDIN>; chomp($knownUser);
            die "Bollocks" unless length $knownUser;
            print 'Password on ',$uri->host_port,': ';
            system('stty -echo');
            my $knownPass = <STDIN>;
            system('stty echo');
            print $NL;  # because we disabled echo
            chomp($knownPass);
            $pws = { user => $knownUser, pass => $knownPass };
            $this->{passwords}->{$this->{domain}} = $pws;
            require Data::Dumper;
            if( open(F, '>'.$ENV{HOME}.'/.buildcontriblogin')) {
                print F Data::Dumper->Dump([$this->{passwords}]);
                close(F);
            }
        }
        return ($pws->{user}, $pws->{pass});
    }
}

sub _getTopicName {
    my $this = shift;
    my $topicname = $this->{project};

    # Example input:  TWiki-4.0.0-beta6
    # Example output: TWikiRelease04x00x00beta06

    # Append 'Release' to first (word) part of name if followed by -
    $topicname =~ s/^(\w+)\-/${1}Release/;
    # Zero-pad numbers to two digits
    $topicname =~ s/(\d+)/sprintf("%0.2i",$1)/ge;
    # replace . with x
    $topicname =~ s/\./x/g;
    # remove dashes
    $topicname =~ s/\-//g;
    return $topicname;
}

=pod

---++++ target_upload
Upload to a repository. Prompts for username and password. Uploads the zip and
the text topic to the appropriate places. Creates the topic if
necessary.

=cut

sub target_upload {
    my $this = shift;

    require LWP;
    if ( $@ ) {
        print STDERR 'LWP is not installed; cannot upload',$NL;
        return 0;
    }

    my $to = $this->{project};

    while (1) {
        print <<END;
Preparing to upload to:
Web:     $this->{UPLOADTARGETWEB}
PubDir:  $this->{UPLOADTARGETPUB}
Scripts: $this->{UPLOADTARGETSCRIPT}
Suffix:  $this->{UPLOADTARGETSUFFIX}
END

        last if ask("Is that correct? Answer 'n' to change", 1);
        print "Enter the name of the TWiki web that contains the target repository\n";
        $this->{UPLOADTARGETWEB} = prompt("Web", $this->{UPLOADTARGETWEB});
        print "Enter the full URL path to the TWiki pub directory\n";
        $this->{UPLOADTARGETPUB} = prompt("PubDir", $this->{UPLOADTARGETPUB});
        print "Enter the full URL path to the TWiki bin directory\n";
        $this->{UPLOADTARGETSCRIPT} = prompt("Scripts", $this->{UPLOADTARGETSCRIPT});
        print "Enter the file suffix used on scripts in the TWiki bin directory (enter 'none' for none)\n";
        $this->{UPLOADTARGETSUFFIX} = prompt("Suffix", $this->{UPLOADTARGETSUFFIX});
        $this->{UPLOADTARGETSUFFIX} = ''
          if $this->{UPLOADTARGETSUFFIX} eq 'none';
    }

    $this->build('release');
    my $userAgent = TWiki::Contrib::Build::UserAgent->new($this->{UPLOADTARGETSCRIPT});
    $userAgent->agent( 'TWikiContribBuild/'.$VERSION.' ' );

    my $topic = $this->_getTopicName();
    my $url = "$this->{UPLOADTARGETSCRIPT}/view$this->{UPLOADTARGETSUFFIX}/$this->{UPLOADTARGETWEB}/$topic";

    # Get the old form data and attach it to the update
    print "Downloading $topic to recover form\n";
    my $response = $userAgent->get( "$url?raw=debug" );

    my %newform;
    unless( $response->is_success ) {
        print 'Failed to GET old topic ', $response->request->uri,
          ' -- ', $response->status_line, $NL;
        $newform{formtemplate} = 'PackageForm';
    } else {
        foreach my $line ( split(/\n/, $response->content() )) {
            if ( $line =~ m/META:FIELD{name="(.*?)".*?value="(.*?)"}/ ) {
                my $val = $2;
                if ($val && $val ne '') {
                    $newform{$1} = $val;
                }
            }
        }
    }
    local $/ = undef; # set to read to EOF
    if( open( IN_FILE, '<'.$this->{basedir}.'/'.$to.'.txt' )) {
        print "Basing new topic on ".$this->{basedir}.'/'.$to.'.txt'."\n";
        $newform{'text'} = <IN_FILE>;
        close( IN_FILE );
    } else {
        print STDERR 'Failed to open base topic: '.$!;
        $newform{'text'} = <<END;
Release $to
END
        print "Basing new topic on some default text:\n$newform{text}\n";
    }

    print "Uploading new topic\n";
    $url =~ s./view/./save/.;
    $response = $userAgent->post( $url, \%newform );

    die 'Update of topic failed ', $response->request->uri,
      ' -- ', $response->status_line, 'Aborting'
        unless $response->is_redirect &&
          $response->headers->header('Location') =~ /view([\.\w]*)\/$this->{UPLOADTARGETWEB}\/$topic/;

    return if($this->{-topiconly});

    # upload any attachments to the developer's version of the topic. Any other
    # attachments to the topic on t.o. will still be there.
    my @attachments;
    my %uploaded;
    # Upload the standard files
    foreach my $ext ('.zip', '.tgz', '_installer', '.md5') {

        $this->_uploadFile($userAgent, $response, $this->{UPLOADTARGETWEB}, $to, $to.$ext,
                           $this->{basedir}.'/'.$to.$ext,'');
        $uploaded{$to.$ext} = 1;
    }
    # Upload other files described in the attachments list. They must be
    # in the pub directory.
    $newform{'text'} =~ s/%META:FILEATTACHMENT(.*)%/push(@attachments, $1)/ge;
    for my $a (@attachments) {
        $a =~ /name="([^"]*)"/;
        my $name = $1;
        next if $uploaded{$name};
        $a =~ /comment="([^"]*)"/;
        my $path = $1;
        $a =~ /path="([^"]*)"/;
        my $comment = $1;

        $this->_uploadFile(
            $userAgent, $response, $this->{UPLOADTARGETWEB}, $to, $name,
            $this->{basedir}.'/pub/TWiki/'.$this->{project}.'/'.$name,
            $comment);
    }
}

sub _uploadFile {
    my ($this, $userAgent, $response, $web, $to, $filename, $filepath, $filecomment) = @_;

    print "Uploading $filename from $filepath\n";
    $response = $userAgent->post(
        "$this->{UPLOADTARGETSCRIPT}/upload$this->{UPLOADTARGETSUFFIX}/$web/$to",
        [
            'filename' => $filename,
            'filepath' => [ $filepath ],
            'filecomment' => $filecomment
           ],
        'Content_Type' => 'form-data' );

    die 'Update of '.$filename.' failed ', $response->request->uri,
      ' -- ', $response->status_line, $NL, 'Aborting',$NL, $response->as_string
        unless $response->is_redirect &&
          $response->headers->header('Location') =~ /view([\.\w]*)\/$web\/$to/;
}

sub _unhtml {
    my $html = shift;

    $html =~ s/<[^<>]*>//og;
    $html =~ s/&#?\w+;//go;
    $html =~ s/\s//go;

    return $html;
}

# Build POD documentation. This target defines =%$POD%= - it
# does not generate any output. The target will be invoked
# automatically if =%$POD%= is used in a .txt file. POD documentation
# is intended for use by developers only.

# POD text in =.pm= files should use TWiki syntax or HTML. Packages should be
# introduced with a level 1 header, ---+, and each method in the package by
# a level 2 header, ---++. Make sure you document any global variables used
# by the module.

sub target_POD {
    my $this = shift;
    $this->{POD} = '';
    local $/ = "\n";
    foreach my $file (@{$this->{files}}) {
        my $pmfile = $file->{name};
        if ($pmfile =~ /\.p[ml]$/o) {
            $pmfile = $this->{basedir}.'/'.$pmfile;
            open(PMFILE,"<$pmfile") || die $!;
            my $inPod = 0;
            while( my $line = <PMFILE>) {
                if( $line =~ /^=(begin|pod)/) {
                    $inPod = 1;
                } elsif ($line =~ /^=cut/) {
                    $inPod = 0;
                } elsif ($inPod) {
                    $this->{POD} .= $line;
                }
            }
            close(PMFILE);
        }
    }
}

=pod

---++++ target_POD

Print POD documentation. This target does not modify any files, it simply
prints the (TWiki format) POD.

POD text in =.pm= files should use TWiki syntax or HTML. Packages should be
introduced with a level 1 header, ---+, and each method in the package by
a level 2 header, ---++. Make sure you document any global variables used
by the module.

=cut

sub target_pod {
    my $this = shift;
    $this->target_POD();
    print $this->{POD}."\n";
}

=pod

---++++ target_installer

Write an install/uninstall script that checks dependencies, and optionally
downloads and installs required zips from twiki.org.

The install script is templated from =contrib/TEMPLATE_installer= and
is always named =module_installer= (where module is your module). It is
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

The install script also acts as an uninstaller and upgrade script.

__Note__ that =target_install= builds and invokes this install script.

At present there is no support for a caller-provided post-install script, but
this would be straightforward to do if it were required.

=cut

sub target_installer {
    my $this = shift;

    # Add the install script to the manifest, unless it is already there
    unless( grep(/^$this->{project}_installer$/,
                 map {$_->{name}} @{$this->{files}})) {
        push(@{$this->{files}},
             { name => $this->{project}.'_installer',
               description => 'Install script',
               permissions => 0640 });
        print STDERR 'Auto-adding install script to manifest',$NL;
    }

    # Find the template on @INC
    my $template;
    foreach my $d ( @INC ) {
        my $dir = `dirname $d`;
        chop($dir);
        my $file = $dir.'/lib/TWiki/Contrib/BuildContrib/TEMPLATE_installer.pl';
        if ( -f $file ) {
            $template = $file;
            last;
        }
        $dir .= '/contrib';
        if ( -f $dir.'/TEMPLATE_installer.pl' ) {
            $template = $dir.'/TEMPLATE_installer.pl';
            last;
        }
    }
    unless($template) {
        die 'COULD NOT LOCATE TEMPLATE_installer.pl - required for install script generation';
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
        push(@sats, "{ name=>'$dep->{name}', type=>'$dep->{type}',version=>'$dep->{version}',description=>'$descr', trigger=>$trig }");
    }
    my $satisfies = join(",", @sats);
    $this->{SATISFIES} = $satisfies;

    my $installScript = $this->{basedir}.'/'.$this->{project}.'_installer';
    if ($this->{-v} || $this->{-n}) {
        print 'Generating installer in ',$installScript,$NL;
    }

    $this->filter_txt( $template, $installScript );

    $this->prot(0755, $installScript);
}

=pod

---++++ build($target)
Build the given target

=cut

sub build {
    my $this = shift;
    my $target = shift;

    if ($this->{-v}) {
        print 'Building ',$target,$NL;
    }
    my $fn = 'target_'.$target;
    no strict "refs";
    $this->$fn();
    use strict "refs";
    if ($@) {
        die 'Failed to build ',$target,': ',$@;
    }
    if ($this->{-v}) {
        print 'Built ',$target,$NL;
    }
}

=pod

---++++ target_manifest
Generate and print to STDOUT a rough guess at the MANIFEST listing

=cut

my $collector;
sub target_manifest {
    my $this = shift;

    $collector = $this;
    my $manifest = _findRelativeTo($buildpldir,'MANIFEST');
    if( $manifest && -e $manifest ) {
        open(F, '<'.$manifest) || die 'Could not open existing '.$manifest;
        local $/ = undef;
        %{$collector->{manilist}} = map{ /^(.*?)(\s+.*)?$/; $1 => ($2||'') } split(/\r?\n/, <F> );
        close(F);
    } else {
        $manifest = $buildpldir.'/MANIFEST';
    }
    require File::Find;
    $collector->{manilist} = ();
    print STDERR "Gathering from $this->{basedir}\n";

    File::Find::find(\&_manicollect, $this->{basedir});
    print '# DRAFT ',$manifest,' follows:',$NL;
    print '################################################',$NL;
    for (sort keys %{$collector->{manilist}}) {
        print $_.' '.$collector->{manilist}{$_}.$NL;
    }
    print '################################################',$NL;
    print '# Copy and paste the text between the ###### lines into the file',$NL;
    print '# '.$manifest,$NL;
    print '# to create an initial manifest. Remove any files',$NL;
    print '# that should _not_ be released, and add a',$NL;
    print '# description of each file at the end of each line.',$NL;
}

sub _manicollect {
    if( /^(CVS|\.svn|twikiplugins)$/ ) {
        $File::Find::prune = 1;
    } elsif ( !-d && /^\w.*\w$/ &&
                !/^(DEPENDENCIES|MANIFEST|(PRE|POST)INSTALL|build\.pl)$/ &&
               !/$collector->{project}\.(md5|zip|tgz|txt)/) {
        my $n = $File::Find::name;
        my @a = stat($n);
        my $perms = sprintf("%04o", $a[2] & 0777);
        $n =~ s/$collector->{basedir}\/?//;
        $collector->{manilist}{$n} = $perms
          unless exists $collector->{manilist}{$n};
    }
}

=pod

#HistoryTarget
Updates the history in the plugin/contrib topic from the subversion checkin history.
   * Requires a line like | Change History:| NNNN: descr | in the topic, where NNN is an SVN rev no and descr is the description of the checkin.
   * Automatically changes ItemNNNN references to links to the bugs web.
   * Must be run in a subversion checkout area!
This target works in the current checkout area; it still requires a checkin of the updated plugin. Note that history items checked in against Item000 are *ignored* (not included in the history).

=cut

sub target_history {
    my $this = shift;

    my $f = $this->{basedir}.'/'.$this->{data_twiki_module}.'.txt';

    my $cmd = "cd $this->{basedir} && svn status";
    print STDERR "Checking status using $cmd\n";
    my $log = join("\n", grep { !/^\?/ } split(/\n/, `$cmd`));
    print STDERR "WARNING:\n$log\n" if $log;

    open(IN, "<$f") or die "Could not open $f: $!";
    # find the table
    my $in_history = 0;
    my @history;
    my $pre = '';
    my $post;
    local $/ = "\n";
    while( my $line = <IN> ) {
        if( $line =~ /^\s*\|\s*Change(?:\s+|&nbsp;)History:.*?\|\s*(.*?)\s*\|\s*$/i ) {
            $in_history = 1;
            push( @history, [ "?1'$1'", $1 ] ) if( $1 && $1 !~ /^\s*$/ );
        } elsif( $in_history ) {
            # | NNNN | desc |
            if( $line =~ /^\s*\|\s*(\d+)\s*\|\s*(.*?)\s*\|\s*$/) {
                push( @history, [ $1, $2 ] );
            }

            # | date | desc |
            elsif( $line =~ /^\s*\|\s*(\d+[-\s\/]+\w+[-\s+\/]\d+)\s*\|\s*(.*?)\s*\|\s*$/) {
                push( @history, [ $1, $2 ] );
            }

            # | verno | desc |
            elsif( $line =~ /^\s*\|\s*([\d.]+)\s*\|\s*(.*?)\s*\|\s*$/) {
                push( @history, [ $1, $2 ] );
            }

            # | | date: desc |
            elsif( $line =~ /^\s*\|\s*\|\s*(\d+\s+\w+\s+\d+):\s*(.*?)\s*\|\s*$/) {
                push( @history, [ $1. $2 ] );
            }

            # | | verno: desc |
            elsif( $line =~ /^\s*\|\s*\|\s*([\d.]+):\s*(.*?)\s*\|\s*$/) {
                push( @history, [ $1, $2 ] );
            }

            # | | desc |
            elsif( $line =~ /^\s*\|\s*\|\s*(.*?)\s*\|\s*$/) {
                push( @history, [ "?". $1 ] );
            }

            else {
                $post = $line;
                last;
            }
        } else {
            $pre .= $line;
        }
    }
    die "No | Change History: | ... | found" unless $in_history;
    $/ = undef;
    $post .= <IN>;
    close(IN);
    # Determine the most recent history item
    my $base = 0;
    if( scalar(@history) && $history[0]->[0] =~ /^(\d+)$/ ) {
        $base = $1;
    }
    print STDERR "Refreshing history since $base\n";
    $cmd = "cd $this->{basedir} && svn info -R";
    print STDERR "Recovering version info using $cmd...\n";
    $log = `$cmd`;
    # find files with revs more recent than $base
    my $curpath;
    my @revs;
    foreach my $line ( split(/\n/, $log )) {
        if( $line =~ /^Path: (.*)$/) {
            $curpath = $1;
        } elsif( $line =~ /^Last Changed Rev: (.*)$/ ) {
            die unless $curpath;
            if( $1 > $base ) {
                print STDERR "$curpath $1 > $base\n";
                push(@revs, $curpath);
            }
            $curpath = undef;
        }
    }

    unless( scalar(@revs) ) {
        print STDERR "History is up to date with svn log\n";
        return;
    }

    # Update the history
    $cmd = "cd $this->{basedir} && svn log ".join(' && svn log ', @revs);
    print STDERR "Updating history using $cmd...\n";
    $log = `$cmd`;
    my %new;
    foreach my $line ( split(/^----+\s*/m, $log)) {
        if( $line =~ /^r(\d+)\s*\|\s*(\w+)\s*\|\s*.*?\((.+?)\)\s*\|.*?\n\s*(.+?)\s*$/ ) {
            # Ignore the history item we already have
            next if $1 == $base;
            my $rev = $1;
            next if $rev <= $base;
            my $when = "$2 $3 ";
            my $mess = $4;
            # Ignore Item000: checkins
            next if $mess =~ /^Item0+:/;
            $mess =~ s/</&lt;/g;
            $mess =~ s/\|/!/g;
            $mess =~ s#^Item(\d+):#<a rel='nofollow' href='$this->{BUGSURL}/Item$1'>Item$1</a> #gm;
            $mess =~ s/\r?\n/ /g;
            $new{$rev} = [ $rev, $mess ];
        }
    }
    unshift(@history, map { $new{$_} } sort { $b <=> $a } keys(%new));
    open(OUT, ">$f") || die "Could not open $f for write: $!";
    print OUT $pre;
    print OUT "| Change&nbsp;History: | |\n";
    print OUT join("\n", map { "|  $_->[0] | $_->[1] |" } @history);
    print OUT "\n$post";
    close(OUT);
}

=pod

---++++ target_dependencies

Extract and print all dependencies, in standard DEPENDENCIES syntax.
Requires B::PerlReq. Analyses perl sources in !includes as well.

All dependencies except those on pragmas (strict, integer etc) are
extracted.

=cut

sub target_dependencies {
    my $this = shift;
    local $/ = "\n";

    eval 'use B::PerlReq';
    die "B::PerlReq is required for 'dependencies': $@" if $@;

    foreach my $m qw(strict vars diagnostics base bytes constant integer locale overload warnings Assert TWiki) {
        $this->{satisfied}{$m} = 1;
    }
    # See if we already know about it
    foreach my $dep (@{$this->{dependencies}}) {
       $this->{satisfied}{$dep->{name}} = 1;
    }

    $this->{extracted_deps} = undef;
    my @queue;
    my %tainted;
    foreach my $file (@{$this->{files}}) {
        my $is_perl = 0;
        my $pmfile = $file->{name};
        if ($pmfile =~ /\.p[ml]$/o &&
              $pmfile !~ /build.pl/ &&
                $pmfile !~ /TEMPLATE_installer.pl/) {
            $is_perl = 1;
        } else {
            my $testfile = $this->{basedir}.'/'.$pmfile;
            if (-e $testfile) {
                open(PMFILE,"<$testfile") || die "$testfile: $!";
                my $fline = <PMFILE>;
                if ($fline && $fline =~ m.#!/usr/bin/perl.) {
                    $is_perl = 1;
                    $tainted{$pmfile} = '-T' if $fline =~ /-T/;
                }
                close(PMFILE);
            }
        }
        if ($pmfile =~ /^lib\/(.*)\.pm$/) {
            my $f = $1;
            $f =~ s.CPAN/lib/..;
            $f =~ s./.::.g;
            $this->{satisfied}{$f} = 1;
        }
        if ($is_perl) {
            $tainted{$pmfile} = '' unless defined $tainted{$pmfile};
            push(@queue, $pmfile);
        }
    }

    my $inc = '-I'.join(' -I', @INC);
    foreach my $pmfile (@queue) {
        die unless defined $basedir;
        die unless defined $inc;
        die unless defined $pmfile;
        die $pmfile unless defined $tainted{$pmfile};
        my $deps = `cd $basedir && perl $inc $tainted{$pmfile} -MO=PerlReq,-strict $pmfile 2>/dev/null`;
        $deps =~ s/perl\((.*?)\)/$this->_addDep($pmfile, $1)/ge if $deps;
    }

    print "MISSING DEPENDENCIES:\n";
    my $depcount = 0;
    foreach my $module (sort keys %{$this->{extracted_deps}}) {
        print "$module,>=0,cpan,May be required for ".
          join(', ',@{$this->{extracted_deps}{$module}})."\n";
        $depcount++;
    }
    print $depcount.' missing dependenc'.($depcount==1?'y':'ies')."\n";
}

sub _addDep {
    my ($this, $from, $file) = @_;

    $file =~ s./.::.g;
    $file =~ s/\.pm$//;
    return '' if $this->{satisfied}{$file};
    push(@{$this->{extracted_deps}{$file}},$from);
    return '';
}

1;
