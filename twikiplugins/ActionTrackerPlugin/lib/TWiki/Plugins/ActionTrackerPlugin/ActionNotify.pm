#
# Copyright (C) Motorola 2002 - All rights reserved
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
use strict;
use integer;

use TWiki;
use TWiki::Net;
use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::ActionSet;
use TWiki::Plugins::ActionTrackerPlugin::Format;

# This module contains the functionality of the bin/actionnotify script
{ package ActionTrackerPlugin::ActionNotify;

  my $vcLogCmd;

  # PUBLIC actionnotify script entry point. Reinitialises TWiki.
  #
  # Notify all persons of actions that match the search expression
  # passed.
  #
  sub actionNotify {
      my $expr = shift;
      
      # Initialise TWiki in the main web
      my ( $topic, $webName, $dummy, $userName, $dataDir) = 
	  &TWiki::initialize( "/Main", "nobody" );
      $dummy = "";  # to suppress warning
      
      doNotifications( $webName, $expr, 0 );
  }

  # Entry point separated from main entry point, because we may want
  # to call it in a topic without initialising TWiki.
  sub doNotifications {
    my ( $webName, $expr, $debugMailer ) = @_;
    
    my $attrs = new ActionTrackerPlugin::Attrs( $expr );
    my $hdr =
      TWiki::Func::getPreferencesValue( "ACTIONTRACKERPLUGIN_TABLEHEADER" );
    my $bdy =
      TWiki::Func::getPreferencesValue( "ACTIONTRACKERPLUGIN_TABLEFORMAT" );
    my $vert =
      TWiki::Func::getPreferencesFlag( "ACTIONTRACKERPLUGIN_TABLEVERTICAL" );
    my $textform =
      TWiki::Func::getPreferencesValue( "ACTIONTRACKERPLUGIN_TEXTFORMAT" );
    my $changes =
      TWiki::Func::getPreferencesValue( "ACTIONTRACKERPLUGIN_NOTIFYCHANGES" );

    my $format = new ActionTrackerPlugin::Format( $hdr, $bdy, $textform, $changes, $vert );
    $vcLogCmd =
      TWiki::Func::getPreferencesValue( "ACTIONTRACKERPLUGIN_LOGCMD" );

    my $notify = {};
    _gatherNotables( $notify );
    
    my $result = "";
    my $webs = $attrs->get( "web" ) || ".*";
    
    # Okay, we have tables of all the actions and a partial set of the
    # people who can be notified.
    my %notifications = ();
    my %people = ();

    my $date = $attrs->remove( "changedsince" );
    if ( defined( $date )) {
      # need to get rid of formatting done in actionnotify perl script
      $date =~ s/[, ]+/ /go; 
      $date = _getRelativeDate( $date );
      _findChangesInWebs( $webs, $date, $format, \%notifications );
      foreach my $key ( keys %notifications ) {
	if ( defined ( $notifications{$key} ) ) {
	  $people{$key} = 1;
	}
      }
    }
    my $actions;
    if ( scalar( keys %$attrs ) > 0 ) {
      # Get all the actions that match the search
      $actions = ActionTrackerPlugin::ActionSet::allActionsInWebs( $webs, $attrs );
      $actions->getActionees( \%people );
    }

    # Now cycle over the list of people and find their sets of actions
    # or changes
    my $mainweb = TWiki::Func::getMainWebname();
    foreach my $key ( keys %people ) {
      if ( defined( $key ) ) {
	my $compare_key = $key;
	$key =~ s/\s//go;
	$key =~ s/$mainweb\.//go;
	my $mailaddr = _getMailAddress( $key, $notify );

	if ( !defined( $mailaddr ) ) {
	  TWiki::Func::writeWarning( "No mail address found for $key" );
	  if ( $debugMailer ) {
	    $result .= "No mail address found for $key<br />"
	  }
	  next;
	}
	
	my $actionsString = "";
	my $actionsHTML = "";
	if ( $actions ) {
	  my $subact = $actions->search("who=\"$key\"");
	  $subact->sort();
	  $actionsString = $subact->formatAsString( $format ) || "";
	  $actionsHTML = $subact->formatAsHTML( $format, "href", 0 ) || "";
	}

	my $changesString = $notifications{$compare_key}{text} || "";
	my $changesHTML = $notifications{$compare_key}{html} || "";

	my $message = _composeActionsMail($actionsString, $actionsHTML,
					  $changesString, $changesHTML,
					  $date, $mailaddr, $format );
	if ( $debugMailer ) {
	  $result .= $message;
	} else {
	  my $error = TWiki::Net::sendEmail( $message );
	  if ( defined( $error )) {
	    $error = "ActionTrackerPlugin:ActionNotify: $error";
	    TWiki::Func::writeWarning( $error );
	  }
	}
      }
    }

    return $result;
  }
  
  # PRIVATE Process all known webs to get the list of notifiable people
  sub _gatherNotables {
    my ( $notify ) = @_;
    
    my $dataDir = TWiki::Func::getDataDir();
    opendir( DIR, "$dataDir" ) or die "could not open $dataDir";
    my @weblist = grep /^[^._].*$/, readdir DIR;
    closedir DIR;
    my $web;
    foreach $web ( @weblist ) {
      if ( -d "$dataDir/$web" ) {
	_gatherNotablesFromWeb( $web, $notify );
      }
    }
  }
  
  # PRIVATE Get the actions that match attrs, and the contents
  # of WebNotify, for a web
  sub _gatherNotablesFromWeb {
    my( $web, $notify ) = @_;
    
    if( ! TWiki::Func::webExists( $web ) ) {
      my $error = "ActionTrackerPlugin:ActionNotify: did not find web $web";
      TWiki::Func::writeWarning( $error );
      return;
    }
    
    # get the notify list for this web
    _addWebNotify( $web, $notify );
  }
  
  # PRIVATE Read the WebNotify topic in this web and add the entries to a map
  # of name->address
  sub _addWebNotify {
    my ( $web, $notify ) = @_;
    
    my $topicname = $TWiki::notifyTopicname;
    return undef unless TWiki::Func::topicExists( $web, $topicname );
    
    my $list = {};
    my $mainweb = TWiki::Func::getMainWebname();
    foreach ( split( /\n/, TWiki::Func::readTopicText( $web, $topicname, undef, 1 ))) {
      next unless /^\s+\*\s([A-Za-z0-9\.]+)\s+\-\s+/;
      my $who = $1;
      $who =~ s/^$mainweb\.//o if ( defined($who) );
      next unless (/([\w\-\.\+]+\@[\w\-\.\+]+)/);
      $notify->{$who} = $1;
    }
  }
  
  # PRIVATE Try to get the mail address of a wikiName by looking up in the
  # map of known addresses or, failing that, by opening their
  # personal topic in the Main web and looking for Email:
  sub _getMailAddress {
    my ( $who, $notify ) = @_;
    
    if ( $who =~ m/,/o ) {
      # Multiple addresses
      # (e.g. who="GenghisKhan,AttillaTheHun")
      # split on , and recursively expand
      my $addresses = "";
      my @persons = split( /,/, $who );
      foreach my $person ( @persons ) {
	my $addressee .= _getMailAddress( $person, $notify );
	$addresses .= "," if ($addresses ne "");
	$addresses .= $addressee;
      }
      $notify->{$who} = $addresses;
    } elsif ( $who =~ /([\w\-\.\+]+\@[\w\-\.\+]+)/ ) {
      # Valid mail address
      $notify->{$who} = $who;
    } else {
      my $mainweb = TWiki::Func::getMainWebname();
      $who =~ s/^$mainweb\.//o if ( defined( $who ) );
      
      if ( !defined( $notify->{$who} ) ) {
	if ( TWiki::Func::topicExists( $mainweb, $who ) ) {
	  my $text = TWiki::Func::readTopicText( $mainweb, $who, undef, 1 );
	  
	  my $addresses = "";
	  # parse Email: format lines from topic
	  while ( $text =~ s/^\s+\*\s*E-?mail:\s*([^\s\r\n]*)//imo ) {
	    $addresses .= "," if ($addresses ne "");
	    $addresses .= $1;
	  }
	  
	  # parse WebNotify format line
	  while ( $text =~ s/^\s+\*\s([A-Za-z0-9\.]+)\s+\-\s+([^\s\r\n]+)//mo ) {
	    $addresses .= "," if ($addresses ne "");
	    $addresses .= $2;
	  }
	  $notify->{$who} = $addresses if ( $addresses ne "" );
	} 
      }
    }
    return $notify->{$who};
  }
  
  # PRIVATE Mail the contents of the action set to the given user(s)
  sub _composeActionsMail {
    my ( $actionsString, $actionsHTML, $changesString, $changesHTML,
	 $since, $mailaddr, $format ) = @_;
    
    my $from = TWiki::Func::getPreferencesValue("WIKITOOLNAME");
    
    my $text = TWiki::Func::readTemplate( "actionnotify" );

    my $subject = "";
    if ( $actionsString ) {
      $subject .= "Outstanding actions";
    }
    if ( $changesString ) {
      $subject .= " and " if ( $subject ne "" );
      $subject .= "Changes to actions";
    }
    $text =~ s/%SUBJECT%/$subject/go;

    $text =~ s/%EMAILFROM%/$from/go;
    $text =~ s/%EMAILTO%/$mailaddr/go;

    if ( $actionsString ne "" ) {
      $text =~ s/%ACTIONS_AS_STRING%/$actionsString/go;
      my $asHTML = TWiki::Func::renderText( $actionsHTML );
      $text =~ s/%ACTIONS_AS_HTML%/$asHTML/go;
      $text =~ s/%ACTIONS%(.*?)%END%/$1/gso;
    } else {
      $text =~ s/%ACTIONS%.*?%END%//gso;
    }

    $since = "" unless ( $since );
    $text =~ s/%SINCE%/$since/go;
    if ( $changesString ne "" ) {
      $text =~ s/%CHANGES_AS_STRING%/$changesString/go;
      my $asHTML = TWiki::Func::renderText( $changesHTML );
      $text =~ s/%CHANGES_AS_HTML%/$asHTML/go;
      $text =~ s/%CHANGES%(.*?)%END%/$1/gso;
    } else {
      $text =~ s/%CHANGES%.*?%END%//gso;
    }

    $text = TWiki::Func::expandCommonVariables( $text, $TWiki::mainTopicname );
    $text =~ s/<img src=.*?[^>]>/[IMG]/goi;  # remove all images
    my $sup = TWiki::Func::getScriptUrlPath();
    my $sun = TWiki::Func::getUrlHost() . $sup;
    $text =~ s/href=\"$sup/href=\"$sun/ogi;
    $text =~ s|</*nop[ /]*>||goi;
    
    return $text;
  }
  
  # Get the revision number of a topic at a specific date
  # SMELL: This is dependent on RCS. Store should provide
  # this functionality.
  sub _getRevAtDate {
    my ( $theWeb, $theTopic, $date ) = @_;
    my $dataDir = TWiki::Func::getDataDir();
    my $fname = "$dataDir\/$theWeb\/$theTopic.txt";
    my $tmp = $vcLogCmd;
    $tmp =~ s/%DATE%/$date/o;
    $tmp =~ s/%FILENAME%/$fname/o;
    $tmp =~ /(.*)/;
    $tmp = $1;
    my $rlog = `$tmp`;
    if ( $rlog =~ s/.*revision (\d+\.\d+).*/$1/so ) {
      return $rlog;
    } else {
      return undef;
    }
  }
  
  # PRIVATE STATIC get the "real" date from a relative date.
  sub _getRelativeDate {
    my $ago = shift;
    
    my $triggerTime = Time::ParseDate::parsedate( "$ago", PREFER_PAST => 1 );
    return gmtime( $triggerTime );
  }
  
  # PRIVATE STATIC
  # Find the actions that have changed between today and a previous date
  # in the given web and topic
  sub _findChangesInTopic {
    my ( $theWeb, $theTopic, $theDate, $format, $notifications ) = @_;
    my $filename = TWiki::Func::getDataDir() . "\/$theWeb\/$theTopic.txt";

    # There can be no changes if the file date on the topic file
    # is earlier than theDate!
    
    # Recover the rev at the previous date
    my $oldrev = _getRevAtDate( $theWeb, $theTopic, $theDate );
    return unless defined( $oldrev );
    $oldrev =~ s/\d+\.(\d+)/$1/o;

    my $text = TWiki::Func::readTopicText( $theWeb, $theTopic, $oldrev, 1 );
    my $oldActions = new ActionTrackerPlugin::ActionSet();
    my $actionNumber = 0;
    while ( $text =~ s/%ACTION{([^%]*)}%([^\n\r]+)//so ) {
      my $action = new ActionTrackerPlugin::Action( $theWeb, $theTopic, $actionNumber++, $1, $2 );
      $oldActions->add( $action );
    }

    # Recover the current action set.
    $text = TWiki::Func::readTopicText( $theWeb, $theTopic, undef, 1 );
    my $currentActions = new ActionTrackerPlugin::ActionSet();
    $actionNumber = 0;
    while ( $text =~ s/%ACTION{([^%]*)}%([^\n\r]+)//so ) {
      my $action = new ActionTrackerPlugin::Action( $theWeb, $theTopic, $actionNumber++, $1, $2 );
      $currentActions->add( $action );
    }
    
    # find actions that have changed between the two dates. These
    # are added as text to a hash keyed on the names of people
    # interested in notification of that action.
    $currentActions->findChanges( $oldActions, $theDate, $format,
				  $notifications );
  }
  
  # Gather all notifications for modifications in all topics in the
  # given web, since the given date.
  sub _findChangesInWeb {
    my ( $theWeb, $theDate, $format, $notifications ) = @_;
    my $actions = new ActionTrackerPlugin::ActionSet();
    my $dd = TWiki::Func::getDataDir() || "..";
    
    # Known problem; if there's only one file in the web matching
    # *.txt then the file name won't be printed, at least with GNU
    # grep. The GNU -H switch, which would solve the problem, is
    # non-standard. This problem is ignored because such a web
    # isn't very useful in TWiki.
    # Also assumed: the output of the egrepCmd must be of the form
    # file.txt: ...matched text...
    my $grep = `${TWiki::egrepCmd} ${TWiki::cmdQuote}%ACTION\\{.*\\}%${TWiki::cmdQuote} $dd/$theWeb/*.txt`;

    my $number = 0;
    my %processed;
    
    while ( $grep =~ s/^.*\/([^\/\.\n]+)\.txt:.*%ACTION{([^\}]*)}%//m ) {
      my $topic = $1;
      if ( !$processed{$topic} ) {
	_findChangesInTopic( $theWeb, $topic, $theDate, $format,
			     $notifications );
	$processed{$topic} = 1;
      }
      #debug
      #$notifications->{"$theWeb.$topic"} = "$theWeb.$topic searched<br>";
    }
  }
  
  # PRIVATE STATIC
  # Gather notifications for modifications in all webs matched in
  # the "web" value of the attribute set. This searches all webs,
  # INCLUDING those flagged NOSEARCHALL, on the assumption that
  # people registering for notifications in those webs really want
  # to know.
  sub _findChangesInWebs {
    my ( $webs, $date, $format, $notifications ) = @_;
    
    my $dataDir = TWiki::Func::getDataDir();
    opendir( DIR, "$dataDir" ) or die "could not open $dataDir";
    my @weblist = grep /^[^._].*$/, readdir DIR;
    closedir DIR;
    
    #debug
    #$notifications->{$dataDir} = "Searching";
    my $web;
    foreach $web ( @weblist ) {
      if ( -d "$dataDir/$web" && $web =~ /^$webs$/ ) {
	$web =~ /(.*)/; # untaint
	my $theWeb = $1;
	_findChangesInWeb( $theWeb, $date, $format, $notifications );
	#debug
	#$notifications->{$theWeb} = "Web $theWeb searched<br>";
      }
    }
  }
}

1;
