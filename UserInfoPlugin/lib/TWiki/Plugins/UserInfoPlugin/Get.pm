# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 Michael Daum <micha@nats.informatik.uni-hamburg.de>
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


package TWiki::Plugins::UserInfoPlugin::Get ;
use vars qw(
	$twikiGuest 
	$sessionDir
	$ignoreHosts
	$debug
);
BEGIN {
  # get spiders
  # $ignoreHosts = TWiki::Func::getPreferencesValue("USERINFOPLUGIN_IGNOR_HOSTS") || '';
  # $ignoreHosts = join('|', split(/,\s?/, $ignoreHosts));
  # figure out where the sessions are
  $sessionDir = $TWiki::cfg{SessionDir} ||
                &TWiki::Func::getDataDir() . "/.session"; 
  if (! -e $sessionDir) {
    &TWiki::Func::writeDebug("- UserInfoPlugin - sessionDir '$sessionDir' not found ... falling back to /tmp") if $debug;
    $sessionDir = '/tmp';
  }
  
  # get twiki guest string
  $twikiGuest = $TWiki::cfg{DefaultUserWikiName};
};

###############################################################################
# get list of users that stil have a session object
# this is the number of session objects
sub getVisitorsFromSessionStore {

  my ($includeNames, $excludeNames) = @_;

  #writeDebug("getVisitorsFromSessionStore()");
  #writeDebug("includeNames=$includeNames") if $includeNames;
  #writeDebug("excludeNames=$excludeNames") if $excludeNames;

  # get session directory

  # get wikinames of current visitors
  my %users = ();
  my %guests = ();
  my @sessionFiles = reverse glob "$sessionDir/cgisess_*";
  foreach my $sessionFile (@sessionFiles) {

    #writeDebug("reading $sessionFile");
  
    my $dump = &TWiki::Func::readFile($sessionFile);
    next if ! $dump;

    my $wikiName;
    my $host;

    $wikiName = $twikiGuest;
    if ($dump =~ /"AUTHUSER" => "(.*?)"/) {
      $wikiName = $1;
    }
    if ($dump =~ /"_SESSION_REMOTE_ADDR" => "(.*?)"/) {
      $host = $1;
    }

    if ($host) {
      next if $host =~ /$ignoreHosts/;
      $guests{$host} = 1 if $wikiName eq $twikiGuest;
    }

    next if $users{$wikiName};
    next if $excludeNames && $wikiName =~ /$excludeNames/;
    #writeDebug("found $wikiName");
    next if $includeNames && $wikiName !~ /$includeNames/;

    $users{$wikiName} = 1;
  }

  my @users = keys %users;
  my @guests = keys %guests;

  return (\@users, \@guests);
}

###############################################################################
# SMELL: this only works for htpasswd authenticated installations
sub getNrUsers {

  
  # get twiki guest string
  $twikiGuest = &TWiki::Func::getDefaultUserName();
  $twikiGuest = &TWiki::Func::userToWikiName($twikiGuest, 1);
  my $htpasswdFilename = &TWiki::Func::getDataDir() . "/.htpasswd";
  my $passwds = &TWiki::Func::readFile($htpasswdFilename);
  my @lines = grep {!/$twikiGuest/} split("\n", $passwds);
  return scalar(@lines);
}


###############################################################################
sub getNrVisitors {

  #writeDebug("getNrVisitors()");
  # get twiki guest string
  $twikiGuest = &TWiki::Func::getDefaultUserName();
  $twikiGuest = &TWiki::Func::userToWikiName($twikiGuest, 1);
  my ($visitors) = &getVisitorsFromSessionStore(undef, $twikiGuest);
  return scalar @$visitors;
}

###############################################################################
sub getNrGuests {

  #writeDebug("getNrGuests()");
  # get twiki guest string
  $twikiGuest = &TWiki::Func::getDefaultUserName();
  $twikiGuest = &TWiki::Func::userToWikiName($twikiGuest, 1);
  my (undef, $guests) = &getVisitorsFromSessionStore($twikiGuest);
  return scalar @$guests;
}

###############################################################################
sub getNrLastVisitors {
  my $attributes = shift;

  $attributes = '' unless $attributes;

  #writeDebug("getNrLastVisitors($attributes)");
  # get twiki guest string
  $twikiGuest = &TWiki::Func::getDefaultUserName();
  $twikiGuest = &TWiki::Func::userToWikiName($twikiGuest, 1);

  my $theDays = TWiki::Func::extractNameValuePair($attributes, "days") || 1;
  my $visitors = &getVisitors($theDays, undef, undef, $twikiGuest);

  return scalar @$visitors;
}

###############################################################################
sub getVisitors {

  my ($theDays, $theMax, $includeNames, $excludeNames) = @_;

  $theMax = 0 unless $theMax;

  #writeDebug("getVisitors()");
  #writeDebug("theDays=$theDays") if $theDays;
  #writeDebug("theMax=$theMax") if $theMax;
  #writeDebug("includeNames=$includeNames") if $includeNames;
  #writeDebug("excludeNames=$excludeNames") if $excludeNames;
  

  # get the logfile mask
  my $logFileGlob = $TWiki::cfg{LogFileName};

  $logFileGlob =~ s/%DATE%/*/g;
  
  # go through the logfiles and collect visitor data
  my $isDone = 0;
  my $days = 0;
  my $n = $theMax;
  my $currentDate = '';
  my @logFiles = reverse glob $logFileGlob;
  my @lastVisitors = ();
  foreach my $logFilename (@logFiles) {
    #writeDebug("reading $logFilename");

    # read one logfile
    my $fileContents = TWiki::Func::readFile($logFilename);
    
    # analysis
    my %seen = ();
    my $nrVisitors = 0;
    foreach my $line (reverse split(/\n/, $fileContents)) {
      my @fields = split(/\|/, $line);
      if (!$fields[2]) {
	      # writeDebug("Hm, line '$line' has no wikiName");
	next;
      }

      # wikiname
      my $wikiName = $fields[2];
      $wikiName =~ s/^\s+//g;
      $wikiName =~ s/\s+$//g;
      next unless $wikiName;
      next if $wikiName =~ /^TWiki/o; # exclude default user

      $wikiName =~ s/^.*?\.(.*)$/$1/g;
      
      next if $excludeNames && $wikiName =~ /$excludeNames/;
      next if $includeNames && $wikiName !~ /$includeNames/;

      # date
      my $date = substr($fields[1], 1, 11);
      $date =~ s/^\s+//g;
      $date =~ s/\s+$//g;
      if ($currentDate ne $date) {
	$currentDate = $date;
	$days++;
      }

      # termination criteria
      if (--$n == 0 || ($theDays && $days > $theDays)) {
	$isDone = 1;
	last;
      }

      # host
      my $host = $fields[6];
      $host =~ s/^\s+//g;
      $host =~ s/\s+$//g;
      next if $host =~ /$ignoreHosts/;
      next if $seen{"$wikiName"};

      # topic
      my $thisTopic = $fields[4];
      $thisTopic =~ s/^\s+//g;
      $thisTopic =~ s/\s+$//g;

      # date, time
      my $time = substr($fields[1], 15, 5);
      my $timeMark = 
	$days * 24 +
	substr($fields[1], 15, 2) * 60 + 
	substr($fields[1], 18, 2);

      # create visitor struct
      my $visitor = {
	'wikiname'=>$wikiName,
	'date'=>$date,
	'time'=>$time,
	'host'=>$host,
	'topic'=>$thisTopic,
      };

      # store
      push @lastVisitors, $visitor;
      $seen{"$wikiName"} = 1;
      $nrVisitors++;
    }
    #writeDebug("found $nrVisitors visitors in file $logFilename");

    last if $isDone;
  }

  return \@lastVisitors;
}



1;

