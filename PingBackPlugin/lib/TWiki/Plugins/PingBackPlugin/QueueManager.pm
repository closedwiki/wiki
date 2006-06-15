# PingBack QueueManager
#
# Copyright (C) 2006 MichaelDaum@WikiRing.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package TWiki::Plugins::PingBackPlugin::QueueManager;

use strict;
use vars qw($debug);

$debug = 0; # toggle me

use TWiki::Plugins::PingBackPlugin::DB qw(getPingDB);
use LWP::UserAgent;
use HTML::TokeParser;
use HTTP::Request;

###############################################################################
sub writeDebug {
  print STDERR '- PingBackPlugin::QueueManager - '.$_[0]."\n" if $debug;
}

###############################################################################
sub writeLog {
  print LOG '- PingBackPlugin::QueueManager - '.$_[0]."\n";
}

###############################################################################
sub run {
  my $session = shift;

  $TWiki::Plugins::SESSION = $session;

  writeDebug("called run");

  # open log
  my $time = TWiki::Func::formatTime(time());
  my $logfile = TWiki::Func::getDataDir().'/pingback.log';
  open(LOG, ">>$logfile") || die "cannot create lock $logfile - $!\n";
  writeLog("started at $time");

  my $queueManager = TWiki::Plugins::PingBackPlugin::QueueManager->new();

  $queueManager->processInQueue();
  $queueManager->processOutQueue();

  # close log
  $time = TWiki::Func::formatTime(time());
  writeLog("finished at $time");
  close LOG;

  writeDebug("done run");
}

################################################################################
# constructor
sub new {
  my $class = shift;

  my $this = {
    ua=>'', # LWP::UserAgent
    timeout=>30,
    @_
  };

  return bless($this, $class);
}

################################################################################
sub getAgent {
  my $this = shift;

  unless ($this->{ua}) {
    $this->{ua} = LWP::UserAgent->new();
    $this->{ua}->agent("TWiki Pingback Manager");
    $this->{ua}->timeout($this->{timeout});
    $this->{ua}->env_proxy();
    writeDebug("new agent=" . $this->{ua}->agent());
  }

  return $this->{ua};
}

################################################################################
sub getDocumentInfo {
  my ($this, $content) = @_;

  my $parser = HTML::TokeParser->new($content);
  die "can't construct parser" unless $parser;

  # get title
  my $title = '';
  if ($parser->get_tag('title')) {
    $title = $parser->get_trimmed_text;
    writeDebug("found document titled '$title'");
  }

  # get all links
  my @links;
  while (my $token = $parser->get_tag("a")) {
    my $url = $token->[1]{href};
    next unless $url;
    my $text = $parser->get_trimmed_text("/a");
    push @links, {
      url=>$url,
      text=>$text,
    };
    writeDebug("found url=$url, text=$text");
  }

  return ($title, @links);
}

################################################################################
# get target page
sub fetchPage {
  my ($this, $source, $target) = @_;

  my $ua = $this->getAgent();
  my $request = HTTP::Request->new('GET', $target);
  $request->referer($source);
  return $ua->request($request);
}


###############################################################################
sub processInQueue {
  my $this = shift;
  writeDebug("called processInQueue");

  my $db = getPingDB();
  my @pings = $db->readQueue('in');
  my $viewUrl = TWiki::Func::getScriptUrl(undef,undef,'view');
  writeDebug("viewUrl=$viewUrl");

  # process all pings
  foreach my $ping (@pings) {

    # remove circular ping
    if ($ping->{source} eq $ping->{target}) {
      writeLog("cirular ping ... moving to trash");
      $ping->unqueue();
      $ping->queue('trash');
      next;
    }

    # check for foregin ping
    if ($ping->isAlien) {
      writeLog("found alien ping .".$ping->toString);
      # remove from queue
      $ping->unqueue();
      next;
    }

    # check for an internal ping
    if ($ping->isInternal) {
      # internal ping
      writeLog('processing internal pingback from '.
	$ping->{sourceWeb}.'.'.$ping->{sourceTopic}.' to '.
	$ping->{targetWeb}.'.'.$ping->{targetTopic});

      # check if target exists
      unless (TWiki::Func::topicExists($ping->{targetWeb}, $ping->{targetTopic})) {
	writeLog("target does not exist ... moving to trash");
	$ping->unqueue();
	$ping->queue('trash');
	next;
      }

      # check if source exists
      unless (TWiki::Func::topicExists($ping->{sourceWeb}, $ping->{sourceTopic})) {
	writeLog("source does not exist ... moving to trash");
	$ping->unqueue();
	$ping->queue('trash');
	next;
      }

      # fetch source topic text and check backlink usage
      # SMELL: might got out in as we are fetching the page externall anyway
      my $text = TWiki::Func::readTopicText($ping->{sourceWeb}, $ping->{sourceTopic}, '', 1);
      writeDebug("text=$text");
      my $found = 0;
      foreach my $line (split(/\r?\n/, $text)) {
	if (($ping->{sourceWeb} eq $ping->{targetWeb} && $line =~ /\b$ping->{targetTopic}\b/) ||
	  ($line =~ /\b$ping->{targetWeb}\.$ping->{targetTopic}\b/)) {
	  $found = 1;
	  last;
	}
      }
      unless ($found) {
	# no source does not link to target
	writeLog("source does not link to target ... moving to trash");
	$ping->unqueue();
	$ping->queue('trash');
	next;
      }

    } else {
      # normal ping
      writeLog("processing pingback from $ping->{source} to $ping->{targetWeb}.$ping->{targetTopic}");

    }

    # fetch page
    my $page = $this->fetchPage($ping->{source}, $ping->{target});
    my $content = $page->content();
    my ($title, @links) = $this->getDocumentInfo(\$content);
    

    # approved
    writeLog("approved ping !!!");
    $ping->unqueue();
    $ping->queue('cur');
  }
  
  writeDebug("done processInQueue");
}

###############################################################################
sub processOutQueue {
  my $this = shift;

  writeDebug("called processOutQueue");
  writeDebug("done processOutQueue");
}

###############################################################################
sub processTrash {
  my $this = shift;

  writeDebug("called processTrash");

  # TODO: remove old items from trash
  writeDebug("done processTrash");
}

1;
