#
# TWiki WikiClone (see wiki.pm for $wikiversion and other info)
#
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
# Notes:
# - Latest version at http://twiki.org/
# - Installation instructions in $dataDir/TWiki/TWikiDocumentation.txt
# - Customize variables in TWiki.cfg when installing TWiki.
#
#  14-02-2001 - Nicholas Lee
#             - Created to partition network related functions from 
#               core TWiki.pm utilities
#             - Moved sendEmail from TWiki.pm 
#             
package TWiki::Net;

use strict;

##use TWiki::Prefs;
use Net::SMTP;

sub sendEmail
{
    # Format: "From: ...\nTo: ...\nSubject: ...\n\nMailBody..."

    my( $from, $toref, $data) = @_;

    my @to;
    # $to is not a reference then it must be a single email address
    @to = ($toref) unless ref ($toref); 
    if ( ref($toref) =~ /ARRAY/ ) {
	@to = @{$toref};
    }
    return undef unless (scalar @to);
    my $mailhost = &TWiki::Prefs::getPreferencesValue("MAILHOST") || "mail";
    
    # ToDo For later:
    # Make it the fail back option dependant on if MAILHOST is non-"" 
    # and Net::Smtp exists.  Rather than creating a new flag in Cfg.

    my $smtp = Net::SMTP->new( $mailhost );
    $smtp->mail($from);
    $smtp->to(@to, { SkipBad => 1 });
    $smtp->data($data);
    $smtp->dataend();
    
    # I think this has to occur before the $smtp->quit, 
    # otherwise we'll miss the status message for the sending of the mail.
    my $status = ($smtp->ok() ? "OK": undef);

    $smtp->quit();
    return $status;    

}

# =========================

1;



