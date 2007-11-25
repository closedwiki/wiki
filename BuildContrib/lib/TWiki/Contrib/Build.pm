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
use CGI qw(:any);

=pod

---++ Package TWiki::Contrib::Build

This is a base class used for making build scripts for TWiki packages.

---+++ Methods

=cut

use strict;
use File::Copy;
use File::Spec;
use File::Find;
use File::Path;
use POSIX;
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
my $TWIKIORGBUGS = 'http://develop.twiki.org/~twiki4/cgi-bin/view/Bugs';
my $TWIKIORGEXTENSIONSWEB = "Plugins";

my $GLACIERMELT = 10; # number of seconds to sleep between uploads,
                      # to reduce average load on server

$SIG{__DIE__} = sub { Carp::confess $_[0] };

my @stageFilters = (
    { RE => qr/\.txt$/,    filter => 'filter_txt' },
    { RE => qr/\.pm$/,     filter => 'filter_pm' },
   );

my @buildFilters = (
    { RE => qr/\.js$/, filter => 'build_js' },
    { RE => qr/\.css$/, filter => 'build_css' },
   );

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

    # where data files live
    $this->{data_twiki} = 'data/TWiki';

    # the root of the name of data files
    $this->{data_twiki_module} = $this->{data_twiki}.'/'.$this->{project};

    ##############################################################
    # Read the manifest

    my $manifest = _findRelativeTo( $buildpldir, 'MANIFEST' );
    ($this->{files}, $this->{other_modules}) =
      TWiki::Contrib::BuildContrib::BaseBuild::readManifest(
          $this->{basedir}, '' , $manifest, sub{ exit(1) });

    # Generate a TWiki table representing the manifest contents
    # and a hash table representing the files
    my $mantable = '';
    my $rawman = '';
    my $hashtable = '';
    foreach my $file (@{$this->{files}}) {
        $rawman .= "$file->{name},$file->{permissions},$file->{description}\n";
        $mantable .= "   | ==" . $file->{name} . '== | ' .
          $file->{description} . ' |'.$NL;
        $hashtable .= "'$file->{name}'=>$file->{permissions},";
    }
    $this->{RAW_MANIFEST} = $rawman;
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
    my $rawdeps = '';
    my $a = ' align="left"';
    foreach my $dep (@{$this->{dependencies}}) {
        $rawdeps .=
          "$dep->{name},$dep->{version},$dep->{trigger},$dep->{type},$dep->{description}\n";
        my $v = $dep->{version};
        $v =~ s/&/&amp;/go;
        $v =~ s/>/&gt;/go;
        $v =~ s/</&lt;/go;
        my $cells = CGI::td({align=>'left'}, $dep->{name} ).
          CGI::td({align=>'left'}, $v ).
              CGI::td({align=>'left'}, $dep->{description});
        $deptable .= CGI::Tr( $cells );
    }
    $this->{RAW_DEPENDENCIES} = $rawdeps;
    $this->{DEPENDENCIES} = 'None';
    if ($deptable) {
        my $cells = CGI::th('Name').CGI::th('Version').CGI::th('Description');
        $this->{DEPENDENCIES} =
          CGI::table({ border=>1}, CGI::Tr($cells).$deptable );
    }

    $this->{VERSION} = $this->_get_svn_version().
      ' ('.POSIX::strftime('%d %b %Y', localtime).')';
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

    local $/;
    $this->{INSTALL_INSTRUCTIONS} = <DATA>;

    my $config = $this->_loadConfig();
    my $rep = $config->{repositories}->{$this->{project}};
    if ($rep) {
        $this->{UPLOADTARGETPUB} = $rep->{pub};
        $this->{UPLOADTARGETSCRIPT} = $rep->{script};
        $this->{UPLOADTARGETSUFFIX} = $rep->{suffix};
        $this->{UPLOADTARGETWEB} = $rep->{web};
    } else {
        $this->{UPLOADTARGETPUB} = $TWIKIORGPUB
          unless defined $this->{UPLOADTARGETPUB};
        $this->{UPLOADTARGETSCRIPT} = $TWIKIORGSCRIPT
          unless defined $this->{UPLOADTARGETSCRIPT};
        $this->{UPLOADTARGETSUFFIX} = $TWIKIORGSUFFIX
          unless defined $this->{UPLOADTARGETSUFFIX};
        $this->{UPLOADTARGETWEB} = $TWIKIORGEXTENSIONSWEB
          unless defined $this->{UPLOADTARGETWEB};
    }

    return $this;
}

sub DESTROY {
    my $self = shift;
    File::Path::rmtree( $self->{tmpDir} ) if $self->{tmpDir};
}

# Load the config memory (passwords, repository locations etc)
sub _loadConfig {
    my $this = shift;

    use vars qw($VAR1);

    if (! defined $this->{config}) {
        if (-r "$ENV{HOME}/.buildcontrib") {
            do "$ENV{HOME}/.buildcontrib";
            $this->{config} = $VAR1;
            print "Loaded config from $this->{config}->{file}\n";
        } else {
        }
        unless ($this->{config}) {
            $this->{config} = {
                file => "$ENV{HOME}/.buildcontrib",
                passwords => {},
                repositories => {},
            }
        }
    }
    return $this->{config};
}

# Save the config
sub _saveConfig {
    my $this = shift;
    require Data::Dumper;
    if( open(F, '>'.$this->{config}->{file})) {
        print F Data::Dumper->Dump([$this->{config}]);
        close(F);
        print "Config saved in $this->{config}->{file}\n";
    } else {
        print STDERR "Could not write $this->{config}->{file}: $!";
    }
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
    my $condition = 1;
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
                $condition = 1;
            } elsif ($line =~ m/^([^,]+),([^,]*),\s*(\w*)\s*,\s*(.+)$/o) {
                $this->_addDependency(
                    name=>$1,
                    version=>$2,
                    type=>$3,
                    description=>$4,
                    trigger=>$condition);
                $condition = 1;
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
Basic build target.

=cut

sub target_build {
    my $this = shift;
}

=pod

---++++ target_compress
Compress Javascript and CSS files

=cut

sub target_compress {
    my $this = shift;
  FILE:
    foreach my $file (@{$this->{files}}) {
        # Find files that match the build filter and try to update
        # them
        foreach my $filter (@buildFilters) {
            if ($file->{name} =~ /$filter->{RE}/) {
                no strict 'refs';
                my $ok = &{$filter->{filter}}(
                    $this, $this->{basedir}.'/'.$file->{name});
                use strict 'refs';
                if ($ok) {
                    next FILE;
                }
            }
        }
    }
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
        warn <<MESSY;
WARNING: CANNOT RUN TESTS; TestRunner.pl not found.
Did you remember to install UnitTestContrib?
MESSY
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
Expands tokens.

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
        open(OF, '>'.$to) || die "$to: $!";
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

---++++ build_js
Uses JavaScript::Minifier to optimise javascripts

=cut

sub build_js {
    my ($this, $to) = @_;

    my $from = $to;
    $from =~ s/.js$/_src.js/;

    return 0 unless -e $from;

    open(IF, '<'.$from) || die $!;
    local $/ = undef;
    my $text = <IF>;
    close(IF);

    eval "require JavaScript::Minifier";
    if ($@) {
        print STDERR "Cannot squish: no JavaScript::Minifier found\n";
    } else {
        $text = JavaScript::Minifier::minify(input => $text);

        if (open(IF, '<'.$to)) {
            my $ot = <IF>;
            close($ot);
            return 1 if $text eq $ot; # no changes?
        }

        unless ($this->{-n}) {
            open(OF, '>'.$to) || die "$to: $!";
        }
        print OF $text unless ($this->{-n});
        close(OF) unless ($this->{-n});
        print STDERR "Generated $to from $from\n";
    }
    return 1;
}

=pod

---++++ build_css
Uses CSS::Minifier to optimise CSS files

=cut

sub build_css {
    my ($this, $to) = @_;

    my $from = $to;
    $from =~ s/\.css$/_src.css/;

    return 0 unless -e $from;

    open(IF, '<'.$from) || die $!;
    local $/ = undef;
    my $text = <IF>;
    close(IF);

    eval "require CSS::Minifier";
    if ($@) {
        print STDERR "Cannot squish: no CSS::Minifier found\n";
    } else {
        $text = CSS::Minifier::minify(input => $text);

        if (open(IF, '<'.$to)) {
            my $ot = <IF>;
            close($ot);
            return 1 if $text eq $ot; # no changes?
        }

        unless ($this->{-n}) {
            open(OF, '>'.$to) || die "$to: $!";
        }
        print OF $text unless ($this->{-n});
        close(OF) unless ($this->{-n});
        print STDERR "Generated $to from $from\n";
    }
    return 1;
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

    $text =~ s/\$Rev(:\s*\d+)?\s*\$/\$Rev: $this->{VERSION} \$/gso;

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
        foreach my $filter (@stageFilters) {
            if ($file->{name} =~ /$filter->{RE}/) {
                no strict 'refs';
                &{$filter->{filter}}(
                    $this,
                    $this->{basedir}.'/'.$file->{name},
                    $this->{tmpDir}.'/'.$file->{name});
                use strict 'refs';
            }
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
            die $from.'/'.$name.' does not exist';
        } else {
            $this->cp($from.'/'.$name, $to.'/'.$name);
            $uncopied--;
        }
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
        my ($class, $id, $bldr) = @_;
        my $this = $class->SUPER::new(keep_alive => 1);
        $this->{domain} = $id;
        $this->{builder} = $bldr;
        require HTTP::Cookies;
        $this->cookie_jar(new HTTP::Cookies(
            file => "$ENV{HOME}/.lwpcookies",
            autosave => 1,
            ignore_discard => 1 ));

        return $this;
    }

    sub get_basic_credentials {
        my($this, $realm, $uri) = @_;
        return $this->{builder}->getCredentials($uri->host());
    }
}

sub getCredentials {
    my ($this, $host) = @_;
    my $config = $this->_loadConfig();
    my $pws = $config->{passwords}->{$host};
    if ($pws) {
        print "Using credentials for $host saved in $config->{file}\n";
    } else {
        local $/ = "\n";
        print 'Enter username for ',$host,': ';
        my $knownUser = <STDIN>; chomp($knownUser);
        die "Inadequate user" unless length $knownUser;
        print 'Password: ';
        system('stty -echo');
        my $knownPass = <STDIN>;
        system('stty echo');
        print $NL;  # because we disabled echo
        chomp($knownPass);
        $pws = { user => $knownUser, pass => $knownPass };
        $config->{passwords}->{$host} = $pws;
        $this->_saveConfig();
    }
    return ($pws->{user}, $pws->{pass});
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
        $this->{UPLOADTARGETSCRIPT} = prompt(
            "Scripts", $this->{UPLOADTARGETSCRIPT});
        print "Enter the file suffix used on scripts in the TWiki bin directory (enter 'none' for none)\n";
        $this->{UPLOADTARGETSUFFIX} = prompt(
            "Suffix", $this->{UPLOADTARGETSUFFIX});
        $this->{UPLOADTARGETSUFFIX} = ''
          if $this->{UPLOADTARGETSUFFIX} eq 'none';
        my $rep = $this->{config}->{repositories}->{$this->{project}} || {};
        $rep->{pub} = $this->{UPLOADTARGETPUB};
        $rep->{script} = $this->{UPLOADTARGETSCRIPT};
        $rep->{suffix} = $this->{UPLOADTARGETSUFFIX};
        $rep->{web} = $this->{UPLOADTARGETWEB};
        $this->{config}->{repositories}->{$this->{project}} = $rep;
        $this->_saveConfig();
    }

    $this->build('release');
    my $userAgent = new TWiki::Contrib::Build::UserAgent(
        $this->{UPLOADTARGETSCRIPT}, $this);
    $userAgent->agent( 'TWikiContribBuild/'.$VERSION.' ' );

    my $topic = $this->_getTopicName();
    my ($user, $pass) = $this->getCredentials($this->{UPLOADTARGETSCRIPT});

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
                # Trim null values or we end up damaging the form
                if (defined $val && length($val)) {
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
        # Hack to avoid revisions being overwritten on twiki.org.
        # Can be removed when twiki.org is upgraded to 4.1.0.
        # Item3216, Item3454
        $newform{'text'} =~ s/^%META:TOPICINFO{.*}%$//m;
    } else {
        print STDERR 'Failed to open base topic: '.$!;
        $newform{'text'} = <<END;
Release $to
END
        print "Basing new topic on some default text:\n$newform{text}\n";
    }

    $this->_uploadTopic($userAgent, $user, $pass, $topic, \%newform);

    # Upload any 'Var*.txt' topics published by the extension
    my $dataDir = $this->{basedir}.'/data/TWiki';
    if (opendir(DIR, $dataDir)) {
        foreach my $f (grep(/^Var\w+\.txt$/, readdir DIR)) {
            if (open(IN_FILE, '<'.$this->{basedir}.'/data/TWiki/'.$f)) {
                %newform = ( text => <IN_FILE> );
                close(IN_FILE);
                $f =~ s/\.txt$//;
                $this->_uploadTopic($userAgent, $user, $pass, $f, \%newform);
            }
        }
    }

    return if($this->{-topiconly});

    # upload any attachments to the developer's version of the topic. Any other
    # attachments to the topic on t.o. will still be there.
    my @attachments;
    my %uploaded; # flag already uploaded

    $newform{text} =~ s/%META:FILEATTACHMENT(.*)%/push(@attachments, $1)/ge;
    foreach my $a (@attachments) {
        $a =~ /name="([^"]*)"/;
        my $name = $1;
        next if $uploaded{$name};
        next if $name =~ /^$to(\.zip|\.tgz|_installer|\.md5)$/;
        $a =~ /comment="([^"]*)"/;
        my $comment = $1;
        $a =~ /attr="([^"]*)"/;
        my $attrs = $1 || '';

        $this->_uploadAttachment(
            $userAgent, $user, $pass,
            $name, $this->{basedir}.'/pub/TWiki/'.$this->{project}.'/'.$name,
            $comment, $attrs =~ /h/ ? 1 : 0);
        $uploaded{$name} = 1;
    }

    my $doup = ask("Do you want to upload the archives and installers?", 1);
    return unless $doup;

    # Upload the standard files
    foreach my $ext qw(.zip .tgz _installer .md5) {
        my $name = $to.$ext;
        next if $uploaded{$name};
        $this->_uploadAttachment(
            $userAgent, $user, $pass,
            $to.$ext, $this->{basedir}.'/'.$to.$ext,'');
        $uploaded{$name} = 1;
    }
}

sub _uploadTopic {
    my ($this, $userAgent, $user, $pass, $topic, $form) = @_;
    my $url = "$this->{UPLOADTARGETSCRIPT}/save$this->{UPLOADTARGETSUFFIX}/$this->{UPLOADTARGETWEB}/$topic";
    $form->{text} = <<EXTRA.$form->{text};
<!--
This topic is part of the documentation for $this->{project} and is
automatically generated from Subversion. Do not edit it! Your edits
will be lost the next time the topic is uploaded!

If you want to report an error in the topic, please raise a report at
http://develop.twiki.org/~twiki4/cgi-bin/view/Bugs/$this->{project}
-->
EXTRA
    print "Saving $topic\n";
    $this->_postForm( $userAgent, $user, $pass, $url, $form );
}

sub _uploadAttachment {
    my ($this, $userAgent, $user, $pass,
        $filename, $filepath, $filecomment, $hide) = @_;
    my $url = "$this->{UPLOADTARGETSCRIPT}/upload$this->{UPLOADTARGETSUFFIX}/$this->{UPLOADTARGETWEB}/$this->{project}";
    my $form = [
        'filename' => $filename,
        'filepath' => [ $filepath ],
        'filecomment' => $filecomment,
        'hidefile' => $hide || 0,
       ];

    print "Uploading $this->{UPLOADTARGETWEB}/$this->{project}/$filename\n";
    $this->_postForm($userAgent, $user, $pass, $url, $form);
}

sub _postForm {
    my ($this, $userAgent, $user, $pass, $url, $form) = @_;
    my $response = $userAgent->post(
        $url, $form,
        'Content_Type' => 'form-data' );

    if ($response->is_redirect() &&
          $response->headers->header('Location') =~ /oopsaccessdenied/) {
        # Try login if we got access denied despite passing creds
        # with the user agent
        $response = $userAgent->post(
            "$this->{UPLOADTARGETSCRIPT}/login",
            { username => $user, password => $pass });
        #print STDERR "Fallthrough login attempt returned ".
        #  $response->request->uri,' -- ', $response->status_line, $NL,
        #    $response->headers->header('Location')."\n".
        #      $response->content().$NL,
        #        $response->headers->header('Set-Cookie').$NL;
        # Post the upload again; we should be logged in
        $response = $userAgent->post( $url, $form );
    }

    die 'Upload failed ', $response->request->uri,
      ' -- ', $response->status_line, $NL, 'Aborting',$NL, $response->as_string
        unless $response->is_redirect &&
          $response->headers->header('Location') !~ /oops/;

    my $sleep = $GLACIERMELT;
    if ($sleep > 0) {
        local $| = 1;
        print "Taking a deep breath after the upload";
        while ($sleep > 0) {
            print '.';
            sleep(2);
            $sleep -= 2;
        }
        print "\n";
    }
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
            next if $pmfile =~ /^$this->{project}_installer(\.pl)?$/;
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
               permissions => 0770 });
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

    # Copy it to .pl
    $this->cp($installScript, "$installScript.pl");
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
            $mess =~ s#(?<!Bugs:)\bItem(\d+):#Bugs:Item$1:#gm;
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
__DATA__
You do not need to install anything in the browser to use this extension. The following instructions are for the administrator who installs the extension on the server where TWiki is running.

Like many other TWiki extensions, this module is shipped with a fully
automatic installer script written using the Build<nop>Contrib.
   * If you have TWiki 4.2 or later, you can install from the =configure= interface (Go to Plugins->Find More Extensions)
      * See the [[http://twiki.org/cgi-bin/view/Plugins/BuildContribInstallationSupplement][installation supplement]] on TWiki.org for more information.
   * If you have any problems, then you can still install manually from the command-line:
      1 Download one of the =.zip= or =.tgz= archives
      1 Unpack the archive in the root directory of your TWiki installation.
      1 Run the installer script ( =perl &lt;module&gt;_installer= )
      1 Run =configure= and enable the module, if it is a plugin.
      1 Repeat for any missing dependencies.
   * If you are *still* having problems, then instead of running the installer script:
      1 Make sure that the file permissions allow the webserver user to access all files.
      1 Check in any installed files that have existing =,v= files in your existing install (take care *not* to lock the files when you check in)
      1 Manually edit !LocalSite.cfg to set any configuration variables.

%IF{"defined 'SYSTEMWEB'" else="<div class='twikiAlert'>%X% WARNING: SYSTEMWEB is not defined in this TWiki. Please add these definitions to your %MAINWEB%.TWikiPreferences, if they are not already there:<br><pre>   * <nop>Set SYSTEMWEB = %<nop>TWIKIWEB%<br>   * <nop>Set USERSWEB = %<nop>MAINWEB%</pre></div>"}%
