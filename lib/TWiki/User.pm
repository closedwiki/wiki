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

=begin twiki

---+ TWiki::User Package
Singleton object that handles mapping of users to wikinames and
vice versa, and user authentication checking.

=cut

package TWiki::User;

use strict;
use Assert;

# 'Use locale' for internationalisation of Perl sorting in getTopicNames
# and other routines - main locale settings are done in TWiki::setupLocale
BEGIN {
    # Do a dynamic 'use locale' for this module
    if( $TWiki::useLocale ) {
        eval 'require locale; import locale ();';
    }
}

=pod

---+++ initialize ()
Construct the user management object

=cut

sub new {
    my ( $class, $session, $impl ) = @_;
    ASSERT(ref($session) eq "TWiki") if DEBUG;
    my $this = bless( {}, $class );
    $this->{session} = $session;

    $this->{IMPL} = "TWiki::User::$impl";
    $this->{CACHED} = 0;

	eval "use $this->{IMPL}";

    return $this;
}

sub prefs { my $this = shift; return $this->{session}->{prefs}; }
sub store { my $this = shift; return $this->{session}->{store}; }
sub sandbox { my $this = shift; return $this->{session}->{sandbox}; }
sub security { my $this = shift; return $this->{session}->{security}; }
sub templates { my $this = shift; return $this->{session}->{templates}; }
sub renderer { my $this = shift; return $this->{session}->{renderer}; }

# Get the password implementation
sub _getPasswordHandler {
    my( $this, $web, $topic, $attachment ) = @_;

    $attachment = "" if( ! $attachment );

    my $passwordHandler = $this->{IMPL}->new( $this->{session} );

    return $passwordHandler;
}

=pod

---++ userPasswordExists( $user ) ==> $passwordExists
| Description: | checks to see if there is a $user in the password system |
| Parameter: =$user= | the username we are looking for  |
| Return: =$passwordExists= | "1" if true, "" if not |
| TODO: | what if the login name is not the same as the twikiname?? (I think we dont have TWikiName to username mapping fully worked out|

=cut

sub userPasswordExists {
    my ( $this, $user ) = @_;
    ASSERT(ref($this) eq "TWiki::User") if DEBUG;

    my $passwordHandler = $this->_getPasswordHandler();

    return $passwordHandler->UserPasswordExists($user);
}

=pod

---++ updateUserPassword( $user, $oldUserPassword, $newUserPassword ) ==> $success
| Description: | used to change the user's password |
| Parameter: =$user= | the username we are replacing  |
| Parameter: =$oldUserPassword= | unencrypted password |
| Parameter: =$newUserPassword= | unencrypted password |
| Return: =$success= | "1" if success |
| TODO: | need to improve the error mechanism so TWikiAdmins know what failed |
| Notes: | always return failure if the $user is AnonymousContributor |
| | this is to stop hyjacking of DeletedUser's content |

=cut

sub updateUserPassword {
    my ( $this, $user, $oldUserPassword, $newUserPassword ) = @_;

	if ( $user =~ /AnonymousContributor/ ) {
		return;
	}

    my $passwordHandler = $this->_getPasswordHandler();
    return $passwordHandler->UpdateUserPassword($user, $oldUserPassword, $newUserPassword);
}

=pod

---++ addUserPassword( $user, $newUserPassword ) ==> $success
| Description: | creates a new user & password entry |
| Parameter: =$user= | the username we are replacing  |
| Parameter: =$newUserPassword= | unencrypted password |
| Return: =$success= | "1" if success |
| TODO: | need to improve the error mechanism so TWikiAdmins know what failed |
| Notes: | always return failure if the $user is AnonymousContributor |
| | this is to stop hyjacking of DeletedUser's content |

=cut

sub addUserPassword {
    my ( $this, $user, $newUserPassword ) = @_;

	if ( $user =~ /AnonymousContributor/ ) {
		return;
	}

    my $passwordHandler = $this->_getPasswordHandler();
    return $passwordHandler->AddUserPassword($user, $newUserPassword);
}

=pod

---++ removeUser( $user ) ==> $success
| Description: | used to remove the user from the password system |
| Parameter: =$user= | the username we are replacing  |
| Return: =$success= | "1" if success |
| TODO: | need to improve the error mechanism so TWikiAdmins know what failed |

=cut

sub removeUser {
    my ( $this, $user ) = @_;

    my $passwordHandler = $this->_getPasswordHandler();
    return $passwordHandler->RemoveUser($user);
}

=pod

---++ checkUserPasswd( $user, $password ) ==> $success
| Description: | used to check the user's password |
| Parameter: =$user= | the username we are replacing  |
| Parameter: =$password= | unencrypted password |
| Return: =$success= | "1" if success |
| TODO: | need to improve the error mechanism so TWikiAdmins know what failed |

=cut

sub checkUserPasswd {
    my ( $this, $user, $password ) = @_;

    my $passwordHandler = $this->getPasswordHandler();
    return $passwordHandler->CheckUserPasswd($user, $password);
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
    my ( $this, $wikiName, $remoteUser ) = @_;
    my $today = &TWiki::formatTime(time(), "\$day \$mon \$year", "gmtime");
    my $topicName = $TWiki::wikiUsersTopicname;
    my( $meta, $text ) =
      $this->store()->readTopic( $TWiki::mainWebname, $topicName, undef, 0 );
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
    $this->store()->saveTopic( $TWiki::mainWebname, $topicName, $result, $meta, "", 1 );
    return $topicName;
}

=pod

---++ getEmail( $wikiName ) ==> $emailAddress
| Description: | get the Users EmailAddress |
| Parameter: =$wikiName= | the users TWikiName |
| Return: =$topicName= | the email address corresponding to  the wikiName |

=cut

sub getEmail {
    my ($this, $wikiName) = @_;
    my $mainWebname = $TWiki::mainWebname;

    # Ignore guest entry and non-existent pages
    unless ($this->store()->topicExists( $mainWebname, $wikiName )) {
        return;
    }

    if ($wikiName eq $TWiki::defaultWikiName) {
        return;
    }

    my @list = ();

    if ( $wikiName =~ /Group$/ ) {
        # Page is for a group, get all users in group
        ##writeDebug "using group: $mainWebname . $wikiName";
        my @userList = TWiki::Access::getUsersOfGroup( $wikiName );
        foreach my $user ( @userList ) {
            $user =~ s/^.*\.//;# Get rid of 'Main.' part.
            foreach my $email ( TWiki::getEmail($user) ) {
                push @list, $email;
            }
        }
    } else {
        # Page is for a user
        ##writeDebug "reading home page: $mainWebname . $wikiName";
        push @list, $this->_getEmailAddressesFromPage($mainWebname, $wikiName);
    }
    use Data::Dumper;
    return (@list);
}

# Returns array of email addresses referenced in 
# the bulletfield / metafield on the page.
sub _getEmailAddressesFromPage {
    my ($this, $mainWebname, $wikiName) = @_;

    return $this->_getField($mainWebname, $wikiName, "Email");
}

# SMELL - this is no longer specific to users - surely any topic has fields
# SMELL - returns singular if refering to a field in meta, but multiple if values are defined that way in topic content
sub _getField {
    my ($this, $web, $topic, $fieldName) = @_;
    my ($meta, $text) =
      $this->store()->readTopic(
                                $this->{session}->{wikiUserName},
                               $web,
                               $topic,
                               undef,
                               1   # SMELL Should this really be internal?
                              );
    my @fieldValues;
    my %entry = $meta->findOne("FIELD", $fieldName); # SMELL - do we always want a singular entry?
    if (keys %entry) {
        return ($entry{value});
    } else {

        foreach my $l (split ( /\r?\n/, $text  )) {
            # REFACTOR UserData::BulletFieldsImpl
            if ($l =~ /^\s\*\s$fieldName:\s+([\w\-\.\+]+\@[\w\-\.\+]+)/) { # SMELL - is this only suited to email?
                push @fieldValues, $1;
            }
        }
    }
    return @fieldValues;
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
    my( $this, $theRemoteUser ) = @_;

    my $remoteUser = $theRemoteUser || $TWiki::defaultUserName;
    $remoteUser =~ s/$TWiki::securityFilter//go;
    $remoteUser = TWiki::Sandbox::untaintUnchecked( $remoteUser );

    my $remoteAddr = $ENV{'REMOTE_ADDR'} || "";

    if( $ENV{'REDIRECT_STATUS'} && $ENV{'REDIRECT_STATUS'} eq '401' ) {
        # bail out if authentication failed
        $remoteAddr = "";
    }

    if( ( ! $TWiki::doRememberRemoteUser ) || ( ! $remoteAddr ) ) {
        # do not remember IP address
        return $remoteUser;
    }

    my $text = $this->store()->readFile( $TWiki::remoteUserFilename );
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
            $this->store()->saveFile( $TWiki::remoteUserFilename, $text );
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
    my $this = shift;

    return if $this->{CACHED};
    $this->{CACHED} = 1;

    %{$this->{U2W}} = ();
    %{$this->{W2U}} = ();
    my @list = ();
    if( $TWiki::doMapUserToWikiName ) {
        @list = split( /\n/, $this->store()->readFile( $TWiki::userListFilename ) );
    } else {
        # fix for Codev.SecurityAlertGainAdminRightWithTWikiUsersMapping
        # for .htpasswd authenticated sites ignore user list, but map only guest to TWikiGuest
        @list = ( "\t* $TWiki::defaultWikiName - $TWiki::defaultUserName - " ); # CODE_SMELL on localization
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
            $this->{U2W}{ $lUser } = $wUser;
            $this->{W2U}{ $wUser } = $lUser;
        }
    }
}

=pod

---++ userToWikiName( $loginUser, $dontAddWeb ) --> $wikiName

Translates intranet username (e.g. jsmith) to WikiName (e.g. JaneSmith)
userToWikiListInit must be called before this function is used.

Unless $flag is set, "Main." is prepended to the returned WikiName.

if you give an invalid username, we just return that (no appending Main. blindy),
unless flag is set to 2, in which case it returns undef.

SMELL: the userToWikiList cache should really contain the WebName so its possible 
		to have userTopics in more than just the MainWeb (what if you move a user topic?)

=cut

sub userToWikiName {
    my( $this, $loginUser, $flag ) = @_;

    if( !$loginUser ) {
        return "";
    }

    $this->_cacheUserToWikiTranslations();

    $loginUser =~ s/$TWiki::securityFilter//go;
    my $wUser = $this->{U2W}{ $loginUser };

    # New behaviour for RegisterCgiScriptRewrite
    if ($flag && ($flag == 2)) {
        # return the real mapping, even if it is undef
        return $wUser;
    }

    # Original behaviour - map existing entries
    unless ($wUser) {
        $wUser = $loginUser;
    }

    # return with webName
    unless ($flag) {
        return "$TWiki::mainWebname.$wUser";
    }

    # v2 - blindy return loginName if mapping not present.
    return $wUser;


}

=pod

---++ wikiToUserName( $wikiName ) --> $loginUser

Translates WikiName (e.g. JaneSmith) to an intranet username (e.g. jsmith)
If there is no mapping, returns the WikiName.

=cut

sub wikiToUserName {
    my( $this, $wikiUser ) = @_;
    $wikiUser =~ s/^.*\.//g;
    $this->_cacheUserToWikiTranslations();
    my $userName =  $this->{W2U}{$wikiUser} || $wikiUser;
    return $userName;
}

1;
