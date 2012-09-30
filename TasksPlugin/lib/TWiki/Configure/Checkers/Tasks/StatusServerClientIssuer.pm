# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.

use strict;
use warnings;

=pod

---+ package TWiki::Configure::Checkers::Tasks::StatusServerClientIssuer
Configure GUI checker for the {Tasks}{StatusServerClientIssuer configuration item.

Verifies that the StatusServerClientIssuer validator is a compilable regexp.

Any problems detected are reported.

=cut

package TWiki::Configure::Checkers::Tasks::StatusServerClientIssuer;

# Standard checker's checkRE won't work with '/'.  Fixed in post 5.1.0 TWiki trunk.  Use private checker for now.
#use base 'TWiki::Configure::Checker';
use base 'TWiki::Configure::Checkers::Tasks::RegExpChecker';

=pod

---++ ObjectMethod check( $valueObject ) -> $errorString
Validates the {Tasks}{StatusServerClientIssuer} item for the configure GUI
   * =$valueObject= - configure value object

Returns empty string if OK, error string with any errors

=cut

sub check {
    my $this = shift;

    my $e = '';

    return $e unless( $TWiki::cfg{Tasks}{StatusServerClientIssuer} );


    return $this->checkRE('{Tasks}{StatusServerClientIssuer}');
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
