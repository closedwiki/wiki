# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 TWiki:Main.AshishNaval
# Copyright (C) 2008-2011 TWiki:TWiki.TWikiContributor
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

# =========================
package TWiki::Plugins::GoogleSearchPlugin;    

# =========================
#This is plugin specific variable
use vars qw(
              $web $topic $user $installWeb $VERSION $RELEASE $debug $name
             );

$VERSION = '$Rev$';
$RELEASE = '2011-03-15';

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between GooglePlugin and Plugins.pm" );
        return 0;
    }
 
    #Getting the value of debug variable from the plugin configuration topic.
    $debug = TWiki::Func::getPreferencesFlag("GOOGLESEARCHPLUGIN_DEBUG");

    #Writing to debug.txt if debug variable is set to 1
    TWiki::Func::writeDebug( "- TWiki::Plugins:GoogleSearchPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;

    return 1;
}

# =========================
sub commonTagsHandler {
    #regular expressions to replace the plugin call with the output of the corresponding functions.
    $_[0] =~ s/%GOOGLE_SEARCH%/_handleTopic(  )/geo;
    $_[0] =~ s/%GOOGLE_SEARCH{(.*?)}%/_handleKeyword( $1) /geo
}

# =========================
sub _handleTopic( ) {
    #Following line extract the name of the topic
    #$topic = $TWiki::topicName;
          
    $query =$topic;
    #Following code find parts of topic name to give them to google search 
    $query =~ s/([A-Z])/+$1/g; 
    $query =~ s/^\+//;
    $name=$query;
    $name=~ s/\+/ /g;
    #Followin line of code displays link on the page to Google Search
    return "<a href=\"http://www.google.com/search?q=$query\" target=\"_blank\">Search for $name </a>";
}

# =========================
sub _handleKeyword( ) {
    my ( $attributes ) = @_;
    
    #Extraxct value of topic specified
    $topic = scalar &TWiki::Func::extractNameValuePair( $attributes, "topic" ) ;
    $query =$topic;

    #Following code find parts of topic name to give them to google search 
    $query =~ s/([A-Z])/+$1/g; 
    $query =~ s/^\+//;
    $name=$query;
    $name=~ s/\+/ /g;

    #Followin line of code displays link on the page to Google Search
    return "<a href=\"http://www.google.com/search?q=$query\" target=\"_blank\">Search for $name </a>";
}
	
# =========================
1;
