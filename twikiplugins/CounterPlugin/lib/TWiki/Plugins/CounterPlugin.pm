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
package TWiki::Plugins::CounterPlugin;    # change the package name and $pluginName!!!

# =========================
#This is plugin specific variable
use vars qw(
        $web $topic $user $installWeb $VERSION $debug 
    );

$VERSION = '1.000';
$debug = 1;

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between CounterPlugin and Plugins.pm" );
        return 0;
    }
   	
    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins:CounterPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
    # Let's read the words from the file in a loop ,
    # look for these words present in the pattern and replace these then with their counter parts.	

    $_[0] =~ s/%COUNTER_PLUGIN%/_handleTag( )/geo;	

}
#-------------------------------------------------------------------------------------------------
sub _handleTag()
{
	# increment the counter and throw up the page with this count
	$FileLocation = &TWiki::Func::getPreferencesFlag("COUNTERPLUGIN_COUNTER_FILE_PATH");
    	&TWiki::Func::writeDebug( "- TWiki::Plugins:CounterPlugin::Filelocation is $FileLocation" );
	
	if(!open(FILE , "< /home/students/mtech03/rahulm/web/twiki/lib/TWiki/Plugins/datacount.txt"))
	{
		# File doesnot exist
		$Count = 0;
 		#die "Can't open datacount.txt file";
	}


	&TWiki::Func::writeDebug("Opened Datacount.txt file successfully");
	$Count = <FILE>;
	$str = " <HTML>  <H1> Visitor Count is " . $Count . " </H1> </HTML>";
	close(FILE);
	
	open(FILE , "> /home/students/mtech03/rahulm/web/twiki/lib/TWiki/Plugins/datacount.txt") || die "Can't open datacount.txt file";
	#sysopen(FILE , "/home/students/mtech03/rahulm/web/twiki/lib/TWiki/Plugins/datacount.txt" , "O_WRONLY" , "0777" ) || die "Can't open datacount.txt file";
	$Count = $Count + 1;
	print FILE $Count;
	close(FILE);
	
	return $str;
}

1;
