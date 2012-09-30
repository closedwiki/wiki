# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (c) 2011 Tmothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.

use strict;
use warnings;

=pod

---+ package TWiki::Tasks::Globals

This code is not expected to run under mod_perl (though in some respects it provides a similar environment
to its clients.).

A few globals are more convenient than making everything a method call and/or spelling long names.
We do this for common, frequently-accessed state.  Centralizing import by tags also documents who
uses what.

=cut

package TWiki::Tasks::Globals;

use base 'Exporter';
our( %EXPORT_TAGS, @EXPORT_OK );

BEGIN {
    our(
	%cliOptions,             # Options parsed from command line
	$cronHandle,             # Schedule::Cron handle
        $cwd,                    # Daemon's working directory
	$daemonName,             # Unique name of this Daemon (from startup)
	$debug,                  # Global debugging mode
	%driverRegistry,         # Loaded driver information
	$forkedTask,             # True when running in an asynchronous fork
	%parentFds,              # File descriptors open in parent
	@restartFds,             # File descriptors preserved across restart, restarting/ed flag
	@serverRegistry,         # List of network servers
	$startTime,              # Time daemon (re-)started
	@termEnvs,               # Terminal environment variables used by perl debugger
	$twiki,                  # TWiki session
	);

    # Standard expression for configuration item keys
    #  - Expression used in TWiki Configure/Valuer.pm.  ':' added to handle some Foswiki cases
    # our $configItemRegex = qr/(?:\{[-:\w'"]+\})+/o;   # Standard expression for configuration item keys

    # - More forgiving of whitespace and most things in quoted keys.
    our $configItemRegex = qr/(?:\{\s*(?:\w+|'(?:\\.|[^'])*'|"(?:\\.|[^"])*")\s*\})+/o;

%EXPORT_TAGS = (
    main => [ qw( %cliOptions $cwd $debug $forkedTask @restartFds %parentFds @serverRegistry $startTime ) ],
    api => [ qw( $forkedTask ) ],
    cfgtrigger => [ qw( $configItemRegex $debug $forkedTask ) ],
#   cgi => [ qw() ],
#    debugsrv => [ qw( ) ],
    execute => [ qw( %cliOptions $cronHandle $forkedTask %parentFds @termEnvs $twiki ) ],
    gcx => [ qw( $forkedTask %parentFds ) ],
    gserver => [ qw( $forkedTask %parentFds ) ],
    httpsrv => [ qw( $debug ) ],
    inotify => [ qw( $debug $forkedTask %parentFds ) ],
    internal => [ qw( %cliOptions $debug %driverRegistry @serverRegistry $twiki ) ],
    logging => [ qw( %cliOptions $debug $forkedTask ) ],
    param => [ qw( $configItemRegex $debug ) ],
    wfpoller => [ qw( $debug $forkedTask ) ],
    schedule => [ qw( $cronHandle $debug ) ],
    schtrigger => [ qw( $cronHandle $debug $forkedTask ) ],
    startup => [ qw( %cliOptions $cronHandle $cwd $daemonName $debug %driverRegistry $forkedTask @restartFds %parentFds
                     @serverRegistry @termEnvs $twiki ) ],
    status => [ qw( $cronHandle $daemonName $debug %driverRegistry @restartFds @serverRegistry $startTime ) ],
    tasks => [ qw( $debug $forkedTask ) ],
    timetrigger => [ qw ( $debug ) ],
    watchfile => [ qw( $debug ) ],
               );

    my %seen;

    push @{$EXPORT_TAGS{all}},
             grep {!$seen{$_}++} @{$EXPORT_TAGS{$_}} foreach keys %EXPORT_TAGS;
    Exporter::export_ok_tags( 'all' );
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
