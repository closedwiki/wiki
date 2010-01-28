#!/usr/bin/perl
# TWiki::Contrib::OpenIdRpContrib::DBLockPerAccess
# by Ian Kluft
# Copyright (C) 2010 TWiki Inc
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

package TWiki::Contrib::OpenIdRpContrib::DBLockPerAccess;
use strict;

use Tie::Hash;							# included with Perl
use DB_File::Lock;						# CPAN dependency

use base "Tie::Hash";

# class variables
our $debug = 0;

# print debugging statements
sub debug
{
	$debug and print STDERR "debug: ".join( " ", @_ )."\n";
}

# new classname, LIST - initialize
sub new
{
	my $class = shift;
	debug "new", @_;

	my $self = {};
	bless $self, $class;
	$self->initialize( @_ );
	return $self;
}

# initialize
sub initialize
{
	my $self = shift;

	# save the parameters - we'll use them for DB_File::Lock with each access
	$self->{filename} = shift;
	$self->{flags} = shift;
	$self->{mode} = shift;
	$self->{db_type} = shift;
	$self->{exception} = shift;

	# determine flags for read and write operations
	$self->{rwflags} = {};
	$self->{rwflags}{read} = O_RDONLY;
	if ( $self->{flags} & O_ACCMODE == O_RDONLY ) {
		$self->{rwflags}{write} = undef;
	} else {
		$self->{rwflags}{write} = $self->{flags};
	}
	
	debug "init: filename=".$self->{filename}, "flags=".$self->{flags},
		"mode=".$self->{mode}, "db_type=".$self->{db_type},
		"exception=".$self->{exception}, "\n";
}

# throw an exception
sub exception
{
	my $self = shift;
	my @params = @_;
	debug "exception", @params;

	# hopefully new() was provided with an exception callback...
	if ( ref $self->{exception} eq "CODE" ) {
		# throw the exception
		$self->{exception}->( @params );
	} else {
		# otherwise punt
		die join( "\n", @params )."\n";
	}
}

# lock/tie
sub lock_tie
{
	my $self = shift;
	my $rw = shift;
	debug "lock";

	# determine read/write flags for tie
	if ( !exists $self->{rwflags}{$rw}) {
			$self->exception(
				"attempt to open for '$rw' failed: mode does not exist" );
	}
	my $flags = $self->{rwflags}{$rw};
	if ( !defined $flags ) {
			$self->exception(
				"attempt to open for '$rw' failed: mode note defined "
					."(usually attempt to write after declaring read-only)" );
	}

	# tie the DB
	$self->{hash} = {};
	$self->{hash_obj} = tie %{$self->{hash}}, 'DB_File::Lock',
		$self->{filename}, $flags, $self->{mode}, $self->{db_type}, $rw
		or $self->exception( "failed to open DB file for $rw" );

	# if we're writing, set flag to prepare to mark it dirty afterward
	if ( $rw eq "write" ) {
		$self->{writing} = 1;
	}
}

# untie/unlock
sub unlock_untie
{
	my $self = shift;
	debug "unlock";

	# remove references with untie - see the "untie gotcha" in perltie(1)
	delete $self->{hash_obj}; # remove reference so DESTROY can happen
	untie %{$self->{hash}};
	delete $self->{hash};

	# if we were writing, mark it dirty
	if ( $self->{writing}) {
		$self->{dirty} = 1;
		delete $self->{writing};
	}
}

# TIEHASH classname, filename, flags, mode, db_type, rw, exception
sub TIEHASH
{
	my $class = shift;

	return $class->new( @_ );
}

# STORE this, key, value - store data
sub STORE
{
	my $self = shift;
	my $key = shift;
	my $value = shift;
	debug "store", $key, $value;

	# lock, write, unlock
	$self->lock_tie( "write" );
	$self->{hash_obj}->STORE( $key, $value );
	$self->unlock_untie;
}

# FETCH this, key - read data
sub FETCH
{
	my $self = shift;
	my $key = shift;
	debug "fetch", $key;

	# lock, read, unlock
	$self->lock_tie( "read" );
	my $value = $self->{hash_obj}->FETCH( $key );
	$self->unlock_untie;
	return $value;
}

# FIRSTKEY this
sub FIRSTKEY
{
	my $self = shift;
	debug "firstkey";

	# lock, check existence, unlock
	$self->lock_tie( "read" );
	my $key = $self->{hash_obj}->FIRSTKEY();
	$self->unlock_untie;
	return $key;
}

# NEXTKEY this, lastkey
sub NEXTKEY
{
	my $self = shift;
	my $lastkey = shift;
	debug "nextkey", $lastkey;

	# lock, check existence, unlock
	$self->lock_tie( "read" );

	# we need to reset the search cursor after untying lost the data
	my ( $key, $value );
	$key = $lastkey;
	my $status = $self->{hash_obj}->get( $key, $value ); # get the value
	( $status == 1 ) and return undef; # key doesn't exist
	$status = $self->{hash_obj}->find_dup ( $key, $value ); # set the cursor

	# now NEXTKEY from DB_File will work
	$key = $self->{hash_obj}->NEXTKEY( $lastkey );
	$self->unlock_untie;
	return $key;
}

# EXISTS this, key
sub EXISTS
{
	my $self = shift;
	my $key = shift;
	debug "exists", $key;

	# lock, check existence, unlock
	$self->lock_tie( "read" );
	my $value = $self->{hash_obj}->EXISTS( $key );
	$self->unlock_untie;
	return $value;
}

# DELETE this, key
sub DELETE
{
	my $self = shift;
	my $key = shift;
	debug "delete", $key;

	# lock, delete, unlock
	$self->lock_tie( "write" );
	$self->{hash_obj}->DELETE( $key );
	$self->unlock_untie;
}

# CLEAR this
sub CLEAR
{
	my $self = shift;
	debug "clear";

	# lock, clear, unlock
	$self->lock_tie( "write" );
	foreach my $key ( keys %{$self->{hash}}) {
		delete $self->{hash}{$key};
	}
	$self->unlock_untie;
}

# UNTIE this - untie/close
sub UNTIE
{
	my $self = shift;
	debug "untie";

	if ( exists $self->{hash}) {
		$self->unlock_untie;
		warn "DB was still locked at untie time\n";
	}
}

1;
__END__

=head1 NAME

TWiki::Contrib::OpenIdRpContrib::DBLockPerAccess - DB_File wrapper which locks the file only per-access

=head1 SYNOPSIS

 use TWiki::Contrib::OpenIdRpContrib::DBLockPerAccess;

 [$X =] tie %hash, "TWiki::Contrib::OpenIdRpContrib::DBLockPerAccess", $filename, $flags, $mode, $DB_HASH;
 [$X =] tie %hash,  'DB_File::Lock', $filename, $flags, $mode, $DB_BTREE, $locking;

 ...use the same way as DB_File for the rest of the interface...

=head1 DESCRIPTION


