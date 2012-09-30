# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Framework:
#     Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
#     Copyright (C) 2006 Meredith Lesly, msnomer@spamcop.net
# This module:
#     Copyright (C) 2012 Timothe Litt, litt@acm.org
#
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::IpPlugin;

use warnings;
use strict;

use Net::IP;

use vars qw( $VERSION $RELEASE $NO_PREFS_IN_TOPIC $SHORTDESCRIPTION );

$VERSION = '$Rev: 10608$';
$RELEASE = 'IpPlugin 1.0';

# Release history:
# 24-Sep-2012 1.0 Initial release


$SHORTDESCRIPTION = 'IP Address functions';
$NO_PREFS_IN_TOPIC = 1;

###############################################################################
sub initPlugin {
  my ($baseTopic, $baseWeb) = @_;

  # check for Plugins.pm versions
  if( $TWiki::Plugins::VERSION < 1.026 ) {
    TWiki::Func::writeWarning( "Version mismatch between IpPlugin and Plugins.pm" );
    return 0;
  }

  # register the tag handlers
  TWiki::Func::registerTagHandler( 'IP', \&_IP);

  # Plugin correctly initialized
  return 1;
}

# The function used to handle the %IP{...}% tag
#
# %IP returns various properties of IP addresses
# See the plugin topic for detailed doumentation.

my %attrs = ( # keyword    Function name      Result type
	     class =>    { f => 'iptype',     r => 'numeric' },
	     display =>  { f => 'short',      r => 'text' },
	     expand =>   { f => 'ip',         r => 'text' },
	     hostname => { f => 'ip',         r => 'hname' },
	     'is_in' =>  { f => 'overlaps',   r => 'over' },
	     'not_in' => { f => 'overlaps',   r => '!over' },
	     reverse =>  { f => 'reverse_ip', r => 'text' },
	     type =>     { f => 'version',    r => 'text' },
	    );

my %numerics = (
		TRUE => 1,
		FALSE =>0,
		PUBLIC => 0,
		PRIVATE => 1,
		RESERVED => 2,
		'GLOBAL-UNICAST' => 3,
		'UNIQUE-LOCAL-UNICAST' => 4,
		'LINK-LOCAL-UNICAST' => 5,
		MULTICAST => 6,
		IPV4COMP => 7,
		IPV4MAP => 8,
		LOOPBACK => 9,
	       );

sub _IP {
    my($session, $params, $theTopic, $theWeb) = @_;
    # $session  - a reference to the TWiki session object.
    # $params=  - a reference to a TWiki::Attrs object containing parameters.
    #             This is a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the tag

    my $address = $params->{address} || $params->{_DEFAULT} || $ENV{REMOTE_ADDR};
    my $function = $params->{get} || 'type';

    my $errors = !$params->{noerror};
    my $numeric = $params->{numeric};

    # Handle hostaddress specially, as it doesn't take an IP address argument

    if( $function eq 'hostaddress' ) {
	require Socket;
	Socket->import( qw/:addrinfo SOCK_RAW AF_INET/ );

	my $hostname = $params->{hostname} || $address;

	my ( $err, @res ) = getaddrinfo( $hostname, "", { socktype => SOCK_RAW() } );
	return $errors? "%RED%$hostname: $err%ENDCOLOR%" : $hostname if $err;

	my @hosts;

	while( my $ai = shift @res ) {
	    my ( $err, $ipaddr ) = getnameinfo( $ai->{addr}, NI_NUMERICHOST(), NIx_NOSERV() );
	    return $errors? "%RED%" . $ai->{addr} . ": $err%ENDCOLOR%" : $hostname if $err;
	    if( $ai->{family} == AF_INET() ) {
		unshift @hosts, $ipaddr;
	    } else {
		push @hosts, $ipaddr;
	    }
	}
	return join( ' ', @hosts );
    }

    # Get and validate arguments

    my $attr = $attrs{$function};
    return $errors? "%RED%Invalid attribute specified: $function%ENDCOLOR%" : $address
           unless( defined $attr );

    my $ip = Net::IP->new($address);
    return $errors? "%RED%Bad address $address%ENDCOLOR%" : $address unless( defined $ip );

    my @args;
    if( $params->{range} ) {
	foreach my $r (split /,\s*/, $params->{range}) {
	    my $rip = Net::IP->new( $r );
	    return $errors? "%RED%Bad range " . $r . "%ENDCOLOR%" : $address unless( defined $rip );
	    push @args, $rip;
	}
    }

    # Dispatch on desired attribute

    my $fn = $attr->{f};
    my $result;
    if( @args && $fn eq 'overlaps' ) {
	$result = $IP_NO_OVERLAP;
	foreach my $r (@args ) {
	    next if( $ip->version != $r->version );
	    $result = $ip->$fn( $r );
	    return $errors? "%RED%$address: " . $ip->error . "%ENDCOLOR%" : $address unless( defined $result );
	    last unless( $result == $IP_NO_OVERLAP );
	}
    } else {
	$result =  $ip->$fn(@args);
	return $errors? "%RED%$address: " . $ip->error . "%ENDCOLOR%" : $address unless( defined $result );
    }

    my $rtype = $attr->{r};

    # Return result

    return $result if( $rtype eq 'text' );

    return ($numeric && exists $numerics{$result})? $numerics{$result} : $result     if( $rtype eq 'numeric' );

    # Map overlap codes to In and notIn

    if( $rtype =~ /^(!)?over$/ ) {
	if($result == $IP_NO_OVERLAP ) {
	    $result = $1? 'TRUE' : 'FALSE';
	} else {
	    $result = $1? 'FALSE' : 'TRUE';
	}
	return $numeric? $numerics{$result} : $result;
    }

    # Handle hostname reverse mapping

    if( $rtype eq 'hname' ) {
	require Socket;
	Socket->import( qw/:addrinfo SOCK_RAW AF_INET/ );

	$address = $result;
	my( $error, @addrs ) = getaddrinfo( $address, 0, { flags => AI_NUMERICHOST() } );
	return $errors? "%RED%$address: $error%ENDCOLOR%" : $address if( $error );

	my $name;
	eval {
	    # This code may fail under mod_perl.
	    # See https://rt.cpan.org/Public/Bug/Display.html?id=79557 for a work-around
	    ($error, $name, undef) = getnameinfo( $addrs[0]->{addr}, NI_NAMEREQD(), NIx_NOSERV() );
	}; return 'Bug in Socket; see [[https://rt.cpan.org/Public/Bug/Display.html?id=79557][This bug report]] for a work-around'
	                                             if( $@ );
	return $errors? "%RED%$address: $error%ENDCOLOR%" : $address if( $error );

	return $name;
    }

    # This is a plugin coding error

    die 'Unknown return value class $rtype';
}
