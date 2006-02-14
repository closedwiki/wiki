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

# ######################################################################################
package TWiki::Plugins::UserInfoPlugin::Render ;

use vars qw(
	$twikiGuest 
);
BEGIN {
  # get twiki guest string
  $twikiGuest = &TWiki::Func::getDefaultUserName();
};

###############################################################################
sub renderCurrentVisitors {
  my $attributes = shift;
  require TWiki::Contrib::CommonCode;

  $attributes = '' unless $attributes;

  #writeDebug("renderCurrentVisitors($attributes)");
  
  my $theFormat = &TWiki::Func::extractNameValuePair($attributes, "format") ||
    "\t* \$wikiusername";
  my $theSep = &TWiki::Func::extractNameValuePair($attributes, "sep") || '$n';
  my $theMax = &TWiki::Func::extractNameValuePair($attributes, "max") || 0;
  $theMax = 0 if $theMax eq "unlimited";
  
  my $result = "";
  my $isFirst = 1;
  my $n = $theMax;
  my $counter = 1;
  my ($visitors) = &TWiki::Plugins::UserInfoPlugin::Get::getVisitorsFromSessionStore(undef, $twikiGuest);
  return "" if !@$visitors;
  $visitors = join('|', @$visitors);
  $visitors = &TWiki::Plugins::UserInfoPlugin::Get::getVisitors(1, undef, $visitors, $twikiGuest);
  foreach my $visitor (sort {$a->{wikiname} cmp $b->{wikiname}} @$visitors) {
    last if --$n == 0;
    my $text;
    if ($isFirst) {
      $isFirst = 0;
      $text = $theFormat;
    } else {
      $text = $theSep . $theFormat;
    }
    $result .= TWiki::Contrib::CommonCode::replaceVars($text, {
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

  my $theFormat = &TWiki::Func::extractNameValuePair($attributes, "format") ||
    "\t* \$date: \$wikiusername";
  my $theSep = &TWiki::Func::extractNameValuePair($attributes, "sep") || '$n';
  my $theMax = &TWiki::Func::extractNameValuePair($attributes, "max") || 10;
  $theMax = 0 if $theMax eq "unlimited";

  my $wikiUsersTopicname = $TWiki::cfg{UsersTopicName};
  #writeDebug("wikiUsersTopicname=$wikiUsersTopicname");

  my(undef, $topicText) = 
    &TWiki::Func::readTopic(&TWiki::Func::getMainWebname(), $wikiUsersTopicname);

  my %users = ();
  my %date = ();
  my $ddate;
  foreach my $line ( split( /\n/, $topicText) ) {
	  # writeDebug("line=$line");
    next unless $line =~ m/[\t|(?: {3})]\*\s([A-Z][a-zA-Z0-9]+)\s\-\s(?:(.*)\s\-\s)?(.*)/;
    my $name = $1;
    next if $name eq $twikiGuest;  # have this early to avoid a lot of assigns
    next if $name eq 'ListOfWikiNames'; # dakar hack
    my $sdate = $3;
	    $ddate = TWiki::Time::parseTime("$sdate - 00:00");
	    # sadly this bombs on 01 Jan 1900  
    push @{$users{$ddate}}, $name;
    $date{$name} = $sdate;  # Save string form so don't have to convert
  }
  
  my $n = $theMax;
  my $counter = 1;
  my $result = "";
  my $isFirst = 1;
  foreach my $ddate (reverse sort { $a <=> $b} keys %users) {
    foreach my $wikiName (sort @{$users{$ddate}}) {
      last if --$n == 0;
      my $text;
      if ($isFirst) {
	$isFirst = 0;
	$text = $theFormat;
      } else {
	$text = $theSep . $theFormat;
      }
      $result .= TWiki::Plugins::CommonCode::replaceVars($text, {
        counter=>$counter++,
	wikiname=>$wikiName, 
	date=>$date{$wikiName}  # could have used TWiki::Time::formatTime
      });
    }
    last if $n == 0;
  }

  return $result;
}

###############################################################################
sub renderLastVisitors {
  my $attributes = shift;

  $attributes = '' unless $attributes;

  #writeDebug("renderLastVisitors($attributes)");

  my $theFormat = TWiki::Func::extractNameValuePair($attributes, "format" ) ||
    "\t* \$date: \$wikiusername";
  my $theSep = TWiki::Func::extractNameValuePair($attributes, "sep" ) || '$n';
  my $theMax = TWiki::Func::extractNameValuePair($attributes, "max") || 0;
  $theMax = 0 if $theMax eq "unlimited";
  my $theDays = TWiki::Func::extractNameValuePair($attributes, "days") || 1;

  my $visitors = &TWiki::Plugins::UserInfoPlugin::Get::getVisitors($theDays, $theMax, undef, $twikiGuest);

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
    $result .= TWiki::Plugins::CommonCode::replaceVars($text, {
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


1;

