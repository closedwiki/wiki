#
# Copyright (C) Motorola 2001,2002,2003 - All rights reserved
#
# TWiki extension that adds tags for action tracking
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
# Script used for communication from the PowerEdit applet (client)
# back to TWiki (server). The script uses an 'action' parameter
# to select one of three server actions:
#
# get           Deliver the raw text of the topic from the DB
#               Required because there's no way to pass enough text
#               in the parameters to the applet
# put           Save the text and return the URL for the applet to
#               jump to when editing is finished.
# commit        Commit the applet-provided text back to the DB and
#               preview it.
#
use strict;
use integer;

use CGI::Carp qw(fatalsToBrowser);
use CGI;
use TWiki;

package PowerEditAddon::PowerEdit;

sub serverCommand {
  my $query = shift;
  my $action = $query->param( 'action' ) || "badaction";
  my $meta;
  my $text;
  
  my $thePathInfo = $query->path_info(); 
  my $theRemoteUser = $query->remote_user();
  my $theTopic = $query->param( 'topic' ) || "";
  my $theUrl = $query->url;
  
  my( $topic, $webName, $scriptUrlPath, $userName ) = 
    &TWiki::initialize( $thePathInfo, $theRemoteUser,
			$theTopic, $theUrl, $query );
  
  if ( $action eq "controls" ) {
    _getControls( $userName, $query );
  } elsif ( $action eq "get" ) {
    if ( ! _checkLock( $webName, $topic, $userName )) {
      print $query->header( -type=>'text/plain' );
      print "ERROR $userName is not locking $topic";
      return;
    }
    _getTopicText( $webName, $topic, $query );
  } elsif ( $action eq "put" ) {
    _cacheText( $webName, $topic, $query );
  } elsif ( $action eq "commit" ) {
    _executeBinScript( "save", $webName, $topic, $query );
  } elsif ( $action eq "preview" ) {
    _executeBinScript( "preview", $webName, $topic, $query );
  } else {
    print $query->header( -type=>'text/plain' );
    print "ERROR unknown server command $action";
  }
}

# Get the text of the controls topic
sub _getControls {
  my ( $userName, $query ) = @_;
  my $controls = TWiki::Func::getPreferencesValue( "POWEREDIT_CONTROLS" );
  if ( ! $controls ) {
    $controls = "TWiki.PowerEditControls";
  }
  $controls =~ /(.*)\.(.*)/;
  _getTopicText( $1, $2, $query );
}

# url: <twiki>/bin/poweredit/<web>/<topic>?action=get
# Pass the raw topic back to the client
# Security note: This is not very safe; the only security check
# is for the locking user being as expected. If a browser invokes
# http://server/twiki/bin/poweredit/Web/Topic?action=get
# and happens to match the name of the locking user, then
# they will receive back the file contents unadulterated without
# further security checks.
sub _getTopicText {
  my ( $webName, $topic, $query ) = @_;
  
  if ( TWiki::Func::topicExists( $webName, $topic ) ) {
    my ( $meta, $text ) = &TWiki::Func::readTopic( $webName, $topic );
    # Meta gets ignored. It gets re-attached when we save.
    $text =~ s/\t/   /go;
    print $query->header( -type=>'text/plain', -expires=>'+1s' );
    print "OK", $text;
  } else {
    print $query->header( -type=>'text/plain' );
    print "ERROR no such topic $webName.$topic";
  }
}

# Make sure there's a lock on the topic, and it's locked by the
# caller. I'd rather do this using topicIsLockedBy but this doesn't
# differentiate between the topic not being locked (bad) and the topic
# being locked by this user (good)
sub _checkLock {
  my ( $webName, $topic, $userName ) = @_;
  my $lockOK = 0;
  my $lockFile = TWiki::Func::getDataDir()."/$webName/$topic.lock";
  if ( -f $lockFile ) {
    my $tmp = TWiki::Func::readFile( $lockFile );
    my( $lockUser, $lockTime ) = split( /\n/, $tmp );
    if ( $lockUser eq $userName ) {
      return 1;
    }
  }
  return 0;
}

# url: <twiki>/bin/poweredit/<web>/<topic>?action=put&text=...
# return: a url
# Cache the new text provided from the client
sub _cacheText {
  my ( $webName, $topic, $query ) = @_;
  
  # Security note: This is safe insofar as it doesn't write back to
  # the DB, just to a temp file.
  # We can't simply invoke the preview script from here because
  # java needs to exit and it can't do it from here.
  
  _writeCache( $webName, $topic,
	       $query->param( 'text' ) );
  # write the url required to access it back to java
  print $query->header( -type=>'text/plain', -expires=>'+1s' ),
  "OK", TWiki::Func::getScriptUrl( $webName, $topic, "poweredit" );
}

# Execute a CGI script from the twiki bin directory by evaling it,
# replacing the "new CGI" with a query passed in.
sub _executeBinScript {
  my ( $script, $webName, $topic, $query ) = @_;

  # Take a copy of the query so we can add to it...
  my $newQuery = new CGI( $query );

  # Recover the meta information from the original topic and restore
  # it. 
  my ( $meta, $oldtext ) = &TWiki::Func::readTopic( $webName, $topic );
  # Push all the fields in the meta into parameters
  my @fields = $meta->find( "FIELD" );
  foreach my $field ( @fields ) {
    my $name  = $field->{"name"};
    my $value = $field->{"value"};
    $newQuery->param( -name=>"$name", -value=>"$value" );
  }

  # set the text in the query by reading the cache
  my $text = _readRemoveCache( $webName, $topic );
  $newQuery->param( -name=>'text', -value=>$text );

  # Read the script from bin and massage it to create a subblock
  my $theScript = TWiki::Func::readFile( $script . $TWiki::scriptSuffix );
  $theScript =~ s/new\s+CGI/\$newQuery/o;
  $theScript =~ s/&main\s*(\s*)//o;
  $theScript =~ s/sub\s+main//o;
  $theScript =~ /(.*)/s;
  $theScript = $1;
  {
    my ($topic, $webName, $dummy, $userName);
    eval "$theScript";
  }
}

sub _writeCache {
    my( $theWeb, $theTopic, $theText ) = @_;
    my $fileName = TWiki::Func::getDataDir() . "/$theWeb/$theTopic.tmp";
    TWiki::Func::saveFile( $fileName, $theText );   
}

sub _readRemoveCache {
    my( $theWeb, $theTopic ) = @_;
    my $fileName = TWiki::Func::getDataDir() . "/$theWeb/$theTopic.tmp";
    my $text = TWiki::Func::readFile( $fileName );
    unlink( $fileName );
    return $text;
}

1;
