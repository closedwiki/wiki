# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.

use strict;
use warnings;

=pod

---+ package TWiki::Configure::Checkers::Tasks::FileMonitor
Configure GUI checker for the {Tasks}{FileMonitor} configuration item.

Validates that the selected TWiki::Tasks::Watchfile driver is likely to work.

Rather than requiring the driver, which would load most of the daemon, we simply scan the driver source
for the @USES list of non-TWiki modules.  These are 'require'd to see that they exist and load successfully.

Any problems detected are reported.

This is not a complete test, but it should catch the common case of a missing platform-specific file system monitoring module.

=cut

package TWiki::Configure::Checkers::Tasks::FileMonitor;
use base 'TWiki::Configure::Checker';


=pod

---++ ObjectMethod check( $valueObject ) -> $errorString
Validates the {Tasks}{FileMonitor} item for the configure GUI
   * =$valueObject= - configure value object

Returns empty string if OK, error string with any errors

=cut

sub check {
    my $this = shift;

    my $e = '';

    my $driver =  $TWiki::cfg{Tasks}{FileMonitor} || '';

    my $dfile = $driver;
    $dfile =~ s!::!/!g;

    # First existing file in @INC

    $dfile = (map { -e "$_/$dfile.pm"? "$_/$dfile.pm" : () } @INC)[0];
    if( !$dfile ) {
	$e .= "<li>Unable to locate $driver in \@INC\n";
    } elsif( !open( my $fh, '<', $dfile ) ) {
	$e .= "<li>Unable to open $dfile: $!\n";
    } else {
	while( <$fh> ) {
	    last if( /^__END__/ );
            next unless( s/^\s*our\s+\@USES\s+=\s+/\@modules =/ );
            my @modules;
            /^(.*$)/;
            eval "$1";
            if( $@ ) {
                die "File monitor driver $dfile error in \@USES: $@\n";
            }
	    foreach my $module (@modules) {
                eval "require $module;";

                if( $@ ) {
                    my $error = $@;
                    # Simplify error by removing @INC listing (available from configure) and removing (eval ... locator.
                    # Convert \n to html <br> and use a monospace font for the error.
                    $error =~ s/\@INC\s+\(\@INC\s+contains:\s.*?\)/\@INC/ms;
                    $error =~ s/ at \(eval .*$//ms;
                    $error =~ s!\n!<br />!gms;
                    $error = "<li><span style=\"font-family:monospace;\">$error</span>";
                    $e .= $error;
                }
           }
            last;
	}
	close $fh;
    }
    return $e unless( $e );

    $e = $this->ERROR( <<"ERROR" . $e . '</ul>' );
Unable to load one or more dependencies of of File Monitoring driver $driver.  <p>Generally this is due to uninstalled or corrupt prerequisite software.
<p>Please correct this error by installing the pre-requisite software indicated, or by
selecting another driver. <br /> The <i><u>TWiki::Tasks::Watchfile::Polled</u></i> driver should
work in any environment.<p>The problem(s) encountered are listed below <ul>
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
