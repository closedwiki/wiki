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
use vars qw($debug $isInitialized $pubUrlPath);

use strict;
use Digest::MD5 qw(md5_base64);
use Fcntl qw(:flock);
use CGI;

$debug = 0; # toggle me

###############################################################################
sub handleVote {
    my ($session, $params, $topic, $web) = @_;

    unless ($pubUrlPath) {
        $pubUrlPath = TWiki::Func::getPubUrlPath().'/'.TWiki::Func::getTwikiWebname().'/VotePlugin';
    }

    TWiki::Func::addToHEAD('VotePlugin_STARS', <<HEAD);
<link href="$pubUrlPath/voting.css" rel="stylesheet" type="text/css" media="screen" />
<script type='text/javascript' src='$pubUrlPath/voting.js' />
HEAD

    my $id =       $params->{id}      || '_default';
    my $isGlobal = $params->{global}  || 0;
    my $isOpen =   $params->{open}    || 0;

    if (defined TWiki::Func::getCgiQuery()->param('register_vote')) {
      registerVote($web, $topic, $id);
    } else {
      #print STDERR "no register_vote\n";
    }

    my @prompts = ();

    if (defined($params->{select})) {
        push(@prompts, {
            type => 'select',
            name => $params->{select},
            options =>
              [ map { expandVars($_) }
                  split(/\s*,\s*/, $params->{options} || '') ]});
    }
    if (defined($params->{stars})) {
        push(@prompts, {
            type => 'stars',
            name => $params->{stars},
            width => $params->{width} || 5 });
    }

    my $n = 1;
    my $ok = 1;
    while ($ok) {
        $ok = 0;
        if (defined($params->{"select$n"})) {
            push(@prompts, {
                type => 'select',
                name => expandVars($params->{"select$n"}),
                options =>
                  [ map { expandVars($_) }
                      split(/\s*,\s*/, $params->{"options$n"} || '') ]});
            $ok = 1;
        }
        if (defined($params->{"stars$n"})) {
            unless (($params->{"width$n"} || 5) =~ /^\d+$/) {
                return inlineError("Expected integer width for stars$n=");
            }
            push(@prompts, {
                type => 'stars',
                name => $params->{"stars$n"},
                width => $params->{"width$n"} || 5 });
            $ok = 1;
        }
        $n++;
    }

    # check attributes
    if (!scalar(@prompts)) {
        return inlineError("no prompts specified ".$params->stringify());
    }

    # read in the votes
    my $votesFile = getVotesFile($web, $topic, $id, $isGlobal);
    my %votes;

    my %lastVote;
    if (open(VOTES, "<$votesFile")) {
        local $/ = "\n";
        while (my $line = <VOTES>) {
            chomp($line);
            if ($line =~ /^([^\|]+)\|([^\|]+)\|(.*?)\|(.+)$/) {
                my $date = $1;
                my $voter = $2;
                my $weight = $3;
                my $data = $4;
                foreach my $item (split(/\|/, $data)) {
                    if ($item =~ /^(.+)=(.+)$/) {
                        $votes{$voter}{$1}{$2} = $weight;
                        $lastVote{$voter}{$1} = $2;
                    }
                }
            }
        }
        close VOTES;
    }

    # collect statistics
    my %keyValueFreq; # frequency of a specific value for a given key
    my %totalVotes;   # total votes for a given key
    foreach my $voter (keys %votes) {
        print STDERR "voter=$voter\n" if $debug;
        foreach my $key (keys %{$votes{$voter}}) {
            print STDERR "key=$key\n" if $debug;
            foreach my $v (keys %{$votes{$voter}{$key}}) {
                print STDERR "v=$v\n" if $debug;
                my $weight = $votes{$voter}{$key}{$v};
                print STDERR "weight=$weight\n" if $debug;
                $keyValueFreq{$key}{$v} += $weight;
                $totalVotes{$key} += $weight;
            }
        }
    }

    my $needSubmit = $prompts[0]->{type} ne 'stars';

    my $act = TWiki::Func::getScriptUrl($web, $topic, 'viewauth');
    my $rows = '';
    foreach my $prompt (@prompts) {
        my $key = $prompt->{name};
        my $row = CGI::td($key);
        if ($prompt->{type} eq 'stars') {
            # The average is the sum of all the votes cast
            my $sum = 0;
            my $votes = 0;
            foreach my $voter (keys %votes) {
                $sum += $lastVote{$voter}{$key};
                $votes++;
            }
            my $average = ($votes ? $sum / $votes : 0);

            my $totalVoters = 0;
            foreach my $voter (keys %votes) {
                if (defined($votes{$voter}{$key})) {
                    $totalVoters++;
                }
            }
            my $myLastVote =
              $lastVote{getIdent($isOpen)}{$key} || 0;
            $row .= CGI::td(lineOfStars(
                $id, $prompt, $needSubmit, $act,
                $average, $myLastVote, $totalVoters));
        }
        else {
            my $opts = CGI::option({selected=>'selected',
                                    value=>''}, 'Select ...');

            foreach my $optionName (@{$prompt->{options}}) {
                $opts .= CGI::option($optionName);
            }

            $row .= CGI::td(
                CGI::Select({name=>'voteplugin_'.$key,
                             size=>1}, $opts))
              . CGI::td(chartResult(
                  $key, \%keyValueFreq,
                  \%totalVotes, $params));
        }
        $rows .= CGI::Tr($row);
    }
    if ($needSubmit) {
        $rows .= CGI::Tr(CGI::td(
            { colspan => 3},
            CGI::submit(
                { name=> 'OK', value=>'OK',
                  style=>'color:green'})));
    }
    my $result = CGI::table({class=>'twikiTable voteTable'},$rows);
    $result .= CGI::input({type=>'hidden',
                           name=>'register_vote', value=>$id});
    $result .= CGI::input({type=>'hidden',
                           name=>'isGlobal', value=>$isGlobal});
    $result .= CGI::input({type=>'hidden',
                           name=>'isSecret', value=>!$isOpen});

    # why is CGI::form not part of my CGI.pm?
    $result = "<form id='$id' action='$act' method='post'>".$result.'</form>';

    return "<literal>\n$result\n</literal>";
}

###############################################################################
sub chartResult {
    my ($key, $keyValueFreq, $totalVotes, $params) = @_;
    my $color =    $params->{color}   || '';
    my $bgcolor =  $params->{bgcolor} || '';
    my $style =    $params->{style}   || 'bar,perc,total';
    my $width =    $params->{width}   || '300';

    my $rows = '';
    foreach my $value (sort {$keyValueFreq->{$key}{$b} <=>
                               $keyValueFreq->{$key}{$a}}
                         keys %{$keyValueFreq->{$key}}) {
        my $row = CGI::td($value);
        my $freq = $keyValueFreq->{$key}{$value};
        my $perc = int(1000 * $freq / $totalVotes->{$key}) / 10;
        my $totals = '';
        if ($style =~ /perc/) {
            $totals .= "$perc\% ";
        }
        if ($style =~ /total/) {
            $totals .= "($freq)";
        }
        my $data = '';
        if ($style =~ /bar/) {
            my $graph = CGI::img({src=>$pubUrlPath.'/leftbar.gif',
                                  alt=>"leftbar",
                                  height=>"14"});
            $graph .= CGI::img({src=>$pubUrlPath.'/mainbar.gif',
                                alt=>"mainbar",
                                height=>14,
                                width=>($width/100*$perc)});
            $graph .= CGI::img({src=>$pubUrlPath.'/rightbar.gif',
                                  alt=>"leftbar",
                                  height=>"14"});
            $row .= CGI::td({
                style=>'white-space:nowrap;border:0px;'.
                  ($bgcolor ? "background:$bgcolor;" : '').
                    ($color ? "color:$color;" : '')}, $graph);
            $row .= CGI::td({
                align=>"left",
                style=> 'white-space:nowrap;border:0px;'.
                  ($bgcolor ? "background:$bgcolor;" : '').
                    ($color ? "color:$color;" : '')}, $totals);
        } else {
            $row .= CGI::td($totals);
        }
        if ($style =~ /sum/) {
            $row .= CGI::td($totalVotes->{$key}.' votes');
        }
        $rows .= CGI::Tr($row);
    }
    return CGI::table({width => '100%'}, $rows);
}

###############################################################################
sub registerVote {
    my ($web, $topic, $id) = @_;

    #print STDERR "called registerVote()\n";

    # check parameters
    my $query = TWiki::Func::getCgiQuery();

    return unless $id eq $query->param('register_vote');

    my $votesFile = getVotesFile(
        $web, $topic, $id,  $query->param('isGlobal'));

    # open and lock the votes
    open(VOTES, ">>$votesFile") || die "cannot append $votesFile";
    flock(VOTES, LOCK_EX); # wait for exclusive rights
    seek(VOTES, 0, 2); # seek EOF in case someone else appended 
    # stuff while we where waiting

    my $date = getLocaldate();
    my $user = TWiki::Func::getWikiUserName();
    my $isOpen = ($query->param('isSecret'))?0:1;
    my $ident = getIdent($isOpen, $user, $date);
#    $ident = int(rand(100)) 
#      if $debug; # for testing

    # Apply a weighting for the voting user
    my $weightsTopic = TWiki::Func::getPreferencesValue(
        'VOTEPLUGIN_WEIGHTINGS');
    my $weight = 1;
    if ($weightsTopic) {
        my ($wweb, $wtopic) = TWiki::Func::normalizeWebTopicName(
            $web, $weightsTopic);
        if (TWiki::Func::topicExists($wweb, $wtopic)) {
            my ($meta, $text) = TWiki::Func::readTopic($wweb, $wtopic);
            foreach my $line (split(/\n/, $text)) {
                if ($line =~ /^\|\s*(\S+)\s*\|\s*(\d+)\s*\|$/) {
                    ($wweb, $wtopic) =  TWiki::Func::normalizeWebTopicName(
                        undef, $1);
                    if ($user eq "$wweb.$wtopic") {
                        $weight = $2 / 100.0;
                    }
                }
            }
        }
    }

    # write the votes
    print VOTES "$date|$ident|$weight";
    foreach my $key ($query->param()) {
        my $val = $query->param($key);
        next unless $key =~ s/^voteplugin_//;
        print VOTES "|$key=$val";
    }
    print VOTES "\n";

    # unlock and close
    flock(VOTES,LOCK_UN);
    close VOTES;

    # invalidate cache entry
    if (defined &TWiki::Cache::invalidateEntry) {
        TWiki::Cache::invalidateEntry($web, $topic);
    }
}

###############################################################################
sub getVotesFile {
    my ($web, $topic, $id, $global) = @_;

    my $path = TWiki::Func::getWorkArea('VotePlugin');
    my $votesFile = $path.'/'.
      ($global ? '' : "${web}_${topic}_").
        ($id ? "_$id" : '');
    $votesFile = normalizeFileName($votesFile);

    if (! -e $votesFile) {
        my $attachPath = TWiki::Func::getPubDir()."/$web/$topic";
        my $oldVotesFile = "$attachPath/_Votes" . ($id?"_$id":"") . ".txt";

        if (!-e $oldVotesFile ) {
            $oldVotesFile = "$attachPath/Votes" . ($id?"_$id":"") . ".txt";
        }

        if (open(F, "<$oldVotesFile") && open(G, ">$votesFile")) {
            local $/;
            print G <F>;
            close(G); close(F);
            unlink $oldVotesFile;
        }
    }

    return $votesFile;
}

###############################################################################
# wrapper
sub normalizeFileName {
    my $fileName = shift;

    if (defined &TWiki::Sandbox::normalizeFileName) {
        return TWiki::Sandbox::normalizeFileName($fileName);
    }

    if (defined &TWiki::normalizeFileName) {
        return TWiki::normalizeFileName($fileName)
    }

    TWiki::Func::writeWarning("normalizeFileName not found ... you live dangerous");
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
    my $text = shift;
    if( defined( &TWiki::Func::decodeFormatTokens )) {
        $text = TWiki::Func::decodeFormatTokens( $text );
    } else {
        $text =~ s/\$percnt/\%/go;
        $text =~ s/\$dollar/\$/go;
        $text =~ s/\$quote/\'/go;
        $text =~ s/\$n/\n/go;
        $text =~ s/\$doublequote/\"/go;
    }
    return $text;
}

###############################################################################
sub getIdent {
    my ($isOpen, $user, $date) = @_;

    $user ||= TWiki::Func::getWikiUserName();
    $date ||= getLocaldate();

    my $ident = $user;

    $ident = md5_base64("$ENV{REMOTE_ADDR}$user$date") 
      unless $isOpen;

    return $ident;
}

###############################################################################
sub lineOfStars {
    my ($form, $prompt, $needSubmit, $act, $count, $myLast, $total) = @_;
    my $width = 25 * scalar(@_);
    my $row = '';
    for (1..$prompt->{width}) {
        my $class = ($_ > $count) ? 'voteClear' : 'voteSet';
        $row .= CGI::td(CGI::a({
            class=>$class,
            title=>$_,
            href=>"javascript:VotePlugin_clicked('$form', '$prompt->{name}', $_);"}
          ));
    }

    $row .= CGI::td(
        CGI::input(
            {type=>'hidden',
             name => "voteplugin_$prompt->{name}",
             id => "${form}_$prompt->{name}",
             value => $count})
            . CGI::small("My last vote $myLast, Total voters $total"));
    return CGI::table({class=>'voteStarRating'}, CGI::Tr($row));
}

1;

