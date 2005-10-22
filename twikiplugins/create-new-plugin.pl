#! /usr/bin/perl -w
use strict;

use FindBin;
use File::Path qw( mkpath );
use File::Copy qw( cp );
use Cwd;

################################################################################

my ( $name ) = @ARGV;
my $type = 'Plugin';

usage(), exit 0 unless $name;

################################################################################

chdir $FindBin::Bin;

#print STDERR "$name already exists; will not overwrite (use --f/--force to override)\n";
-e $name && die "$name already exists; will not overwrite\n";

eval { mkpath [ "$name/lib/TWiki/Plugins/$name", "$name/data/TWiki/$name.txt" ] };
$@ && die $@;

# BuildContrib
cp "BuildContrib/lib/TWiki/Contrib/BuildContrib/build.pl", "$name/lib/TWiki/Plugins/$name/build.pl" or die $!;

# PluginSkeleton
cp "../lib/TWiki/Plugins/EmptyPlugin.pm", "$name/lib/TWiki/Plugins/$name.pm" or die $!;

################################################################################

sub usage
{
    print STDERR <<__USAGE__;
Usage: create-new-extension.pl ExtensionName
__USAGE__
}

################################################################################
