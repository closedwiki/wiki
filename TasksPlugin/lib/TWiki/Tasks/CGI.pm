# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.


use strict;
use warnings;


=pod

---+ package TWiki::Tasks::CGI

CGI interface for the TASK daemon.

The daemon executable runs as a standard CGI script under the system webserver.  In this mode, it provides a mechanism to start
the daemon without root or webserver user access.  It also acts as a selective proxy for status and control.

=cut

package TWiki::Tasks::CGI;

use TWiki;

use CGI;

=pod

---++ StaticMethod dispatch( $script)
Authenticate and dispatch CGI requests.

   * =$script= - path of daemon executable

Does not return.

=cut

sub dispatch {
    my $script = shift;

    my $q = CGI->new();

    unless( $ENV{REQUEST_METHOD} =~ /^(POST|GET)$/i ) {
	print $q->header( -status => "405 Method not allowed" ),
              $q->start_html(-title => "Request error" ),
                $q->h1( "Invalid request method\n" ),
              $q->end_html, "\n";
	exit 0;
    }

    my $cmd = "$script ";

    # Subset of TWiki::Engine::run necessary to authenticate

    my $req = TWiki::Request->new();
    $TWiki::engine->prepareConnection( $req );
    $TWiki::engine->prepareQueryParameters( $req );
    $TWiki::engine->prepareHeaders( $req );
    $TWiki::engine->prepareCookies( $req );

    my $twiki = TWiki->new( undef, $req );
    $TWiki::Plugins::SESSION = $twiki;

    unless( TWiki::Func::isGroupMember( "TWikiAdminGroup", undef ) ||
	    TWiki::Func::isGroup( 'TWikiTasksGroup' ) && TWiki::Func::isGroupMember( 'TWikiTasksGroup', undef ) ) {
	print $q->header( -status => "400 Request error" ),
              $q->start_html(-title => "Request error" ),
                $q->h1( "Not authorized\n" ) . "<B>You must be a member of the TWikiAdminGroup</B><br />" .
                $q->p( $q->a( {href=>$q->referer(),} , "Return to previous page" ) ),
              $q->end_html, "\n";
	exit 0;
    }
    undef $TWiki::Plugins::SESSION;
    undef $twiki;

    if( $ENV{REQUEST_METHOD} eq 'POST' ) {
	$cmd = POST( $q, $cmd );
    } else {
	$cmd = GET( $q, $cmd );
    }

    # Don't confuse TWiki or its plugins with Webserver %ENVs
    # Also make sure that recursive call to status for GET doesn't loop.
    #
    # These are the CGI gateway spec (1.1) + a few from apache

    foreach my $e (keys %ENV) {
	delete $ENV{$e} if( $e =~ /^(?:AUTH_TYPE|CONTENT_.*|GEOIP_.*|HTTPS|HTTP_.*|PATH_(?:INFO|TRANSLATED)|QUERY_STRING|REMOTE_(?:ADDR|HOST|IDENT|PORT|USER)|REQUEST_(?:METHOD|URI)|SCRIPT_.*|SERVER_.*|SSL_.*|DOCUMENT_ROOT)$/i );
    }
    delete $ENV{GATEWAY_INTERFACE};

    # Run command - first line of output is a header, rest is preformatted text
    $ENV{TWIKI_TASKS_CGICMD} = 1;

    my @rsp = split( /\n/, `$cmd`, 2 );

    print $q->header,
          $q->start_html(-title => "Task Framework Startup" ),
            $q->h1( $rsp[0] ) . 
            $q->pre( $rsp[1] || '' ) .
            $q->p( $q->a( {href=>"$TWiki::cfg{DefaultUrlHost}$TWiki::cfg{ScriptUrlPath}/$TWiki::cfg{Tasks}{StartupUrlName}$TWiki::cfg{ScriptSuffix}/status/brief",} , "View task status" ) ) .
            $q->p( $q->a( {href => '#', onclick=>'history.go(-1); return 1;'}, "Return to previous page" ) ),
          $q->end_html, "\n";
    exit 0;
}

=pod

---++ StaticMethod GET( $q, $cmd ) -> $response
Process CGI GET.
   * =$q= - CGI object
   * =$cmd= - path to daemon executable

Execute daemon status command, including detail if path info is '/status' or '/status/level', where level is 'brief', 'list',
or 'debug'.

Returns output.

=cut

sub GET {
    my $q = shift;
    my $cmd = shift;

    # Handle GET for fiddlers with refresh and back buttons.

    $cmd .= 'status';
    if( $ENV{PATH_INFO} =~ m!^/status(?:/(brief|list|debug)/?)$! ) {
        $cmd .= defined( $1 )? " $1" : ' brief';
    }

    return $cmd;
}

=pod

---++ StaticMethod POST( $q, $cmd ) -> $response
Process CGI POST.
   * =$q= - CGI object
   * =$cmd= - path to daemon executable

Unless path info specified, start daemon.  If the 'debug' parameter is true, start in debug mode with enhanced logging.

Otherwise, proxy post to /control to the daemon's internal webserver.  If the response contains a management form, adjust
it to point back to the proxy.

Returns output.

=cut

sub POST {
    my $q = shift;
    my $startcmd = shift;

    my $pi = $ENV{PATH_INFO};
    unless( $pi ) {
        $startcmd .= '-dv0 ' if( $q->param('debug') );
        $startcmd .= "start ";

        return $startcmd;
    }

    # Proxy POST from management GUI back to daemon (Daemon listening on localhost; browser elsewhere)

    unless( $pi =~ m!/control! ) {
        print $q->header( status => "400 Request error", title => "Request error" ), 
          $q->html( $q->body( $q->h1( "Invalid request\n" ) . "<B>$pi is unsupported</B><br />"
                              . $q->p( $q->a( {href=>$q->referer(),} , "Return to previous page" ) )
                            ) ), "\n";
        exit 0;
    }
    my @pnames = ($q->param, $q->url_param);
    my @plist;
    foreach my $p (@pnames) {
        my @vals = $q->param( $p );
        push @plist, map { ($p, $_) } @vals;
    }
    my( $sts, $rsp ) = main::daemonCmd( 'post', $pi, @plist );

    # I suppose we should do a redirect to a temporary GET location...
    # Not today.
#   if( $rsp =~ /ERROR: Failed[^:]*:\s*(\d+\s+.*)$/ ) {
#	print $q->header( status => $1, title => "Request error" ), 
#	$q->html( $q->body( split( /\n/, $rsp, 2 )[1]
#				) ), "\n";

    # Convert response from Daemon's HTTP header into a Status: header for httpd

    $rsp =~ s!\AHTTP/\d+\.\d+\s+!Status: !;

    # If response contains a management form pointing to localhost, insert proxy

    if( $rsp =~ m!<form action="https?://([^/]*)/control!m ) {
        my $daeuri = "$TWiki::cfg{DefaultUrlHost}$TWiki::cfg{ScriptUrlPath}/" .
                     ($TWiki::cfg{Tasks}{StartupUrlName} || "TaskDaemon$TWiki::cfg{ScriptSuffix}");
        $rsp =~ s!(<form action=")(https?://[^/]*)(/control.*)$!$1$daeuri$3!mg
          if( $1 && ($1 =~ /^(?:localhost|127\.)/i ) );
    }

    print $rsp;
    exit 0;
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
