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

#if( $TWiki::OS eq "WINDOWS" ) {
#    require MIME::Base64;
#    import MIME::Base64 qw( encode_base64 );
#    require Digest::SHA1;
#    import Digest::SHA1 qw( sha1 );
#}


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

#use $userTopicImpl = "HtPasswdUser";

# ===========================
# TODO: why / what is this (docco it)
sub initialize
{
    %templateVars = ();
    eval "use TWiki::User::HtPasswdUser";
}

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

sub _getUserHandler
{
   my( $web, $topic, $attachment ) = @_;

   $attachment = "" if( ! $attachment );

   my $handlerName = "TWiki::User::HtPasswdUser";

   my $handler = $handlerName->new( );
   return $handler;
}

#========================= 
# what if the login name is not the same as the twikiname??
# $user == TWikiName..
sub UserPasswordExists
{
    my ( $user ) = @_;

    my $handler = _getUserHandler();

    return $handler->UserPasswordExists($user);
}
 
#========================= 
# params: username, oldpassword (unencrypted), newpassword (unencrypted)
# TODO: needs to fail if it doesw not succed due to file permissions
sub UpdateUserPassword
{
    my ( $user, $oldUserPassword, $newUserPassword ) = @_;

    my $handler = _getUserHandler();
    return $handler->UpdateUserPassword($user, $oldUserPassword, $newUserPassword);
}

#========================= 
# params: username, newpassword (unencrypted)
sub AddUserPassword
{
    my ( $user, $newUserPassword ) = @_;

    my $handler = _getUserHandler();
    return $handler->AddUserPassword($user, $newUserPassword);
}

# =========================
sub CheckUserPasswd
{
    my ( $user, $password ) = @_;

    my $handler = _getUserHandler();
    return $handler->CheckUserPasswd($user, $password);
}
 
# =========================
sub addUserToTWikiUsersTopic
{
    my ( $wikiName, $remoteUser ) = @_;
    my $today = &TWiki::getGmDate();
    my $topicName = $TWiki::wikiUsersTopicname;
    my( $meta, $text )  = &TWiki::Store::readTopic( $TWiki::mainWebname, $topicName );
    my $result = "";
    my $status = "0";
    my $line = "";
    my $name = "";
    my $isList = "";
    # add name alphabetically to list
    foreach( split( /\n/, $text) ) {
        $line = $_;
	# TODO: I18N fix here once basic auth problem with 8-bit user names is
	# solved
        $isList = ( $line =~ /^\t\*\s[A-Z][a-zA-Z0-9]*\s\-/go );
        if( ( $status == "0" ) && ( $isList ) ) {
            $status = "1";
        }
        if( $status == "1" ) {
            if( $isList ) {
                $name = $line;
                $name =~ s/(\t\*\s)([A-Z][a-zA-Z0-9]*)\s\-.*/$2/go;            
                if( $wikiName eq $name ) {
                    # name is already there, do nothing
                    return $topicName;
                } elsif( $wikiName lt $name ) {
                    # found alphabetical position
                    if( $remoteUser ) {
                        $result .= "\t* $wikiName - $remoteUser - $today\n";
                    } else {
                        $result .= "\t* $wikiName - $today\n";
                    }
                    $status = "2";
                }
            } else {
                # is last entry
                if( $remoteUser ) {
                    $result .= "\t* $wikiName - $remoteUser - $today\n";
                } else {
                    $result .= "\t* $wikiName - $today\n";
                }
                $status = "2";
            }
        }

        $result .= "$line\n";
    }
    &TWiki::Store::saveTopic( $TWiki::mainWebname, $topicName, $result, $meta, "", 1 );
    return $topicName;
}



1;

# EOF
