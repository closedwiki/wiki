# MathModePlugin.pm
# Copyright (C) 2002 Graeme Lufkin, gwl@u.washington.edu
#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
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
# This is the Math Mode TWiki plugin.  See TWiki.MathModePlugin for details.
#
# Each plugin is a package that contains the subs:
#
#   initPlugin           ( $topic, $web, $user, $installWeb )
#   commonTagsHandler    ( $text, $topic, $web )
#   startRenderingHandler( $text, $web )
#   outsidePREHandler    ( $text )
#   insidePREHandler     ( $text )
#   endRenderingHandler  ( $text )
#
# initPlugin is required, all other are optional. 
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name.
# 
# NOTE: To interact with TWiki use the official TWiki functions
# in the &TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!

# MathModePlugin: This plugin allows you to include mathematics in
# TWiki pages.  To delimit a piece of math, enclose it with the markup
# tag of %$ ... $%  The dollar sign renders an equation in-line, just as
# in LaTeX.  To get equations in big mode on their own line, use %\[ ... \]%
# or %MATHMODE{ ... }%  An image is rendered for each expression on a page
# using the external program latex2html (not included!)
# The rendering is done the first time an expression is used.  Subsequent
# views of the page will not require a re-render.
# Images from old expressions no longer included in the page will be deleted.



# =========================
package TWiki::Plugins::MathModePlugin; 	# change the package name!!!

use strict;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $debug
    );

#this is the second release of this plugin
$VERSION = '1.100';

#the MD5 hash function is used to uniquely identify a string of math
use Digest::MD5 qw( md5_hex );

#we use the basename() function to determine which script is running
use File::Basename qw( basename );

#these variables are used by the plugin

#this is the extension of the images.  To use a different image type,
#you need to change this AND the variable in the latex2html init file.
my $EXT = 'png';

#this is the name of the latex file created by the program.  You shouldn't
#need to change it unless for some bizarre reason you have a file attached to
#a TWiki topic called twiki_math or twiki_math.tex
my $LATEXBASENAME = 'twiki_math';
my $LATEXFILENAME = $LATEXBASENAME . '.tex';

#this variable will point to the init file used by latex2html
my $L2H_INIT_FILEPATH = '';

#this variable gives the length of the hash code.  If you switch to a different
#hash function, you will likely have to change this
my $HASH_CODE_LENGTH = 32;

#this hash table will contain the math strings, indexed by their hash code
my %hashed_math_strings = ();

#this hash table is used to differentiate between in-line and own-line equations
my %own_line_equation = ();

#the url to the attachment directory for this page
my $pubUrlPath;

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;
	
    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between MathModePlugin and Plugins.pm" );
        return 0;
    }

	#get the full path to the init file to be handed to latex2html
	#If the plugin is installed somewhere other than the default location,
	#you may need to change this
	$L2H_INIT_FILEPATH = &TWiki::Func::getPubDir() . '/' . &TWiki::Func::getTwikiWebname() . '/MathModePlugin/twiki_l2h.init';
	#get a fully qualified URL to the attachment directory for this page
	$pubUrlPath = &TWiki::Func::getUrlHost() . &TWiki::Func::getPubUrlPath() . "/$web/$topic";
    
	# Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "MATHMODEPLUGIN_DEBUG" );
		 
    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::MathModePlugin::initPlugin( $web.$topic ) is OK" ) if $debug;

    return 1;
}

# =========================
sub outsidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    # look for markup for math (the ? makes it not greedy)
	# three ways to markup, %$ ... $% which is similar to LaTeX inline math.
	# %\[ ... \]% and %MATHMODE{ ... }% which render the equation on its own line
	$_[0] =~ s/%\$(.*?)\$%/&handleMath($1,0)/gseo;
	$_[0] =~ s/%\\\[(.*?)\\\]%/&handleMath($1,1)/gseo;
	$_[0] =~ s/%MATHMODE{(.*?)}%/&handleMath($1,1)/gseo;
}

# =========================
sub handleMath
{
# This function takes a string of math, computes its hash code, and returns a
# link to what will be the image representing this math.
### my ( $math_string ) = @_;   # do not uncomment, use $_[0], $_[1] instead
	
	#compute the MD5 hash of this string
	my $hash_code = md5_hex( $_[0] );
	#store the string in a hash table, indexed by the MD5 hash
	$hashed_math_strings{$hash_code} = $_[0];
	
	#remove any quotes in the string, so the alt tag doesn't break
	my $escaped = $_[0];
	$escaped =~ s/\"/&quot;/gso;
	
	#return a link to an attached image, which we will create later
	if($_[1]) {
		$own_line_equation{$hash_code} = 1;
		return "<div align=\"center\"><img src=\"$pubUrlPath/$hash_code.$EXT\" alt=\"$escaped\" /></div>";
	} else {
		$own_line_equation{$hash_code} = 0;
		return "<img src=\"$pubUrlPath/$hash_code.$EXT\" alt=\"$escaped\" align=\"center\" />"; 
	}
}

	
# =========================
sub endRenderingHandler
{
# Here we check if we saw any math, try to delete old files, render new math, and clean up
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    &TWiki::Func::writeDebug( "- MathModePlugin::endRenderingHandler( $web.$topic )" ) if $debug;
	
	#my @revinfo = &TWiki::Func::getRevisionInfo($web, $topic, "", 0);
    #&TWiki::Func::writeDebug( "- MathModePlugin: @revinfo" ) if $debug;

	#check if there was any math in this document
	return unless scalar( keys( %hashed_math_strings ) );
	
	#get the full path of this topic's attachment directory
	my $path = &TWiki::Func::getPubDir() . "/$web/$topic";
	&TWiki::Func::writeDebug( "Path to attachment dir: $path" ) if $debug;
		
	#does the topic's attachment directory exist?
	if( -e $path ) {
		#if it's not really a directory, we can't do anything
		return unless ( -d $path );
		&TWiki::Func::writeDebug( "Directory already exists." ) if $debug;
	} else {
		#create the directory if it didn't exist
		return unless mkdir( $path );
		&TWiki::Func::writeDebug( "Made the directory successfully" ) if $debug;
	}
	#move into this page's attachment directory
	return unless chdir( $path );
	
	#get the name of the script that called us
	my $script = basename( $0 );
	#if this is a view script, then we will try to delete old files
	my $delete_files = ( $script =~ m/^view/ );

	#look for existing images, delete old ones
	foreach my $fn ( <*.$EXT> ) {
		&TWiki::Func::writeDebug( "Found an image: $fn" ) if $debug;
		#is the filename the same length as one of our images?
		if( length( $fn ) == $HASH_CODE_LENGTH + 1 + length( $EXT ) ) {
			my $copy = $fn;
			#is the filename composed of the same characters as ours?
			next unless ( $HASH_CODE_LENGTH == ( $copy =~ tr/0-9a-f//d ) );
			my $prefix = substr( $fn, 0, $HASH_CODE_LENGTH );
			#is the image still used in the document?
			if( exists( $hashed_math_strings{$prefix} ) ) {
				#if the image is already there, we don't need to re-render
				delete( $hashed_math_strings{$prefix} );
				next;
			}
			
			if( $delete_files ) {
				#delete the old image
				#pathologically, if there were an image in this directory with a long filename
				#that matches an MD5 hash code, we would delete it unintentionally.  Oh well
				&TWiki::Func::writeDebug( "Deleting old image that I think belongs to me: $fn" ) if $debug;
				#the glob returns tainted data, so we need to untaint using a special regexp (see the perlsec man page)
				if( $fn =~ /^([-\@\w.]+)$/ ) {
					$fn = $1; # $fn now untainted
					unlink( $fn );
				} else {
					&TWiki::Func::writeDebug( "How the hell did this happen? $fn" ) if $debug;
				}
			}
		}
	}
		
	#check if there are any new images to render
	return unless scalar( keys( %hashed_math_strings ) );
	
	#latex2html names its image img(n).png where (n) is an integer
	#we will rename these files, so need to know which math string gets with image
	my $image_number = 0;
	#this hash table maps math strings' hash codes to the filename latex2html generates
	my %hash_code_mapping = ();
	#create a latex file, consisting solely of math strings
	open( MATHOUT, ">$LATEXFILENAME" );
	print MATHOUT "\\documentclass{article}\n\\begin{document}\n";
	while( (my $key, my $value) = each( %hashed_math_strings ) ) {
		$image_number++;
		if($own_line_equation{$key}) {
			print MATHOUT "\\[ $value \\]\n";
		} else {
			print MATHOUT "\$$value\$\n";
		}
		$hash_code_mapping{$key} = "img$image_number.$EXT";
	}
	print MATHOUT "\\end{document}\n";
	close( MATHOUT );
	
	#run latex2html on the latex file we generated, using the init file and redirecting the output
	system( "latex2html -init_file $L2H_INIT_FILEPATH $LATEXFILENAME > /dev/null" );
	
	#rename the files to the hash code, so we can uniquely identify them
	while( (my $key, my $value) = each( %hash_code_mapping ) ) {
		&TWiki::Func::writeDebug( "Renaming $LATEXBASENAME/$value to $key.$EXT" ) if $debug;
		rename( "$LATEXBASENAME/$value", "$key.$EXT" );
	}

	#clean up by deleting all the extra stuff latex2html generates
	foreach my $fn ( <$LATEXBASENAME/*> ) {
		(my $unused, $fn) = split( /\//, $fn, 2 );
		#again, we need to untaint the globbed filenames
		if( $fn =~ /^([-\@\w.]+)$/ ) {
			$fn = $1; # $fn now untainted
			unlink( "$LATEXBASENAME/$fn" );
		} else {
			&TWiki::Func::writeDebug( "How the hell did this happen? $fn" ) if $debug;
		}
	}
	#remove the directory latex2html creates
	rmdir( $LATEXBASENAME );
	#delete the latex file we created
	unlink( $LATEXFILENAME );
	
	#clear the hash table of math strings
	%hashed_math_strings = ();
	%own_line_equation = ();
	&TWiki::Func::writeDebug( "Math strings reset, done." ) if $debug;
}

# =========================

1;
