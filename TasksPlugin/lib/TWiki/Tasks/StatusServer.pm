# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.


use strict;
use warnings;


=pod

---+ package TWiki::Tasks::StatusServer

Threaded server for daemon control and status.

Implemented as a minimal HTTP server for universal access, reasonable security and SSL potential.

This class implements the status server.  It is a subclass of HttpServer (and GenericServer).

=cut

package TWiki::Tasks::StatusServer;

our @ISA;
# Will inherit from configure-defined protocol server

use base 'Exporter';
our @EXPORT_OK = qw/_max/;

use TWiki::Tasks::Globals qw/:status/;
use TWiki::Tasks::Logging qw/:DEFAULT logHistory logLines tprint/;
use TWiki::Tasks::Schedule qw/suspendScheduling resumeScheduling stopDaemon restartDaemon
				       schedulerStatus schedulerForkStatus/;
use File::Basename;
use FindBin;
use HTTP::Status qw/:constants/;
use Sys::Hostname;

use TWiki;
use TWiki::Func;

# Lines of log history to display (-1 for all, 0 for none)
our $statusLogLines = 25;

=pod

---++ ClassMethod new( @args )
Constructor for a new StatusServer object
   * =@args= - Network arguments for whatever protocol is selected

We don't know StatusServer's base class until we know what protocol was selected by configure - and that can change.

So, new will load the appropriate module & adjust @ISA to match.  This relies on the fact that only one instance of the
status server can be active at any point in time.  To support multiple simultaneous instances based on different
protocols would require a different approach.  This isn't in the requirements...

=cut

sub new {
    my $class = shift;

    # Adjust our base class according to the currently selected protocol

    my $proto = ucfirst( $TWiki::cfg{Tasks}{StatusServerProtocol} );
    eval "require TWiki::Tasks::${proto}Server;";
    die "Status server ${proto}Server: $@\n" if( $@ );

    @ISA = grep { !/^TWiki::Tasks::\w+Server$/ } @ISA;
    unshift @ISA, "TWiki::Tasks::${proto}Server";

    return $class->SUPER::new( @_ );
}

=pod

---++ ObjectMethod connect( $sock, $restarting, $initiator, $textformat ) -> $cx
Associate a new connection's socket with this server.

Subclass of GenericServer::connect, which documents the parameters.

If initiator of a restart, tell client we're back.  Only that http connection is maintained across a restart.

Returns connection object.

=cut

sub connect {
    my $self = shift;
    my( $sock, $restarting, $initiator, $txtformat ) = @_;

    my $cx = $self->SUPER::connect( @_ );

    return unless( $cx );

    my $now =time;
    foreach my $cookie (keys %{$self->{CookieJar}}) {
	delete $self->{CookieJar}{$cookie} if( $now > $self->{CookieJar}{$cookie} );
    }

    return $cx unless( $initiator );

    if( $txtformat =~ /^s$/i ) {
        # Summary only from script - no redirect, no status just a simple text ack

        if( $txtformat eq 'S' ) {
            my $q = CGI->new();
            $cx->print( $q->header, $q->html($q->body("Daemon $$ has restarted")) );
        } else {
            $cx->print( "Daemon $$ has restarted\n" );
        }
	$cx->send;
	$cx->close(0);

        return $cx;
    }

    # Respond to the restart's POST with a redirect to prevent refresh accidents.
    my $pars = ($txtformat eq 't')? '&text' : '';

    # Issue a cookie for authentication because we don't have the old instance's secret or issued nonces.
    # This is reasonably safe since we are sending the cookie over the connection previously authenticated,
    # it's only valid for GET, and it has a short lifetime.

    require CGI;
    require CGI::Cookie;
    require CGI::Session::ID::sha256;

    my $q = CGI->new();

    my $sessid = CGI::Session::ID::sha256::generate();
    $self->{CookieJar}{$sessid} = $now +  ($debug? 600 : 30);

    # Session cookie, no max-age or expires
    my $cookie = CGI::Cookie->new( -name => 'X-TWiki-Redirect',
                                   -value => $sessid,
                                 );
    my $selfhost = $cx->sockhost;
    $cx->rspheader( Status => '303 Use GET for data', 
                    Location => "http://$selfhost/status?manage$pars",
                    Content_Type => 'text/html',
                    Set_Cookie => "$cookie",
                  );
    $cx->print( $q->html($q->body($q->a( {href => "http://$selfhost/status?manage$pars"}, "Click here for result" ))) );
    $cx->send;
    $cx->close(0);

    return $cx;
}

# ---++ StaticMethod _manageForm( $cx, $textformat ) -> $form
# Produce a management form
#
# (This form could use some formatting)
#
# Returns form text

sub _manageForm {
    my $cx = shift;
    my $textformat = shift(@_)? '?text=1' : '';

    my $info = $cx->reqinfo;
    my $selfhost = $info->{scheme} . $info->{selfhost};

    return <<"FORM";
<form action="$selfhost/control$textformat" method="post">
<label for="debug"> Output debugging information<input type="checkbox" id="debug" name="debug" value="1"></label>
<label for="abort"> Abort running tasks<input type="checkbox" id="abort" name="abort" value="1"></label>
<input type="submit" name="Submit" value="Stop">
<input type="submit" name="Submit" value="Restart">
<input type="submit" name="Submit" value="Suspend">
<input type="submit" name="Submit" value="Resume">
</form>
FORM
}

=pod

---++ ObjectMethod authenticate( $cx, $info ) -> $status
Authenticates a connection
   * =$cx= - connection object
   * =$info= - connection request information object

 =$info= provides protocol, method, uri, query & fulluri if it's necessary to discriminate.

There are three authentication scenarios:
   * A cookie-based authentication is used for connection restart
   * A private digest-style method is used for local scripts, which can obtain the TWiki configure password
   * HTTP Basic authentication for real users.

Updates =$info= with realm and authorized user hash

Returns true if request authenticates; false if not (and a new challenge has been issued)

=cut

sub authenticate {
    my $self = shift;
    my $cx = shift;
    my $info = shift() || $cx->reqinfo();

    # Authenticate GET if we've issued a redirect with a matching session cookie recently
    # This is required for restart

    if( $info->{method} eq 'GET' && (my $cookies = $info->{cookies}) ) {
	if( my $rc = $cookies->{'X-TWiki-Redirect'} ) {
	    $rc = $rc->value;
	    return 1 if( exists $self->{CookieJar}{$rc} &&
			 time <= $self->{CookieJar}{$rc} );
	}
    }

    # Standard request, provide realm and authorized user hash to standard authentication

    $TWiki::cfg{Tasks}{StatusAddr} =~ /^([^:]+)(?::(\d+))?$/;
    my $host = $1;

    my $realm = "TWiki Administration\@" . (($host && $host !~ /^localhost(?:\.localdomain)?/)? $host : hostname);

    $info->{realm} = $realm;
    $info->{users} = {
		      $TWiki::cfg{AdminUserLogin} => $TWiki::cfg{Password},
		     };
    return $self->SUPER::authenticate( $cx, $info );
}

=pod

---++ ObjectMethod receive( $cx, $method )
HTTP request dispatch

Validates request method and dispatches.

If invalid, upcalls to HttpServer to provide error response.

=cut

sub receive {
    my $self = shift;
    my( $cx, $method ) = @_;

    if( $method =~ /^(?:GET|POST)$/ ) {
	return $self->$method( $cx );
    }
    return $self->SUPER::receive( @_ );
}

=pod

---++ ObjectMethod GET( $cx )
Process http GET
   * =$cx= - connection object

Generates response to HTTP GET.

URI:
   * / -  standard status display
   * /status - standard status display
   * /status/list - Display daemon status listing developer information
   * /status/brief - Reserved - currently standard display: Should it suppress some log messages?
   * /status/debug - Debug level detail

Query parameters:
   * =debug= - Debug level detail
   * =embed= - Omit header (output is to be embedded in a larger page)
   * =manage= - Include management form in response.  Form only if =manage= value is =onlyform=.
   * =text= - Provide output in text format (default is html)

=cut

sub GET {
    my( $self, $cx ) = @_;

    my $req = $cx->reqinfo();

    my $uri = $req->{uri};

    my $textformat = $cx->qparam( 'text' );
    $self->htmlHeader( $cx, title => 'Task Framework Status' ) unless( $textformat || $cx->qparam( 'embed' ) );
    my $manage = $cx->qparam( 'manage' ) || '';

    if( $uri =~ m!^(?:/|/status/?|/status/(list|brief|debug)/?)?$! ) {
	$cx->print( statusText( $textformat, ($cx->qparam( 'debug' )? "debug" : ( defined $1? $1 : 'brief' )) ) )
          unless( $manage eq 'onlyform' );
    } else {
	$self->Error( $cx, HTTP_NOT_FOUND, "Not Found", "$uri is not available on this server" );
	return;
    }
    $cx->print( _manageForm($cx, $textformat) ) if( $manage );

    $self->htmlEnd( $cx ) unless( $textformat  || $cx->qparam( 'embed' ) );

    $cx->send();

    return;
}

=pod

---++ ObjectMethod POST( $cx )
Process http POST
   * =$cx= - connection object

Generates response to HTTP POST.

URI:
   * /control
      * Submit
         * restart - restart daemon
         * resume - resume task scheduling
         * stop - stop daemon
         * suspend - suspend task scheduling
      * text - generate status in text format
      * debug - send daemon status in response
      * abort - kill running tasks (normally waits for them to complete)

Function.
Return value.

=cut

sub POST {
    my( $self, $cx ) = @_;

    my $req = $cx->reqinfo();

    # Get form data, process commands - e.g. stop

    return $self->Error( $cx, HTTP_BAD_REQUEST, "Unacceptable post" ) unless( $cx->fparam( 'Submit' ) );

    my $cmd = lc( $cx->fparam( 'Submit' ) );

    my( $ctype, $txt );
    my $msg = '';
    my $uri = $req->{uri};

    my $textformat = $cx->param( 'text' );
    my $sendstatus = $cx->param( 'debug' );
    my $abort = $cx->param( 'abort' );

    unless( $textformat ) {
	$msg = "Content-Type: text/html\n\n";
    }

# Redirects ?
# stop => Page with start control
# suspend => Page with resume control
# Referer header (sic) or default to reqinfo->{selfhost}/status?manage(&{querystr)

    if( $uri eq '/control' ) {
	if( $cmd eq 'stop' ) {
	    ($ctype, $txt) = stopDaemon( $abort );
	    $msg .= $txt;
	    $msg .= statusText( $textformat, 'debug' ) if( $sendstatus );
	} elsif( $cmd eq 'restart' ) {
	    ($ctype, $txt) = restartDaemon( $abort );
	    # Msg perhaps with server push, not now.
#	    $msg .= $txt;

	    # Compute the list of connections to be maintained and response type
            # s = 1 line summary; t = text status; h = html

            my $type = 0;
            $type += 1 if( $textformat );
            $type += 2 if( $cx->param( 'summary' ) );

	    main::listRestartCxs( $cx,  ( 'h', 't', 'S', 's' )[$type] );

	    logLines( "\t", statusText( $type & 1, 'debug' ), \&tprint ) if( $sendstatus );

            # Can we preserve this connection to report restart from the new instance?
            # Protocols with heavy state (e.g. SSL) can't.

            if( $cx->server->preserve( $cx ) ) {
                # Preserving, don't say anything now.
                $cx->close($ctype);
                return;
            }

            # Can't preserve, issue message

            $txt .= '<p>' unless( $textformat );
            $msg .= $txt . << "RESTART";

Closing control connection.
RESTART
	} elsif( $cmd eq 'suspend' ) {
	    ($ctype, $txt) = suspendScheduling();
	    $msg .= $txt;
	    $msg .= statusText( $textformat, 'debug' ) if( $sendstatus );
	} elsif( $cmd eq 'resume' ) {
	    ($ctype, $txt) = resumeScheduling();
	    $msg .= $txt;
	    $msg .= statusText( $textformat, 'debug' ) if( $sendstatus );
	} else {
	    $msg = "Unknown control command: $cmd " . join( " ", map { "$_:" . $cx->param( $_ ) } $cx->param );
	}
    } else {
	$self->Error( $cx, HTTP_NOT_FOUND, "Not Found", "$uri is not available on this server" );
	return;
    }

    $cx->print( $msg );
    $cx->send();

    $cx->close($ctype) if( $ctype );
    return;
}

=pod

---++ ObjectMethod Error( $cx, $errnum, $errtxt, @paras )
Provide an error page

If request is text format, generate page.

If html, let HttpServer do the work.

=cut

sub Error {
    my $self = shift;
    my $cx = shift;

    my $req = $cx->reqinfo();
    return $self->SUPER::Error( $cx, @_ ) unless( $cx->qparam( 'text' ) );

    $cx->cancelRsp();

    my( $errnum, $errtxt)  = @_[2..3];
    my $msg = "Error $errnum: $errtxt\n";
    $msg .= "\n" . join( "\n", @_[4..$#_] ) if( @_[4..$#_] );
    chomp $msg;
    $msg .= "\n";

    $cx->print( <<"EOM" );
Status: $errnum $errtxt

$msg
EOM
    $cx->send();

    return;
}

# ##################################################
#
# Status text generator
#
# ##################################################

=pod

---++ StaticMethod _max( $max, $idx, $newstring ) -> $new
Update maximum field width
   * =$max= - reference to field width array
   * =$idx= - slot index to update
   * =$newstring= - new string

Updates maximum width of field data when generating text format tables.

Returns new maximum width of selected field.

Used by status-generating subroutines, but not for general use.

=cut

sub _max(\@$$) {
    my( $max, $idx, $new ) = @_;

    my $newlen = length( $new );
    $max->[$idx] = $newlen if( $max->[$idx] < $newlen );
    return $max->[$idx];
}

=pod

---++ StaticMethod statusText( $txtformat, $detail ) -> $string
Generate daemon status display
   * =$txtformat= - True to generate status as formatted text, false for html
   * =$detail= - Desired level of detail - Definitions may vary with experience.  Not for scripts.
      * =brief= - Standard summary
      * =list= - Intermediate detail (plugin/driver developer & some admins)
      * =debug= - All available detail (any developer, including framework)

Generates status display.  This code knows rather more about other object's internals than it should; at some point it might be
better to delegate more to object  =status= methods.

Returns formatted status.

=cut

sub statusText {
    my $txtformat = shift;
    my $detail = lc( shift || 'brief' );

    my @max = (0) x 10;

    # *** Section: Server heading
    my $msg = '';
    $msg .= '<div style="font:monospace;">' unless( $txtformat );

    $msg .= sprintf( "%s version $main::VERSION $$ %s %s\n",
		     $daemonName,
		     (@restartFds? 'restarted' : 'started'),
		     (scalar localtime($startTime))
		     );
    $msg .= '<br />' unless( $txtformat );
    $msg .= schedulerStatus() . "\n";

    # *** Section: Plugin status
    #     Report any initialization errors (may be unique to tasking environment)

    my $twiki = $TWiki::Plugins::SESSION;
    @max = (0);
    my $perrs;
    foreach my $plugin ( @{$twiki->{plugins}{plugins}} ) {
        if( $plugin->{errors} ){
	    $perrs++;
	    _max @max, 0, $plugin->{name};
	}
    }
    if( $perrs ) {
	$msg .=  $txtformat? "\nPlugin initialization errors:\n" :
	         '<h2 style="color:red;font-weight:bold;">Plugin initialization errors</h2><table>';
	my $sp = basename $main::twikiLibPath;
	foreach my $plugin (@{$twiki->{plugins}{plugins}} ) {
	    next unless( $plugin->{errors} );
	    my @errors = map { s/$main::twikiLibPath/$sp/gm; $_ } @{$plugin->{errors}};

	    if( $txtformat ) {
		$msg .= sprintf( " %-*s => %s\n",
				 $max[0], $plugin->{name},
				 join( "\n" . ' ' x (1+$max[0]+4), @errors ) );
	    } else {
		$msg .= "<tr valign=\"top\"><td style=\"font-family:monospace;color:red;\"><b>$plugin->{name}</b><td><code>" . join( "\n", @errors ) . '</code>';
	    }
	}
	$msg .= '</table>' unless( $txtformat );
    } else {
	$msg .= '<h2>' unless( $txtformat );
	$msg .= "\nAll plugins initialized succesfully\n";
	$msg .= '</h2>' unless( $txtformat );
    }

    # *** Section: Driver configuration
    #     (External task) drivers are only loaded in this environment
    #     so we provide a bit more detail

    if( keys %driverRegistry ) {
	$msg .= '<h2>' unless( $txtformat );
	$msg .= "\nConfigured drivers\n";
	$msg .= '</h2><table><tr valign="bottom"><td><b>Name</b><td><b>Version</b><td><b>Release</b><td><b>Description<br />' .
                'Path/Error' unless( $txtformat );

	# mod ver file err
	@max = (0) x 4;
	_max @max,0, 'Name';
	_max @max,1, 'Version';
	_max @max,2, 'Release';
	_max @max,3, 'Description';
	my $sp = basename $main::twikiLibPath;
	foreach my $driver (keys %driverRegistry) {
	    my $k = "$driverRegistry{$driver}{Module}.pm";
	    $k =~ s!::!/!g;
	    _max @max,0, $driver;
	    _max @max,1, (exists $driverRegistry{$driver}{Version})? $driverRegistry{$driver}{Version} : '(No version)';
	    _max @max,2, (exists $driverRegistry{$driver}{Release})? $driverRegistry{$driver}{Release} : '(No Release)';
	    _max @max,3, (exists $driverRegistry{$driver}{Description})? $driverRegistry{$driver}{Description} : '(No Description)';
	    my $path = $INC{$k};
	    $path =~ s/^$main::twikiLibPath/$sp/ if( defined $path );
	    _max @max,3, $INC{$k}? "from $path" : "Not loaded" if( $detail ne 'brief' );
	}
	$msg .= sprintf( " %-*s %-*s %-*s %-*s\n",
                         $max[0], 'Name',
                         $max[1], 'Version',
                         $max[2], 'Release',
                         $max[3], 'Description' ) if( $txtformat );

	foreach my $driver (sort keys %driverRegistry) {
	    my $k = "$driverRegistry{$driver}{Module}.pm";
	    $k =~ s!::!/!g;

	    my $path = $INC{$k};
	    $path =~ s/^$main::twikiLibPath/$sp/ if( defined $path );
	    my $error = $driverRegistry{$driver}{error} if( exists $driverRegistry{$driver}{error} );
	    if( defined $error ) {
		$error =~ s/$main::twikiLibPath/$sp/gm;
		chomp $error;
	    }

	    if( $txtformat ) {
		$msg .= sprintf( " %-*s %-*s %-*s %s\n",
				 $max[0], $driver,
				 $max[1], ((exists $driverRegistry{$driver}{Version})? $driverRegistry{$driver}{Version} :
                                                                                       '(No version)'),
				 $max[2], ((exists $driverRegistry{$driver}{Release})? $driverRegistry{$driver}{Release} :
                                                                                       '(No version)'),
				 ((exists $driverRegistry{$driver}{Description})? $driverRegistry{$driver}{Description} :
                                                                                  '(No description)') );
                $msg .= sprintf( "    %-*.*s%-*s%s\n",
				 $max[0]+$max[1]+$max[2], $max[0]+$max[1]+$max[2], , '',
				 $max[3], ($INC{$k}? "from $path" : "Not loaded"),
				 (defined $error? " $error" : '') . '' ) if( $detail ne 'brief' || defined $error );
	    } else {
		$msg .= "<tr valign=\"top\"><td><b>$driver</b><td>" . ((exists $driverRegistry{$driver}{Version})?
                                                                       $driverRegistry{$driver}{Version} : '(No&nbsp;version)') .
		    "<td>" . ((exists $driverRegistry{$driver}{Release})? $driverRegistry{$driver}{Release} : '(No&nbsp;release)') .
		    "<td>" . ((exists $driverRegistry{$driver}{Description})? $driverRegistry{$driver}{Description} :
                                                                              '(No&nbsp;description)');
                $msg .= "<tr><td><td><td>" .
                  "<td>" . ($INC{$k}? $path : "Not loaded") .
                    (defined $error? "<td><code>$error}</code>" : '') if( $detail ne 'brief' || defined $error );
	    }
	}
	$msg .= '</table>' unless( $txtformat );
    }

    # *** Section: Scheduled tasks (crontab & time)

    # Sort by next scheduled execution time.
    # (Does not reflect order of execution due to queueing & hashing, but that doesn't seem important.)

    @max = (0, 0);
    my $now = time;
    my @entries = sort { $a->[2] <=> $b->[2] }
                                               map {
						       my $r;
						       my $time = $_->{schedule};
						       _max @max, 0, $time; _max @max, 1, $_->{queue};
						       if( $_->{trigger} eq 'schedule' ) {
							   my $cronjob = $_->cronjob;
							   $cronjob = '?' unless( defined $cronjob );
							   $r = [ $_,
								  $cronjob,
								  $cronHandle->get_next_execution_time( $time, $now ),
								];
						       } elsif( !$_->{_queued} ) { # Exclude time tasks already in execution queue
							   $r = [ $_,
								  '-',
								  $_->{runtime},
								];
						       }
						       $r ? $r : ()
						   } grep { $_->{trigger} =~ /^(?:schedule|time)$/ }
                                                                             TWiki::Tasks::getTaskList( owner => '*' );
    my $pad = ' ' x (($max[0] - length('schedule'))/2); # N.B. "Run Once"
    $msg .= '<h2>' unless( $txtformat );
    $msg .= "\nTime-triggered job queue (ordered by next scheduled execution time):\n";
    $msg .= '</h2><table>' unless( $txtformat );
    if( $txtformat ) {
	$msg .= sprintf( " Job %sSchedule%s  Next Execution           Queue%s Task\n",
			          $pad, $pad, ' ' x ($max[1] > 5? $max[1] - 5 : 0) );
    } else {
	$msg .= '<tr><td><b>Job</b><td><b>Schedule</b><td><b>Next Execution</b><td><b>Queue</b><td><b>Task</b>';
    }
    foreach my $qe ( @entries ) {
	if( $txtformat ) {
	    my $sched = $qe->[0]{schedule};
	    $sched = (' ' x (($max[0] - length( $sched ))/2)) . $sched if( $qe->[0]{trigger} eq 'time' );
	    $msg .= sprintf( "%4s %-*s %s%s %-*s %s", 
			     $qe->[1], $max[0], $sched,
			     ($now > $qe->[2]? '*' : ' '), (scalar localtime( $qe->[2] )),
			     $max[1], $qe->[0]{queue},
			     $qe->[0]{name},
			   );
	} else {
	    $msg .= "<tr><td>$qe->[1]<td>$qe->[0]{schedule}<td>";
	    if( $now > $qe->[2] ) {
		$msg .= '<span style="color:red;">' . (scalar localtime( $qe->[2] )) . '</span>';
	    } else {
		$msg .= scalar localtime( $qe->[2] );
	    }
	    $msg .= "<td>$qe->[0]{queue}" .
	            "<td>$qe->[0]{name}";
	}
	$msg .= "\n";
    }
    $msg .= '</table>' unless( $txtformat );

    # *** Section: event-triggered tasks

    @max = (0, 0);
    my @eventTasks = sort { $a->{trigger} cmp $b->{trigger} || $a->{name} cmp $b->{name} }
                     grep { ($_->{trigger} =~ /schedule|time/)? 0 : (_max( @max, 0, $_->{name} ), _max( @max, 1, $_->{queue} ), 1) }
                                                                                          TWiki::Tasks::getTaskList( owner => '*' );

    if( @eventTasks ) {
	$msg .= '<h2>' unless( $txtformat );
	$msg .= "\nEvent-triggered tasks:\n";
	$msg .= '</h2><table>' unless( $txtformat );

	if( $txtformat ) {
	    $msg .= "   Type    Queue" . ' ' x ($max[1] -5) . " Task";
            $msg .= ' ' x ($max[0] -4) . " Target(s)" if( $detail ne 'brief' );
            $msg .= "\n";
	} else {
	    $msg .= '<tr><td><b>Type</b><td><b>Queue</b><td><b>Task</b>';
            $msg .= '<td><b>Target(s)</b>' if( $detail ne 'brief' );
	}
	foreach my $task ( @eventTasks ) {
	    if( $txtformat ) {
		$msg .= sprintf( " %-9s %-*s %-*s ", $task->{trigger}, $max[1], $task->{queue}, $max[0], $task->{name} );
	    } else {
		$msg .= "<tr valign=\"top\"><td>$task->{trigger}<td>$task->{queue}<td>$task->{name}";
	    }
            if( $detail ne 'brief' ) {
                if( $task->{trigger} =~ /^(?:file|directory)$/ ) {
                    $msg .= "<td>" unless( $txtformat );
                    $msg .= $task->{file};
                } elsif( $task->{trigger} eq 'config' ) {
                    $msg .= "<td>" unless( $txtformat );
                    $msg .= join( ', ', @{$task->{items}} );
                }
            }
	    $msg .= "\n";
	}
	$msg .= '</table>' unless( $txtformat );
    }

    # *** Section: queued tasks

    my $ftab = schedulerForkStatus();
    my $taskQ = TWiki::Tasks::Execute::_queuedTaskList();
    my $h;

    foreach my $qName (sort keys %$taskQ ) {
	my $queue = $taskQ->{$qName};

	next unless( $queue && @$queue );

	unless( $h ) {
	    $msg .= '<h2>' unless( $txtformat );
	    $msg .= "\nTask execution queues:\n";
	    $msg .= '</h2>' unless( $txtformat );
	    $h = 1;
	}

	@max = (0);
	foreach my $task (@$queue) {
	    _max( @max, 0, $task->{name} );
	}

	if( $txtformat ) {
	    $msg .= "\n$qName:\n";
	    $msg .= "  PID Started                   Type     Task";
            $msg .= ' ' x ($max[0] -4) . " Target(s)" if( $detail ne 'brief' );
            $msg .= "\n";
	} else {
	    $msg .= "<h3>$qName:</h3><table>" .
	            '<tr><td><b>PID</b><td><b>Started</b><td><b>Type</b><td><b>Task</b>';
            $msg .= '<td><b>Target(s)</b>' if( $detail ne 'brief' );
	}
	foreach my $task ( @$queue ) {
	    my $pid = $task->{_pid};
	    if( $txtformat ) {
		if( defined $pid ) {
		    if( $ftab->{$pid}{running} ) {
			$msg .= sprintf( "%5u %24s %-9s %-*s ", $pid, (scalar localtime($ftab->{$pid}{started})),
					 $task->{trigger}, $max[0], $task->{name} );
		    } else {
			$msg .= sprintf( "%5s %24s %-9s %-*s ", 'done', (scalar localtime($ftab->{$pid}{started})),
					 $task->{trigger}, $max[0], $task->{name} );
		    }
		} else {
		    $msg .= sprintf( "%5s %-24s %-9s %-*s ", ' ', 
				     (' ' x 8) . '-queued-' . ((@{$task->{_args}} > 1)? sprintf( '(x%u)', 
                                                                                                 scalar @{$task->{_args}} ) : ''),
				     $task->{trigger}, $max[0], $task->{name} );
		}
	    } else {
		$msg .= "<tr valign=\"top\">";
		if( defined $pid ) {
		    if( $ftab->{$pid}{running} ) {
			$msg .= "<td>$pid<td>";
		    } else {
			$msg .= "<td>done<td>";
		    }
		    $msg .= (scalar localtime($ftab->{$pid}{started}));
		} else {
		    $msg .= "<td>&nbsp;<td style=\"text-align:center;\">-queued-";
		    $msg .= sprintf( '(x%u)', scalar @{$task->{_args}} ) if( @{$task->{_args}} );
		}
		$msg .= "<td>$task->{trigger}<td>$task->{name}";
	    }
            if( $detail ne 'brief' ) {
                if( $task->{trigger} =~ /^(?:file|directory)$/ ) {
                    $msg .= "<td>" unless( $txtformat );
                    $msg .= $task->{file};
                } elsif( $task->{trigger} eq 'config' ) {
                    $msg .= "<td>" unless( $txtformat );
                    $msg .= join( ', ', @{$task->{items}} );
                }
            }
	    $msg .= "\n";
	}
	$msg .= '</table>' unless( $txtformat );
    }

    # *** Section: Client connection (to embedded webserver, debug server, etc)  listing

    foreach my $server (@serverRegistry) {
	if( defined $server ) {
	    $msg .= $server->status( $txtformat );
	}
    }

    # *** Section: Recent log entires

    if( $statusLogLines || $detail eq 'debug' ) {
	$msg .= '<h2>' unless( $txtformat );
	$msg .= "\nRecent activity\n";
	$msg .= '</h2>' unless( $txtformat );

	my $logtext = logHistory( ($detail eq 'debug')? -1 : $statusLogLines );
	$logtext =~ s!\n!<br />!g unless( $txtformat );
	$msg .= $logtext;
    }

    $msg .= '</div>' unless( $txtformat );

    return $msg;
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
