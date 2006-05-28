# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 MichaelDaum@WikiRing.com
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
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

package TWiki::Plugins::PingBackPlugin::Core;
use strict;
use vars qw( $debug $pingbackClient);

$debug = 0; # toggle me

use Fcntl qw(:flock);

###############################################################################
sub writeDebug {
  #&TWiki::Func::writeDebug('- PingBackPlugin::Core - '.$_[0]) if $debug;
  print STDERR '- PingBackPlugin::Core - '.$_[0]."\n" if $debug;
}

################################################################################
sub expandVariables {
  my ($format, %variables) = @_;

  my $text = $format;

  foreach my $key (keys %variables) {
    $text =~ s/\$$key/$variables{$key}/g;
  }
  $text =~ s/\$percnt/\%/go;
  $text =~ s/\$dollar/\$/go;
  $text =~ s/\$n/\n/go;
  $text =~ s/\\\\/\\/go;
  $text =~ s/\$nop//g;

  return $text;
}

###############################################################################
sub getLocaldate {

  my ($sec, $min, $hour, $mday, $mon, $year) = localtime(time());
  return  sprintf("%.4u/%.2u/%.2u - %.2u:%.2u:%.2u", 
    $year+1900, $mon+1, $mday, $hour, $min, $sec);
}

###############################################################################
sub handlePingbackTag {
  my ($session, $params, $theTopic, $theWeb) = @_;

  my $action = $params->{action} || $params->{_DEFAULT} || 'ping';
  return handlePing(@_) if $action eq 'ping';
  return handleShow(@_) if $action eq 'show';
  return inlineError("unknown action $action");
}

###############################################################################
sub inlineError {
  return '<span class="twikiAlert">ERROR: '.$_[0].'</span>';
}

###############################################################################
sub handlePing {
  my ($session, $params, $theTopic, $theWeb) = @_;

  writeDebug("called handlePing");

  my $query = TWiki::Func::getCgiQuery();
  my $action = $query->param('action') || '';
  my $source;
  my $target;
  my $format = $params->{format} || 
    '<pre style="overflow:auto">$status: $result</pre>';

  if ($action eq 'ping') { 
    # cgi mode
    $source = $query->param('source');
    $target = $query->param('target');
  } else { 
    # tml mode
    $source = $params->{source};
    $target = $params->{target};
  }

  return '' unless $target;
  $source = &TWiki::Func::getViewUrl($theWeb, $theTopic) unless $source;

  writeDebug("source=$source");
  writeDebug("target=$target");

  unless ($pingbackClient) {
    eval 'use TWiki::Plugins::PingBackPlugin::Client;';
    die $@ if $@;
    $pingbackClient = TWiki::Plugins::PingBackPlugin::Client->new();
    die $@ unless $pingbackClient;
  }

  my ($status, $result) = $pingbackClient->ping($source, $target);

  my $text = expandVariables($format, 
    status=>$status,
    result=>$result,
    target=>$target,
    source=>$source,
  );


  writeDebug("done handlePing");

  return $text;
}

###############################################################################
sub handleShow {
  my ($session, $params, $theTopic, $theWeb) = @_;

  writeDebug("called handleShow");

  my $header = $params->{header} || 
    '<span class="twikiAlert">$count</span> pings pending<p/>'.
    '<table class="twikiTable" width="100%">';
  my $format = $params->{format} || 
    '<tr><th>$index</th><th>$date</th><th>$state</th></tr>'.
    '<tr><td>&nbsp;</td><td colspan="2">'. '
      <table><tr><td><b>Source</b>:</td><td> $source </td></tr>'.
	'<tr><td><b>Target</b>:</td><td> $target </td></tr>'.
      '</table>'.
    '</tr>';
  my $footer = $params->{footer} || '</table>';
    
  my $separator = $params->{sep} || $params->{separator} || '$n';
  my $warn = $params->{warn} || 'on';

  my @pings = readPingbackLog();

  return inlineError("no pings found") if $warn eq 'on' && !@pings ;

  @pings = reverse @pings;

  my $result = '';
  my $index = 0;
  foreach my $ping (@pings) {
    my $text = '';
    $index++;
    $text .= $separator if $result;
    $text .= $format;
    $text = expandVariables($text,
      date=>$ping->{date},
      source=>$ping->{source},
      target=>$ping->{target},
      state=>$ping->{state},
      'index'=>$index,
    );
    $result .= $text;
  }
  writeDebug("result=$result");

  if ($result) {
    $result = $header.$separator.$result if $header;
    $result .= $separator.$footer if $footer;
    $result = expandVariables($result, count=>$index);
  }

  writeDebug("done handleShow");

  return $result;
}

###############################################################################
sub getPingbackLog {
  return TWiki::Func::getWorkArea('PingBackPlugin').'/logfile.txt';
}

###############################################################################
sub appendPingbackLog {
  my ($source, $target, $status) = @_;

  # open and lock
  my $pingbackLog = getPingbackLog();
  open(PBL, ">>$pingbackLog") || die "cannot append $pingbackLog";
  flock(PBL, LOCK_EX); # wait for exclusive rights
  seek(PBL, 0, 2); # seek EOF in case someone else appended 
		   # stuff while we where waiting

  my $date = &getLocaldate();
  print PBL "$date|$source|$target|received\n";

  # unlock and close
  flock(PBL,LOCK_UN);
  close PBL;
}

###############################################################################
sub readPingbackLog {

  writeDebug("called readPingbackLog");

  my $pingbackLog = getPingbackLog();
  my @pings = ();

  writeDebug("pingbackLog=$pingbackLog");

  if (open(PBL, "<$pingbackLog")) {
    # date|source|target|status
    while (my $line = <PBL>) {
      if ($line =~ /^\s*([^\|]+)\|([^\|]+)\|([^\|]+)\|(.*?)\s*$/) {
	writeDebug("found ping");
	my $ping = {
	  date=>$1,
	  source=>$2,
	  target=>$3,
	  state=>$4,
	};
	push @pings, $ping;
      } else {
	writeDebug("no ping found in line $line");
      }
    }
    close PBL;
  }

  writeDebug("found ".(scalar @pings)." pings");
  writeDebug("done readPingbackLog");
  return @pings;
}

###############################################################################
sub handlePingbackCall {
  my ($session, $params) = @_;

  $TWiki::Plugins::SESSION = $session;

  writeDebug("called handlePingbackCall");

  # check arguments
  if (@$params != 2) {
    return ('400 Bad Request', -32602, 'Wrong number of arguments');
  }

  my $source = $params->[0]->value;
  my $target = $params->[1]->value;
  my $web = $session->{webName};
  my $topic = $session->{topicName};

  $session->writeLog('ping', $web.'.'.$topic);

  writeDebug("source=$source");
  writeDebug("target=$target");

  # write into log
  appendPingbackLog($source, $target, 'received');

  writeDebug("done handlePingBackCall");

  return ('200 OK', 1, 'Done');
}

1;
