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
package TWiki::Plugins::NotificationPlugin;    # change the package name and $pluginName!!!

use TWiki::Store;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName
        $sender @users $debug @sections
	%paramDefaults $peopleWeb
    );

$VERSION = '1.14';
$pluginName = 'NotificationPlugin';  # Name of this Plugin

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    $peopleWeb = 'People'; #TWiki::Func::getMainWebname();
    @users = getUsers();
    @sections = (
      "(Topic) immediate notifications",
      "(Web) immediate notifications",
      "(Regex) immediate notifications",
      "(Topic) notifications",
      "(Web) notifications",
      "(Regex) notifications"
    );

    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" ) || 0;
    $sender = TWiki::Func::expandCommonVariables( TWiki::Func::getPreferencesValue( "\U$pluginName\E_SENDER" ),
						  $topic, $web ) || "TWiki NotificationPlugin";

    %paramDefaults = (
		      popup       => 'on',
		      style       => TWiki::Func::getPreferencesValue( "\U$pluginName\E_NTFSTYLE" ) || "buttons",
		      buttonsep   => TWiki::Func::getPreferencesValue( "\U$pluginName\E_BUTTONSEP" ) || "&nbsp;",
		      labelstyle  => 'default',
		      value	  => 'text',
		      border      => 1,
		      cellspacing => 0,
		      cellpadding => 1,
		      align       => 'center',
		      optional	  => '' # what's this for?
		     );

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

sub commonTagsHandler
  {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

  TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )"
 ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # do custom extension rule, like for example:
    $_[0] =~ s/%NTF{(.*?)}%/&showNotifyButtons($1,$_[1],$_[2])/ge;
}

# =========================
sub beforeSaveHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

  TWiki::Func::writeDebug( "- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )" ) if $debug;

  # This handler is called by TWiki::Store::saveTopic just before the save action.
  # New hook in TWiki::Plugins $VERSION = '1.010'

  my $wikiUser = &TWiki::userToWikiName( $user, 1 );
  my @notifyUsers = ();
  push( @notifyUsers, getUsersToNotify( $_[2], $_[1], 0 ) );
  push( @notifyUsers, getUsersToNotify( $_[2], $_[1], 1 ) );
  push( @notifyUsers, getUsersToNotify( $_[2], $_[1], 2 ) );
#  &TWiki::Func::writeDebug( "COUNT = $#notifyUsers" );
  my $subject = "Topic $_[2].$_[1] has been changed by $wikiUser.";
  my $body = "Topic ".&TWiki::getViewUrl( $_[2], $_[1] )." has been changed by $wikiUser at " . TWiki::Func::formatTime( time(), '', "gmtime" ) . " GMT";
  notifyUsers( \@notifyUsers, $subject, $body );
}

# =========================
sub getUsers {
  my @result;
  #&TWiki::Func::writeDebug( &TWiki::Func::getDataDir()."/".$peopleWeb );
  if ( opendir( DIR, &TWiki::Func::getDataDir()."/".$peopleWeb ) ) {
    my @topics = grep( /NotifyList.*txt$/, readdir( DIR ) );
    foreach my $name ( @topics ) {
      $name =~ /^(.*?)NotifyList/;
      #&TWiki::Func::writeDebug( "NAME = $1" );
      $result[++$#result] = $1 if ( $1 ne "" ); 
    }
    closedir( DIR );
  }
  #&TWiki::Func::writeDebug( "USERS = $#result" );
  return @result;
}

sub getUsersToNotify {
  my ( $tweb, $ttopic, $section ) = @_;
  my @result;
  #&TWiki::Func::writeDebug( "TYPE = $type" );
  foreach my $tmp ( @users ) {
    #&TWiki::Func::writeDebug( "TMP = $tmp" );
    my $text = &TWiki::Store::readTopic( $peopleWeb, "$tmp"."NotifyList" );
    my $test = "";
    foreach my $line ( split( /\n/, $text ) ) {
      $line =~ s/\s+$//;
      #&TWiki::Func::writeDebug( "LINE = $line" );
      #&TWiki::Func::writeDebug( "TEST = $test" );
      $test = "" if ( ( $test ne "" ) && ( $line !~ /^\s*\*/ ) );
      #&TWiki::Func::writeDebug( "TEST = $test" );
      if ( $test eq "Topic" ) {
        $line =~ /\s*\*\s(.*?)\.(.*)/;
        if ( ( $tweb eq $1 ) && ( $ttopic eq $2 ) ) {
          $result[++$#result] = $tmp;
          last;
        }
      } elsif ( $test eq "Web" ) {
        $line =~ /\s*\*\s(.*)/;
        if ( $tweb eq $1 ) {
          $result[++$#result] = $tmp;
          last;
        }
      } elsif ( $test eq "Regex" ) {
        $line =~ /\s*\*\s(.*)/;
	my $pat = eval{ qr($1) };
	next if $@;
        if ( "$tweb.$ttopic" =~ /$pat/ ) {
          $result[++$#result] = $tmp;
          last;
      }
      }
      $test = $1 if ( $line =~ /$sections[$section]/ );
    }
  }  
  return @result;
}

sub getNotificationsOfUser {
  my $who = shift;
  my $section = shift;
  my $text = shift || "";
  my $meta;
  #&TWiki::Func::writeDebug( "NTF:getNotificationsOfUser: WHO = $who, SCT = $section, TXT = ".length( $text ) );
  ( $meta, $text ) = checkUserNotifyList( $who ) if ( $text eq "" );
  my @result;
  #&TWiki::Func::writeDebug( "USER = $tuser" );
  $test = "";
  foreach my $line ( split( /\n/, $text ) ) {
      #&TWiki::Func::writeDebug( "LINE = $line" );
    while ( ( $line =~ /\n$/ ) || ( $line =~ /\r$/ ) ) {
      chop( $line );
    }
    last if ( ( $test ne "" ) && ( $line !~ /^\s*\*/ ) );
    if ( $test eq "Topic" ) {
        $line =~ /\s*\*\s(.*?)\.(.*)/;
        #&TWiki::Func::writeDebug( "TOPIC = $1.$2" );
        $result[++$#result] = "$1.$2";
    } elsif ( ( $test eq "Web" ) || ( $test eq "Regex" ) ) {
      $line =~ /\s*\*\s(.*)/;
      #&TWiki::Func::writeDebug( "RESULT = $1" );
      $result[++$#result] = $1;
      }
    $test = $1 if ( $line =~ /$sections[$section]/ );
  }
  return @result;
}

sub notifyUsers {
  my ( $notifyUsers, $subject, $body ) = @_;
  #&TWiki::Func::writeDebug( "NT = $notifyUsers" );
  foreach my $tmp ( @{$notifyUsers} ) {
    &TWiki::Func::writeDebug( "MAIL SENT TO $tmp ..." );
    #my $email = "Date: ".&TWiki::handleTime("","gmtime")."\n";
    my $email .= "From: $sender\n";
    $email .= "To: ".getUserEmail( $tmp )."\n";
    $email .= "CC: \n";
    $email .= "Subject: $subject\n\n";
    $email .= "$body\n";
    #&TWiki::Func::writeDebug( "Sending mail to $tmp ..." );
    my $error = &TWiki::Net::sendEmail( $email );
    if ( $error ) {
      &TWiki::Func::writeDebug( "ERROR WHILE SENDING MAIL - $error" );
    }
  }  
}

sub getUserEmail {
  my $who = shift;
  my @emails = &TWiki::getEmailOfUser( $who );
  return "" if ( $#emails < 0 );
  #&TWiki::Func::writeDebug( "USER: $user, EMAIL $emails[0]" );
  return $emails[0];
}

sub addItemToNotifyList {
  my $who = shift;
  my $what = shift;
  my $section = shift;
  my $meta = shift || "";
  my $text = shift || "";
  #&TWiki::Func::writeDebug( "NTF:addItemToNotifyList: adding '$what' to section $sections[$section]" );
  ( $meta, $text ) = checkUserNotifyList( $who ) if ( $text eq "" );
  return ( $meta, $text ) if ( isItemInSection( $who, $what, $section, $text ) );
  my @items = &TWiki::Plugins::NotificationPlugin::getNotificationsOfUser( $TWiki::wikiName, $section, $text );
  my $newText = "";
  my $tmp = 0;
  foreach $line ( split( /\n/, $text ) ) {
    #&TWiki::Func::writeDebug( "LINE = $line" );
    $tmp = 0 if ( $line =~ /^---\+\+\s/ && $tmp );
    $tmp = 1 if ( $line =~ /$sections[$section]/ );
    if ( $tmp == 0 ) {
      $newText .= "$line\n";
    }
    if ( $tmp == 1 ) {
      $newText .= "$line\n";
      foreach my $item ( @items ) {
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
  my $who = shift;
  my $what = shift;
  my $section = shift;
  my $meta = shift || "";
  my $text = shift || "";
  #&TWiki::Func::writeDebug( "NTF:removeItemFromNotifyList: removing '$what' from section $sections[$section]" );
  ( $meta, $text ) = checkUserNotifyList( $who ) if ( $text eq "" );
  return ( $meta, $text ) if ( !isItemInSection( $who, $what, $section, $text ) );
  my @items = &TWiki::Plugins::NotificationPlugin::getNotificationsOfUser( $TWiki::wikiName, $section, $text );
  my $newText = "";
  my $tmp = 0;
  foreach $line ( split( /\n/, $text ) ) {
    $tmp = 0 if ( $line =~ /^---\+\+\s/ && $tmp );
    $tmp = 1 if ( $line =~ /$sections[$section]/ );
    if ( $tmp == 0 ) {
      $newText .= "$line\n";
    }
    if ( $tmp == 1 ) {
      $newText .= "$line\n";
      foreach my $item ( @items ) {
        #&TWiki::Func::writeDebug( "ITEM = ^$item^" );
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
  #&TWiki::Func::writeDebug( "NTF:checkUserNotifyList: WHO = $who" );
  if ( !&TWiki::Store::topicExists( $peopleWeb, $who."NotifyList" ) ) {
    &TWiki::Func::writeDebug( "TEST1" );
    ( $tmpMeta, $tmpText ) = &TWiki::Store::readTopic( $peopleWeb, "NotificationPluginListTemplate" );
    $tmpMeta->put( "TOPICPARENT", ( "name" => $who ) );
    saveUserNotifyList( $who, $tmpMeta, $tmpText );
  } else {
    ( $tmpMeta, $tmpText ) = &TWiki::Store::readTopic( $peopleWeb, $who."NotifyList" );
  }
  return ( $tmpMeta, $tmpText );
}

sub saveUserNotifyList {
  my ( $who, $meta, $text ) = @_;
  #&TWiki::Func::writeDebug( "NTF:saveUserNotifyList: Saving $peopleWeb.".$who."NotifyList topic..." );
  $text =~ s/   /\t/g;
  my $repRev = "repRev";
  $repRev = "" if ( !&TWiki::Store::topicExists( $peopleWeb, $who."NotifyList" ) );
  my $error = &TWiki::Store::saveTopic( $peopleWeb, $who."NotifyList", $text, $meta, $repRev, "checked", "checked" );
  if ( $error ) {
    my $url = &TWiki::getOopsUrl( $web, $topic, "oopssaveerr", $error );
    &TWiki::redirect( $query, $url );
  }    
}

sub isItemInSection {
  my $who = shift;
  my $what = shift;
  my $section = shift;
  my $text = shift || "";
  #&TWiki::Func::writeDebug( "NTF:isItemInSection: WHO = $who, WHT = $what, SCT = $section, TXT = ".length( $text ) );
  my $meta;
  ( $meta, $text ) = checkUserNotifyList( $who ) if ( $text eq "" );
  my @items = getNotificationsOfUser( $who, $section, $text );
  return 1 if ( grep( /$what/, @items ) );
  return 0;
}

sub showNotifyButtons {
### my( $attr, $topic, $web ) = @_;     # do not uncomment, use $_[0], $_[1]... instead

  return ""  if $TWiki::wikiName eq "TWikiGuest";

  my %param = TWiki::Func::extractParameters( $_[0] );

  foreach ( keys %paramDefaults )
  {
    $param{$_} = $paramDefaults{$_}
      unless defined $param{$_};
  }

  my %flip = ( on => "OFF", off => "ON" );
  my %icon = ( on  => '<img src="%PUBURL%/%TWIKIWEB%/TWikiDocGraphics/choice-yes.gif">',
	       off => '<img src="%PUBURL%/%TWIKIWEB%/TWikiDocGraphics/choice-no.gif">',
	     );


  my @ufields = qw/ TIN WIN TN WN /;
  my @fields  = qw/ tin win tn wn /;

  my %attrs;

  $attrs{uc($_)}{req} = $param{$_} || 'on' foreach @fields;

  $attrs{TIN}{state} = isItemInSection( $TWiki::wikiName, "$web.$topic", 0 ) ? 'on' : 'off';
  $attrs{WIN}{state} = isItemInSection( $TWiki::wikiName, "$web",        1 ) ? 'on' : 'off';
  $attrs{TN}{state}  = isItemInSection( $TWiki::wikiName, "$web.$topic", 3 ) ? 'on' : 'off';
  $attrs{WN}{state}  = isItemInSection( $TWiki::wikiName, "$web",        4 ) ? 'on' : 'off';

  $attrs{T}{label} = "Topic";
  $attrs{W}{label} = "Web";
  $attrs{TIN}{label} = "Topic immediate";
  $attrs{WIN}{label} = "Web immediate";
  $attrs{TN}{label}  = "Topic";
  $attrs{WN}{label}  = "Web";

  if ( $param{labelstyle} eq 'short' )
  {
    $attrs{$_}{label} = $_ foreach  @ufields;
  }

  if ( $param{value} eq 'text' )
  {
    $attrs{$_}{value} = $attrs{$_}{state} foreach @ufields;
  }

  else
  {
    $attrs{$_}{value} = $icon{$attrs{$_}{state}} foreach @ufields;
  }


  my $tableattr = join(' ', map { "$_ = '$param{$_}'" } qw/ border cellspacing cellpadding align / );

  my $changeURL = &TWiki::getScriptUrl( $web, $topic, "changenotify" );

  my $text = "";

  if ( $param{style} eq 'buttons' ) {
    my @text;

    push @text,
      "<input onClick='javascript:window.open(\"$changeURL?popup=on\");' type='button' value='Popup'>"
	if ( $param{popup} eq "on" );

    for my $what ( qw/ TIN WIN TN WN / )
    {
      next unless $attrs{$what}{req} eq 'on';

      push @text, sprintf("<input onClick='javascript:location.href='%s?what=%s&action=%s&%s;' type='button' value='%s %s' title='%s notification: Click to set it !'>",
			  $changeURL, $what, $flip{$attrs{$what}{state}}, $param{optional}, $what, 
			  $attrs{$what}{value}, $attrs{$what}{label}, $flip{$attrs{$what}{state}} );
    }

    $text = join( $param{buttonsep}, @text );
  }

  elsif ( $param{style} eq 'twikitable' ) {

    $text = "| *Notification* | *State* |\n";
    for my $what ( qw/ TIN WIN TN WN / )
    {
      next unless $attrs{$what}{req} eq 'on';

      $text .= sprintf("| *%s* | [[%s?what=%s&action=%s&%s'][%s]] |\n",
			  $attrs{$what}{label}, $changeURL, $what, $flip{$attrs{$what}{state}}, $param{optional}, $attrs{$what}{value} );
    }
    $text = TWiki::Func::renderText($text, $_[2] );
  }

  elsif ( $param{style} eq 'twikitable2' ) {

    $text = "|  | *IN* | *N* |\n";
    for my $what ( qw/ T W / )
    {
      $text .= "| *$attrs{$what}{label}* | ";

      for my $where ( qw/ IN N / )
      {
	my $ww = $what . $where;
	$text .= sprintf("[[%s?what=%s&action=%s&%s][%s]] |",
			 $changeURL, $ww, $flip{$attrs{$ww}{state}}, $param{optional}, $attrs{$ww}{value} );
      }
      $text .= "\n";
    }
  }

  elsif ( $param{style} eq 'table' ) {

    $text = "<table $tableattr>";

    for my $what ( qw/ TIN WIN TN WN / )
    {
      next unless $attrs{$what}{req} eq 'on';

      $text .= sprintf("<tr><td><strong>%s</strong></td><td><a href='%s?what=%s&action=%s&%s'>%s</a></td></tr>",
			  $attrs{$what}{label}, $changeURL, $what, $flip{$attrs{$what}{state}}, $param{optional}, $attrs{$what}{value} );

    }
    $text .= "</table>\n";
  }

  elsif ( $param{style} eq 'compacttable' ) {
    $text = "<table $tableattr>";

    my $idx = 0;
    for my $what ( qw/ TIN WIN TN WN / )
    {
      next unless $attrs{$what}{req} eq 'on';
      $idx++;

      $text .= '<tr>' if $idx%2 ;
      $text .= sprintf("<td><strong>%s</strong></td><td><a href='%s?what=%s&action=%s&%s'>%s</a></td>",
			  $attrs{$what}{label}, $changeURL, $what, $flip{$attrs{$what}{state}}, $param{optional}, $attrs{$what}{value} );
      $text .= '</tr>' unless $idx%2;

    }
    $text .= "</table>\n";
  }

  elsif ( $param{style} eq 'wide' ) {
    $text = "<table $tableattr><tr>";

    for my $what ( qw/ TIN WIN TN WN / )
    {
      next unless $attrs{$what}{req} eq 'on';
      $text .= sprintf("<td><strong>%s</strong></td><td><a href='%s?what=%s&action=%s&%s'>%s</a></td>",
			  $attrs{$what}{label}, $changeURL, $what, $flip{$attrs{$what}{state}}, $param{optional}, $attrs{$what}{value} );
    }
    $text .= "</tr></table>\n";
  }

  elsif ( $param{style} eq 'compacttable2' ) {

    $text = "<table $tableattr> <tr><th></th><th><strong>IN</strong></th><th><strong>N</strong></th></tr>";
    for my $what ( qw/ T W / )
    {
      $text .= "<tr><td><strong>$attrs{$what}{label}</strong></td>";

      for my $where ( qw/ IN N / )
      {
	my $ww = $what . $where;
	$text .= sprintf("<td><a href='%s?what=%s&action=%s&%s'>%s</a></td>",
			 $changeURL, $ww, $flip{$attrs{$ww}{state}}, $param{optional}, $attrs{$ww}{value} );
      }
      $text .= "</tr>";
    }
    $text .= "</table>";
  }

  $text = TWiki::Func::renderText($text, $_[2] );
  return $text;
}

1;
