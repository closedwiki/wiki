# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 Sven Dowideit SvenDowideit@wikiring.com
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

=pod

---+ package AntiWikiSpamPlugin

This is the AntiWikiSpam TWiki plugin. it uses the shared Anti-spam regex list to 
check topic text when saving, refusing to save if it finds a matche.

=cut

package TWiki::Plugins::AntiWikiSpamPlugin;

use Error qw(:try);
use strict;

use vars qw( $VERSION $RELEASE $pluginName $debug );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '1.1';

$pluginName = 'AntiWikiSpamPlugin';  # Name of this Plugin

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

not used for plugins specific functionality at present

=cut

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    #forceUpdate
    TWiki::Func::registerRESTHandler('forceUpdate', \&forceUpdate);

    # Plugin correctly initialized
    return 1;
}

=pod

---++ beforeSaveHandler($text, $topic, $web, $meta )
   * =$text= - text _with embedded meta-data tags_
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - the metadata of the topic being saved, represented by a TWiki::Meta object 

This handler is called just before the save action, checks 

__NOTE:__ meta-data is embedded in $text (using %META: tags)

=cut

sub beforeSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )" ) if $debug;

    #do localspamlist first
    my $regexWeb;
    my $regexTopic = TWiki::Func::getPluginPreferencesValue( 'LOCALANTISPAMREGEXLISTTOPIC' );
    ($regexWeb, $regexTopic) = TWiki::Func::normalizeWebTopicName('TWiki', $regexTopic);
    if (TWiki::Func::topicExists($regexWeb, $regexTopic) ) {
        if (($_[1] eq $regexTopic) && ($_[2] eq $regexWeb)) {
            return; #don't check the anti-spam topic
        }
        my ( $meta, $regexs) = TWiki::Func::readTopic($regexWeb, $regexTopic);
        checkTextUsingTopic($_[0], $regexs);
    }

    my $timesUp;
    my $topicExists = fileExists(${pluginName}.'_regexs');
    if ($topicExists) {
        my $getListTimeOut = TWiki::Func::getPluginPreferencesValue( 'GETLISTTIMEOUT' ) || 61;
        #has it been more than $getListTimeOut minutes since the last get?
        my $lastTimeWeCheckedForUpdate = readWorkFile(${pluginName}.'_timeOfLastCheck');
        #print STDERR "time > ($lastTimeWeCheckedForUpdate + ($getListTimeOut * 60))";
        $timesUp = time > ($lastTimeWeCheckedForUpdate + ($getListTimeOut * 60));
    }
    if ($timesUp || (!$topicExists)) {
        getSharedSpamData();
    }
    #use the share spam regexs
    my $regexs = readWorkFile(${pluginName}.'_regexs');
    checkTextUsingTopic($_[0], $regexs);
}

sub beforeAttachmentSaveHandler
{
    ### my ( $attachmentAttr, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    my $attachmentName = $_[0]->{"attachment"};
    my $tmpFilename    = $_[0]->{"tmpFilename"}
                      || $_[0]->{"file"};  # workaround for TWiki 4.0.2 bug
    my $text = TWiki::Func::readFile( $tmpFilename );

    #from BlackListPlugin
    # check for evil eval() spam in <script>
    if( $text =~ /<script.*?eval *\(.*?<\/script>/gis ) { #TODO: there's got to be a better way to do this.
        throw TWiki::OopsException( 'attention', def=>'attach_error',
            params => 'the attach has been rejected by the %TWIKIWEB%.'.
            ${pluginName}.' as it contains a possible javascript eval exploit');
    }

    beforeSaveHandler($text, $_[1], $_[2]);
}


sub checkTextUsingTopic {
my ($text, $regexs) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::checkTextUsingTopic( )" ) if $debug;

    #load text as a set of regex's, and eval
    foreach my $regexLine (split(/\n/, $regexs)) {
        $regexLine =~ /([^#]*)\s*#?/;
        my $regex = $1;
        $regex =~ s/^\s+//;
        $regex =~ s/\s+$//;
        if ($regex ne '') {
            if ( $_[0] =~ /$regex/i ) {
                TWiki::Func::writeWarning('MATCH]]'.$regex.'[[');
#TODO: make this a nicer error, or make its own template
                throw TWiki::OopsException( 'attention', def=>'save_error', 
                    params => 'the topic save has been rejected by the %TWIKIWEB%.'.
                    ${pluginName}.' as it matches content that may be WikiSpam ('.$regex.')');
            }
        }
    }
}


sub getSharedSpamData {
    TWiki::Func::writeDebug( "- ${pluginName}::getSharedSpamData( )" ) if $debug;

    my $getSharedSpamLock = readWorkFile(${pluginName}.'_lock');

    if ( $getSharedSpamLock eq '' ) {
        saveWorkFile(${pluginName}.'_lock', 'lock');
        my $listUrl = TWiki::Func::getPluginPreferencesValue( 'ANTISPAMREGEXLISTURL' );
        my $list = includeUrl($listUrl);
        if (defined ($list)) {
            saveWorkFile(${pluginName}.'_regexs', $list);
            saveWorkFile(${pluginName}.'_timeOfLastCheck', time);
        }
        saveWorkFile(${pluginName}.'_lock', '');
    }
}

=pod

---++ forceUpdate($session) -> $text

can be used to force an update of the spam list

%SCRIPTURL%/rest/AntiWikiSpamPlugin/forceUpdate

=cut

sub forceUpdate {
    TWiki::Func::writeDebug(${pluginName}.' about to forceUpdate') if $debug;
    getSharedSpamData();
    TWiki::Func::writeDebug(${pluginName}.' forceUpdate complete') if $debug;

   return ${pluginName}.' SharedSpamList forceUpdate complete ';
}

sub saveWorkFile($$) {
    my $fileName = shift;
    my $text = shift;

    my $workarea = TWiki::Func::getWorkArea($pluginName);
    TWiki::Func::saveFile($workarea.'/'.$fileName , $text);
}
sub readWorkFile($) {
    my $fileName = shift;

    my $workarea = TWiki::Func::getWorkArea($pluginName);
    return TWiki::Func::readFile($workarea.'/'.$fileName);
}
sub fileExists($) {
    my $fileName = shift;

    my $workarea = TWiki::Func::getWorkArea($pluginName);
    return (-e $workarea.'/'.$fileName);
}

#simplified version of INCLUDE, why we have policy mixed in with implementation is bejond me
sub includeUrl($) {
    my $theUrl = shift;
    my $text;

    my $host = '';
    my $port = 80;
    my $path = '';
    my $user = '';
    my $pass = '';

    if( $theUrl =~ /http\:\/\/(.+)\:(.+)\@([^\:]+)\:([0-9]+)(\/.*)/ ) {
        ( $user, $pass, $host, $port, $path ) = ( $1, $2, $3, $4, $5 );
    } elsif( $theUrl =~ /http\:\/\/(.+)\:(.+)\@([^\/]+)(\/.*)/ ) {
        ( $user, $pass, $host, $path ) = ( $1, $2, $3, $4 );
    } elsif( $theUrl =~ /http\:\/\/([^\:]+)\:([0-9]+)(\/.*)/ ) {
        ( $host, $port, $path ) = ( $1, $2, $3 );
    } elsif( $theUrl =~ /http\:\/\/([^\/]+)(\/.*)/ ) {
        ( $host, $path ) = ( $1, $2 );
    } else {
#        $text = TWiki::Plugins::SESSION->inlineAlert( 'alerts', 'bad_protocol', $theUrl );
        return $text;
    }

    try {
        $text = $TWiki::Plugins::SESSION->{net}->getUrl( $host, $port, $path, $user, $pass );
        $text =~ s/\r\n/\n/gs;
        $text =~ s/\r/\n/gs;
        $text =~ s/^(.*?\n)\n(.*)/$2/s;
        my $httpHeader = $1;
        my $contentType = '';
        if( $httpHeader =~ /content\-type\:\s*([^\n]*)/ois ) {
            $contentType = $1;
        }
        if( $contentType =~ /^text\/html/ ) {
            $path =~ s/[#?].*$//;
            $host = 'http://'.$host;
            if( $port != 80 ) {
                $host .= ":$port";
            }
#            $text = $TWiki::Plugins::SESSION->_cleanupIncludedHTML( $text, $host, $path, $disableremoveheaders, $disableremovescript, $disableremovebody, $disablecompresstags, $disablerewriteurls ) unless $theRaw;
        } elsif( $contentType =~ /^text\/(plain|css)/ ) {
            # do nothing
        } else {
            #bad content
        }
    } catch Error with {
    };
    
    return $text;
}

1;
