# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2003 Peter Thoeny, peter@thoeny.com
#
# For licensing info read license.txt file in the TWiki root.
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
# - Installation instructions in $dataDir/Main/TWikiDocumentation.txt
# - Customize variables in TWiki.cfg when installing TWiki.
# - Optionally change TWiki.pm for custom extensions of rendering rules.
# - Upgrading TWiki is easy as long as you do not customize TWiki.pm.
# - Check web server error logs for errors, i.e. % tail /var/log/httpd/error_log
#

package TWiki::User;

#use File::Copy;
#use Time::Local;

use strict;

# 'Use locale' for internationalisation of Perl sorting in getTopicNames
# and other routines - main locale settings are done in TWiki::setupLocale
BEGIN {
    # Do a dynamic 'use locale' for this module
    if( $TWiki::useLocale ) {
        require locale;
	import locale ();
    }
}

# FIXME: Move elsewhere?
# template variable hash: (built from %TMPL:DEF{"key"}% ... %TMPL:END%)
use vars qw( %templateVars ); # init in TWiki.pm so okay for modPerl

# ===========================
# Normally writes no output, uncomment writeDebug line to get output of all RCS etc command to debug file
sub _traceExec
{
   #my( $cmd, $result ) = @_;
   #TWiki::writeDebug( "User exec: $cmd -> $result" );
}

# ===========================
sub writeDebug
{
   #TWiki::writeDebug( "User: $_[0]" );
}


#========================= 
sub htpasswdReadPasswd
{
    my ( $user ) = @_;
 
    if( ! $user ) {
        return "";
    }
 
    my $text = &TWiki::Store::readFile( $TWiki::htpasswdFilename );
    if( $text =~ /$user\:(\S+)/ ) {
        return $1;
    }
    return "";
}
 
#========================= 
sub htpasswdExistUser
{
    my ( $user ) = @_;
 
    if( ! $user ) {
        return "";
    }
 
    my $text = &TWiki::Store::readFile( $TWiki::htpasswdFilename );
    if( $text =~ /$user\:/go ) {
        return "1";
    }
    return "";
}
 
#========================= 
# TODO: needs to fail if it doesw not succed due to file permissions
# TODO: rename this to indicate that is is replacing an existing user..
sub htpasswdAddUser
{
    my ( $oldUserEntry, $newUserEntry ) = @_;
 
    # can't use `htpasswd $wikiName` because htpasswd doesn't understand stdin
    # simply add name to file, but this is a security issue
    my $text = &TWiki::Store::readFile( $TWiki::htpasswdFilename );
    $text =~ s/$oldUserEntry/$newUserEntry/;
    &TWiki::Store::saveFile( $TWiki::htpasswdFilename, $text );
}



# =========================

1;

# EOF
