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
  
  if ( $action eq "get" ) {
    _getAction( $webName, $topic, $userName, $query );
  } elsif ( $action eq "put" ) {
    _putAction( $webName, $topic, $query );
  } elsif ( $action eq "commit" ) {
    _commitAction( $webName, $topic, $query );
  } else {
    # error message
    TWiki::writeDebug( "Unknown server command $action" );
    # Can't do much more because context is unknown.
    my $url = &TWiki::getOopsUrl( $webName, $topic, "oopslocked",
				  "ERROR action $action" );
    TWiki::redirect( $query, $url );
  }
}

# url: <twiki>/bin/poweredit/<web>/<topic>?action=get
# Pass the raw topic back to the client
# Security note: This is not very safe; the only security check
# is for the locking user being as expected. If a browser invokes
# http://server/twiki/bin/poweredit/Web/Topic?action=get
# and happens to match the name of the locking user, then
# they will receive back the file contents unadulterated without
# further security checks.
sub _getAction {
  my ( $webName, $topic, $userName, $query ) = @_;
  
  # Make sure there's a lock on the topic, and it's locked by the
  # caller. I'd rather do this using topicIsLockedBy but this doesn't
  # differentiate between the topic not being locked (bad) and the topic
  # being locked by this user (good)
  my $lockOK = 0;
  my $lockFile = TWiki::Func::getDataDir()."/$webName/$topic.lock";
  if ( -f $lockFile ) {
    my $tmp = TWiki::Func::readFile( $lockFile );
    my( $lockUser, $lockTime ) = split( /\n/, $tmp );
    if ( $lockUser eq $userName ) {
      $lockOK = 1;
    }
  }
  
  print $query->header( -type=>'text/plain', -expires=>'+1s' );
  
  if ( !$lockOK ) {
    print "ERROR $userName is not locking $topic";
  } elsif ( TWiki::Func::topicExists( $webName, $topic ) ) {
    my ( $meta, $text ) = &TWiki::Func::readTopic( $webName, $topic );
    # Meta gets ignored. It gets re-attached when we save.
    $text =~ s/\t/   /go;
    $text = "OK" . $text;
    print $text;
  } else {
    print "ERROR no such topic $topic";
  }
}

# url: <twiki>/bin/poweredit/<web>/<topic>?action=put&text=...
# return: a url that will commit the changes
# Cache the new text provided from the client
sub _putAction {
  my ( $webName, $topic, $query ) = @_;
  
  # Security note: This is safe insofar as it doesn't write back to
  # the DB, just to a temp file.
  # We can't simply invoke the preview script from here because
  # java needs to exit and it can't do it from here.
  
  TWiki::Store::savePreview( $webName, $topic,
			     $query->param( 'text' ));
  # write the url required to access it back to java
  print $query->header( -type=>'text/plain', -expires=>'+1s' ),
  TWiki::Func::getScriptUrlPath(),
  "/poweredit/$webName/$topic?action=commit",
  "&topic=$webName.$topic";
}

# url:  <twiki>/bin/poweredit/<web>/<topic>?action=commit
# return: nothing; commit is invoked by a redirect from the
# applet (which terminates the applet).

# Commit the cached text by passing to the preview script
sub _commitAction {
  my ( $webName, $topic, $query ) = @_;
  
  # Take a copy of the query so we can add to it...
  my $query2 = new CGI( $query );
  
  # Recover the meta information from the original topic and restore
  # it. 
  my ( $meta, $oldtext ) = &TWiki::Store::readTopic( $webName, $topic );
  # Push all the fields in the meta into parameters
  my @fields = $meta->find( "FIELD" );
  foreach my $field ( @fields ) {
    my $name  = $field->{"name"};
    my $value = $field->{"value"};
    $query2->param( -name=>"$name", -value=>"$value" );
  }
  
  # set the text in the query by reading the cache
  my $text = TWiki::Store::readRemovePreview( $webName, $topic );
  $query2->param( -name=>'text', -value=>$text );

  # FIXME: truly nasty - edit the preview script. I really want to call
  # the 'preview function' on my modified query, but just can't figure a way.
  my $preview = TWiki::Store::readFile( "preview" . $TWiki::scriptSuffix );
  # edit off the offensive bits, starting with the comments
  $preview =~ s/^\s*\#.*$//gom;
  # take out the call to main
  $preview =~ s/\&main.*$//om;
  # kill main
  $preview =~ s/sub\s+main//om;
  # convert the CGI creation to read the parameter
  $preview =~ s/new CGI/\$query2/o;
  $preview =~ /(.*)/s; # untaint
  $preview = $1;
  open FH, ">/tmp/blah";
  print FH $preview;
  close FH;
  # invoke the edited preview script on the edited query
  eval "$preview";
}

1;
