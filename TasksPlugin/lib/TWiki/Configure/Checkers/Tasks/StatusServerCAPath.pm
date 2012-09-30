# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.

use strict;
use warnings;

=pod

---+ package TWiki::Configure::Checkers::Tasks::StatusServerCAPath
Configure GUI checker for the {Tasks}{StatusServerCAPath} configuration item.

Verifies that a CAfile or CApath is specified and readable when https client verification is selected.
CAPath can also be used for CRL checking, but that also requires https client verification.
Verifies no world write.

Any problems detected are reported.

=cut

package TWiki::Configure::Checkers::Tasks::StatusServerCAPath;
use base 'TWiki::Configure::Checker';


=pod

---++ ObjectMethod check( $valueObject ) -> $errorString
Validates the {Tasks}{StatusServerCAPath} item for the configure GUI
   * =$valueObject= - configure value object

Returns empty string if OK, error string with any errors

=cut

sub check {
    my $this = shift;

    my $e = '';

    my $capath =  $TWiki::cfg{Tasks}{StatusServerCAPath} || '';
    if( $capath ) {
        $TWiki::cfg{Tasks}{StatusServerVerifyClient} or
          return $this->WARN( "CA path is not used unless https client verification is active" );

        -d $capath && -r $capath
          or return $this->ERROR( "CA path must be a webserver-readable directory" );

        ((stat $capath)[2] || 0) & 002 and return $this->ERROR( "Directory permissions allow world write" );
    } elsif( $TWiki::cfg{Tasks}{StatusServerVerifyClient} ) {
        my $cafile =  $TWiki::cfg{Tasks}{StatusServerCAFile} || '';

        $cafile && -r $cafile or
          return $this->ERROR( "Client verification requires either a webserver-readable CA path or a CA file" );
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
