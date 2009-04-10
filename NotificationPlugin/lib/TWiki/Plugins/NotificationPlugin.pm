# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2008-2009 Peter Thoeny, peter@twiki.net
#               2008-2009 Sopan Shewale sopan.shewale@gmail.com
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

# =========================
package TWiki::Plugins::NotificationPlugin
  ;    # change the package name and $pluginName!!!

use TWiki::Func;
use TWiki::Plugins;
use TWiki::Store;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $sender @users $debug @sections
);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '03 Mar 2009';

$pluginName = 'NotificationPlugin';    # Name of this Plugin

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            "Version mismatch between $pluginName and Plugins.pm");
        return 0;
    }

    @users    = getUsers();
    @sections = (
        "(Topic) immediate notifications",
        "(Web) immediate notifications",
        "(Regex) immediate notifications",
        "(Topic) notifications",
        "(Web) notifications",
        "(Regex) notifications"
    );

    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG") || 0;
    $sender = TWiki::Func::getPreferencesValue("\U$pluginName\E_SENDER")
      || "TWiki NotificationPlugin";

    # Plugin correctly initialized
    TWiki::Func::writeDebug(
        "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    $_[0] =~ s/%NTF{(.*?)}%/&showNotifyButtons($1)/ge;
}

# =========================
sub beforeSaveHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug("- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )")
      if $debug;

# This handler is called by TWiki::Store::saveTopic just before the save action.
# New hook in TWiki::Plugins $VERSION = '1.010'

    my $wikiUser = TWiki::Func::userToWikiName( $user, 1 );
    my @notifyUsers = ();
    push( @notifyUsers, getUsersToNotify( $_[2], $_[1], 0 ) );
    push( @notifyUsers, getUsersToNotify( $_[2], $_[1], 1 ) );
    push( @notifyUsers, getUsersToNotify( $_[2], $_[1], 2 ) );

    my $subject = "Topic $_[2].$_[1] has been changed by $wikiUser.";
    my $body =
        "Topic "
      . TWiki::Func::getScriptUrl( $_[2], $_[1], "view" )
      . " has been changed by $wikiUser at "
      . TWiki::Func::formatTime( time() ) . " GMT";
    notifyUsers( \@notifyUsers, $subject, $body );
}

# =========================
# list of users who has defined/registered for alerts through NotifyPlugin
sub getUsers {
    my @result;
    my $mainweb = TWiki::Func::getMainWebname();
    my @topics  = TWiki::Func::getTopicList($mainweb);
    foreach my $name (@topics) {
        if ( $name =~ /^(.*?)NotifyList$/ ) {
            push @result, $1 if defined $1;
        }
    }
    return @result;
}

sub getUsersToNotify {
    my ( $tweb, $ttopic, $section ) = @_;
    my @result;

    #&TWiki::Func::writeDebug( "TYPE = $type" );

    foreach my $tmp (@users) {

        my $text = TWiki::Func::readTopic( &TWiki::Func::getMainWebname(),
            "$tmp" . "NotifyList" );
        my $test = "";
        foreach my $line ( split( /\n/, $text ) ) {
            $line =~ s/\s+$//;

            $test = "" if ( ( $test ne "" ) && ( $line !~ /^\s*\*/ ) );

            if ( $test eq "Topic" ) {
                $line =~ /\s*\*\s(.*?)\.(.*)/;
                if ( ( $tweb eq $1 ) && ( $ttopic eq $2 ) ) {
                    $result[ ++$#result ] = $tmp;
                    last;
                }
            }
            elsif ( $test eq "Web" ) {
                $line =~ /\s*\*\s(.*)/;
                if ( $tweb eq $1 ) {
                    $result[ ++$#result ] = $tmp;
                    last;
                }
            }
            elsif ( $test eq "Regex" ) {
                $line =~ /\s*\*\s(.*)/;
                if ( "$tweb.$ttopic" =~ /$1/ ) {
                    $result[ ++$#result ] = $tmp;
                    last;
                }
            }
            $test = $1 if ( $line =~ /$sections[$section]/ );
        }
    }
    return @result;
}

sub getNotificationsOfUser {
    my $who     = shift;
    my $section = shift;
    my $text    = shift || "";
    my $meta;

    ( $meta, $text ) = checkUserNotifyList($who) if ( $text eq "" );
    my @result;

    $test = "";
    foreach my $line ( split( /\n/, $text ) ) {

        while ( ( $line =~ /\n$/ ) || ( $line =~ /\r$/ ) ) {
            chop($line);
        }
        last if ( ( $test ne "" ) && ( $line !~ /^\s*\*/ ) );
        if ( $test eq "Topic" ) {
            $line =~ /\s*\*\s(.*?)\.(.*)/;

            $result[ ++$#result ] = "$1.$2";
        }
        elsif ( ( $test eq "Web" ) || ( $test eq "Regex" ) ) {
            $line =~ /\s*\*\s(.*)/;

            $result[ ++$#result ] = $1;
        }
        $test = $1 if ( $line =~ /$sections[$section]/ );
    }
    return @result;
}

sub notifyUsers {
    my ( $notifyUsers, $subject, $body ) = @_;

    foreach my $tmp ( @{$notifyUsers} ) {

        my $email .= "From: $sender\n";
        $email    .= "To: " . getUserEmail($tmp) . "\n";
        $email    .= "CC: \n";
        $email    .= "Subject: $subject\n\n";
        $email    .= "$body\n";

        #&TWiki::Func::writeDebug( "Sending mail to $tmp ..." );
        my $error = TWiki::Func::sendEmail($email);
        if ($error) {
            TWiki::Func::writeDebug("ERROR WHILE SENDING MAIL - $error");
        }
    }
}

sub getUserEmail {
    my $who    = shift;
    my @emails = TWiki::Func::wikiToEmail($who);
    return "" if ( $#emails < 0 );

    #&TWiki::Func::writeDebug( "USER: $user, EMAIL $emails[0]" );
    return $emails[0];
}

sub addItemToNotifyList {
    my $who     = shift;
    my $what    = shift;
    my $section = shift;
    my $meta    = shift || "";
    my $text    = shift || "";

    ( $meta, $text ) = checkUserNotifyList($who) if ( $text eq "" );
    return ( $meta, $text )
      if ( isItemInSection( $who, $what, $section, $text ) );
    my @items =
      TWiki::Plugins::NotificationPlugin::getNotificationsOfUser(
        $TWiki::wikiName, $section, $text );
    my $newText = "";
    my $tmp     = 0;
    foreach $line ( split( /\n/, $text ) ) {

        $tmp = 0 if ( $line =~ /^---\+\+\s/ && $tmp );
        $tmp = 1 if ( $line =~ /$sections[$section]/ );
        if ( $tmp == 0 ) {
            $newText .= "$line\n";
        }
        if ( $tmp == 1 ) {
            $newText .= "$line\n";
            foreach my $item (@items) {
                $newText .= "   * $item\n";
            }
            $newText .= "   * $what\n";
            $tmp = 2;
            next;
        }
    }
    return ( $meta, $newText );
}

sub removeItemFromNotifyList {
    my $who     = shift;
    my $what    = shift;
    my $section = shift;
    my $meta    = shift || "";
    my $text    = shift || "";

    ( $meta, $text ) = checkUserNotifyList($who) if ( $text eq "" );
    return ( $meta, $text )
      if ( !isItemInSection( $who, $what, $section, $text ) );
    my @items =
      TWiki::Plugins::NotificationPlugin::getNotificationsOfUser(
        $TWiki::wikiName, $section, $text );
    my $newText = "";
    my $tmp     = 0;
    foreach $line ( split( /\n/, $text ) ) {
        $tmp = 0 if ( $line =~ /^---\+\+\s/ && $tmp );
        $tmp = 1 if ( $line =~ /$sections[$section]/ );
        if ( $tmp == 0 ) {
            $newText .= "$line\n";
        }
        if ( $tmp == 1 ) {
            $newText .= "$line\n";
            foreach my $item (@items) {

                $newText .= "   * $item\n" if ( $item ne $what );
            }
            $tmp = 2;
            next;
        }
    }
    return ( $meta, $newText );
}

sub checkUserNotifyList {
    my $who = shift;
    my $tmpText;
    my $tmpMeta;
    if ( !TWiki::Func::topicExists( "Main", $who . "NotifyList" ) ) {
        ( $tmpMeta, $tmpText ) =
          TWiki::Func::readTopic( "Main", "NotificationPluginListTemplate" );

        $tmpMeta->put( "TOPICPARENT", { 'name' => $who } );
        saveUserNotifyList( $who, $tmpMeta, $tmpText );
    }
    else {
        ( $tmpMeta, $tmpText ) =
          TWiki::Func::readTopic( "Main", $who . "NotifyList" );
    }
    return ( $tmpMeta, $tmpText );
}

sub saveUserNotifyList {
    my ( $who, $meta, $text ) = @_;
    TWiki::Func::writeDebug(
        "NTF:saveUserNotifyList: Saving Main." . $who . "NotifyList topic..." );
    $text =~ s/   /\t/g;
    my $repRev = "repRev";
    $repRev = ""
      if ( !TWiki::Func::topicExists( "Main", $who . "NotifyList" ) );
    my $error =
      TWiki::Func::saveTopic( "Main", $who . "NotifyList", $meta, $text, {} );
    if ($error) {
        my $url =
          TWiki::Func::getOopsUrl( $web, $topic, "oopssaveerr", $error );
        TWiki::Func::redirectCgiQuery( $query, $url );
    }
}

sub isItemInSection {
    my $who     = shift;
    my $what    = shift;
    my $section = shift;
    my $text    = shift || "";
    my $meta;
    ( $meta, $text ) = checkUserNotifyList($who) if ( $text eq "" );
    my @items = getNotificationsOfUser( $who, $section, $text );
    return 1 if ( grep( /$what/, @items ) );
    return 0;
}

sub showNotifyButtons {
    my $attrsstring = shift;
    my ( $tin, $win, $tn, $wn, $popup ) = ( "on", "on", "on", "on", "on" );
    my ( $tinOn, $winOn, $tnOn, $wnOn ) = ( "on", "on", "on", "on" );
    my $opt = "";
    my %tmp = ( "on" => "OFF", "off" => "ON" );

    my %attrs = TWiki::Func::extractParameters($attrsstring);

    $tin   = $attrs{'tin'}   if defined $attrs{'tin'};
    $win   = $attrs{'win'}   if defined $attrs{'win'};
    $tn    = $attrs{'tn'}    if defined $attrs{'tn'};
    $wn    = $attrs{'wn'}    if defined $attrs{'wn'};
    $popup = $attrs{'popup'} if defined $attrs{'popup'};
    $opt   = $attrs{'opt'}   if defined $attrs{'opt'};
    my $text = "";

    my $wikiName = TWiki::Func::getWikiName();

    if ( $wikiName ne "TWikiGuest" ) {
        $tinOn = "off" if ( !isItemInSection( $wikiName, "$web.$topic", 0 ) );
        $winOn = "off" if ( !isItemInSection( $wikiName, "$web",        1 ) );
        $tnOn  = "off" if ( !isItemInSection( $wikiName, "$web.$topic", 3 ) );
        $wnOn  = "off" if ( !isItemInSection( $wikiName, "$web",        4 ) );
        $text .=
            "<input onClick='javascript:window.open(\""
          . TWiki::Func::getScriptUrl( $web, $topic, "changenotify" )
          . "?popup=on\");' type='button' value='Popup'>&nbsp;"
          if ( $popup eq "on" );
        $text .=
            "<input onClick='javascript:location.href(\""
          . TWiki::Func::getScriptUrl( $web, $topic, "changenotify" )
          . "?what=TIN&action=$tmp{$tinOn}&$opt\");' type='button' value='TIN $tinOn' title='Topic immediate notifications! Click to set it $tmp{$tinOn}!'>&nbsp;"
          if ( $tin eq "on" );
        $text .=
            "<input onClick='javascript:location.href(\""
          . TWiki::Func::getScriptUrl( $web, $topic, "changenotify" )
          . "?what=WIN&action=$tmp{$winOn}&$opt\");' type='button' value='WIN $winOn' title='Web immediate notifications! Click to set it $tmp{$winOn}!'>&nbsp;"
          if ( $win eq "on" );
        $text .=
            "<input onClick='javascript:location.href(\""
          . TWiki::Func::getScriptUrl( $web, $topic, "changenotify" )
          . "?what=TN&action=$tmp{$tnOn}&$opt\");' type='button' value='TN $tnOn' title='Topic notifications! Click to set it $tmp{$tnOn}!'>&nbsp;"
          if ( $tn eq "on" );
        $text .=
            "<input onClick='javascript:location.href(\""
          . TWiki::Func::getScriptUrl( $web, $topic, "changenotify" )
          . "?what=WN&action=$tmp{$wnOn}&$opt\");' type='button' value='WN $wnOn' title='Web notifications! Click to set it $tmp{$wnOn}!'>&nbsp;"
          if ( $wn eq "on" );
    }

    return $text;
}

1;
