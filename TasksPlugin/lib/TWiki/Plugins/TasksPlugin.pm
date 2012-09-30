# -*- mode: CPerl; -*-
# TasksPlugin for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.

=pod

---+ package TWiki::Plugins::TasksPlugin

This plugin used to interface TWiki pages to the off-line Tasks Daemon.

It enables TWiki pages to obtain status and exercise some control over the Tasks
Daemon, which implements the tasking framework.  For packaging purposes, the entire
framework is considered part of this plugin, since it doesn't fit in any of
the other established categories.

=cut

# And so the elephant looks to the flea...

use warnings;
use strict;

package TWiki::Plugins::TasksPlugin;

use Digest::MD5 qw/md5_hex/;
use HTTP::Status qw/HTTP_UNAUTHORIZED/;
use Socket qw/:crlf/;

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package. It should always be Rev enclosed in dollar
# signs so that TWiki can determine the checked-in status of the plugin.
# It is used by the build automation tools, so you should leave it alone.
our $VERSION = '$Rev$';

our $RELEASE = '3.001';

our $SHORTDESCRIPTION = 'Interface to time and event-driven task framework';
our $NO_PREFS_IN_TOPIC = 1;

# Define other global package variables
our $debug;

   # Kludge to get LWP to use IPV6
   # Done as a BEGIN because other TWiki components also use LWP
BEGIN {
    package Net::HTTP;
    use vars qw/$SOCKET_CLASS/;
    die "TasksPlugin must initialize first\n" if( defined $SOCKET_CLASS  && $SOCKET_CLASS ne 'IO::Socket::IP' );
    require IO::Socket::IP;
    $SOCKET_CLASS = 'IO::Socket::IP';
}

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

=cut

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.2 ) {
        TWiki::Func::writeWarning( "Version mismatch between TasksPlugin and Plugins.pm" );
        return 0;
    }

    TWiki::Func::registerTagHandler( 'TASKS', \&_TASKS );

    # Plugin correctly initialized
    return 1;
}

=pod

---++ _TASKS
%<nop>TASKS% directive.

Provides content for a TASK daemon management topic.

The following parameters can be specified to determine what information is returned:
   * =status= Returns daemon status (default)
   * =start-server= Returns a form for starting the server

The following keyword parameters can be specified:

   * =format= =text= for plain (monospaced) text format; default is =html=
   * =manage= Include management form
      * =withstatus= to include status with management form
      * =onlyform= just management form
   * =detail= Specify level of status detail.
      * =brief= Explicitly specifies the default level of status detail
      * =list= Include additional detail
      * =debug= Include maximum detail

<nop>=manage= and =start-server= are incompatible with =format=text=.

Note that the status output is intended for human consumption and may be changed from time to time.
Do not attempt to parse it mechanically.

This directive is restricted to members of the TWikiTasksGroup or the TWikiAdminGroup.

=cut

sub _TASKS {
    my($session, $params, $theTopic, $theWeb) = @_;
    # $session  - a reference to the TWiki session object.
    # $params=  - a reference to a TWiki::Attrs object containing parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    #
    # Returns string that replaces the %TASKS% directive in the wiki display.

    # Get format first so that errors appear in the requested format.

    my $textformat;
    if( defined $params->{format} ) {
        if( $params->{format} eq 'text' ) {
            $textformat = 1;
        } elsif( $params->{format} !~ m/^(?:html|tml)$/ ) {
            # Unknown format, complain in tml
            return "%RED%TASKS: Invalid value '$params->{format}' for _format_ parameter";
        }
    }

    # Verify that user is in admin group

    return ($textformat? '<pre>*** Not authorized to use TASKS directive ***</pre>' :
                         '%RED%Not authorized to use %<nop>TASKS% directive%ENDCOLOR%')
	unless( TWiki::Func::isGroupMember( "TWikiAdminGroup", undef ) ||
#	        TWiki::Func::isGroup( 'FoswikiTasksGroup' ) && TWiki::Func::isGroupMember( 'FoswikiTasksGroup', undef ) ||
	        TWiki::Func::isGroup( 'TWikiTasksGroup' ) && TWiki::Func::isGroupMember( 'TWikiTasksGroup', undef )
	      );

    # Default and validate parameters

    my $function = $params->{_DEFAULT} || 'status';
    return ($textformat? "<pre>*** TASKS: Invalid function '$params->{_DEFAULT}' ***</pre>" :
                         "%RED%TASKS: Invalid function '$params->{_DEFAULT}'%ENDCOLOR%")
	unless( $function =~ /^(?:start-server|status)$/ );

    my $detail = $params->{detail} || 'brief';
    return ($textformat? "<pre>*** TASKS: Invalid value '$params->{detail}' for _detail_ parameter ***</pre>" :
                         "%RED%TASKS: Invalid value '$params->{detail}' for _detail_ parameter%ENDCOLOR%")
	unless( $detail =~ /^(?:brief|list|debug)$/ );

    # URI of the tasks daemon CGI (under the webserver, not the daemon itself)

    my $daeuri = "$TWiki::cfg{DefaultUrlHost}$TWiki::cfg{ScriptUrlPath}/" .
                 ( $TWiki::cfg{Tasks}{StartupUrlName} || "TaskDaemon$TWiki::cfg{ScriptSuffix}" );

    # Basic form - probably will get fancier formatting at some point

    if( $function eq 'start-server' ) {
	return <<"FORM";
<form action="$daeuri" method="post">
 <label for="debug"> Output debugging information
  <input type="checkbox" id="debug" name="debug" value="1"></label>
 <input type="submit" name="Submit" value="Start Task Service">
</form>
FORM
    }

    # Build URI for accessing daemon to get requested information

    my $uri = "/status/$detail?embed";

    if( defined $params->{manage} ) {
        if( $params->{manage} =~ /^(?:onlyform|withstatus)$/ ) {
            $uri .= "&manage=$params->{manage}";
        } else {
            return ($textformat? "<pre>*** TASKS: Invalid value '$params->{manage}' for _manage_ parameter ***</pre>" :
                                 "%RED%TASKS: Invalid value '$params->{manage}' for _manage_ parameter%ENDCOLOR%");
        }
    }

    $uri .= '&text' if( $textformat );

    # Communicate with the daemon to get status.  Similar, but not identical to daemonCmd in Daemon as there is no need for
    # cookies here and formating requirements differ.  However, authentication logic must be kept in sync.

    my $address = $TWiki::cfg{Tasks}{StatusAddr} || '';
    return ($textformat? '<pre>*** TASKS: Status not configured ***</pre>' :
                         '%RED%%<nop>TASKS%: Status not configured%ENDCOLOR%') unless( $address );

    my $protocol = $TWiki::cfg{Tasks}{StatusServerProtocol};

    # Make request

    require LWP::UserAgent;

    my $ua = LWP::UserAgent->new( (
				   agent => "TWikiTasksPlugin/1.0",
				  ) );
    push @{ $ua->requests_redirectable }, 'POST';

    # If client verification is enabled, send our certificate (note: Requires LWP::Protocol::https)

    if( $TWiki::cfg{Tasks}{StatusServerVerifyClient} ) {
        $ua->ssl_opts( SSL_cert_file => $TWiki::cfg{Tasks}{DaemonClientCertificate},
                       SSL_key_file => $TWiki::cfg{Tasks}{DaemonClientKey},
                       SSL_passwd_cb => sub { return $TWiki::cfg{Tasks}{DaemonClientKeyPassword} },
                     );
        # LWP will attempt to verify server hostname, which is unlikely to succeed if it is localhost or a loopback address
        $ua->ssl_opts( verify_hostname => undef )
          if( $address =~ /^(?:localhost|::1|127\.\d{1,3}\.\d{1,3}\.\d{1,3}|::1)(:\d+)?$/i );
    }

    my $rsp = $ua->get(  "$protocol://$address$uri" );
    if( $rsp->code == HTTP_UNAUTHORIZED ) {
        # Provide daemon authentication based on the user validation done above

	my $nonce = $rsp->header('X-TWiki-Authenticator' );
	if( $nonce ) {
	    my $realm;
	    ($realm, $nonce) = split( /\s*,\s*/, $nonce, 2 );

	    $ua->credentials( $address, $realm, $TWiki::cfg{AdminUserLogin},
			      md5_hex( $nonce, "$realm:$TWiki::cfg{AdminUserLogin}:$TWiki::cfg{Password}" ) );

	    $rsp = $ua->get(  "$protocol://$address$uri", 'X-TWiki-Authenticator', $nonce );
	}
    }

    # Process response, handling LWP errors and network EOL markers

    my $text = $rsp->content unless( $rsp->is_error && $rsp->header( 'Client-Warning' ) &&
                                     $rsp->header( 'Client-Warning' ) eq 'Internal response' );
    $text = '' unless( defined $text );
    $text =~ s/$CR+//gmso;
    $text =~ s/$LF/\n/gmso;

    if( $rsp->is_error ) {
        return "<pre>*** TASKS: Failed to obtain status $protocol://$address$uri: " . $rsp->code . ' ' . $rsp->message . ' ***</pre>'
          if( $textformat );
	return "%RED%%<nop>TASKS%: $Net::HTTP::SOCKET_CLASS;Failed to obtain status $protocol://$address$uri: " . $rsp->code . ' ' . $rsp->message . "%ENDCOLOR%";
    }

    if( $textformat ) {
	$text = "<pre>$text</pre>";
    } else {
	# If response contains a management form pointing to localhost, insert daemon CGI as a proxy

	if( $text =~ m!<form action="https?://([^/]*)/control!m ) {
	    $text =~ s!(<form action=")(https?://[^/]*)(/control.*)$!$1$daeuri$3!mg
	      if( $1 && ($1 =~ /^(?:localhost|127\.)/i ) );
	}
	$text = "<noautolink>$text</noautolink>";
    }

    return $text;
}


1;
__END__

This is an original work by Timothe Litt.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 3
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at
http://www.gnu.org/copyleft/gpl.html

This code is based on the plugin template from
  the TWiki Collaboration Platform, http://TWiki.org/

which is Copyright (C) 2005-2007 TWiki Contributors and is
licensed under GPL.
