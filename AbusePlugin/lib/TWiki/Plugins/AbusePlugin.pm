# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
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
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see TWiki.TWikiPlugins for details.
#
# Each plugin is a package that may contain these functions:        VERSION:
#
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   initializeUserHandler   ( $loginName, $url, $pathInfo )         1.010
#   registrationHandler     ( $web, $wikiName, $loginName )         1.010
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#   startRenderingHandler   ( $text, $web )                         1.000
#   outsidePREHandler       ( $text )                               1.000
#   insidePREHandler        ( $text )                               1.000
#   endRenderingHandler     ( $text )                               1.000
#   beforeEditHandler       ( $text, $topic, $web )                 1.010
#   afterEditHandler        ( $text, $topic, $web )                 1.010
#   beforeSaveHandler       ( $text, $topic, $web )                 1.010
#   writeHeaderHandler      ( $query )                              1.010  Use only in one Plugin
#   redirectCgiQueryHandler ( $query, $url )                        1.010  Use only in one Plugin
#   getSessionValueHandler  ( $key )                                1.010  Use only in one Plugin
#   setSessionValueHandler  ( $key, $value )                        1.010  Use only in one Plugin
#
# initPlugin is required, all other are optional. 
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name. Remove disabled handlers you do not need.
#
# NOTE: To interact with TWiki use the official TWiki functions 
# in the TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::AbusePlugin;    # change the package name and $pluginName!!!

# =========================
#This is plugin specific variable
use vars qw(
        $web $topic $user $installWeb $VERSION $debug $abusefilelocation

    );

$VERSION = '1.000';
$debug = 1;

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between AbusePlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $abusefilelocation = &TWiki::Func::getPreferencesFlag( "ABUSEFILE_LOCATION" );
 
    &TWiki::Func::writeDebug( " Abuse File location is $abusefilelocation" ) if $debug;
   	
    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins:AbusePlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
    # Let's read the words from the file in a loop ,
    # look for these words present in the pattern and replace these then with their counter parts.	

    $line = $_[0];
    if( !open( SOURCE , "/home/students/mtech03/rahulm/web/twiki/lib/TWiki/Plugins/master.txt"))
    {
	 &TWiki::Func::writeDebug( "Can't open master.txt file");

    }
    while( $line1 = <SOURCE>)
    {
	&TWiki::Func::writeDebug( "The abuse word is $line1");
	#&TWiki::Func::writeDebug( "The page data is $line");
	#$line1 = <SOURCE>;
	#if( !$line1 eq "")
	#{
		#if( $line =~ m/$line1/g )
		#{
			chomp($line1);
		 	&TWiki::Func::writeDebug( "The abuse word is $line1");
		 	&TWiki::Func::writeDebug( "The page data is $line");
			# We had found the abused word
			#$_[0] =~s/$line1/"Found offensive word"/img;
			$_[0] =~ s/$line1/_handleTag($line1) /imge
		 	&TWiki::Func::writeDebug( "New page data is $line");
		#}   
	#}
    }	
    close(SOURCE);
}
#-------------------------------------------------------------------------------------------------
sub _handleTag( )
{
	my($str) = @_;


	$str1 =	substr($str,0,1);
	for ( $i =1 ; $i< length($str); $i++)
	{
		$str1 = $str1 . "*";
	}
	return $str1;
	#return "word";
}

1;
