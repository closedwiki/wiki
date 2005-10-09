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

###############################################################################
package TWiki::Plugins::VotePlugin; 

###############################################################################
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE
        $debug $isInitialized
    );

use Digest::MD5 qw(md5_base64);
use Fcntl qw(:flock);

$VERSION = '$Rev$';
$RELEASE = '1.21';

###############################################################################
# debug suite
sub writeDebug {
  &TWiki::Func::writeDebug("VotePlugin - $_[0]") if $debug;
}

###############################################################################
# standard plugin initialization
sub initPlugin {
  ($topic, $web, $user, $installWeb) = @_;

  $isInitialized = 0;
  $debug = 0; # toggle me

  return 1;
}

###############################################################################
sub commonTagsHandler {
  $_[0] =~ s/%VOTE{(.*?)%/&handleVote($1)/geo;
}

###############################################################################
# render the VOTE macro
sub handleVote {
  my $args = shift;
  $args = "" if !$args;
  &writeDebug("called handleVote($args)");

  my $theId = &TWiki::Func::extractNameValuePair($args, 'id') || '';
  my $theStyle = &TWiki::Func::extractNameValuePair($args, 'style') || 'bar,perc,total';
  my $theWidth = &TWiki::Func::extractNameValuePair($args, 'width') || '100%';
  my $theColor = &TWiki::Func::extractNameValuePair($args, 'color') || 'lightblue';
  my $theBgColor = &TWiki::Func::extractNameValuePair($args, 'bgcolor') || 'lightcyan';
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
    return &showError("no options specified");
  }
  if (!@theSelects) {
    return &showError("no options for your select specified");
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
  my $votesFile = &getVotesFile($theId);
  my %votes;
  
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
  $result .= "<div class=\"VoteResult\"><table><tr><td>\n";
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
      if ($theStyle =~ /bar/) {
	$result .= '<table width="' . $theWidth 
	  . '" cellspacing="0" cellpadding="0"><tr>'
	  . '<td style="border:0px" bgcolor="' . $theColor . '" '
	  . 'width="' . ($theWidth/100 * $perc) . '">'
	  . '</td><td bgcolor="' . $theBgColor 
	  . '" style="border:0px" align="right">';
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
  &writeDebug("vote called");

  my $formData = shift;

  # check parameters
  $formData->{id} = "" if ! $formData->{id};
  $formData->{id} = &securityFilter($formData->{id});

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

  if (1) { # for debugging
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
sub getVotesFile
{
  my $id = shift;

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
sub showError {
  my $msg = shift;
  return "<span class=\"twikiAlert\">Error: $msg</span>" ;
}

###############################################################################
sub expandVars {
  $_[0] =~ s/\$percnt/\%/go;
  $_[0] =~ s/\$dollar/\$/go;
  $_[0] =~ s/\$quote/\'/go;
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
