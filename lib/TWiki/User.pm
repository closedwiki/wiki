# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2004 Peter Thoeny, peter@thoeny.com
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

=begin twiki

---+ TWiki::User Package

This module hosts the user authentication implementation

=cut

package TWiki::User;

use TWiki::Templates;

use strict;

# 'Use locale' for internationalisation of Perl sorting in getTopicNames
# and other routines - main locale settings are done in TWiki::setupLocale
BEGIN {
    # Do a dynamic 'use locale' for this module
    if( $TWiki::useLocale ) {
        eval 'require locale; import locale ();';
    }
}

use vars qw(
            $UserImpl
            %userToWikiList %wikiToUserList
            $wikiNamesMapped
           );

$UserImpl = "";

=pod

---+++ initialize ()
| Description: | loads the selected User Implementation |

=cut

sub initialize {
	if ( # (-e $TWiki::htpasswdFilename ) && #<<< maybe
		( $TWiki::htpasswdFormatFamily eq "htpasswd" ) ) {
	    $UserImpl = "TWiki::User::HtPasswdUser";
#	} elseif ($TWiki::htpasswdFormatFamily eq "something?") {
#	    $UserImpl = "TWiki::User::SomethingUser";
	} else {
	    $UserImpl = "TWiki::User::NoPasswdUser";
	}
	eval "use ".$UserImpl;
}

sub _getUserHandler {
   my( $web, $topic, $attachment ) = @_;

   $attachment = "" if( ! $attachment );

   my $handlerName = $UserImpl;

   my $handler = $handlerName->new( );
   $wikiNamesMapped = 0;

   return $handler;
}

=pod

---++ UserPasswordExists( $user ) ==> $passwordExists
| Description: | checks to see if there is a $user in the password system |
| Parameter: =$user= | the username we are looking for  |
| Return: =$passwordExists= | "1" if true, "" if not |
| TODO: | what if the login name is not the same as the twikiname?? (I think we dont have TWikiName to username mapping fully worked out|

=cut

sub UserPasswordExists {
    my ( $user ) = @_;

    my $handler = _getUserHandler();

    return $handler->UserPasswordExists($user);
}

=pod

---++ UpdateUserPassword( $user, $oldUserPassword, $newUserPassword ) ==> $success
| Description: | used to change the user's password |
| Parameter: =$user= | the username we are replacing  |
| Parameter: =$oldUserPassword= | unencrypted password |
| Parameter: =$newUserPassword= | unencrypted password |
| Return: =$success= | "1" if success |
| TODO: | need to improve the error mechanism so TWikiAdmins know what failed |
| Notes: | always return failure if the $user is AnonymousContributor |
| | this is to stop hyjacking of DeletedUser's content |

=cut

sub UpdateUserPassword {
    my ( $user, $oldUserPassword, $newUserPassword ) = @_;

	if ( $user =~ /AnonymousContributor/ ) {
		return;
	}

    my $handler = _getUserHandler();
    return $handler->UpdateUserPassword($user, $oldUserPassword, $newUserPassword);
}

=pod

---++ AddUserPassword( $user, $newUserPassword ) ==> $success
| Description: | creates a new user & password entry |
| Parameter: =$user= | the username we are replacing  |
| Parameter: =$newUserPassword= | unencrypted password |
| Return: =$success= | "1" if success |
| TODO: | need to improve the error mechanism so TWikiAdmins know what failed |
| Notes: | always return failure if the $user is AnonymousContributor |
| | this is to stop hyjacking of DeletedUser's content |

=cut

sub AddUserPassword {
    my ( $user, $newUserPassword ) = @_;

	if ( $user =~ /AnonymousContributor/ ) {
		return;
	}

    my $handler = _getUserHandler();
    return $handler->AddUserPassword($user, $newUserPassword);
}

=pod

---++ RemoveUser( $user ) ==> $success
| Description: | used to remove the user from the password system |
| Parameter: =$user= | the username we are replacing  |
| Return: =$success= | "1" if success |
| TODO: | need to improve the error mechanism so TWikiAdmins know what failed |

=cut

sub RemoveUser {
    my ( $user ) = @_;

    my $handler = _getUserHandler();
    return $handler->RemoveUser($user);
}

=pod

---++ CheckUserPasswd( $user, $password ) ==> $success
| Description: | used to check the user's password |
| Parameter: =$user= | the username we are replacing  |
| Parameter: =$password= | unencrypted password |
| Return: =$success= | "1" if success |
| TODO: | need to improve the error mechanism so TWikiAdmins know what failed |

=cut

sub CheckUserPasswd {
    my ( $user, $password ) = @_;

    my $handler = _getUserHandler();
    return $handler->CheckUserPasswd($user, $password);
}

=pod

---++ addUserToTWikiUsersTopic( $wikiName, $remoteUser ) ==> $topicName
| Description: | create the Users TWikiTopic |
| Parameter: =$wikiName= | the users TWikiName |
| Parameter: =$remoteUser= | the remote username (is this used in the password file at any time?) |
| Return: =$topicName= | the name of the TWikiTopic created |
| TODO: | does this really belong here? |

=cut

sub addUserToTWikiUsersTopic {
    my ( $wikiName, $remoteUser ) = @_;
    my $today = &TWiki::formatTime(time(), "\$day \$mon \$year", "gmtime");
    my $topicName = $TWiki::wikiUsersTopicname;
    my( $meta, $text ) =
      TWiki::Store::readTopic( $TWiki::mainWebname, $topicName, undef, 0 );
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
    TWiki::Store::saveTopic( $TWiki::mainWebname, $topicName, $result, $meta, "", 1 );
    return $topicName;
}

=pod

---++ initializeRemoteUser( $remoteUser )
Return value: $remoteUser

Acts as a filter for $remoteUser.  If set, $remoteUser is filtered for
insecure characters and untainted.

If $doRememberRemoteUser and $remoteUser are both set in TWiki.cfg, it
also caches $remoteUser as belonging to the IP address of the current request.

If $doRememberRemoteUser is set and $remoteUser is not, then it sets
$remoteUser to the last authenticated user to make a request with the
current request's IP address, or $defaultUserName if no cached name
is available.

If neither are set, then it sets $remoteUser to $defaultUserName.

SMELL: the association of a user with an IP address is a high
risk strategy that can fail in the following environments:
   1 Multiple users at the same IP address
   1 Short-lease DHCP environments
This is documented sufficiently for a risk assessment to be made
by the installer. However it would be much safer (and more user
friendly) to use cookies.

SMELL: this should be done in User.pm

=cut

sub initializeRemoteUser {
    my( $theRemoteUser ) = @_;

    my $remoteUser = $theRemoteUser || $TWiki::defaultUserName;
    $remoteUser =~ s/$TWiki::securityFilter//go;
    $remoteUser =~ /(.*)/;
    $remoteUser = $1;  # untaint variable

    my $remoteAddr = $ENV{'REMOTE_ADDR'} || "";

    if( $ENV{'REDIRECT_STATUS'} && $ENV{'REDIRECT_STATUS'} eq '401' ) {
        # bail out if authentication failed
        $remoteAddr = "";
    }

    if( ( ! $TWiki::doRememberRemoteUser ) || ( ! $remoteAddr ) ) {
        # do not remember IP address
        return $remoteUser;
    }

    my $text = TWiki::Store::readFile( $TWiki::remoteUserFilename );
    # Assume no I18N characters in userids, as for email addresses
    # FIXME: Needs fixing for IPv6?
    my %AddrToName = map { split( /\|/, $_ ) }
                     grep { /^[0-9\.]+\|[A-Za-z0-9]+\|$/ }
                     split( /\n/, $text );

    my $rememberedUser = "";
    if( exists( $AddrToName{ $remoteAddr } ) ) {
        $rememberedUser = $AddrToName{ $remoteAddr };
    }

    if( $theRemoteUser ) {
        if( $theRemoteUser ne $rememberedUser ) {
            $AddrToName{ $remoteAddr } = $theRemoteUser;
            # create file as "$remoteAddr|$theRemoteUser|" lines
            $text = "# This is a generated file, do not modify.\n";
            foreach my $usrAddr ( sort keys %AddrToName ) {
                my $usrName = $AddrToName{ $usrAddr };
                # keep $userName unique
                if(  ( $usrName ne $theRemoteUser )
                  || ( $usrAddr eq $remoteAddr ) ) {
                    $text .= "$usrAddr|$usrName|\n";
                }
            }
            TWiki::Store::saveFile( $TWiki::remoteUserFilename, $text );
        }
    } else {
        # get user name from AddrToName table
        $remoteUser = $rememberedUser || $TWiki::defaultUserName;
    }

    return $remoteUser;
}

=pod

---++ _cacheUserToWikiTranslations()
Build hashes to translate in both directions between username (e.g. jsmith) 
and WikiName (e.g. JaneSmith).  Only used for sites where authentication is
managed by external Apache configuration, instead of via TWiki's .htpasswd
mechanism.

Should only be called once per request.

SMELL: this should be done in User.pm

=cut

sub _cacheUserToWikiTranslations {
    return if $wikiNamesMapped;
    $wikiNamesMapped = 1;

    %userToWikiList = ();
    %wikiToUserList = ();
    my @list = ();
    if( $TWiki::doMapUserToWikiName ) {
        @list = split( /\n/, TWiki::Store::readFile( $TWiki::userListFilename ) );
    } else {
        # fix for Codev.SecurityAlertGainAdminRightWithTWikiUsersMapping
        # for .htpasswd authenticated sites ignore user list, but map only guest to TWikiGuest
        @list = ( "\t* TWikiGuest - guest - " ); # CODE_SMELL on localization
    }

    # Get all entries with two '-' characters on same line, i.e.
    # 'WikiName - userid - date created'
    @list = grep { /^\s*\* $TWiki::regex{wikiWordRegex}\s*-\s*[^\-]*-/o } @list;
    my $wUser;
    my $lUser;
    foreach( @list ) {
	# Get the WikiName and userid, and build hashes in both directions
        if(  ( /^\s*\* ($TWiki::regex{wikiWordRegex})\s*\-\s*([^\s]*).*/o ) && $2 ) {
            $wUser = $1;	# WikiName
            $lUser = $2;	# userid
            $lUser =~ s/$TWiki::securityFilter//go;	# FIXME: Should filter in for security...
            $userToWikiList{ $lUser } = $wUser;
            $wikiToUserList{ $wUser } = $lUser;
        }
    }
}

=pod

---++ userToWikiName( $loginUser, $dontAddWeb )
Return value: $wikiName

Translates intranet username (e.g. jsmith) to WikiName (e.g. JaneSmith)

Unless $dontAddWeb is set, "Main." is prepended to the returned WikiName.

If you give an invalid username, we just return that (no appending Main. blindy)

SMELL: the userToWikiList cache should really contain the WebName so its possible 
		to have userTopics in more than just the MainWeb (what if you move a user topic?)

=cut

sub userToWikiName {
    my( $loginUser, $dontAddWeb ) = @_;

    if( !$loginUser ) {
        return "";
    }

    _cacheUserToWikiTranslations();

    $loginUser =~ s/$TWiki::securityFilter//go;
    my $wUser = $userToWikiList{ $loginUser } || $loginUser;
    if( $dontAddWeb ) {
        return $wUser;
    }
    return "$TWiki::mainWebname.$wUser";
}

=pod

---++ wikiToUserName( $wikiName )
Return value: $loginUser

Translates WikiName (e.g. JaneSmith) to an intranet username (e.g. jsmith)

=cut

sub wikiToUserName {
    my( $wikiUser ) = @_;
    $wikiUser =~ s/^.*\.//g;
    _cacheUserToWikiTranslations();
    my $userName =  $wikiToUserList{"$wikiUser"} || $wikiUser;
    return $userName;
}

1;

# EOF
