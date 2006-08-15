# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005-2006 Michael Daum <micha@nats.informatik.uni-hamburg.de>
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

###############################################################################
package TWiki::Plugins::VotePlugin::Core; 

###############################################################################
use vars qw($debug $isInitialized);

use strict;
use Digest::MD5 qw(md5_base64);
use Fcntl qw(:flock);

$debug = 0; # toggle me

###############################################################################
sub writeDebug {
  &TWiki::Func::writeDebug("VotePlugin - $_[0]") if $debug;
}

###############################################################################
sub handleVote {
  my ($web, $topic, $args) = @_;

  $args = '' unless $args;
  &writeDebug("called handleVote($args)");

  my $theId = &TWiki::Func::extractNameValuePair($args, 'id') || '';
  my $theStyle = &TWiki::Func::extractNameValuePair($args, 'style') || 'bar,perc,total';
  my $theWidth = &TWiki::Func::extractNameValuePair($args, 'width') || '300';
  my $theColor = &TWiki::Func::extractNameValuePair($args, 'color') || '';
  my $theBgColor = &TWiki::Func::extractNameValuePair($args, 'bgcolor') || '';
  my $theLimit = &TWiki::Func::extractNameValuePair($args, 'limit') || '-1';

  my @theSelects = ();
  my @theOptions = ();

  my $tmp = &TWiki::Func::extractNameValuePair($args, 'select1') ||
	 &TWiki::Func::extractNameValuePair($args, 'select');
  push @theSelects, $tmp if $tmp;
  $tmp = &TWiki::Func::extractNameValuePair($args, 'select2');
  push @theSelects, $tmp if $tmp;
  $tmp = &TWiki::Func::extractNameValuePair($args, 'select3');
  push @theSelects, $tmp if $tmp;
  $tmp = &TWiki::Func::extractNameValuePair($args, 'select4');
  push @theSelects, $tmp if $tmp;
  $tmp = &TWiki::Func::extractNameValuePair($args, 'select5');
  push @theSelects, $tmp if $tmp;

  $tmp = &TWiki::Func::extractNameValuePair($args, 'options1') ||
	 &TWiki::Func::extractNameValuePair($args, 'options');
  push @theOptions, $tmp if $tmp;
  $tmp = &TWiki::Func::extractNameValuePair($args, 'options2');
  push @theOptions, $tmp if $tmp;
  $tmp = &TWiki::Func::extractNameValuePair($args, 'options3');
  push @theOptions, $tmp if $tmp;
  $tmp = &TWiki::Func::extractNameValuePair($args, 'options4');
  push @theOptions, $tmp if $tmp;
  $tmp = &TWiki::Func::extractNameValuePair($args, 'options5');
  push @theOptions, $tmp if $tmp;

  # check attributes
  if (!@theOptions) {
    return &inlineError("no options specified");
  }
  if (!@theSelects) {
    return &inlineError("no options for your select specified");
  }

  # compute the result
  my $result = "<div class=\"Vote\">";

  $result .= "<form action=\"" . &TWiki::Func::getScriptUrl($web, $topic, 'vote') 
    . "\" method=\"post\">\n";
  $result .= "<input type=\"hidden\" name=\"id\" value=\"$theId\"/>\n";
  $result .= "<table class=\"VoteSelect\">\n";

  my %selectOptions;
  for (my $i = 0; $theSelects[$i]; $i++) {
    my $selectName = $theSelects[$i];
    my $optionNames = $theOptions[$i];
    next if ! $optionNames;
    &expandVars($selectName);
    &expandVars($optionNames);

    $result .= "<tr><td><b>$selectName</b>&nbsp;</td>\n";
    $result .= "<td><select name=\"$selectName\" size=\"1\">\n";
    $result .= "<option selected value=\"\">Select ...</option>\n";

    foreach my $optionName (split /\s?,\s?/,$optionNames) {
      writeDebug("setting selectOptions{$selectName}{$optionName}");
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

  # do some common substitutions
  &expandVars($result);
 

  # read in the votes
  my $votesFile = &getVotesFile($web, $topic, $theId);
  my %votes;
  
  my $user = &TWiki::Func::getWikiUserName();

  if (open(VOTES, "<$votesFile")) {
    while (my $line = <VOTES>) {
      chomp($line);
  #    &writeDebug("line=$line");
      if ($line =~ /^([^\|]+)\|([^\|]+)\|(.+)$/) {
	my $date = $1;
	my $voter = $2;
	my $data = $3;
	#&writeDebug("date=$date voter=$voter data=$data");
	foreach my $item (split(/\|/, $data)) {
	  #writeDebug("item=$item");
	  if ($item =~ /^(.+)=(.+)$/) {
	    #writeDebug("key=$1, value=$2");
	    if ($selectOptions{$1}{$2}) {
	      $votes{$voter}{$1} = $2;
	    } else {
	      #&writeDebug("invalid votes key='$1', value='$2'");
	      &TWiki::Func::writeWarning("invalid votes key='$1', value='$2' from $ENV{REMOTE_ADDR}, $user");
	    }
	  }
	}
      }
    }
    close VOTES;
  }

  # collect statistics
  my %keyValueFreq;
  my %totalVotes;
  foreach my $voter (keys %votes) {
    foreach my $key (keys %{$votes{$voter}}) {
      my $value = $votes{$voter}{$key};
      #&writeDebug("voter=$voter, vote for $key is $value");

      # count frequency of a key
      $keyValueFreq{$key}{$value}++;

      # count nr votes for a key
      $totalVotes{$key}++;
    }
  }
  
  # render vote result
  $result .= '<div class="VoteResult">'
    .'<table border="0" cellpadding="0" cellspacing="0" '
    .'width="' . $theWidth .'"><tr><td>'."\n";
  my $isFirst = 1;
  my $n;
  $theWidth = ($theWidth-28)*0.6;
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
      my $freq = $keyValueFreq{$key}{$value};
      my $perc = int(1000 * $freq / $totalVotes{$key}) / 10;
      if ($theStyle =~ /bar/) {
	$result .= '<table width="100%" cellspacing="0" cellpadding="0" border="0"><tr>'
	  . '<td style="white-space:nowrap;border:0;'
	  . ($theBgColor?'background:'.$theBgColor.'; ':'')
	  . ($theColor?'color:'.$theColor.'; ':'')
	  . '">'
	  . '<img src="%PUBURLPATH%/%TWIKIWEB%/VotePlugin/leftbar.gif" alt="leftbar" height="14"/>'
	  . '<img src="%PUBURLPATH%/%TWIKIWEB%/VotePlugin/mainbar.gif" alt="mainbar" height="14" width="'
	  . ($theWidth/100*$perc) . '" />' 
	  . '<img src="%PUBURLPATH%/%TWIKIWEB%/VotePlugin/rightbar.gif" alt="rightbar" height="14" />'
	  . '</td>'
	  . '<td align="right" style="white-space:nowrap;border:0;'
	  . ($theBgColor?'background:'.$theBgColor.'; ':'')
	  . ($theColor?'color:'.$theColor.'; ':'')
	  . '">';
	if ($theStyle =~ /perc/) {
	  $result .= "$perc\%";
	  if ($theStyle =~ /total/) {
	    $result .= "&nbsp;($freq)";
	  }
	} elsif ($theStyle =~ /total/) {
       	  $result .= "$freq";
	} else {
	  $result .= '&nbsp;';
	}
	$result .= '</td></tr></table>';
      } elsif ($theStyle =~ /perc/) {
	$result .= $perc . '%';
	if ($theStyle =~ /total/) {
	  $result .= "&nbsp;($freq)";
	}
      } else {
	$result .= $freq;
      }
      $result .= " |\n";
    }
    if ($theStyle =~ /sum/) {
      $result .= "|||\n";
      $result .= "|  $totalVotes{$key} votes ||\n";
    }
  }
  $result .= "\n</td></tr></table></div></div>";

  &writeDebug("handleVoteResult done");
  return $result;
}

###############################################################################
# called by the vote cgi
sub vote {
  my ($web, $topic, $formData) = @_;
  
  &writeDebug("vote called");


  # check parameters
  $formData->{id} = "" if ! $formData->{id};
  $formData->{id} = &securityFilter($formData->{id});

  # create the attachment directory for this topic
  my $attachPath = &TWiki::Func::getPubDir() . "/$web/$topic";
  my $votesFile = &getVotesFile($web, $topic, $formData->{id});
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
  my $user = &TWiki::Func::getWikiUserName();
  my $host;
  if ($debug) {
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
  if (defined &TWiki::Cache::invalidateEntry) {
    &writeDebug("found Cache");
    &TWiki::Cache::invalidateEntry($web, $topic);
  }
  
  &writeDebug("vote done");
}

###############################################################################
sub getVotesFile {
  my ($web, $topic, $id) = @_;

  my $attachPath = &TWiki::Func::getPubDir() . "/$web/$topic";
  my $votesFile = "$attachPath/_Votes" . ($id?"_$id":"") . ".txt";
  $votesFile = &normalizeFileName($votesFile);

  # to upgrade smoothly
  my $oldVotesFile = "$attachPath/Votes" . ($id?"_$id":"") . ".txt";
  $oldVotesFile = &normalizeFileName($oldVotesFile);
  #writeDebug("oldVotesFile=$oldVotesFile, newVotesFile=$votesFile");

  if (-e $oldVotesFile && ! -e $votesFile) {
    &TWiki::Func::writeWarning("renamed old votes file '$oldVotesFile' to '$votesFile'");
    rename $oldVotesFile, $votesFile;
  }

  return $votesFile;
}

###############################################################################
# wrapper
sub normalizeFileName {
  my $fileName = shift;

  if (defined &TWiki::Sandbox::normalizeFileName) {
    writeDebug("using TWiki::Sandbox::normalizeFileName");
    return &TWiki::Sandbox::normalizeFileName($fileName);
  }

  if (defined &TWiki::normalizeFileName) {
    writeDebug("using TWiki::normalizeFileName");
    return &TWiki::normalizeFileName($fileName)
  }
  
  &TWiki::Func::writeWarning("normalizeFileName not found ... you live dangerous");
  return $fileName;
}


###############################################################################
sub getLocaldate {

  my( $sec, $min, $hour, $mday, $mon, $year) = localtime(time());
  $year = sprintf("%.4u", $year + 1900);  # Y2K fix
  my $date = sprintf("%.2u-%.2u-%.2u", $year, $mon, $mday);
  return $date;
}

###############################################################################
sub inlineError {
  return '<span class="twikiAlert">Error: '.$_[0].'</span>';
}

###############################################################################
sub expandVars {
  $_[0] =~ s/\$percnt/\%/go;
  $_[0] =~ s/\$dollar/\$/go;
  $_[0] =~ s/\$quote/\'/go;
  $_[0] =~ s/\$n/\n/go;
  $_[0] =~ s/\$doublequote/\"/go;
}

###############################################################################
sub securityFilter {
  my $string = shift;
  
  if (defined $TWiki::securityFilter) {
    $string =~ s/$TWiki::securityFilter//go
  } elsif (defined $TWiki::cfg{NameFilter}) {
    $string =~ s/$TWiki::cfg{NameFilter}//go
  }

  $string =~ /(.*)/;
  $string = $1; # untaint
  return $string;
}

1;

