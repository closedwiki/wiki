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
<script type='text/javascript' src='$pubUrlPath/voting.js'></script>
HEAD

    my $defaults = TWiki::Func::getPreferencesValue('VOTEPLUGIN_DEFAULTS')
      || '';

    while ($defaults =~ s/^\s*(\w+)=\"(.*?)\"//) {
        $params->{$1} = $2 unless defined $params->{$1};
    }

    my $id =       defined($params->{id}) ? $params->{id} : '_default';
    my $isGlobal = isTrue($params->{global}, 0);
    my $isOpen =   isTrue($params->{open}, 1);
    my $isSecret = isTrue($params->{secret}, 1);
    my $bayesian = isTrue($params->{bayesian}, 0);

    my $saveto =   $params->{saveto};

    if (defined TWiki::Func::getCgiQuery()->param('register_vote')) {
        registerVote($web, $topic, $id);
    } else {
        #print STDERR "no register_vote\n";
    }

    my @prompts = ();

    my $defaultStarsFormat =
      '| $key | $small<small>Score: $score, My vote: $mylast, Total votes: $sum</small> |';
    my $defaultSelectFormat =  '| $key | $prompt | $bars |';
    my $defaultChartFormat = '<div>$bar(300) $option $perc% ($score)</div>';

    if (defined($params->{style})) {
        # Compatibility
        my $format = '';
        if ($params->{style} =~ /perc/) {
            $format .= '$perc% ';
        }
        if ($params->{style} =~ /total/) {
            $format .= '($freq)';
        }
        if ($params->{style} =~ /sum/) {
            $format .= '$sum votes';
        }
        $defaultSelectFormat = $format;
    }
    my $separator = $params->{separator} || "\n";

    # Compatibility
    if (defined($params->{select})) {
        push(@prompts, {
            type => 'select',
            name => expandFormattingTokens($params->{select}),
            format => $defaultSelectFormat,
            options =>
              [ map { expandFormattingTokens($_) }
                  split(/\s*,\s*/, $params->{options} || '') ]});
    }

    my $n = 1;
    while (1) {
        if (defined($params->{"select$n"})) {
            push(@prompts, {
                type => 'select',
                name => expandFormattingTokens($params->{"select$n"}),
                format => $params->{"format$n"} || $defaultSelectFormat,
                chart => $params->{"chart$n"} || $defaultChartFormat,
                options =>
                  [ map { expandFormattingTokens($_) }
                      split(/\s*,\s*/, $params->{"options$n"} || '') ]});
        } elsif (defined($params->{"stars$n"})) {
            unless (($params->{"width$n"} || 5) =~ /^\d+$/) {
                return inlineError("Expected integer width for stars$n=");
            }
            push(@prompts, {
                type => 'stars',
                name => $params->{"stars$n"},
                format => $params->{"format$n"} || $defaultStarsFormat,
                width => $params->{"width$n"} || 5 });
        } else {
            last;
        }
        $n++;
    }

    # check attributes
    if (!scalar(@prompts)) {
        return inlineError("no prompts specified ".$params->stringify());
    }

    # read in the votes
    my $lines = getVoteData($web, $topic, $id, $isGlobal, $saveto);
    my %votes;

    my %lastVote;
    foreach my $line (split/\r?\n/, $lines) {
        if ($line =~ /^\|(.*)\|$/) {
            my @data = split(/\|/, $1);
            my $vid = $data[0];
            my $voter = $data[1];
            my $weight = $data[2];
            foreach my $item (split(/,/, $data[3] || '')) {
                if ($item =~ /^(.+)=(.+)$/) {
                    my ($row, $choice) = ($1, $2);
                    $votes{$voter}{$vid}{$row} = [ $choice, $weight ];
                }
            }
        } elsif (!$saveto && $line =~ /^([^\|]+)\|([^\|]+)\|(.*?)\|(.+)$/) {
            # Old format - compatibility only
            my $voter = $2;
            my $weight = $3;
            my $data = $4;
            foreach my $item (split(/\|/, $data)) {
                if ($item =~ /^(.+)=(.+)$/) {
                    my ($row, $choice) = ($1, $2);
                    $votes{$voter}{$id}{$row} = [ $choice, $weight ];
                }
            }
        }
    }

    # Terminology:
    # An =id= is the identifier of a %VOTE
    # A =key= is the identifier of a vote row e.g. stars="" or select=""
    # A =choice= is the identified of one of the options in a key

    # collect statistics. This is complicated by the fact that we
    # have top level keys (represented by $key) which can receive
    # a rating for lines of stars, and also individual values in a
    # select, each of which has its own frequency. For the purposes
    # of this analysis, a line of stars is treated as having a single
    # leaf value, so the frequency of that value should be the same as the
    # total number of votes for the key.
    my %keyValueFreq; # frequency of a specific value for a given key
    my %totalVotes;   # total votes for a given key
    my %totalVoters;  # how many different people voted for each key
    my %totalRate;    # Total of all ratings for each key
    my %items;        # Hash of id's that have the same key
    my $voteSum = 0;  # Sum of the number of votes on all rated items
    my $rateSum = 0;  # Sum of all ratings of rated items
    foreach my $voter (keys %votes) {
        foreach my $vid (keys %{$votes{$voter}}) {
            foreach my $key (keys %{$votes{$voter}{$vid}}) {
                my $choice = $votes{$voter}{$vid}{$key}->[0];
                my $weight = $votes{$voter}{$vid}{$key}->[1];
                $keyValueFreq{$vid}{$key}{$choice} += $weight;
                $totalVotes{$key} += $weight;
                $items{$key}{$vid} = 1;
                $voteSum += $weight;
                if ($choice =~ /^[\d.]+$/) {
                    $totalRate{$key} += $choice * $weight;
                    $rateSum += $choice * $weight;
                }
                $totalVoters{$key}++;
            }
        }
    }

    # Do we need a submit button?
    my $needSubmit = scalar(@prompts) > 1;

    my $act;
    if ($isOpen) {
        $act = TWiki::Func::getScriptUrl($web, $topic, 'view');
    } else {
        $act = TWiki::Func::getScriptUrl($web, $topic, 'viewauth');
    }
    my @rows;
    foreach my $prompt (@prompts) {
        my $key = $prompt->{name};
        my $row;

        if ($prompt->{type} eq 'stars') {
            my $numItems = scalar(keys(%{$items{$key}}));

            # avg_num_votes: The average number of votes of all items that have
            # num_votes>0
            # avg_rating: The average rating of each item (again, of those that
            # have num_votes>0)
            my $avg_num_votes = $numItems ? $voteSum / $numItems : 0;
            my $avg_rating = $voteSum ? $rateSum / $voteSum : 0;
            my $myLastVote =
              $votes{getIdent($isSecret, $isOpen)}{$id}{$key}->[0] || 0;
            my $mean = 0;
            if ($totalVotes{$key}) {
                $mean = $totalRate{$key} / $totalVotes{$key};
                if ($bayesian) {
                    $mean = ($avg_num_votes * $avg_rating +
                               $totalVotes{$key} * $mean) /
                                 ($avg_num_votes + $totalVotes{$key});
                }
            }
            push(@rows, showLineOfStars(
                $id, $prompt, $needSubmit, $act,
                $mean, $myLastVote, $totalVoters{$key} || 0));
        }
        else {
            my $opts = CGI::option({selected=>'selected',
                                    value=>''}, 'Select ...');

            foreach my $optionName (@{$prompt->{options}}) {
                $opts .= CGI::option($optionName);
            }
            my $o = { name => 'voteplugin_'.$key, size => 1 };
            unless ($needSubmit) {
                $o->{onchange} = 'javacript: submit()';
            }
            my $select = CGI::Select($o, $opts);

            push(@rows, showSelect(
                $prompt, $select, \%{$keyValueFreq{$id}{$key}},
                $totalVotes{$id}{$key}, $params));
        }
    }
    my $result = join($separator, @rows)."\n";
    if ($needSubmit) {
        $result .= CGI::submit(
            { name=> 'OK', value=>'OK',
              style=>'color:green'});
    }
    $result .= CGI::input({type=>'hidden',
                           name=>'register_vote', value=>$id});
    $result .= CGI::input({type=>'hidden',
                           name=>'isGlobal', value=>$isGlobal});
    $result .= CGI::input({type=>'hidden',
                           name=>'isSecret', value=>$isSecret});
    $result .= CGI::input({type=>'hidden',
                           name=>'isOpen', value=>$isOpen});
    $result .= CGI::input({type=>'hidden',
                           name=>'saveTo', value=>$saveto});

    # why is CGI::form not part of my CGI.pm?
    $result = "<form id='$id' action='$act' method='post'>\n".$result.'</form>';

    return $result;
}

###############################################################################
sub registerVote {
    my ($web, $topic, $id) = @_;

    #print STDERR "called registerVote()\n";

    # check parameters
    my $query = TWiki::Func::getCgiQuery();

    return unless $id eq $query->param('register_vote');

    my $user = TWiki::Func::getWikiUserName();
    my $isSecret = $query->param('isSecret') || 0;
    my $isOpen = $query->param('isOpen') || 0;
    my $ident = getIdent($isSecret, $isOpen);
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
    my $voteData = "|$id|$ident|$weight|";
    my @v;
    foreach my $key ($query->param()) {
        my $val = $query->param($key);
        next unless $key =~ s/^voteplugin_//;
        push @v, "$key=$val";
    }
    $voteData .= join(',', @v) . "|\n";

    saveVotesData($web, $topic, $id,  $query->param('isGlobal') || 0,
                  $query->param('saveTo') || '', $voteData);
    # invalidate cache entry
    if (defined &TWiki::Cache::invalidateEntry) {
        TWiki::Cache::invalidateEntry($web, $topic);
    }
}

sub saveVotesData {
    my ($web, $topic, $id, $isGlobal, $saveto, $voteData) = @_;
    if ($saveto) {
        my $text = '';
        $saveto =~ /(.*)/;
        my ($vw, $vt) = TWiki::Func::normalizeWebTopicName($web, $1);
        if (TWiki::Func::topicExists($vw, $vt)) {
            $text = TWiki::Func::readTopicText( $vw, $vt );
        }
        $text .= $voteData;
        TWiki::Func::saveTopicText($vw, $vt, $text, 1, 1);
    } else {
        my $votesFile = getVotesFile($web, $topic, $id, $isGlobal);
        # open and lock the votes
        open(VOTES, ">>$votesFile") || die "cannot append $votesFile";
        flock(VOTES, LOCK_EX); # wait for exclusive rights
        seek(VOTES, 0, 2); # seek EOF in case someone else appended
        # stuff while we were waiting
        print VOTES $voteData;
        # unlock and close
        flock(VOTES, LOCK_UN);
        close VOTES;
    }
}

sub getVoteData {
    my ($web, $topic, $id, $isGlobal, $saveto) = @_;

    my $lines = '';
    if ($saveto) {
        my ($vw, $vt) = TWiki::Func::normalizeWebTopicName($web, $saveto);
        if (TWiki::Func::topicExists($vw, $vt)) {
            my $meta;
            ( $meta, $lines ) = TWiki::Func::readTopic( $vw, $vt );
        }
    } else {
        my $votesFile = getVotesFile($web, $topic, $id, $isGlobal);
        if (open(F, "<$votesFile")) {
            local $/ = undef;
            $lines = <F>;
            close(F);
        }
    }
    return $lines;
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
sub expandFormattingTokens {
    my $text = shift;
    $text =~ s/\$quote/\'/go;# Compatibility

    return $text;
    if( defined( &TWiki::Func::decodeFormatTokens )) {
        $text = TWiki::Func::decodeFormatTokens( $text );
    } else {
        $text =~ s/\$n\(\)/\n/gs;
        $text =~ s/\$n\b/\n$1/gs;
        $text =~ s/\$nop(\(\))?//gs;
        $text =~ s/\$quot(\(\))?/\"/gs;
        $text =~ s/\$percnt(\(\))?/\%/gs;
        $text =~ s/\$dollar(\(\))?/\$/gs;
    }
    $text =~ s/\$doublequote?/\"/gs;
    return $text;
}

###############################################################################
sub getIdent {
    my ($id, $isSecret, $isOpen) = @_;

    my $user = TWiki::Func::getWikiUserName();

    my $ident;

    if ($isOpen) {
        my $date = getLocaldate();
        $ident = "$ENV{REMOTE_ADDR},$user,$date";
    } else {
        $ident = $user;
    }

    if ($isSecret) {
        return md5_base64($ident);
    } else {
        return $ident;
    }
}

###############################################################################
sub showSelect {
    my ($prompt, $select, $keyValueFreq, $totalVotes, $params) = @_;

    my $key = $prompt->{name};
    my $totty = $totalVotes || 0;
    my $row = $prompt->{format};
    $row =~ s/\$key/$key/g;
    $row =~ s/\$prompt/$select/g;
    $row =~ s/\$sum/$totty/;
    my $bars = '';
    foreach my $value (sort {$keyValueFreq->{$b} <=>
                               $keyValueFreq->{$a}}
                         keys %{$keyValueFreq}) {
        my $score = $keyValueFreq->{$value} || 0;

        my $perc = $totty ? int(1000 * $score / $totty) / 10 : 0;
        my $bar = expandFormattingTokens($prompt->{chart});
        $bar =~ s/\$option/$value/;
        $bar =~ s/\$perc/$perc/g;
        $bar =~ s/\$score/$score/g;
        $bar =~ s/\$bar(\((\d+)\))?/_makeBar($2, $perc, $params)/ge;
        $bars .= $bar;
    }
    $row =~ s/\$bars/$bars/g;
    return $row;
}

sub _makeBar {
    my ($width, $perc, $params) = @_;
    $width = $params->{width} || $width || 300;
    my $graph = CGI::img(
        { src=>$pubUrlPath.'/leftbar.gif',
          alt=>'leftbar',
          height=>14});
    $graph .= CGI::img(
        { src => $pubUrlPath.'/mainbar.gif',
          alt => 'mainbar',
          height => 14,
          width => $width / 100 * $perc });
    $graph .= CGI::img(
        { src=>$pubUrlPath.'/rightbar.gif',
          alt => 'rightbar',
          #width => $width - $width / 100 * $perc,
          height => 14});
    return $graph;
}

###############################################################################
sub showLineOfStars {
    my ($form, $prompt, $needSubmit, $act,
        $mean, $myLast, $total) = @_;
    my $max = $prompt->{width};

    my $row = expandFormattingTokens($prompt->{format});
    $row =~ s/\$key/$prompt->{name}/g;
    $row =~ s/\$sum/$total/g;
    $row =~ s/\$score/$mean/g;
    my $perc = $total ? int(1000 * $mean / $total) / 10 : 0;
    $row =~ s/\$perc/$perc/g;
    $row =~ s/\$mylast/$myLast/g;

    my $size = ($row =~ /\$small/) ? 10 : 25;
    my $style = $size < 25 ? ' small-star' : '';

    my $lis = CGI::li(
        {
            class=>'current-rating',
            style=>'width:'.($size * $mean).'px',
        }, CGI::input(
        {
            type => 'hidden',
            name => 'voteplugin_'.$prompt->{name},
            id => $form.'_'.$prompt->{name},
            value => '0',
        }));
    if ($needSubmit) {
        $lis .= CGI::li(
            {
                class=>'my-rating',
                id => $prompt->{name}.'_rated',
                style=>'width:0px; z-index:2',
            }, '&nbsp;');
    }

    foreach my $i (1..$max) {
        $lis .= CGI::li(
            CGI::a(
                {
                    href=>"javascript:VotePlugin_clicked('$form',".
                      "'$prompt->{name}', $i, ".
                        ($needSubmit ? 'false' : 'true').", $size)",
                    style=>'width:'.($size * $i).
                      'px;z-index:'.($max - $i + 2),
                }, $i));
    }
    my $ul = CGI::ul(
        {
            class=>'star-rating'.$style,
            style=>'width:'.($max * $size).'px',
        }, $lis);
    $row =~ s/\$(small|large)/$ul/g;

    return $row;
}

sub isTrue {
    my( $value, $default ) = @_;

    $default ||= 0;

    return $default unless defined( $value );

    $value =~ s/^\s*(.*?)\s*$/$1/gi;
    $value =~ s/off//gi;
    $value =~ s/no//gi;
    $value =~ s/false//gi;
    return ( $value ) ? 1 : 0;
}

1;

