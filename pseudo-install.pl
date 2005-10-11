#!perl
# pseduo-install plugins in a SVN checkout tree
# This is done by a simple copy of the files listed in the MANIFEST for each
# plugin and contrib. There is no linking, and no attempt to be clever. It should
# be equivalent to a zip - unzip of the plugin over the dev tree.
#
# Intended for use on PC where softlinks (as done by mklinks.sh) are not
# available
use strict;
use File::Path;
use File::Copy;

opendir(D, "twikiplugins") || die "Must be run from root of installation";
foreach my $module ( grep { /(Plugin|Contrib)$/ } readdir( D )) {
    print "Processing $module\n";
    my $subdir = 'Plugins';
    $subdir = 'Contrib' if $module =~ /Contrib$/;
    if( -e "twikiplugins/$module/lib/TWiki/$subdir/$module/MANIFEST" ) {
        open( F, "<twikiplugins/$module/lib/TWiki/$subdir/$module/MANIFEST" ) || die $!;
        foreach my $file ( <F> ) {
            chomp( $file );
            next unless $file =~ /^\w+/;
            $file =~ s/\s.*$//;
            next if -d "twikiplugins/$module/$file";
            my $dir = $file;
            $dir =~ s/\/[^\/]*$//;
            File::Path::mkpath( $dir );
            File::Copy::copy( "twikiplugins/$module/$file", $file );
        }
        close(F);
    } else {
        print STDERR "No MANIFEST in $module\n";
    }
}
closedir( D );
