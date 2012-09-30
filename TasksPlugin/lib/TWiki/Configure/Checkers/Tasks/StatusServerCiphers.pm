# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.

use strict;
use warnings;

=pod

---+ package TWiki::Configure::Checkers::Tasks::StatusServerCiphers
Configure GUI checker for the {Tasks}{StatusServerCiphers} configuration item.

Verifies that a https protocol is selected and that a cipher list exists.

It would be ideal to ask OpenSSL to verify the list elements, but there doesn't seem to be an
easy and inexpensive way to do this, especially with the macros (like HIGH).

Any problems detected are reported.

=cut

package TWiki::Configure::Checkers::Tasks::StatusServerCiphers;
use base 'TWiki::Configure::Checker';


=pod

---++ ObjectMethod check( $valueObject ) -> $errorString
Validates the {Tasks}{StatusServerCiphers} item for the configure GUI
   * =$valueObject= - configure value object

Returns empty string if OK, error string with any errors

=cut

sub check {
    my $this = shift;

    my $e = '';

    return $e unless( $TWiki::cfg{Tasks}{StatusServerProtocol} eq 'https' );

    unless( length( $TWiki::cfg{Tasks}{StatusServerCiphers} ) >= 3 ) {
        return $this->ERROR( "A cipher list must be specified when https is enabled" );
    }

    return $e;
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
