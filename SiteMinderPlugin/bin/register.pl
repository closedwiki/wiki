#!/usr/bin/perl -wT
BEGIN{($_=$0)=~s!(.*)[\\/][^\\/]+$!!;chdir $1} 

#
# TWiki WikiClone (see wiki.pm for $wikiversion and other info)
#
# Copyright (C) 1999 Peter Thoeny, peter@thoeny.com
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

use CGI::Carp qw(fatalsToBrowser);
use CGI;
use lib ( '.' );
use lib ( '../lib' );
use TWiki;
use TWiki::Net;

if( $TWiki::OS eq "WINDOWS" ) {
    use MIME::Base64;
    use Digest::SHA1;
}


$query = new CGI;

##### for debug only: Remove next 3 comments (but redirect does not work)
#open(STDERR,'>&STDOUT'); # redirect error to browser
#$| = 1;                  # no buffering
#TWiki::writeHeader( $query );

&main();

sub main
{
    # get all parameters from the form
    my @paramNames = $query->param();
    my @formDataName = ();
    my @formDataValue = ();
    my @formDataRequired = ();
    my $name = "";
    my $value = "";
    my $emailAddress = "";
    my $firstLastName = "";
    my $wikiName = "";
    my $remoteUser = "";
    my $passwordA = "";
    my $passwordB = "";
    foreach( @paramNames ) {
        if( /^(Twk)([0-9])(.*)/ ) {
            $value = $query->param( "$1$2$3" );
            $formDataRequired[@formDataRequired] = $2;
            $name = $3;
            $name =~ s/([a-z0-9])([A-Z0-9])/$1 $2/go;
            $formDataName[@formDataName] = $name;
            $formDataValue[@formDataValue] = $value;
            if( $name eq "Name" ) {
                $firstLastName = $value;
            } elsif( $name eq "Wiki Name" ) {
                $wikiName = $value;
            } elsif( $name eq "Login Name" ) {
                $remoteUser = $value;
            } elsif( $name eq "Email" ) {
                $emailAddress = $value;
            } elsif( $name eq "Password" ) {
                $passwordA = $value;
            } elsif( $name eq "Confirm" ) {
                $passwordB = $value;
            }
        }
    }

    #RJE
    
    $wikiName = &TWiki::Plugins::SiteMinderPlugin::wikiNameFromSiteMinderName();

    &TWiki::writeDebug( "WIKI NAME IN REG IS $wikiName");

    my $formLen = @formDataValue;

    my $topicName = $query->param( 'TopicName' );
    my $thePathInfo = $query->path_info(); 
    my $theUrl = $query->url;
    ( $topic, $webName ) = 
	&TWiki::initialize( $thePathInfo, $wikiName, $topicName, $theUrl, $query );

    my $text = "";
    my $url = "";


    # check if user entry already exists
    if(  ( $wikiName ) 
      && (  ( &TWiki::Store::topicExists( $webName,  $wikiName ) )
         || ( htpasswdExistUser( $wikiName ) ) 
         ) ) {
        # PTh 20 Jun 2000: changed to getOopsUrl
        $url = &TWiki::getOopsUrl( $webName, $topic, "oopsregexist", $wikiName );
        TWiki::redirect( $query, $url );
        return;
    }

    # check if required fields are filled in
    my $x;
    for( $x = 0; $x < $formLen; $x++ ) {
        if( ( $formDataRequired[$x] ) && ( ! $formDataValue[$x] ) ) {
            $url = &TWiki::getOopsUrl( $webName, $topic, "oopsregrequ", );
            TWiki::redirect( $query, $url );
            return;
        }
    }



    # check if wikiName is a WikiName
    if( ! &TWiki::isWikiName( $wikiName ) ) {
        $url = &TWiki::getOopsUrl( $webName, $topic, "oopsregwiki" );
        TWiki::redirect( $query, $url );
        return;
    }
    # a WikiName is safe, so untaint variable
    $wikiName =~ /(.*)/;
    $wikiName = $1;

    # check if passwords are identical
    if( $passwordA ne $passwordB ) {
        $url = &TWiki::getOopsUrl( $webName, $topic, "oopsregpasswd" );
        TWiki::redirect( $query, $url );
        return;
    }

    # everything OK

    # generate user entry and add to .htpasswd file
    if( ! $remoteUser ) {
        htpasswdAddUser( htpasswdGeneratePasswd( $wikiName, $passwordA ) );
    }

    # send email confirmation
    $text = &TWiki::Store::readTemplate( "registernotify" );
    $text =~ s/%FIRSTLASTNAME%/$firstLastName/go;
    $text =~ s/%WIKINAME%/$wikiName/go;
    $text =~ s/%EMAILADDRESS%/$emailAddress/go;
    ( $before, $after) = split( /%FORMDATA%/, $text );
    for( $x = 0; $x < $formLen; $x++ ) {
        $name = $formDataName[$x];
        $value = $formDataValue[$x];
        if( ( $name eq "Password" ) && ( $TWiki::doHidePasswdInRegistration ) ) {
            $value = "*******";
        }
        if( $name ne "Confirm" ) {
            $before .= "   * $name\: $value\n";
        }
    }
    $text = "$before$after";
    $text = &TWiki::handleCommonTags( $text, $wikiName );

    my $senderr = &TWiki::Net::sendEmail( $text );

    # create user topic if not exist
    if( ! &TWiki::Store::topicExists( $TWiki::mainWebname, $wikiName ) ) {
        $text = &TWiki::Store::readTemplate( "register" );
        ( $before, $after) = split( /%FORMDATA%/, $text );
        for( $x = 0; $x < $formLen; $x++ ) {
            $name = $formDataName[$x];
            $value = $formDataValue[$x];
            $value =~ s/[\n\r]/ /go;
            if( ! (    ( $name eq "Wiki Name" )
                    || ( $name eq "Password" )
                    || ( $name eq "Confirm" ) ) ) {
                $before .= "   * $name\: $value\n";
            }
        }
        $text = "$before$after";
        $text =~ s/ {3}/\t/go;
        my $meta = TWiki::Meta->new();
        &TWiki::Store::saveTopic( $webName, $wikiName, $text, $meta, "", 1 );
    }

    # add user to TWikiUsers topic
    my $userTopic = addUserToTWikiUsersTopic( $wikiName, $remoteUser );

    # write log entry
    if( $TWiki::doLogRegistration ) {
        &TWiki::Store::writeLog( "register", "$webName.$userTopic", $emailAddress, $wikiName );
    }

    if( $senderr ) {
        my $url = &TWiki::getOopsUrl( $webName, $wikiName, "oopssendmailerr", $senderr );
        TWiki::redirect( $query, $url );
    }

    # and finally display thank you page
    $url = &TWiki::getOopsUrl( $webName, $wikiName, "oopsregthanks", $emailAddress );
    TWiki::redirect( $query, $url );
}

sub htpasswdGeneratePasswd
{
    my ( $user, $passwd ) = @_;
    # by David Levy, Internet Channel, 1997
    # found at http://world.inch.com/Scripts/htpasswd.pl.html
    if ( $TWiki::OS eq "WINDOWS" ) {
        return $user . ':{SHA}' . encode_base64(Digest::SHA1::sha1($passwd));
    }
    srand( $$|time );
    my @saltchars = ( 'a'..'z', 'A'..'Z', '0'..'9', '.', '/' );
    my $salt = $saltchars[ int( rand( $#saltchars+1 ) ) ];
    $salt .= $saltchars[ int( rand( $#saltchars+1 ) ) ];
    my $passwdcrypt = crypt( $passwd, $salt );
    return "$user\:$passwdcrypt";
}

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

sub htpasswdAddUser
{
    my ( $userEntry ) = @_;

    # can't use `htpasswd $wikiName` because htpasswd doesn't understand stdin
    # simply add name to file, but this is a security issue
    my $text = &TWiki::Store::readFile( $TWiki::htpasswdFilename );
    $text .= "$userEntry\n";
    &TWiki::Store::saveFile( $TWiki::htpasswdFilename, $text );
}

sub addUserToTWikiUsersTopic
{
    my ( $wikiName, $remoteUser ) = @_;
    my $today = &TWiki::getLocaldate();
    my $topicName = $TWiki::userListFilename;
    $topicName =~ s/(.*[^\/])\/([a-zA-Z0-9]*)\.txt$/$2/go;
    my( $meta, $text )  = &TWiki::Store::readTopic( $TWiki::mainWebname, $topicName );
    my $result = "";
    my $status = "0";
    my $line = "";
    my $name = "";
    my $isList = "";
    # add name alphabetically to list
    foreach( split( /\n/, $text) ) {
        $line = $_;
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
