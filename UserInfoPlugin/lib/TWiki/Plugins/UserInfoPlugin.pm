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

package TWiki::Plugins::UserInfoPlugin;
use Date::Parse; # for str2time
use strict;

###############################################################################
use vars qw(
	$web $topic $user $installWeb $VERSION $debug @currentVisitors 
	$isDakar $twikiGuest @isoMonth
	$ignoreHosts $isInitialized $isOldSessionPlugin
);

$VERSION = '1.1';

###############################################################################
sub writeDebug {
  &TWiki::Func::writeDebug("- UserInfoPlugin - " . $_[0]) if $debug;
}


###############################################################################
sub initPlugin {
  ($topic, $web, $user, $installWeb) = @_;

  # check for Plugins.pm versions
  if ($TWiki::Plugins::VERSION < 1) {
    &TWiki::Func::writeWarning ("Version mismatch between UserInfoPlugin and Plugins.pm");
    return 0;
  }

  $debug = 0;
  $isInitialized = 0;

  # Plugin correctly initialized
  #&writeDebug("initPlugin ($web.$topic) is OK");

  return 1;
}

###############################################################################
sub doInit {

  return if $isInitialized;
  $isInitialized = 1;
  
  # find out if we run dakar or not
  $isDakar = (defined $TWiki::cfg{MimeTypesFileName})?1:0;
  writeDebug("isDakar=$isDakar");

  # get twiki guest string
  $twikiGuest = &TWiki::Func::getDefaultUserName();
  $twikiGuest = &TWiki::Func::userToWikiName($twikiGuest, 1);

  # init globals
  @isoMonth = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'); 
  @currentVisitors = ();

  # get spiders
  $ignoreHosts = TWiki::Func::getPreferencesValue("USERINFOPLUGIN_IGNOR_HOSTS") || '';
  $ignoreHosts = join('|', split(/,\s?/, $ignoreHosts));

  # get version of the SessionPlugin
  use TWiki::Plugins::SessionPlugin;
  my $sessionPluginVersion = $TWiki::Plugins::SessionPlugin::VERSION;
  $isOldSessionPlugin = ($sessionPluginVersion < 2.0)?1:0;
  writeDebug("sessionPluginVersion=$sessionPluginVersion, isOldSessionPlugin=$isOldSessionPlugin");
  

  writeDebug("doInit() done");
}

###############################################################################
sub commonTagsHandler {

  $_[0] =~ s/%VISITORS%/&renderCurrentVisitors()/ge;
  $_[0] =~ s/%VISITORS{(.*?)}%/&renderCurrentVisitors($1)/ge;
  $_[0] =~ s/%NRVISITORS%/&getNrVisitors()/ge;

  $_[0] =~ s/%LASTVISITORS%/&renderLastVisitors()/ge;
  $_[0] =~ s/%LASTVISITORS{(.*?)}%/&renderLastVisitors($1)/ge;
  $_[0] =~ s/%NRLASTVISITORS%/&getNrLastVisitors()/ge;
  $_[0] =~ s/%NRLASTVISITORS{(.*?)}%/&getNrLastVisitors($1)/ge;

  $_[0] =~ s/%NRUSERS%/&getNrUsers()/ge;
  $_[0] =~ s/%NRGUESTS%/&getNrGuests()/ge;

  $_[0] =~ s/%NEWUSERS%/&renderNewUsers()/ge;
  $_[0] =~ s/%NEWUSERS{(.*?)}%/&renderNewUsers($1)/ge;

}

###############################################################################
# SMELL: this only works for htpasswd authenticated installations
sub getNrUsers {

  &doInit();
  
  my $htpasswdFilename = &TWiki::Func::getDataDir() . "/.htpasswd";
  my $passwds = &TWiki::Func::readFile($htpasswdFilename);
  my @lines = grep {!/$twikiGuest/} split("\n", $passwds);
  return scalar(@lines);
}

###############################################################################
sub getNrVisitors {
  &doInit();

  writeDebug("getNrVisitors()");
  my ($visitors) = &getCurrentVisitors(undef, $twikiGuest);
  return scalar @$visitors;
}

###############################################################################
sub getNrGuests {
  &doInit();

  writeDebug("getNrGuests()");
  my (undef, $guests) = &getCurrentVisitors($twikiGuest);
  return scalar @$guests;
}

###############################################################################
sub getNrLastVisitors {
  my $attributes = shift;

  $attributes = '' unless $attributes;
  &doInit();

  writeDebug("getNrLastVisitors($attributes)");

  my $theDays = TWiki::Func::extractNameValuePair($attributes, "days") || 1;
  my $visitors = &getVisitors($theDays, undef, undef, $twikiGuest);

  return scalar @$visitors;
}

###############################################################################
sub renderCurrentVisitors {
  my $attributes = shift;

  $attributes = '' unless $attributes;

  writeDebug("renderCurrentVisitors($attributes)");
  
  &doInit();

  my $theFormat = &TWiki::Func::extractNameValuePair($attributes, "format") ||
    "\t* \$wikiusername";
  my $theSep = &TWiki::Func::extractNameValuePair($attributes, "sep") || '$n';
  my $theMax = &TWiki::Func::extractNameValuePair($attributes, "max") || 0;
  $theMax = 0 if $theMax eq "unlimited";
  
  my $result = "";
  my $isFirst = 1;
  my $n = $theMax;
  my $counter = 1;
  my ($visitors) = &getCurrentVisitors(undef, $twikiGuest);
  return "" if !@$visitors;
  $visitors = join('|', @$visitors);
  $visitors = &getVisitors(1, undef, $visitors, $twikiGuest);
  foreach my $visitor (sort {$a->{wikiname} cmp $b->{wikiname}} @$visitors) {
    last if --$n == 0;
    my $text;
    if ($isFirst) {
      $isFirst = 0;
      $text = $theFormat;
    } else {
      $text = $theSep . $theFormat;
    }
    $result .= &replaceVars($text, {
      'counter'=>$counter++,
      'wikiname'=>$visitor->{wikiname}, 
      'date'=>$visitor->{date},
      'time'=>$visitor->{time},
      'host'=>$visitor->{host},
      'topic'=>$visitor->{topic},
    });
  }
  
  return $result;
}

###############################################################################
# renderNewUsers: render list of 10 most recently registered users.
# this information is extracted from %MAINWEB%.TWikiUsers
sub renderNewUsers
{
  my $attributes = shift;

  $attributes = '' unless $attributes;
  &doInit();

  my $theFormat = &TWiki::Func::extractNameValuePair($attributes, "format") ||
    "\t* \$date: \$wikiusername";
  my $theSep = &TWiki::Func::extractNameValuePair($attributes, "sep") || '$n';
  my $theMax = &TWiki::Func::extractNameValuePair($attributes, "max") || 10;
  $theMax = 0 if $theMax eq "unlimited";

  my $wikiUsersTopicname = ($isDakar)?$TWiki::cfg{UsersTopicName}:$TWiki::wikiUsersTopicname;
  writeDebug("wikiUsersTopicname=$wikiUsersTopicname");

  my(undef, $topicText) = 
    &TWiki::Func::readTopic(&TWiki::Func::getMainWebname(), $wikiUsersTopicname);

  my %users = ();
  foreach my $line ( split( /\n/, $topicText) ) {
    #writeDebug("line=$line");
    next unless $line =~ m/[\t|(?: {3})]\*\s([A-Z][a-zA-Z0-9]+)\s\-\s(?:(.*)\s\-\s)?(.*)/;
    my $name = $1;
    my $date = $3;
    next if $name eq $twikiGuest;
    next if $name eq 'ListOfWikiNames'; # dakar hack
    push @{$users{$date}}, $name;
  }
  
  my $n = $theMax;
  my $counter = 1;
  my $result = "";
  my $isFirst = 1;
  foreach my $date (reverse sort { str2time($a) <=> str2time($b)} keys %users) {
    foreach my $wikiName (sort @{$users{$date}}) {
      last if --$n == 0;
      my $text;
      if ($isFirst) {
	$isFirst = 0;
	$text = $theFormat;
      } else {
	$text = $theSep . $theFormat;
      }
      $result .= &replaceVars($text, {
        counter=>$counter++,
	wikiname=>$wikiName, 
	date=>$date,
      });
    }
    last if $n == 0;
  }

  return $result;
}

###############################################################################
# get list of users currently online.
# this is the number of session objects
sub getCurrentVisitors {

  my ($includeNames, $excludeNames) = @_;

  writeDebug("getCurrentVisitors()");
  writeDebug("includeNames=$includeNames") if $includeNames;
  writeDebug("excludeNames=$excludeNames") if $excludeNames;

  # get session directory
  my $sessionDir = &TWiki::Func::getDataDir() . "/.session";

  if (! -e $sessionDir) {
    writeDebug("sessionDir '$sessionDir' not found");
    return ();
  }

  # get wikinames of current visitors
  my %users = ();
  my %guests = ();
  my @sessionFiles = reverse glob "$sessionDir/*";
  foreach my $sessionFile (@sessionFiles) {

    #writeDebug("reading $sessionFile");
  
    my $dump = &TWiki::Func::readFile($sessionFile);
    next if ! $dump;

    my $wikiName;
    my $host;
    if ($isOldSessionPlugin) {
      my %sessionInfo = map { split( /\|/, $_, 2 ) }
		     grep { /[^\|]*\|[^\|]*$/ }
		     split( /\n/, $dump );

      $wikiName = $sessionInfo{"user"} || $twikiGuest;
      $host = $sessionInfo{"host"};
    } else {
      $wikiName = $twikiGuest;
      if ($dump =~ /"AUTHUSER" => "(.*?)"/) {
	$wikiName = $1;
      }
      if ($dump =~ /"_SESSION_REMOTE_ADDR" => "(.*?)"/) {
	$host = $1;
      }
    }
    if ($host) {
      next if $host =~ /$ignoreHosts/;
      $guests{$host} = 1 if $wikiName eq $twikiGuest;
    }
    next if $users{$wikiName};
    next if $excludeNames && $wikiName =~ /$excludeNames/;
    writeDebug("found $wikiName");
    next if $includeNames && $wikiName !~ /$includeNames/;

    $users{$wikiName} = 1;
  }

  my @users = keys %users;
  my @guests = keys %guests;

  return (\@users, \@guests);
}

###############################################################################
sub getVisitors {

  my ($theDays, $theMax, $includeNames, $excludeNames) = @_;

  $theMax = 0 unless $theMax;

  writeDebug("getVisitors()");
  #writeDebug("theDays=$theDays") if $theDays;
  writeDebug("theMax=$theMax") if $theMax;
  writeDebug("includeNames=$includeNames") if $includeNames;
  writeDebug("excludeNames=$excludeNames") if $excludeNames;
  

  # get the logfile mask
  my $logFileGlob = ($isDakar)?$TWiki::cfg{LogFileName}:$TWiki::logFilename;

  $logFileGlob =~ s/%DATE%/*/g;
  
  # go through the logfiles and collect visitor data
  my $isDone = 0;
  my $days = 0;
  my $n = $theMax;
  my $currentDate = '';
  my @logFiles = reverse glob $logFileGlob;
  my @lastVisitors = ();
  foreach my $logFilename (@logFiles) {
    writeDebug("reading $logFilename");

    # read one logfile
    my $fileContents = TWiki::Func::readFile($logFilename);
    
    # analysis
    my %seen = ();
    my $nrVisitors = 0;
    foreach my $line (reverse split(/\n/, $fileContents)) {
      my @fields = split(/\|/, $line);
      if (!$fields[2]) {
	writeDebug("Hm, line '$line' has no wikiName");
	next;
      }

      # wikiname
      my $wikiName = $fields[2];
      $wikiName =~ s/^\s+//g;
      $wikiName =~ s/\s+$//g;
      next unless $wikiName;

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
    writeDebug("found $nrVisitors visitors in file $logFilename");

    last if $isDone;
  }

  return \@lastVisitors;
}

###############################################################################
sub renderLastVisitors {
  my $attributes = shift;

  $attributes = '' unless $attributes;
  &doInit();

  writeDebug("renderLastVisitors($attributes)");

  my $theFormat = TWiki::Func::extractNameValuePair($attributes, "format" ) ||
    "\t* \$date: \$wikiusername";
  my $theSep = TWiki::Func::extractNameValuePair($attributes, "sep" ) || '$n';
  my $theMax = TWiki::Func::extractNameValuePair($attributes, "max") || 0;
  $theMax = 0 if $theMax eq "unlimited";
  my $theDays = TWiki::Func::extractNameValuePair($attributes, "days") || 1;

  my $visitors = &getVisitors($theDays, $theMax, undef, $twikiGuest);

  # garnish the collected data
  my $result = '';
  my $isFirst = 1;
  my $counter = 1;
  foreach my $visitor (sort {$a->{wikiname} cmp $b->{wikiname}} @$visitors) {
    my $text;
    if ($isFirst) {
      $isFirst = 0;
      $text = $theFormat;
    } else {
      $text = $theSep . $theFormat;
    }
    $result .= &replaceVars($text, {
      'counter'=>$counter++,
      'wikiname'=>$visitor->{wikiname}, 
      'date'=>$visitor->{date},
      'time'=>$visitor->{time},
      'host'=>$visitor->{host},
      'topic'=>$visitor->{topic},
    });
  }
  
  return $result;
}

###############################################################################
sub replaceVars {
  my ($format, $data) = @_;

  #writeDebug("replaceVars($format, data)");

  if (defined $data) {
    if (defined $data->{wikiname}) {
      $data->{username} = &TWiki::Func::wikiToUserName($data->{wikiname});
      $data->{wikiusername} = &TWiki::Func::getMainWebname() . '.' . $data->{wikiname};
    }

    foreach my $key (keys %$data) {
      $format =~ s/\$$key/$data->{$key}/g;
    }
  }

  $format =~ s/\$n\b/\n/g;
  $format =~ s/\$quot\b/\"/gos;
  $format =~ s/\$percnt\b/\%/gos;
  $format =~ s/\$dollar\b/\$/gos;

  #writeDebug("returns '$format'");

  return $format;
}


1;

