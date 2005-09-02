# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 Sven Dowideit SvenDowideit@home.org.au
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

use vars qw( $VERSION $pluginName $debug );

$VERSION = '0.100';
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

__Since:__ TWiki::Plugins::VERSION = '1.010'

=cut

sub beforeSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )" ) if $debug;
    
    #do localspamlist first
    my $regexWeb;
    my $regexTopic = TWiki::Func::getPluginPreferencesValue( 'LOCALANTISPAMREGEXLISTTOPIC' );
    ($regexWeb, $regexTopic) = TWiki::Func::normalizeWebTopicName('TWiki', $regexTopic);

    if (($_[1] eq $regexTopic) && ($_[2] eq $regexWeb)) {
        return; #don't check the anti-spam topics
    }

    if (TWiki::Func::topicExists($regexWeb, $regexTopic) ) {
        checkTextUsingTopic($_[0], $regexWeb, $regexTopic);
    }

    #check the global spamlist
    $regexTopic = TWiki::Func::getPluginPreferencesValue( 'ANTISPAMREGEXLISTTOPIC' );
    ($regexWeb, $regexTopic) = TWiki::Func::normalizeWebTopicName('TWiki', $regexTopic);

    if (($_[1] eq $regexTopic) && ($_[2] eq $regexWeb)) {
        return; #don't check the anti-spam topics
    }

    my $topicExists = TWiki::Func::topicExists($regexWeb, $regexTopic);
    my $timesUp;
    if ($topicExists) {
        my $getListTimeOut = TWiki::Func::getPluginPreferencesValue( 'GETLISTTIMEOUT' );
        #has it been more than $getListTimeOut minutes since the last get?
        my $lastTimeWeCheckedForUpdate = $TWiki::Plugins::SESSION->{store}->readMetaData('', ${pluginName}.'_timeOfLastCheck');
        $timesUp = time > $lastTimeWeCheckedForUpdate + ($getListTimeOut * 60);
    }
    if ($timesUp || (!$topicExists)) {
        getSharedSpamData($regexWeb, $regexTopic);
    }
    if ( TWiki::Func::topicExists($regexWeb, $regexTopic) ) {
        checkTextUsingTopic($_[0], $regexWeb, $regexTopic);
    } 
}

sub getSharedSpamData {
    my ($regexWeb, $regexTopic) = @_;
    
    TWiki::Func::writeDebug( "- ${pluginName}::getSharedSpamData( $regexWeb, $regexTopic )" ) if $debug;
    
    my $getSharedSpamLock = $TWiki::Plugins::SESSION->{store}->readMetaData('', ${pluginName}.'_lock');

    if ( $getSharedSpamLock eq ''  && (!$alreadyDownloading) ) {
        $TWiki::Plugins::SESSION->{store}->saveMetaData('', ${pluginName}.'_lock', 'lock');
        my $listUrl = TWiki::Func::getPluginPreferencesValue( 'ANTISPAMREGEXLISTURL' );
        my $list = $TWiki::Plugins::SESSION->_includeUrl($listUrl);
        TWiki::Func::saveTopicText($regexWeb, $regexTopic, $list, 1, 1);
        $TWiki::Plugins::SESSION->{store}->saveMetaData('', ${pluginName}.'_timeOfLastCheck', time);
        $TWiki::Plugins::SESSION->{store}->saveMetaData('', ${pluginName}.'_lock', '');
    }
}

sub checkTextUsingTopic {
my ($text, $regexWeb, $regexTopic) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::checkTextUsingTopic( $regexWeb, $regexTopic )" ) if $debug;

    my ( $meta, $regexs) = TWiki::Func::readTopic($regexWeb, $regexTopic);
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
                    params => 'the topic save has been rejected by the '.
                    ${pluginName}.' as it matches content that may be WikiSpam ('.$regex.')');
            }
        }
    }
}

=pod

---++ forceUpdate($session) -> $text

can be used to force an update of the spam list

%SCRIPTURL%/rest/AntiWikiSpamPlugin/forceUpdate

=cut

sub forceUpdate {

    TWiki::Func::writeDebug(${pluginName}.' about to forceUpdate') if $debug;

    my $regexWeb;
    my $regexTopic = TWiki::Func::getPluginPreferencesValue( 'ANTISPAMREGEXLISTTOPIC' );
    ($regexWeb, $regexTopic) = TWiki::Func::normalizeWebTopicName('TWiki', $regexTopic);
    getSharedSpamData($regexWeb, $regexTopic);

    TWiki::Func::writeDebug(${pluginName}.' forceUpdate complete') if $debug;

   return ${pluginName}.' SharedSpamList forceUpdate complete ('.$regexWeb.'.'.$regexTopic.')';
}

1;
