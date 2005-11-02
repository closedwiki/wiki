#!perl
#
# Intended for use on PC where softlinks (as done by mklinks.sh) are not
# available
# SMELL this will become unnecessary once twikishell is bundled.
use strict;
use File::Path;
use File::Copy;
my %cfg;
$cfg{-v} = 0;

sub usage {
    print <<EOM;
 pseduo-install plugins in a SVN checkout tree
 This is done by a simple copy of the files listed in the MANIFEST for each
 plugin and contrib. There is no linking, and no attempt to be clever. It should
 be equivalent to a zip - unzip of the plugin over the dev tree.

 either:
    * pseudo-install all
  or:
    * pseudo-install FirstPlugin SomeContrib ...
EOM

}

my @modules = @ARGV;

unless (@modules) {
    usage();
    exit 1;
}

if ($modules[0] eq "all") {
  opendir(D, "twikiplugins") || die "Must be run from root of installation";
  @modules = ( grep { /(Plugin|Contrib)$/ } readdir( D )); 
  closedir( D );
}


if ($modules[0] eq "default") {
    @modules = qw(CommentPlugin EditTablePlugin InterwikiPlugin PreferencesPlugin SpreadSheetPlugin SmiliesPlugin TablePlugin WysiwygPlugin TipsContrib);
}

print "Installing modules: ".join(",", @modules).":\n";

foreach my $module (@modules) {
    installModule($module);
}
print "Don't forget to enable them using configure\n";

# SMELL - this probably duplicates something in BuildContrib
sub installModule {
  my $module = shift;
  print "Processing $module\n";
  my $subdir = 'Plugins';
  $subdir = 'Contrib' if $module =~ /Contrib$/;
  my $moduleDir = "twikiplugins/$module/";
#lib/TWiki/$subdir/$module/
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
            File::Path::mkpath( $dir );
            File::Copy::copy( "$moduleDir/$file", $file ) || die "Couldn't install $file";
	    print "  installed $file\n" if $cfg{-v};
        }
        close(F);
    } else {
        print STDERR "---> No MANIFEST in $module\n";
    }
}
