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

use TWiki;# for unpublished functions

use TWiki::Net;
use TWiki::Plugins::ActionTrackerPlugin::Action;
use TWiki::Plugins::ActionTrackerPlugin::ActionSet;
use TWiki::Plugins::ActionTrackerPlugin::Config;
use TWiki::Plugins::ActionTrackerPlugin::Format;

# This module contains the functionality of the bin/actionnotify script
{ package ActionTrackerPlugin::ActionNotify;

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
      
      # COVERAGE OFF
      if ( $expr =~ s/DEBUG//o ) {
	print doNotifications( $webName, $expr, 1 ),"\n";
      } else {
	doNotifications( $webName, $expr, 0 );
      }
      # COVERAGE ON
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

    # Resolve all mail addresses
    my $mailAddress = {};
    my $unsatisfied = 0;
    foreach my $key ( keys %people ) {
      if ( !defined( _getMailAddress( $key, $mailAddress ))) {
	$unsatisfied = 1;
      }
    }

    # If we could not find everyone, gather up WebNotifys as well.
    _loadWebNotifies( $mailAddress ) if ( $unsatisfied );

    # Now cycle over the list of people and find their sets of actions
    # or changes. When we find actions or changes for someone then
    # combine them and add them to the notifications for each indicated
    # mail address.
    my %actionsPerEmail;
    my %changesPerEmail;
    my %notifyEmail;

    foreach my $wikiname ( keys %people ) {
      # first expand the mail address(es)
      my $mailaddr = _getMailAddress( $wikiname, $mailAddress );

      if ( !defined( $mailaddr ) ) {
	TWiki::Func::writeWarning( "No mail address found for $wikiname" );
	$result .= "No mail address found for $wikiname<br />" if ( $debugMailer );
	next;
      }

      # find all the actions for this wikiname
      my $myActions;
      if ( $actions ) {
	my $ats = new ActionTrackerPlugin::Attrs( "who=\"$wikiname\"" );
	$myActions = $actions->search( $ats );
      }

      # now add these to the lists for each mail address
      foreach my $email ( split( /,/, $mailaddr )) {
	if ( $myActions ) {
	  if ( !defined( $actionsPerEmail{$email} )) {
	    $actionsPerEmail{$email} = new ActionTrackerPlugin::ActionSet();
	  }
	  $actionsPerEmail{$email}->concat( $myActions );
	  $notifyEmail{$email} = 1;
	}
	if ( $notifications{$wikiname} ) {
	  if ( !defined( $changesPerEmail{$email} )) {
	    $changesPerEmail{$email}{text} = "";
	    $changesPerEmail{$email}{html} = "";
	  }
	  $changesPerEmail{$email}{text} .= $notifications{$wikiname}{text};
	  $changesPerEmail{$email}{html} .= $notifications{$wikiname}{html};
	  $notifyEmail{$email} = 1;
	}
      }
    }

    # Finally send out the messages
    foreach my $email ( keys %notifyEmail ) {
      my $actionsString = "";
      my $actionsHTML = "";
      my $changesString = "";
      my $changesHTML = "";
      if ( $actionsPerEmail{$email} ) {
	# sorted by due date
	$actionsPerEmail{$email}->sort();
	$actionsString = $actionsPerEmail{$email}->formatAsString( $format );
	$actionsHTML = $actionsPerEmail{$email}->formatAsHTML( $format, "href", 0 );
      }
      if ( $changesPerEmail{$email} ) {
	$changesString = $changesPerEmail{$email}{text};
	$changesHTML = $changesPerEmail{$email}{html};
      }
      
      my $message = _composeActionsMail($actionsString, $actionsHTML,
					$changesString, $changesHTML,
					$date, $email, $format );
      # COVERAGE OFF
      if ( $debugMailer ) {
	$result .= $message;
      } else {
	my $error = TWiki::Net::sendEmail( $message );
	if ( defined( $error )) {
	  $error = "ActionTrackerPlugin:ActionNotify: $error";
	  TWiki::Func::writeWarning( $error );
	}
      }
      # COVERAGE ON
    }

    return $result;
  }
  
  # PRIVATE Process all known webs to get the list of notifiable people
  sub _loadWebNotifies {
    my ( $mailAddress ) = @_;
    
    my $dataDir = TWiki::Func::getDataDir();
    opendir( DIR, "$dataDir" ) or die "could not open $dataDir";
    my @weblist = grep /^[^._].*$/, readdir DIR;
    closedir DIR;
    my $web;
    foreach $web ( @weblist ) {
      if ( -d "$dataDir/$web" ) {
	_loadWebNotify( $web, $mailAddress );
      }
    }
  }
  
  # PRIVATE Get the actions that match attrs, and the contents
  # of WebNotify, for a web
  sub _loadWebNotify {
    my( $web, $mailAddress ) = @_;
    
    # COVERAGE OFF
    if( ! TWiki::Func::webExists( $web ) ) {
      my $error = "ActionTrackerPlugin:ActionNotify: did not find web $web";
      TWiki::Func::writeWarning( $error );
      return;
    }
    # COVERAGE ON

    my $topicname = $ActionTrackerPlugin::Config::notifyTopicname;
    return undef unless TWiki::Func::topicExists( $web, $topicname );
    
    my $list = {};
    my $mainweb = TWiki::Func::getMainWebname();
    my $text = TWiki::Func::readTopicText( $web, $topicname, undef, 1 );
    foreach my $line ( split( /\r?\n/, $text)) {
      if ( $line =~ /^\s+\*\s([\w\.]+)\s+-\s+([\w\-\.\+]+\@[\w\-\.\+]+)/o ) {
	my $who = $1;
	my $addr = $2;
	$who = ActionTrackerPlugin::Action::_canonicalName( $who );
	if ( !defined( $mailAddress->{$who} )) {
	  TWiki::Func::writeWarning( "ActionTrackerPlugin:ActionNotify: mail address for $who found in WebNotify" );
	  $mailAddress->{$who} = $addr;
	}
      }
    }
  }
  
  # PRIVATE Try to get the mail address of a wikiName by looking up in the
  # map of known addresses or, failing that, by opening their
  # personal topic in the Main web and looking for Email:
  sub _getMailAddress {
    my ( $who, $mailAddress ) = @_;
    
    if ( defined( $mailAddress->{$who} )) {
      return $mailAddress->{$who};
    }

    my $addresses;

    if ( $who =~ m/^([\w\-\.\+]+\@[\w\-\.\+]+)$/o ) {
      # Valid mail address
      $addresses = $who;
    } elsif ( $who =~ m/,/o ) {
      # Multiple addresses
      # (e.g. who="GenghisKhan,AttillaTheHun")
      # split on , and recursively expand
      my @persons = split( /\s*,\s*/, $who );
      foreach my $person ( @persons ) {
	$person = _getMailAddress( $person, $mailAddress );
      }
      $addresses = join( ",", @persons );
    } elsif ( $who =~ m/^[A-Z]+[a-z]+[A-Z]+\w+$/o ) {
      # A legal topic wikiname
      $who = ActionTrackerPlugin::Action::_canonicalName( $who );
      $addresses = _getMailAddress( $who, $mailAddress );
    } elsif ( $who =~ m/^(\w+)\.([A-Z]+[a-z]+[A-Z]+\w+)$/o ) {
      # A topic in a web
      my ( $inweb, $intopic ) = ( $1, $2 );
      if ( TWiki::Func::topicExists( $inweb, $intopic ) ) {
	my $text = TWiki::Func::readTopicText( $inweb, $intopic, undef, 1 );

	if ( $intopic =~ m/Group$/o ) {
	  # If it's a Group topic, match * Set GROUP = 
	  if ( $text =~ m/^\s+\*\s+Set\s+GROUP\s*=\s*([^\r\n]+)/so ) {
	    my @people = split( /\s*,\s*/, $1 );
	    foreach my $person ( @people ) {
	      $person = _getMailAddress( $person, $mailAddress );
	    }
	    $addresses = join( ",", @people );
	  }
	} else {
	  # parse Email: format lines from personal topic
	  my @people;
	  while ( $text =~ s/^\s+\*\s*E-?mail:\s*([^\s\r\n]+)//imo ) {
	    push( @people, $1 );
	  }
	  $addresses = join( ",", @people );
	}
      }
    }

    if ( defined( $addresses )) {
      if ( $addresses =~ m/^\s*$/o ) {
	$addresses = undef;
      } else {
	$mailAddress->{$who} = $addresses;
      }
    }

    return $addresses;
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
    # add the url host to any in-twiki urls that lack it
    my $sup = TWiki::Func::getScriptUrlPath();
    my $sun = TWiki::Func::getUrlHost() . $sup;
    $text =~ s/href=\"$sup/href=\"$sun/ogi;
    $text =~ s/<\/?nop( \/)?>//goi;
    
    return $text;
  }
  
  # Get the revision number of a topic at a specific date
  # SMELL: This is dependent on RCS. Store should provide
  # this functionality.
  sub _getRevAtDate {
    my ( $theWeb, $theTopic, $date ) = @_;
    my $dataDir = TWiki::Func::getDataDir();
    my $fname = "$dataDir\/$theWeb\/$theTopic.txt";
    # COVERAGE OFF
    if ( !-e "$fname,v") {
      return undef;
    }
    # COVERAGE ON
    my $tmp = $ActionTrackerPlugin::Config::rlogCmd;
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

    # Recover the action set at that date
    my $text = TWiki::Func::readTopicText( $theWeb, $theTopic, $oldrev, 1 );
    my $oldActions =
      ActionTrackerPlugin::ActionSet::load( $theWeb, $theTopic, $text );

    # Recover the current action set.
    $text = TWiki::Func::readTopicText( $theWeb, $theTopic, undef, 1 );
    my $currentActions =
      ActionTrackerPlugin::ActionSet::load( $theWeb, $theTopic, $text );
    
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
    my $cmd = $ActionTrackerPlugin::Config::egrepCmd;
    my $q = $ActionTrackerPlugin::Config::cmdQuote;
    # This greb is only used to find the files containing actions.
    # The output is thrown away. So we could use fgrep instead, but
    # since this is run as a cron there's not much benefit.
    my $grep = `$cmd $q%ACTION\\{.*\\}%$q $dd/$theWeb/*.txt`;

    my $number = 0;
    my %processed;
    
    foreach my $line ( split( /\r?\n/, $grep )) {
      $line =~ m/^.*\/([^\/\.\n]+)\.txt:/o;
      my $topic = $1;
      if ( !$processed{$topic} ) {
	_findChangesInTopic( $theWeb, $topic, $theDate, $format,
			     $notifications );
	$processed{$topic} = 1;
      }
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
      }
    }
  }
}

1;
