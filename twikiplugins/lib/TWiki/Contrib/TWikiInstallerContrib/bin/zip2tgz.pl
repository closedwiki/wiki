#! /usr/bin/perl -w
use strict;
use Data::Dumper qw( Dumper );
use File::Basename qw( fileparse );
use File::Path qw( rmtree );
use Cwd qw( abs_path );
++$|;

( my @zips = @ARGV ) or die <<__USAGE__;
Usage: zip2tgz.pl <listOfZipFiles>
__USAGE__

our $dirTemp = "";

foreach my $zip ( @zips )
{
    my ( $plugin, $path, $suffix ) = fileparse( abs_path( $zip ), qw( .zip ) );
    print "Converting $plugin";

    $dirTemp = ".tmp";
    rmtree( $dirTemp );
    mkdir $dirTemp or die $!;
    chdir $dirTemp or die $!;

    `unzip $path/${plugin}.zip` or die $!;
    `tar czvf $path/$plugin.tar.gz .` or die $!;

    chdir ".." or die $!;
    rmtree( $dirTemp ) or die $!;

    print "\n";
}
