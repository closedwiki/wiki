#! /usr/bin/perl -w
use strict;

use FindBin;
use File::Path qw( mkpath );
use Cwd;

################################################################################

my ( $name ) = @ARGV;
my $type = 'Plugin';

usage(), exit 0 unless $name;

################################################################################

chdir $FindBin::Bin;

#print STDERR "$name already exists; will not overwrite (use --f/--force to override)\n";
-e $name && die "$name already exists; will not overwrite\n";

eval { mkpath [ "$name/lib/TWiki/Plugins/$name/", "$name/data/TWiki/" ] };
$@ && die $@;

{ # BuildContrib
#cp "BuildContrib/lib/TWiki/Contrib/BuildContrib/build.pl", "$name/lib/TWiki/Plugins/$name/build.pl" or die $!;
    open( BUILD, '<', "BuildContrib/lib/TWiki/Contrib/BuildContrib/build.pl" ) or die $!;
    local $/ = undef;
    my $build = <BUILD>;
    close BUILD;

    $build =~ s/BuildContrib/$name/g;

    open( BUILD, '>', "$name/lib/TWiki/Plugins/$name/build.pl" ) or die $!;
    print BUILD $build;
    close BUILD;
}

{ # PluginSkeleton
#    cp "../lib/TWiki/Plugins/EmptyPlugin.pm", "$name/lib/TWiki/Plugins/$name.pm" or die $!;
    open( PLUGIN, '<', "../lib/TWiki/Plugins/EmptyPlugin.pm" ) or die $!;
    local $/ = undef;
    my $lib = <PLUGIN>;
    close PLUGIN;

    $lib =~ s/EmptyPlugin/$name/g;

    open( PLUGIN, '>', "$name/lib/TWiki/Plugins/$name.pm" ) or die $!;
    print PLUGIN $lib;
    close PLUGIN;

    open( MANIFEST, '>', "$name/lib/TWiki/Plugins/$name/MANIFEST" ) or die $!;
    print MANIFEST <<__MANIFEST__;
data/TWiki/$name.txt  Plugin doc page
lib/TWiki/Plugins/$name.pm  Plugin Perl module 
__MANIFEST__
    close MANIFEST;

    open( DEPENDENCIES, '>', "$name/lib/TWiki/Plugins/$name/DEPENDENCIES" ) or die $!;
    close DEPENDENCIES;

    open( TOPIC, '>', "$name/data/TWiki/$name.txt" ) or die $!;
    print TOPIC "xxx";
    close TOPIC;

    # TODO: make unit tests
}

# replace-string EmptyPlugin $name

################################################################################

sub usage
{
    print STDERR <<__USAGE__;
Usage: create-new-extension.pl ExtensionName
__USAGE__
}

################################################################################
