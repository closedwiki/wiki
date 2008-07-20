# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This module is based/inspired on Catalyst framework. Refer to
#
# http://search.cpan.org/~mramberg/Catalyst-Runtime-5.7010/lib/Catalyst.pm
# 
# for credits and liscence details.
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

=begin twiki

---+!! package TWiki::Engine::CLI

Class that implements CGI scripts functionality when called from
command line or cron job

Refer to TWiki::Engine documentation for explanation about methos below.

=cut

package TWiki::Engine::CLI;

use strict;
use base 'TWiki::Engine::CGI';
use TWiki::Request;
use TWiki::Request::Upload;
use TWiki::Response;

sub prepareRequest {
    my $this = shift;
    $this->{argv} = [ @ARGV ]; # Copy, so original @ARGV doesn't get modified
    while( scalar( @{ $this->{argv} } ) ) {
        my $arg = shift( @{ $this->{argv} } );
        if ( $arg =~ /^-?([A-Za-z0-9_]+)$/o ) {
            my $name = $1;
            my $arg = TWiki::Sandbox::untaintUnchecked( shift( @{ $this->{argv} } ));
            if( $name eq 'user' ) {
                $this->{user} = $arg;
            } else {
                push @{$this->{params}->{$name}}, $arg;
            }
        } else {
            $this->{path_info} = TWiki::Sandbox::untaintUnchecked( $arg );
        }
    }
    delete $this->{argv};
    $this->SUPER::prepareRequest(@_);
}

sub prepareConnection {
    my ( $this, $req ) = @_;
    if ( defined $this->{user} ) {
        $req->remoteUser( $this->{user} );
        delete $this->{user};
    }
    else {
        $req->remoteUser( $TWiki::cfg{SuperAdminGroup} );
    }
    $req->remoteAddress('127.0.0.1');
}

sub preparePath {
    my ( $this, $req ) = @_;
    $this->SUPER::preparePath($req);
    my ( $script ) = $0 =~ m{([^/\\:]+)$};
    if ( exists $this->{path_info} ) {
        $req->pathInfo( "/$script/" . $this->{path_info} );
        delete $this->{path_info};
    }
    else {
#        $req->pathInfo('');
        $req->action($script);
    }
}

sub prepareParameters {
    my ( $this, $req ) = @_;
    $this->SUPER::prepareParameters( $req );
    while ( my ( $name, $values ) = each %{ $this->{params} } ) {
        $req->param( -name => $name, -value =>  $values );
    }
    delete $this->{params};
}

# No headers when running from command line
sub finalizeHeaders { }

1;
