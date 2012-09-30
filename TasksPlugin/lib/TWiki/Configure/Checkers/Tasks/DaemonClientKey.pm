# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.

use strict;
use warnings;

=pod

---+ package TWiki::Configure::Checkers::Tasks::DaemonClientKey
Configure GUI checker for the {Tasks}{DaemonClientKey} configuration item.

Verifies that a private key file is specified and readable when https client verification is selected.
Verifies no world write.

Any problems detected are reported.

=cut

package TWiki::Configure::Checkers::Tasks::DaemonClientKey;
use base 'TWiki::Configure::Checkers::Certificate::KeyChecker';


=pod

---++ ObjectMethod check( $valueObject ) -> $errorString
Validates the {Tasks}{DaemonClientKey} item for the configure GUI
   * =$valueObject= - configure value object

Returns empty string if OK, error string with any errors

=cut

sub check {
    my $this = shift;


    return '' unless( $TWiki::cfg{Tasks}{StatusServerVerifyClient} );

    return $this->SUPER::check( @_, '{Tasks}{DaemonClientKeyPassword}' );
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
