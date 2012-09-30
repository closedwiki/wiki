# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.

use strict;
use warnings;

=pod

---+ package TWiki::Configure::Checkers::Tasks::StatusServerCrlFile
Configure GUI checker for the {Tasks}{StatusServerCrlFile configuration item.

Verifies that a https protocol with client verification is selected and that a CRL source exists.
Verifies that thre is no world write access to the file.

Any problems detected are reported.

=cut

package TWiki::Configure::Checkers::Tasks::StatusServerCrlFile;
use base 'TWiki::Configure::Checker';


=pod

---++ ObjectMethod check( $valueObject ) -> $errorString
Validates the {Tasks}{StatusServerCrlFile} item for the configure GUI
   * =$valueObject= - configure value object

Returns empty string if OK, error string with any errors

=cut

sub check {
    my $this = shift;

    my $e = '';

    my $crlfile = $TWiki::cfg{Tasks}{StatusServerCrlFile} || '';
    if( $crlfile ) {
        $TWiki::cfg{Tasks}{StatusServerCheckCRL} or
          return $this->WARN( "CRL file is not used unless CRL checking is active" );

        -r $crlfile
          or return $this->ERROR( "File is not  webserver-readable" );

        ((stat $crlfile)[2] || 0) & 002 and return $this->ERROR( "File permissions allow world write" );
    } elsif( $TWiki::cfg{Tasks}{StatusServerCheckCRL} ) {
        my $capath = $TWiki::cfg{Tasks}{StatusServerCAPath} || '';

        $capath && -d $capath && -r $capath
          or return $this->ERROR( "CRL use requires either a  webserver-readable CRL file or CA path" );
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
