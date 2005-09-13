# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Copyright (C) 2004 Florian Weimer, Crawford Currie http://c-dot.co.uk
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
#
# As per the GPL, removal of this notice is prohibited.

package TWiki::Plugins::NatSkinPlugin::Sandbox;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(readFromProcess normalizeFileName);

use vars qw($cmdQuote);
use POSIX;

$cmdQuote = "'";

###############################################################################
sub writeDebug {
  #&TWiki::Func::writeDebug("- NatSkinPlugin::Sandbox - " . $_[0]);
}

###############################################################################

=pod
---++untaintUnchecked ( $string )
Return value: $untainted

Untaints $string without any checks (dangerous).  If $string is
undefined, return undef.

The intent is to use this routine to be able to find all untainting
places using grep.

=cut

sub untaintUnchecked ($) {
    my $string = shift;
    return undef unless defined $string;
    if ($string =~ /^(.*)$/) {
	return $1;
    } 
    return $string;		# Can't happen.
}

=pod
---++normalizeFileName ( $string [, $dotdot] )
Return value: $filename

Errors out if $string contains whitespace characters.  If $dotdot is
present and true, allow ".." in path names.

The returned string is not tainted, but it may contain shell
metacharacters and even control characters.

=cut

sub normalizeFileName ($;$) {
    my ($string, $dotdot) = @_;
    my $absolute = $string =~ /^\//;
    my @result;
    for my $component (split /\//, $string) {
	next unless $component;
	next if $component eq '.';
	if ($component eq '..') {
	    if ($dotdot && @result > 0) {
		pop @result;
	    } else {
	      &TWiki::Func::writeWarning(Carp::longmess("directory traversal attempt"));
	      die 'directory traversal attempt';
	    }
	} elsif ($component =~ /^(\S+)$/) {
            # We need to untaint the string explicitly.
            # FIXME: This might be a Perl bug.
            push @result, untaintUnchecked $1;
	} else {
	    &TWiki::Func::writeWarning(Carp::longmess("whitespace in file name component"));
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
	&TWiki::Func::writeWarning(Carp::longmess("empty file name"));
	die 'empty file name';
    }
}


=pod
---++buildCommandLine ( $template, %params )
Return value: @arguments

$template is split at whitespace, and '%VAR%' strings contained in it
are replaced with $params{VAR}.  %params may consist of scalars and
array references as values.  Array references are dereferenced and the
array elements are inserted into the command line at the indicated
point.

'%VAR%' can optionally take the form '%VAR|FLAG%', where FLAG is a
single character flag.  Permitted flags are U (untaint without further
checks -- dangerous), F (normalize as file name), N (generalized
number), S (simple, short string), and E (simple regexp string),

=cut

sub buildCommandLine ($%) {
    my ($template, %params) = @_;
    my @arguments;

    for my $tmplarg (split /\s+/, $template) {
	next if $tmplarg eq '';	# ignore leading/trailing whitespace

	# Split single argument into its parts.  It may contain
	# multiple substitutions.

	my @tmplarg = $tmplarg =~ /([^%]+|%[^%]+%)/g;
	my @targs;
	for my $t (@tmplarg) {
	    if ($t =~ /%(.*?)(|\|[A-Z])%/) {
		my ($p, $flag) = ($1, $2);
		if (! exists $params{$p}) {
		    &TWiki::Func::writeWarning(Carp::longmess("unknown parameter name $p"));
		    die "unknown parameter name $p";
		}
		my $type = ref $params{$p};
		my @params;
		if ($type eq '') {
		    @params = ($params{$p});
		} elsif ($type eq 'ARRAY') {
		    @params =  @{$params{$p}};
		} else {
		    &TWiki::Func::writeWarning(Carp::longmess("$type reference passed in $p"));
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
				&TWiki::Func::writeWarning(Carp::longmess("invalid number argument"));
				die "invalid number argument";
			    }
			} elsif ($flag =~ /E/) {
			    # simple regexp string.
			    if ($param =~ /^([0-9A-Za-z.+_\-\*\.\?\[\]\^\|]{0,30})$/) {
				push @targs, $1;
			    } else {
				&TWiki::Func::writeWarning(Carp::longmess("invalid regexp argument"));
				die "invalid regexp argument";
			    }
			} elsif ($flag =~ /S/) {
			    # Harmless string.
			    if ($param =~ /^([0-9A-Za-z.+_\-]{0,30})$/) {
				push @targs, $1;
			    } else {
				&TWiki::Func::writeWarning(Carp::longmess("invalid string argument"));
				die "invalid string argument";
			    }
			} elsif ($flag =~ /D/) {
			    # RCS date.
			    if ($param =~ m/^(\d\d\d\d\/\d\d\/\d\d \d\d:\d\d:\d\d)$/) {
				push @targs, "$cmdQuote$1$cmdQuote";
			    } else {
				&TWiki::Func::writeWarning(Carp::longmess("invalid date argument"));
				die "invalid date argument";
			    }
			} else {
			    &TWiki::Func::writeWarning(Carp::longmess("illegal flag in $t"));
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

---++readFromProcess ($cmd, @params )
Return value: ($output, $status)

Invokes the program $cmd and @params, and returns the output of the program as
an array of lines. The program to execute is taken from the first argument in
$cmd, and standard error is redirected to standard input.

$cmd is interpreted by buildCommandLine.

The caller has to ensure that the invoked program does not react in a harmful
way to the passed arguments.  readFromProcess merely ensures that the shell
does not interpret any of the passed arguments.

Returns the process output as a single string, together with the exit status.  

=cut

sub readFromProcess ($@) {
    my ($cmd, %params) = @_;

    my @args = buildCommandLine $cmd, %params;
    writeDebug("readFromProcess(): @args");

    # The code follows the safe pipe construct found in perlipc(1).
    my $pipe;
    my $pid = open $pipe, '-|';
    if ($pid) {			# parent
	local $/;		# read everything in one operation
	my $data = <$pipe>;
	close $pipe;
	my $exit = ($? >> 8);
	return ($data, $exit);
    } else {
	# Redirect standard error to standard output.
	POSIX::close 2;
	POSIX::dup 1;
	exec {$args[0]} @args
	  or &TWiki::Func::writeWarning("exec of $args[0] with args @args failed: $!");
	# Usually not reached.
	die 'readFromProcess(): cannot happen';
	exit 127;
    }
}


