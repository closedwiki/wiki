# Copyright (C) 2004 Florian Weimer, Crawford Currie http://c-dot.co.uk
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

=pod

---+ package TWiki::Sandbox
This object provides an interface to the outside world. All calls to
system functions, or handling of file names, should be brokered by
this object.

=cut

package TWiki::Sandbox;

use strict;
use Assert;
use Error qw( :try );

# TODO: Sandbox module should probably use custom 'die' handler so that
# output goes only to web server error log - otherwise it might give
# useful debugging information to someone developing an exploit.

# TODO: Get rid of $cmdQuote in TWiki.cfg and TWiki.pm

sub _writeDebug {
    my $this = shift;
#    $this->{session}->writeDebug($_[0]);
#    print STDERR $_[0],"\n";
}

=pod

---++ new( $session, $OS, $detailedOS )

Construct a new sandbox suitable for $OS, setting
flags for platform features that help.  $detailedOS distinguishes
Perl variants on platforms such as Windows.

=cut

sub new {
    my ( $class, $session, $OS, $detailedOS ) = @_;
    my $this = bless( {}, $class );

    assert(ref($session) eq "TWiki") if DEBUG;
    $this->{session} = $session;

    $this->{REAL_SAFE_PIPE_OPEN} = 0;           # supports "open FH, '-|"
    $this->{EMULATED_SAFE_PIPE_OPEN} = 0;       # emulate open from pipe

    if ( $OS eq "UNIX" or 
        ($OS eq "WINDOWS" and $detailedOS eq "cygwin"  ) ) {
        # Real safe pipes on Unix/Linux/Cygwin, for Perl 5.005+
        $this->{REAL_SAFE_PIPE_OPEN} = 1;

    } elsif ( $OS eq "WINDOWS" ) {
        # Emulated safe pipes on ActivePerl 5.8 or higher 
        my $isActivePerl = eval 'Win32::BuildNumber !~ /Win32/';
        if ( $isActivePerl and $] >= 5.008 ) {
            $this->{EMULATED_SAFE_PIPE_OPEN} = 1 unless $@;
        }
        # FIXME - not yet working, disable!
        $this->{EMULATED_SAFE_PIPE_OPEN} = 0;
    }

    $this->_writeDebug("use safe pipes setting = $this->{REAL_SAFE_PIPE_OPEN}");
    $this->_writeDebug("emulated safe pipes setting = $this->{EMULATED_SAFE_PIPE_OPEN}");

    # 'Safe' means no need to filter in on this platform - check 
    # sandbox status at time of filtering
    $this->{SAFE} = ($this->{REAL_SAFE_PIPE_OPEN} || 
                    $this->{EMULATED_SAFE_PIPE_OPEN});

    ##$this->_writeDebug("safe setting = $this->{SAFE}");

    # Shell quoting - shell used only on non-safe platforms
    if ($OS eq "UNIX" or ($OS eq "WINDOWS" and $detailedOS eq "cygwin"  ) ) {
        $this->{CMDQUOTE} = '\'';
    } else {
        $this->{CMDQUOTE} = '\"';
    }

    # Set to 1 to trace all command executions to STDERR
    $this->{TRACE} = 0;
    #$this->{TRACE} = 1;             # DEBUG

    return $this;
};


=pod

---++ untaintUnchecked ( $string ) -> $untainted

Untaints $string without any checks (dangerous).  If $string is
undefined, return undef.

The intent is to use this routine to be able to find all untainting
places using grep.

=cut

sub untaintUnchecked {
    my ( $string ) = @_;

    if ( defined( $string) && $string =~ /^(.*)$/ ) {
        return $1;
    }
    return $string;            # Can't happen.
}

=pod

---++ normalizeFileName ( $string [, $dotdot] ) -> $filename

STATIC Errors out if $string contains whitespace characters.  If $dotdot is
present and true, allow ".." in path names.

The returned string is not tainted, but it may contain shell
metacharacters and even control characters.

=cut

sub normalizeFileName {
    my ($string, $dotdot) = @_;
    return "" unless $string;
    my $absolute = $string =~ /^\//;
    my @result;
    for my $component (split /\//, $string) {
        next unless $component;
        next if $component eq '.';
        if ($component eq '..') {
            if ($dotdot && @result > 0) {
                pop @result;
            } else {
                throw Error::Simple( "directory traversal attempt in filename '$string'" );
            }
        } elsif ($component =~ /^(\S+)$/) {
            # We need to untaint the string explicitly.
            # FIXME: This might be a Perl bug.
            push @result, untaintUnchecked $1;
        } else {
            throw Error::Simple( "whitespace in file name component '$component' of filename '$string'" );
        }
    }
    if (@result) {
        if ($absolute) {
            $result[0] = "/$result[0]";
        } elsif ($result[0] =~ /^-/) {
            $result[0] = "./$result[0]";
        }
        return join '/', @result;
    } else {
        return '/' if $absolute;
        throw Error::Simple( "empty filename '$string'" );
    }
}

=pod

---++ buildCommandLine ( $template, %params ) -> @arguments

$template is split at whitespace, and '%VAR%' strings contained in it
are replaced with $params{VAR}.  %params may consist of scalars and
array references as values.  Array references are dereferenced and the
array elements are inserted into the command line at the indicated
point.

'%VAR%' can optionally take the form '%VAR|FLAG%', where FLAG is a
single character flag.  Permitted flags are
   * U untaint without further checks -- dangerous,
   * F normalize as file name,
   * N generalized number,
   * S simple, short string,
   * D rcs format date

=cut

sub buildCommandLine {
    my ($this, $template, %params) = @_;
    assert(ref($this) eq "TWiki::Sandbox") if DEBUG;
    my @arguments;

    for my $tmplarg (split /\s+/, $template) {
        next if $tmplarg eq ''; # ignore leading/trailing whitespace

        # Split single argument into its parts.  It may contain
        # multiple substitutions.

        my @tmplarg = $tmplarg =~ /([^%]+|%[^%]+%)/g;
        my @targs;
        for my $t (@tmplarg) {
            if ($t =~ /%(.*?)(|\|[A-Z])%/) {
                my ($p, $flag) = ($1, $2);
                if (! exists $params{$p}) {
                    throw Error::Simple( "unknown parameter name $p" );
                }
                my $type = ref $params{$p};
                my @params;
                if ($type eq '') {
                    @params = ($params{$p});
                } elsif ($type eq 'ARRAY') {
                    @params =  @{$params{$p}};
                } else {
                    throw Error::Simple( "$type reference passed in $p" );
                }

                for my $param (@params) {
                    if ($flag) {
                        if ($flag =~ /U/) {
                            push @targs, untaintUnchecked $param;
                        } elsif ($flag =~ /F/) {
                            push @targs, normalizeFileName $param;
                        } elsif ($flag =~ /N/) {
                            # Generalized number.
                            if ( $param =~ /^([0-9A-Fa-f.x+\-]{0,30})$/ ) {
                                push @targs, $1;
                            } else {
                                throw Error::Simple( "invalid number argument '$param'" );
                            }
                        } elsif ($flag =~ /S/) {
                            # Harmless string.
                            if ( $param =~ /^([0-9A-Za-z.+_\-]{0,30})$/ ) {
                                push @targs, $1;
                            } else {
                                throw Error::Simple( "invalid string argument" );
                            }
                        } elsif ($flag =~ /D/) {
                            # RCS date.
                            if ( $param =~ m|^(\d\d\d\d/\d\d/\d\d \d\d:\d\d:\d\d)$| ) {
                                push @targs, $1;
                            } else {
                                throw Error::Simple( "invalid date argument $param" );
                            }
                        } else {
                            throw Error::Simple( "illegal flag in $t" );
                        }
                    } else {
                        push @targs, $param;
                    }
                }
            } else {
                push @targs, $t;
            }
        }

        # Recombine the argument if the template argument contained
        # multiple parts.

        if (@tmplarg == 1) {
            push @arguments, @targs;
        } else {
            push @arguments, join ('', @targs);
        }
    }

    return @arguments;
}

=pod

---++ readFromProcessArray ( $path, $template, @params ) -> @outputLines

Invokes the program $path with the arguments described by $template
and @params, and returns the output of the program as an array of
lines.  If $path is not absolute, $ENV{PATH} is searched.

$template is interpreted by buildCommandLine.

The caller has to ensure that the invoked program does not react in a
harmful way to the passed arguments.  readFromProcessArray merely
ensures that the shell does not interpret any of the passed arguments.

=cut

# TODO: get emulated pipes or even backticks working on ActivePerl...
# TODO: make most of this routine common with readFromProcess?

sub readFromProcessArray {
    my ($this, $path, $template, %params) = @_;
    assert(ref($this) eq "TWiki::Sandbox") if DEBUG;

    my @data;                          # Output lines
    my $processFileHandle;             # Holds filehandle to read from process

    # Build argument list from template
    my @args = $this->buildCommandLine( $template, %params );

    $this->_writeDebug("path = $path");
    $this->_writeDebug("args = @args");

    if ( $this->{REAL_SAFE_PIPE_OPEN} ) {
        $this->_writeDebug("Got to safe pipes section");
        # Real safe pipes, open from process directly - works
        # for most Unix/Linux Perl platforms and on Cygwin.  Based on
        # perlipc(1).
        my $pid = open ($processFileHandle, '-|');
        throw Error::Simple( "open of pipe failed: $!" ) unless defined $pid;

        $this->_writeDebug("processFileHandle = $processFileHandle");

        if ( $pid ) {
            # Parent - read data from process filehandle and remove newlines 
            $this->_writeDebug("pid = $pid");
            @data = map { chomp $_; $_ } <$processFileHandle>;
            $this->_writeDebug("data = @data");
            close $processFileHandle;
        } else {
            # Child - run the command, stdout to pipe
            exec $path, @args
              or throw Error::Simple( "exec of $path with args @args failed: $!" );
            die "cannot happen";
            exit 127;
        }

    } elsif ( $this->{EMULATED_SAFE_PIPE_OPEN} ) {
        $this->_writeDebug("Got to emulated pipes section");

        # FIXME: not working yet for ActivePerl on Windows
        # Safe pipe emulation mostly on Windows platforms
        my $pid;
        ($pid, $processFileHandle) = $this->_openSafePipeFromProcess();
        if ( $pid ) {
            # Parent - read data from process filehandle and remove newlines 
            $this->_writeDebug("pid = $pid");
            # Exec definitely does work, can cause error if wrong pathname 
            $this->_writeDebug("fileno of processFileHandle= " . fileno($processFileHandle) );
            # FIXME: Doesn't read (or perhaps write in child) any data here... File handle
            # issue of some sort...
            @data = map { chomp $_; $_ } <$processFileHandle>;
            $this->_writeDebug("data = @data ");
            close $processFileHandle;
        } else {
            # Child - run the command, stdout to pipe
            exec $path, @args
                or throw Error::Simple( "exec of $path with args @args failed: $!" );
            die "should never happen";
            exit 127;
        }

    } else {
        # FIXME: not working yet for ActivePerl on Windows
        # No safe pipes available, use the shell as last resort (with
        # earlier filtering in unless administrator forced to use filtering out)
        my $cmdQuote = $this->{CMDQUOTE};

        my $cmd = "$path $cmdQuote";
        $cmd .= join( "$cmdQuote $cmdQuote", @args ) .  $cmdQuote;
        # DEBUG
        $cmd .= ' >c:\temp\searchout.log';
        @data = split( /\r?\n/, `$cmd` );
    }

    if( $this->{TRACE} ) {
        my $q = $this->{CMDQUOTE};
        print STDERR "$path $q",join( "$q $q", @args ), "$q -> ",
          join( "\n", @data ),"\n";
   }
    return @data;
}


# _openSafePipeFromProcess ( $parentFileHandle ) -> $pid
#
# Simulate open(FOO, "-|") for read from piped process on platforms such as
# Windows - see perlfork(1).  
#
# NOTE: This routine does a fork and returns in both the parent and child
# processes - check for $pid == 0 to see if you are in the child process.
sub _openSafePipeFromProcess {
    my $this = shift;

    # Create pipe 
    my $parentFileHandle;
    my $childFileHandle;
    pipe ($parentFileHandle, $childFileHandle) or
                     throw Error::Simple( "could not create pipe: $!" );
    $this->_writeDebug("filehandles = $parentFileHandle $childFileHandle ");

    my $pid = fork();
    if (not defined $pid) {
        throw Error::Simple( "fork() failed: $!" );
    }

    if ($pid) {
        $this->_writeDebug("Parent, pid = $pid");
        # Parent
        close $childFileHandle or die;
        $this->_writeDebug("fileno of parent handle is " . fileno($parentFileHandle));
        return ($pid, $parentFileHandle);
    } else {
        # Child
        $this->_writeDebug("Child, pid = $pid");
        close $parentFileHandle or die;
        # FIXME: standard output to pipe disappears - hard to work out
        # what's happening
        $this->_writeDebug("fileno of stdout handle is " . fileno(STDOUT));
        $this->_writeDebug("fileno of stderr handle is " . fileno(STDERR));
        $this->_writeDebug("fileno of child handle is " . fileno($childFileHandle));
        # Tried this from readFromProcess routine - doesn't work either ...
        # use POSIX;
        # POSIX::close 2;
        # POSIX::dup 1;

        close STDOUT;
        open(STDOUT, ">&=" . fileno($childFileHandle)) or die;
        $this->_writeDebug("fileno of stdout handle is now " . fileno(STDOUT));
        close STDERR;
        open(STDERR, ">&=" . fileno($childFileHandle)) or die;
        $this->_writeDebug("fileno of stderr handle is now " . fileno(STDERR));
        return ($pid, $parentFileHandle);
    }
}


=pod

---++ readFromProcess( $template, @params ) -> ($output, $status)

Like readFromProcessArray, but returns the process output as a single
string, together with the exit status.  Furthermore, the program to
execute is taken from the first argument in $template, and standard
error is redirected to standard input.

=cut

# FIXME: need to upgrade as per the Array variant
sub readFromProcess {
    my ($this, $template, %params) = @_;
    assert(ref($this) eq "TWiki::Sandbox") if DEBUG;

    my @args = $this->buildCommandLine( $template, %params );
    my $data;
    my $exit;
    if ( $this->{REAL_SAFE_PIPE_OPEN} ) {
        # The code follows the safe pipe construct found in perlipc(1)
        # since Perl 5.005 
        my $pipe;
        my $pid = open $pipe, '-|';
        if ($pid) {                        # parent
            local $/;               # read everything in one operation
            $data = <$pipe>;
            close $pipe;
            $exit = ( $? >> 8 );
        } else {
            # Redirect standard error to standard output.
            # FIXME: do a require since only needed with safe pipe platform
            use POSIX qw(close dup);
            POSIX::close 2;
            POSIX::dup 1;
            exec { $args[0] } @args;
            # Usually not reached.
            exit 127;
        }
    } else {
        # FIXME: Should be able to do similarly safe pipe open in 5.6 or
        # earlier, see perlipc(1)
        my $cmdQuote = $this->{CMDQUOTE}; 

        my $cmd = shift( @args ) . " $TWiki::cmdQuote";
        $cmd .= join( "$cmdQuote $cmdQuote", @args ) .  $cmdQuote;
        $cmd .= " 2>&1" if( $TWiki::OS eq "UNIX" );
        $data = `$cmd`;
        $exit = ( $? >> 8 );
    }
    if( $this->{TRACE} ) {
        print STDERR join( " ", @args ), " -($exit)-> $data\n";
    }
    return ( $data, $exit );
}

1;
