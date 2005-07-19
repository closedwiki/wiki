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


###############################################################################
package TWiki::Plugins::VotePlugin;    # change the package name and $pluginName!!!

###############################################################################
use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName
        $debug $isInitialized
    );

$VERSION = '1.010';
$pluginName = 'VotePlugin';  # Name of this Plugin

###############################################################################
# debug suite
sub writeDebug 
{
  &TWiki::Func::writeDebug("${pluginName} - $_[0]") if $debug;
}

###############################################################################
# standard plugin initialization
sub initPlugin
{
  ($topic, $web, $user, $installWeb) = @_;

  # check for Plugins.pm versions
  if( $TWiki::Plugins::VERSION < 1 ) {
    TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
    return 0;
  }

  $isInitialized = 0;

  return 1;
}

###############################################################################
# initialize those parts of the plugin that we can delay til we realy need
# the plugin
sub doInit
{
  return if $isInitialized;
  $isInitialized = 1;

  eval {
    use Digest::MD5 qw(md5_base64);
    use Fcntl qw(:flock);
  };

  #$debug = &TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );
  $debug = 0;
}

###############################################################################
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

  $_[0] =~ s/%VOTE{(.*?)%/&handleVote($1)/ge;
}

###############################################################################
# render the VOTE macro
sub handleVote
{
  &doInit();
  &writeDebug("handleVote called");
  my $theAttributes = shift;
  $theAttributes = "" if !$theAttributes;

  my $theId = &TWiki::Func::extractNameValuePair($theAttributes, "id") || "";
  my $theStyle = &TWiki::Func::extractNameValuePair($theAttributes, "style") || "bar";
  my $theWidth = &TWiki::Func::extractNameValuePair($theAttributes, "width") || "200";
  my $theColor = &TWiki::Func::extractNameValuePair($theAttributes, "color") || "lightblue";
  my $theBgColor = &TWiki::Func::extractNameValuePair($theAttributes, "bgcolor") || "lightcyan";
  my $theLimit = &TWiki::Func::extractNameValuePair($theAttributes, "limit") || "-1";

  my @theSelects = ();
  my @theOptions = ();

  push @theSelects, &TWiki::Func::extractNameValuePair($theAttributes, "select1") ||
    &TWiki::Func::extractNameValuePair($theAttributes, "select") || "";
  push @theSelects, &TWiki::Func::extractNameValuePair($theAttributes, "select2") || "";
  push @theSelects, &TWiki::Func::extractNameValuePair($theAttributes, "select3") || "";
  push @theSelects, &TWiki::Func::extractNameValuePair($theAttributes, "select4") || "";
  push @theSelects, &TWiki::Func::extractNameValuePair($theAttributes, "select5") || "";

  push @theOptions, &TWiki::Func::extractNameValuePair($theAttributes, "options1") ||
    &TWiki::Func::extractNameValuePair($theAttributes, "options") || "";
  push @theOptions, &TWiki::Func::extractNameValuePair($theAttributes, "options2") || "";
  push @theOptions, &TWiki::Func::extractNameValuePair($theAttributes, "options3") || "";
  push @theOptions, &TWiki::Func::extractNameValuePair($theAttributes, "options4") || "";
  push @theOptions, &TWiki::Func::extractNameValuePair($theAttributes, "options5") || "";

  # check attributes
  if (!@theOptions) {
    return &TWiki::showError("no options specified");
  }
  if (!@theSelects) {
    return &TWiki::showError("no options for your select specified");
  }
  if ($theStyle !~ /^(bar|perc|total)$/) {
    return &TWiki::showError("unknown style $theStyle");
  }


  # compute the result
  my $result = "<div class=\"Vote\">";

  $result .= "<form action=\"" . &TWiki::Func::getScriptUrlPath() . 
	   "/vote/$web/$topic\" method=\"post\">\n";
  $result .= "<input type=\"hidden\" name=\"id\" value=\"$theId\"/>\n";
  $result .= "<table class=\"VoteSelect\">\n";

  my %selectOptions;
  for (my $i = 0; $theSelects[$i]; $i++) {
    my $selectName = $theSelects[$i];
    my $optionNames = $theOptions[$i];
    next if ! $optionNames;

    $result .= "<tr><td><b>$selectName</b>&nbsp;</td>\n";
    $result .= "<td><select name=\"$selectName\" size=\"1\" style=\"width:90%\">\n";
    $result .= "<option selected value=\"\">Select ...</option>\n";

    foreach my $optionName (split /\s?,\s?/,$optionNames) {
      $selectOptions{$selectName}{$optionName} = 1;
      $result .= "<option>$optionName</option>\n";
    }

    $result .= "</select>\n";
    
    if ($theSelects[$i+1]) {
      $result .= "</td><td>&nbsp;</td></tr>";
    } else {
      $result .= "&nbsp;</td>\n"
	    . "<td><input type=submit value=\"OK\" style=\"color:green\"/></td></tr>\n";
    }
  }

  $result .= "</table></form>\n";
 

  # read in the votes
  my $votesFile = &getVotesFile($theId);
  open(VOTES, "<$votesFile");
  my %votes;
  while (my $line = <VOTES>) {
    chomp($line);
#    &writeDebug("line=$line");
    if ($line =~ /^([^\|]+)\|([^\|]+)\|(.+)$/) {
      my $date = $1;
      my $voter = $2;
      my $data = $3;
      #&writeDebug("date=$date voter=$voter data=$data");
      foreach my $item (split(/\|/, $data)) {
	if ($item =~ /^(.+)=(.+)$/) {
	  if ($selectOptions{$1}{$2}) {
	    $votes{$voter}{$1} = $2;
	  } else {
	    &TWiki::Func::writeWarning("invalid votes key='$1', value='$2' from $ENV{REMOTE_ADDR}, $user");
	  }
	}
      }
    }
  }
  close VOTES;

  # collect statistics
  my %keyValueFreq;
  my %totalVotes;
  foreach my $voter (keys %votes) {
    foreach my $key (keys %{$votes{$voter}}) {
      my $value = $votes{$voter}{$key};
      &writeDebug("voter=$voter, vote for $key is $value");

      # count frequency of a key
      $keyValueFreq{$key}{$value}++;

      # count nr votes for a key
      $totalVotes{$key}++;
    }
  }
  
  # render vote result
  $result .= "<div class=\"VoteResult\"><table><tr><td>\n";#"| *$theId* | *counts* |\n";
  my $isFirst = 1;
  my $n;
  foreach my $key (sort keys %keyValueFreq) {
    if ($isFirst) {
      $isFirst = 0;
    } else {
      $result .= "|||\n";
    }
    $result .= "| *$key* || \n";
    $n = $theLimit;
    foreach my $value (sort {$keyValueFreq{$key}{$b} <=> $keyValueFreq{$key}{$a}} keys %{$keyValueFreq{$key}}) {
      last if $n == 0;
      $n--;
      $result .= "| $value | ";
      $freq = $keyValueFreq{$key}{$value};
      $perc = int(1000 * $freq / $totalVotes{$key}) / 10;
      if ($theStyle eq 'total') {
	$result .= $freq;
      } elsif ($theStyle eq 'bar') {
	$result .= '<table width="' . $theWidth 
	  . '" cellspacing="0" cellpadding="0"><tr>'
	  . '<td style="border:0px" bgcolor="' . $theColor . '"'
	  . 'width="' . ($theWidth/100 * $perc) . '">'
	  . '</td><td bgcolor="' . $theBgColor 
	  . '" style="border:0px" align="right">' . $perc
	  . '</td></tr></table>';
      } else {
	$result .= $perc;
      }
      $result .= " |\n";
    }
    #$result .= "|||\n";
    #$result .= "| total | $totalVotes{$key} |\n";
  }
  $result .= "\n</td></tr></table></div></div>";

  &writeDebug("handleVoteResult done");
  return $result;
}

###############################################################################
# called by the vote cgi
sub vote
{
  &doInit();
  &writeDebug("vote called");

  my $formData = shift;

  # check parameters
  $formData->{id} = "" if ! $formData->{id};
  $formData->{id} =~ s/$TWiki::securityFilter//go;
  $formData->{id} =~ /(.*)/;
  $formData->{id} = $1;  # untaint variable

  # create the attachment directory for this topic
  my $attachPath = &TWiki::Func::getPubDir() . "/$web/$topic";
  my $votesFile = &getVotesFile($formData->{id});
  if(-e $attachPath) {
    die "$attachPath is not a directory" unless -d $attachPath;
  } else {
    mkdir($attachPath) || die "cannot create directory $attachPath";
  }

  # open and lock the votes
  open(VOTES, ">>$votesFile") || die "cannot append $votesFile";
  flock(VOTES, LOCK_EX); # wait for exclusive rights
  seek(VOTES, 0, 2); # seek EOF in case someone else appended 
		     # stuff while we where waiting

  my $date = &getLocaldate();

  if (0) { # for debugging
    $host = int(rand(100)); # for testing
  } else {
    $host = md5_base64("$ENV{REMOTE_ADDR}$user$date");
  }
  
  # write the votes
  print VOTES "$date|$host";
  &writeDebug("keys=" . join(",", keys %{$formData}));
  foreach my $key (keys %{$formData}) {
    next if $key eq "id";
    &writeDebug("$key=$formData->{$key}");
    print VOTES "|$key=$formData->{$key}"
  }
  print VOTES "\n";

  # unlock and close
  flock(VOTES,LOCK_UN);
  close VOTES;
  
  # invalidate cache entry
  my $libDir = &TWiki::getTWikiLibDir();
  if(-e "$libDir/TWiki/Cache.pm" ) {
    &writeDebug("found Cache.pm");
    eval "&TWiki::Cache::invalidateEntry($web, $topic);";
  }
  
  &writeDebug("vote done");
  return 1;
}

###############################################################################
sub getVotesFile
{
  my $id = shift;

  my $attachPath = &TWiki::Func::getPubDir() . "/$web/$topic";
  my $votesFile = "$attachPath/Votes" . ($id?"_$id":"") . ".txt";
  &TWiki::normalizeFileName($votesFile);

  #&writeDebug("attachPath=$attachPath votesFile=$votesFile");

  return $votesFile;
}

###############################################################################
sub getLocaldate
{

  my( $sec, $min, $hour, $mday, $mon, $year) = localtime(time());
  $year = sprintf("%.4u", $year + 1900);  # Y2K fix
  my $date = sprintf("%.2u-%.2u-%.2u", $year, $mon, $mday);
  return $date;
}

1;
