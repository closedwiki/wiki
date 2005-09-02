# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004-2005 Cole Beck, cole.beck@vanderbilt.edu
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
# =========================
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#
# =========================
#
# This plugin creates a png file by using the graphviz dot command.
# See http://www.graphviz.org/ for more information.
# Note that png files created with this plugin can only be deleted manually; 
# it stays there even after the dot tags are removed.

package TWiki::Plugins::DirectedGraphPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName
        $debug $exampleCfgVar
    );

$VERSION = '1.201';
$pluginName = 'DirectedGraphPlugin';
use Digest::MD5 qw( md5_hex );
#the MD5 and hash table are used to create a unique name for each graph
use File::Path;

my $HASH_CODE_LENGTH=32;
my %hashed_math_strings=();
#my $cmd = '/home/mrjc/packages/graphviz/bin/dot';
my $cmd = '/usr/bin/dot';
my $tmpFile = '/tmp/'.$pluginName."$$";

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;
    
    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );
    
    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    #pass everything within <dot> tags to handleDot function
    #$_[0] =~ s/%DOT{(.*?)}%/&handleDot($1)/gise;
    $_[0] =~ s/<DOT>(.*?)<\/DOT>/&handleDot($1)/giseo;
    # pass extra parameter for map - either 0 or 1
    $_[0] =~ s/<DOT\s+map=([01])>(.*?)<\/DOT>/&handleDot($2,$1)/giseo;
}

# =========================
sub handleDot
{
    # Create topic directory "pub/$web/$topic" if needed
    my $dir = TWiki::Func::getPubDir() . "/$web/$topic";
    unless( -e "$dir" ) {
        umask( 002 );
        mkpath($dir, 0, 0755) or return "<noc>DirectedGraph Error: *folder $dir could not be created*";
    }
    # compute the MD5 hash of this string
    my $hash_code = md5_hex( "DOT$_[0]" );
    # store the string in a hash table, indexed by the MD5 hash
    $hashed_math_strings{"$hash_code"} = $_[0];

    # output the parameter into the file "foo.dot"
    open OUTFILE, ">$tmpFile" or return "<noc>DirectedGraph Error: could not create file";
    print OUTFILE $_[0];
    close OUTFILE;

    # run the "dot" command to create a png file with the directed graph
    my $image="${dir}/graph${hash_code}.png";
    # don't do anything if it already exists
    if (open TMP, "$image") {
        close TMP;
    }
    # create the png
    else {
        $command=system($cmd." -Tpng $tmpFile -o $image");
        # If you've installed the netpbm package, you could alternatively 
        # use this command to smooth-scale the image
        #$command=system($cmd." -Tpng $tmpFile | pngtopnm | pnmscale 0.7 | pnmtopng > $image");
        if($command) {
            # errors existed so remove created files
            unlink "$image";
            unlink $tmpFile;
            return "<nop>DirectedGraph Error: syntax error - $command";
        }
    }

    # run the "dot" command to create a map file with a clientside map for the directed graph
    my $cmapx="${dir}/graph${hash_code}.map";
    # $_[1] is either 0, 1, or not set - if it is 1, I want to create a clientside map
    if($_[1]) {
        # don't do anything if it already exists
        if (open TMP, "$cmapx") {
            close TMP;
        }
        # create the map
        else {
            $command=system("$cmd -Tcmapx -o $cmapx $tmpFile");
            if($command) {
                # errors existed so remove created files
                unlink "$cmapx";
                unlink $tmpFile;
                return "<noc>DirectedGraph Error: syntax error";
            }
        }
    }

    # delete the temp file 
    unlink $tmpFile;

    if($_[1]) {
        # read and format map
        my $mapfile = TWiki::Func::readFile( $cmapx );
        $mapfile =~ s/(<map\ id\=\")(.*?)(\"\ name\=\")(.*?)(\">)/$1$hash_code$3$hash_code$5/go;
        # place map and "foo.png" at the source of the <dot> tag in $Web.$Topic
        my $loc = &TWiki::Func::getPubUrlPath() . "/$web/$topic";
        return "$mapfile<img usemap=\"#$hash_code\" src=\"$loc/graph$hash_code.png\"/>";
    } else {
        # attach "foo.png" at the source of the <dot> tag in $Web.$Topic
        $loc= &TWiki::Func::getPubUrlPath() . "/$web/$topic";
        return "<img src=\"$loc/graph$hash_code.png\"/>";
    }
}

1;
