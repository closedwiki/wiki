#!perl
use strict;

use File::Path;
use File::Copy;

my $install;

sub usage {
    print <<EOM;
 Must be run from the root of a SVN checkout tree

 pseudo-install optional modules in a SVN checkout tree
 This is done by a simple copy or link of the files listed in the MANIFEST
 for each module. The installer script is not called.
 It should be equivalent to a tar zx of the packaged module over the dev tree.

 Usage: pseudo-install.pl [-link] [all|default] <module>...
    -link - link instead of copy (using ln -s)
    -uninstall - self explanatory
    all - install all modules found in twikiplugins
    default - install modules listed in tools/MANIFEST
    <module>... one or more modules to install e.g. FirstPlugin SomeContrib ...
EOM

}

sub installModule {
    my $module = shift;
    print "Processing $module\n";
    my $subdir = 'Plugins';
    $subdir = 'Contrib' if $module =~ /Contrib$/;
    my $moduleDir = "twikiplugins/$module/";

    unless (-d $moduleDir) {
        print STDERR "---> No such $moduleDir\n";
        return;
    }

    my $manifest = $moduleDir."lib/TWiki/$subdir/$module/".'/MANIFEST';
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
        print STDERR "---> No MANIFEST in $module\n";
    }
}

sub copy_in {
    my( $moduleDir, $dir, $file ) = @_;
    File::Path::mkpath( $dir );
    File::Copy::copy( "$moduleDir/$file", $file ) ||
        die "Couldn't install $file";
    print "Copied $file\n";
}

sub just_link {
    my( $moduleDir, $dir, $file ) = @_;
    File::Path::mkpath( $dir );
    my $argh = `ln -s $moduleDir/$file $file`;
    die "$argh $@" if ( $argh || $@ );
    print "Lunk $file\n";
}

sub uninstall {
    my( $moduleDir, $dir, $file ) = @_;
    unlink $file;
    print "Unlunk $file\n";
}

unless (@ARGV) {
    usage();
    exit 1;
}

if ($ARGV[0] eq '-link') {
    shift(@ARGV);
    $install = \&just_link;
} elsif ($ARGV[0] eq '-uninstall') {
    shift(@ARGV);
    $install = \&uninstall;
} else {
    $install = \&copy_in;
}

my @modules;

if ($ARGV[0] eq "all") {
  opendir(D, "twikiplugins") || die "Must be run from root of installation";
  @modules = ( grep { /(Plugin|Contrib)$/ } readdir( D ));
  closedir( D );
} elsif ($ARGV[0] eq "default") {
    open(F, "<", "tools/MANIFEST") || die "Could not open MANIFEST: $!";
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
print "Don't forget to enable plugins using configure\n";
