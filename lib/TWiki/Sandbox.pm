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

=pod

---++ new( $OS )
Construct a new sandbox suitable for $OS

=cut

sub new {
    my ( $class, $OS ) = @_;
    my $this = bless( {}, $class );

    $this->{USE_SAFE_PIPES} = 0;
    if ( $OS ne "WINDOWS" ) {
        eval 'require 5.008';
        return if $@;
        eval 'use POSIX';
        return if $@;
        $this->{USE_SAFE_PIPES} = 1;
    }
    # Set to 1 to trace all command executrions to STDERR
    $this->{TRACE} = 0;

    return $this;
};

=pod

---++ untaintUnchecked ( $string ) ->: $untainted

Untaints $string without any checks (dangerous).  If $string is
undefined, return undef.

The intent is to use this routine to be able to find all untainting
places using grep.

=cut

sub untaintUnchecked ($) {
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

sub normalizeFileName ($;$) {
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
                die 'directory traversal attempt';
            }
        } elsif ($component =~ /^(\S+)$/) {
            # We need to untaint the string explicitly.
            # FIXME: This might be a Perl bug.
            push @result, untaintUnchecked $1;
        } else {
            die 'whitespace in file name component';
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
        die 'empty file name';
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
                    die "unknown parameter name $p";
                }
                my $type = ref $params{$p};
                my @params;
                if ($type eq '') {
                    @params = ($params{$p});
                } elsif ($type eq 'ARRAY') {
                    @params =  @{$params{$p}};
                } else {
                    die "$type reference passed in $p";
                }

                for my $param (@params) {
                    if ($flag) {
                        if ($flag =~ /U/) {
                            push @targs, untaintUnchecked $param;
                        } elsif ($flag =~ /F/) {
                            push @targs, normalizeFileName $param;
                        } elsif ($flag =~ /N/) {
                            # Generalized number.
                            if ($param =~ /^([0-9A-Fa-f.x+\-]{0,30})$/) {
                                push @targs, $1;
                            } else {
                                die "invalid number argument '$param'";
                            }
                        } elsif ($flag =~ /S/) {
                            # Harmless string.
                            if ($param =~ /^([0-9A-Za-z.+_\-]{0,30})$/) {
                                push @targs, $1;
                            } else {
                                die "invalid string argument";
                            }
                        } elsif ($flag =~ /D/) {
                            # RCS date.
                            if ($param =~ m!^(\d\d\d\d/\d\d/\d\d \d\d:\d\d:\d\d)$!) {
                                push @targs, $1;
                            } else {
                                die "invalid date argument";
                            }
                        } else {
                            die "illegal flag in $t";
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

sub readFromProcessArray {
    my ($this, $path, $template, %params) = @_;

    my @args = $this->buildCommandLine( $template, %params );
    my @data;
    if ( $this->{USE_SAFE_PIPES} ) {
        my $process;
        open $process, '-|', $path, @args
          or die "open failed: $!";
        # remove newline characters.
        @data = map { chomp $_; $_ } <$process>;
        close $process;
    } else {
        my $cmd = "$path $TWiki::cmdQuote";
        $cmd .= join( "$TWiki::cmdQuote $TWiki::cmdQuote", @args ) .
          $TWiki::cmdQuote;
        @data = split( /\r?\n/, `$cmd` );
    }
    if( $this->{TRACE} ) {
        print STDERR "$path ",join( "  ", @args ), " -> ",
          join( "\n", @data ),"\n";
    }
    return @data;
}

=pod

---++ readFromProcess( $template, @params ) -> ($output, $status)

Like readFromProcessArray, but returns the process output as a single
string, together with the exit status.  Furthermore, the program to
execute is taken from the first argument in $template, and standard
error is redirected to standard input.

=cut

sub readFromProcess {
    my ($this, $template, %params) = @_;

    my @args = $this->buildCommandLine( $template, %params );
    my $data;
    my $exit;
    if ( $this->{USE_SAFE_PIPES} ) {
        # The code follows the safe pipe construct found in perlipc(1).
        my $pipe;
        my $pid = open $pipe, '-|';
        if ($pid) {                        # parent
            local $/;               # read everything in one operation
            $data = <$pipe>;
            close $pipe;
            $exit = ( $? >> 8 );
        } else {
            # Redirect standard error to standard output.
            use POSIX;
            POSIX::close 2;
            POSIX::dup 1;
            exec { $args[0] } @args;
            # Usually not reached.
            exit 127;
        }
    } else {
        my $cmd = shift( @args ) . " $TWiki::cmdQuote";
        $cmd .= join( "$TWiki::cmdQuote $TWiki::cmdQuote", @args ) .
          $TWiki::cmdQuote;
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
