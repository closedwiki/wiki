# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.

use strict;
use warnings;

=pod

---+ package TWiki::Configure::Checkers::Tasks::StatusServerProtocol
Configure GUI checker for the {Tasks}{StatusServerCertificate} configuration item.

Verifies that required CPAN modules are present when https is selected.

Any problems detected are reported.

=cut

package TWiki::Configure::Checkers::Tasks::StatusServerProtocol;
use base 'TWiki::Configure::Checker';


=pod

---++ ObjectMethod check( $valueObject ) -> $errorString
Validates the {Tasks}{StatusServerProtocol} item for the configure GUI
   * =$valueObject= - configure value object

Returns empty string if OK, error string with any errors

=cut

sub check {
    my $this = shift;

    my $e = '';

    return $e unless( $TWiki::cfg{Tasks}{StatusServerProtocol} eq 'https' );

    foreach my $module (qw/IO::Socket::SSL LWP::Protocol::https/) {
        eval "require $module";
        if( $@ ) {
            my $error = "$module: $@ ";
            # Simplify error by removing @INC listing (available from configure) and removing (eval ... locator.
            # Convert \n to html <br> and use a monospace font for the error.
            $error =~ s/\@INC\s+\(\@INC\s+contains:\s.*?\)/\@INC/ms;
            $error =~ s/ at \(eval .*$//ms;
            $error =~ s!\n!<br />!gms;
            $error = "<li><span style=\"font-family:monospace;\">$error</span>";
            $e .= $error;
        }
    }
    return $e unless( $e );

    $e = $this->ERROR( <<"ERROR" . $e . '</ul>' );
Unable to load one or more CPAN modules required for https.
<p>Please correct this error by installing the pre-requisite software indicated, or by
selecting http.
<p>The problem(s) encountered are listed below <ul>
ERROR
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
