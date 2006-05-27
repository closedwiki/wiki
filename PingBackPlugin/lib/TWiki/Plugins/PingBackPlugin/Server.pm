# Pingback Server
#
# Copyright (c) 2005 by MichaelDaum <micha@nats.informatik.uni-hamburg.de>
#
# based on Pingback Proxy Copyright (c) 2002 by Ian Hickson
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

package TWiki::Plugins::PingBackPlugin::Server;

use strict;
use RPC::XML;
use RPC::XML::Parser;
use URI::Escape;

use vars qw( $debug );

$debug = 0; # toggle me

################################################################################
# static
sub writeDebug {
  #&TWiki::Func::writeDebug('- PingBackPlugin::Server - '.$_[0]) if $debug;
  print STDERR '- PingBackPlugin::Server - '.$_[0]."\n" if $debug;
}

################################################################################
# constructor
sub new {
  my ($class, %handler) = @_;
  my $this = bless({}, $class);

  writeDebug("new PingBack::Server");

  # RPC::XML::Parser
  $this->{parser} = ''; 

  # default RPC pingback.ping handler
  $this->{handler}{'pingback.ping'} = \&handlePingBack;

  # register RPCs
  foreach my $methodName (keys %handler) {
    $this->{handler}{$methodName} = $handler{$methodName};
  }

  return $this;
}

################################################################################
sub getError  {
  my ($this, $status, $error, $data) = @_;

  writeDebug("called getError");
  writeDebug("status=$status");
  writeDebug("error=$error");

  return $this->getResponse($status, RPC::XML::fault->new($error, $data));
}

################################################################################
sub getResponse {
  my ($this, $status, $data) = @_;

  writeDebug("called getResponse");
  writeDebug("status=$status");

  my $response = RPC::XML::response->new($data);

  return 
    "Status: $status\n".
    "Content-Type: text/xml\n\n".
    $response->as_string;
}

################################################################################
sub callProcedure {
  my ($this, $data) = @_;

  writeDebug("called callProcedure");
  writeDebug("data=$data");

  # check ENV
  if ($ENV{'REQUEST_METHOD'} ne 'POST') {
    return $this->getError('405 Method Not Allowed', -32300, 'Only XML-RPC POST requests recognised.');
    #, 'Allow: POST');
  }

  if ($ENV{'CONTENT_TYPE'} ne 'text/xml') {
    return $this->getError('415 Unsupported Media Type', -32300, 'Only XML-RPC POST requests recognised.');
  }


  # parse
  $this->{parser} = RPC::XML::Parser->new() unless $this->{parser};
  my $request = $this->{parser}->parse($data);
  return $this->getError(400, 'Bad Request', -32700, $request) unless ref($request);

  # check impl
  my $name = $request->name;
  unless ($this->{handler}{$name}) {
    return $this->getError('501 Not Implemented', -32601, "Method $name not supported");
  }

  # call 
  my $result = &{$this->{handler}{$name}}($this, $request->args);
  writeDebug("result=$result");

  return $result;
}

################################################################################
# default pingback handler
sub handlePingBack  {
  my ($this, $args) = @_;

  writeDebug("called handlePingBack");

  my $source = $args->[0]->value;
  my $target = $args->[1]->value;

  writeDebug("source=$source");
  writeDebug("target=$target");

  # check arguments
  if (@$args != 2) {
    return $this->getError('400 Bad Request', -32602, 'Wrong number of arguments');
  }

  # TODO: do something

  writeDebug("done handlePingBack");

  return $this->getResponse('200 OK', RPC::XML::string->new('Done'));
}

################################################################################
1;
