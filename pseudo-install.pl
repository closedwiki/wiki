#!/usr/bin/perl
use strict;

use File::Path;
use File::Copy;
use File::Spec;
use Cwd;

my $install;
my $basedir;

BEGIN {
    $basedir = Cwd::getcwd();
}

sub usage {
    print <<EOM;
 Must be run from the root of a SVN checkout tree

 pseudo-install optional modules in a SVN checkout tree
 This is done by a link or copy of the files listed in the MANIFEST
 for each module. The installer script is not called.
 It should be almost equivalent to a tar zx of the packaged module
 over the dev tree.

 Usage: pseudo-install.pl [-link] [-copy] [all|default] <module>...
    -link - create links (default behaviour)
    -copy - copy instead of linking
    -uninstall - self explanatory (doesn't remove dirs)
    all - install all modules found in twikiplugins
    default - install modules listed in lib/MANIFEST
    <module>... one or more modules to install e.g. FirstPlugin SomeContrib ...
EOM

}

sub findRelativeTo {
    my( $startdir, $name ) = @_;

    my @path = split( /\/+/, $startdir );

    while (scalar(@path) > 0) {
        my $found = join( '/', @path).'/'.$name;
        return $found if -e $found;
        pop( @path );
    }
    return undef;
}

sub installModule {
    my $module = shift;
    print "Processing $module\n";
    my $subdir = 'Plugins';
    $subdir = 'Contrib' if $module =~ /(Contrib|Skin|AddOn)$/;
    $subdir = 'Tags' if $module =~ /Tag$/;
    my $moduleDir = "twikiplugins/$module/";

    unless (-d $moduleDir) {
        print STDERR "---> No such $moduleDir\n";
        return;
    }

    my $manifest = findRelativeTo($moduleDir."lib/TWiki/$subdir/$module/",'MANIFEST');

    if( -e "$manifest" ) {
        open( F, "<$manifest" ) || die $!;
        foreach my $file ( <F> ) {
            chomp( $file );
            next unless $file =~ /^\w+/;
            $file =~ s/\s.*$//;
            next if -d "$moduleDir/$file";
            my $dir = $file;
            $dir =~ s/\/[^\/]*$//;
            &$install( $moduleDir, $dir, $file );
        }
        close(F);
    } else {
        print STDERR "---> No MANIFEST in $module (at $manifest)\n";
    }
    if( -d "$moduleDir/test/unit/$module" ) {
        opendir(D, "$moduleDir/test/unit/$module");
        foreach my $f (grep(/\.pm$/, readdir(D))) {
            &$install(
                $moduleDir, "test/unit/$module", "test/unit/$module/$f" );
        }
        closedir(D);
    }
}

sub copy_in {
    my( $moduleDir, $dir, $file ) = @_;
    File::Path::mkpath( $dir );
    File::Copy::copy( "$moduleDir/$file", $file ) ||
        die "Couldn't install $file: $!";
    print "Copied $file\n";
}

sub _checkLink {
    my( $moduleDir,$path,$c) = @_;

    my $base = "$basedir/$moduleDir";
    my $dest = readlink "$path$c";
    $dest =~ s#/([^/]*)$##;
    unless( $1 eq $c ) {
        print STDERR <<HERE;
WARNING Confused by
     $path -> '$dest$1' doesn't point to the expected place
     (should be $base$path$c)
HERE
    }

    $dest = "$basedir/$path$dest";
    while ( $dest =~ s#/[^/]+/\.\.## ) {
    }
    if( "$dest/$c" ne "$base$path$c" ) {
        print STDERR <<HERE;
WARNING Confused by
     $path$c -> '$dest/$c' doesn't point to the expected place
     (should be $base$path$c)
HERE
        return 0;
    }
    return 1;
}

# Will try to link as high in the dir structure as it can
sub just_link {
    my( $moduleDir, $dir, $file ) = @_;

    my $base = "$basedir/$moduleDir";
    my $relp = '';
    my @components = split(/\/+/, $file);
    my $path = '';
    foreach my $c ( @components ) {
        if( -l "$path$c" ) {
            _checkLink($moduleDir,$path,$c);
            #print STDERR "$path$c already linked\n";
            last;
        } elsif( -d "$path$c" ) {
            $path .= "$c/";
            $relp .= '../';
        } elsif( -e "$path$c" ) {
            print STDERR "ERROR $path$c is in the way\n";
            last;
        } else {
            my $tgt = "$relp$moduleDir$path$c";
            #print "Link $tgt $path$c\n";
            #print `cd $path && ls -l $tgt`;
            my $argh = `ln -s $tgt $path$c 2>&1`;
            die "$argh $@" if ( $argh || $@ );
            print "Linked $base$path$c\n";
            last;
        }
    }
}

sub uninstall {
    my( $moduleDir, $dir, $file ) = @_;
    # link handling that detects valid linking path components higher in the
    # tree so it unlinks the directories, and not the leaf files.
    my @components = split(/\/+/, $file);
    my $base = "$basedir/$moduleDir";
    my $relp = '';
    my $path = '';
    foreach my $c ( @components ) {
        if( -l "$path$c" ) {
            return unless _checkLink($moduleDir,$path,$c);
            unlink "$path$c";
            print "Unlinked $path$c\n";
            return;
        } else {
            $path .= "$c/";
            $relp .= '../';
        }
    }
    if( -e $file ) {
        unlink $file;
        print "Removed $file\n";
    }
}

unless (@ARGV) {
    usage();
    exit 1;
}

$install = \&just_link;
if ($ARGV[0] eq '-link') {
    shift(@ARGV);
    $install = \&just_link;
} elsif ($ARGV[0] eq '-copy') {
    shift(@ARGV);
    $install = \&copy_in;
} elsif ($ARGV[0] eq '-uninstall') {
    shift(@ARGV);
    $install = \&uninstall;
}

my @modules;

if ($ARGV[0] eq "all") {
  opendir(D, "twikiplugins") || die "Must be run from root of installation";
  @modules = ( grep { /(Tag|Plugin|Contrib|Skin|AddOn)$/ } readdir( D ));
  closedir( D );
} elsif ($ARGV[0] eq "default") {
    open(F, "<", "lib/MANIFEST") || die "Could not open MANIFEST: $!";
    local $/ = "\n";
    @modules =
      map { /(\w+)$/; $1 }
        grep { /^!include/ } <F>;
    close(F);
} else {
    @modules = @ARGV;
}

print "Installing modules: ".join(",", @modules).":\n";

foreach my $module (@modules) {
    installModule($module);
}
print "Don't forget to enable/disable plugins using configure\n";
