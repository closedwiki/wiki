#!/usr/bin/perl
#
# TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (c) 1999-2004 Peter Thoeny, peter@thoeny.com
#           (c) 2001 Kevin Atkinson, kevin twiki at atkinson dhs org
#           (c) 2003 SvenDowideit
#           (c) 2003 Graeme Pyle graeme@raspberry dot co dot za
#           (c) 2004 Martin Cleaver, Martin.Cleaver@BCS.org.uk
#           (c) 2004 Gilles-Eric Descamps twiki at descamps.org
#           (c) 2004 Crawford Currie c-dot.co.uk
#
# All rights reserved.
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

package TWiki::UI::Register;

use strict;
use TWiki;
use TWiki::Net;
use TWiki::Plugins;
use TWiki::User;
use TWiki::Data::DelimitedFile;
use Data::Dumper;
use Error qw( :try );
use TWiki::UI;
use TWiki::UI::OopsException;

use vars qw( $unitTestMode );
# set unitTestMode to 1 for testing

=pod

---++ register_cgi( $session )
Body of 'register' script

=cut

sub register_cgi {
    my $session = shift;

    my $tempUserDir = $TWiki::pubDir."/TWiki/RegistrationApprovals";
    # SMELL hacked name, and stores in binary format!
    my $sendActivationCode = 1;
    my $needApproval = 1;

    # Register -> Verify -> Approve -> Finish

    # NB. bulkRegister is in ManageCgiScript.

    my $action = $session->{cgiQuery}->param('action');

    if ($action eq 'register') {
        register(
                 session=>$session,
                 sendActivationCode => $sendActivationCode,
                 tempUserDir => $tempUserDir
                );
        if (!$sendActivationCode) {
            throw Error::Simple("Need to call verify automatically");
        }
    } elsif ($action eq 'approve') {
        finish(
               session=>$session,
               tempUserDir=>$tempUserDir
              );
    }
    elsif ($action eq 'verify') {
        verifyEmailAddress(
                           session=>$session,
                           tempUserDir=>$tempUserDir,
                           needApproval=>$needApproval
                          );
        #	if (! $needApproval) {
        #	    throw Error::Simple("Need to call approve automatically");
        #	}
        finish(
               session=>$session,
               tempUserDir=>$tempUserDir,
               approve=>$session->{cgiQuery}->param('code')
              );

    } elsif ($action eq 'resetPassword') { #TODO
        resetPassword( $session );
    } else {
        # SMELL: this should be an OopsException
        throw Error::Simple("invalid action ($action) in register");
    }

    # Output of register:
    #    UnsavedUser, accessible by username.$verificationCode

    # Output of reset password:
    #    unaffected user, accessible by username.$verificationCode

    # Output of verify:
    #    UnsavedUser, accessible by username.$approvalCode (only sent to administrator)

    # Output of approve:
    #    RegisteredUser, all related UnsavedUsers deleted
}

=pod

---++ register_cgi( $session )
Body of 'passwd' script

=cut

sub passwd_cgi {
    my $session = shift;

    my $action = $session->{cgiQuery}->param("action");

    if( $action eq "changePassword" ) {
        changePassword( $session );
    } elsif ( $action eq "resetPassword" ) {
        resetPassword( $session );
    } else {
        throw TWiki::UI::OopsException( $session->{webName},
                                        $session->{topicName},
                                        "manage");
    }
}

# TODO: S&R {form} with {ordered}
# TODO: S&R row, data => user
# TODO: Use Oops.pm instead of TWiki::Oops
# TODO: Try/catch
# TODO: Move parts to User.pm
# TODO: Replace LoginName with UserName (NB. templates/topics)
# TODO: During normal registration, a Plugin callback to set cookies,
#       TWiki::Plugins::registrationHandler( $data{webName}, $data{WikiName},
#       $data{remoteUser} );
#       Is called. But this has little to do with registration - it is an authentication rememberer.
#       In fact, isn't my bulkregistration handler just a reg handler?
# TODO: registernotifybulk.tmpl 
# CAVEAT: you must not delete a requiredField - there is no check for this but it will break things like TWikiUsers
#     * TODO: make it copy the fields it wants before handing off to the RegsitrationPlugin - that way it won't matter if
#             that deletes such keys.
# ISSUE: TWiki::User::addUserToTWikiUsersTopic does not replace the line if you now supply a login name when one was not needed before.
# TODO: write a plugin that intercepts the change of metadata on a topic and invokes functionality as described on 
#       RegistrationAsPlugin.
# TODO: more work to align the checks made by the two register/bulkRegister systems 

my $b = "\t*"; # SMELL legacy format - bulletpoint. I'd hardcode it except there is a proposal to change it.
my $b2 ="\t\t*";
my $indent = "\t"; # SMELL indent legacy

=pod

---++ bulkRegister
  Called by ManageCgiScript::bulkRegister (requires authentication) with topic = the page with the entries on it.
   1 Makes sure you are an admin user ;)
2 Calls TWiki::Data::DelimitedFile (delimiter => "|", content =>textReadFromTopic)
   3 ensures requiredFieldsPresent()
   4 starts a log file
   5 calls registerSingleBulkUser() for each row 
   6 writes output to log file, sets [[TWiki.TOPICPARENT]] back to page with entries on it.
   7 redirects to log file

=cut

sub bulkRegister {
    my $session = shift;

    my $remoteUser = $session->{userName};
    my $topic = $session->{topicName};
    my $web = $session->{webName};
    my $userweb = $TWiki::mainWebname;
    my $query = $session->{cgiQuery};

    my %settings = ();
    $settings{doOverwriteTopics} = $query->param('OverwriteHomeTopics') || 0;
    $settings{doUseHtPasswd} = $TWiki::htpasswdFormatFamily eq "htpasswd";
    $settings{doEmailUserDetails} = $query->param('EmailUsersWithDetails') || 0;

    my ($wikiName, $loginName) = _getUserByEitherLoginOrWikiName( $session, $remoteUser );

    unless( $unitTestMode ) {
        TWiki::UI::checkAdmin( $session, $web, $topic, $wikiName );
    }

    #-- Read the topic containing a table of people to be registered


    my ($meta, $text) = $session->{store}->readTopic($session->{wikiUserName},
                                                     $web, $topic, undef, 1);
    my %data;
    ( $settings{fieldNames}, %data) =
      TWiki::Data::DelimitedFile::read(content => $text, delimiter => "|" );
    #    my @fieldNames = @{$fieldNamesArrayRef};

    my $registrationsMade = 0;
    my $log = "---+Report for Bulk Register\n\n%TOC%\n";

    #-- Process each row, generate a log as we go

    foreach my $row ( (values %data) ) {
        $row->{webName} = $userweb;

        my ($userTopic, $uLog) = _registerSingleBulkUser($session, $row, %settings );
        $log .= "\n---++ ". $row->{WikiName}."\n";
        $log .= "$b Added to users' topic ".$userTopic.":\n".join("\n$indent",split /\n/, "$uLog")."\n";	
        $registrationsMade++; # SMELL - no detection for failure
    }
    $log .= "----\n";
    $log .= "registrationsMade: $registrationsMade";

    my $logTopic =  $query->param('LogTopic') || $topic."Result"; # get preference 
    $logTopic =~ s/(.*)\.(.*)/$2/ ; # ignore the web as TWiki is too stupid to let $topic specify web.topic in save's $topic. SMELL SMELL SMELL. 


    #-- Save the LogFile as designated, link back to the source topic 

    $meta->put( "TOPICPARENT", ( "name" => $topic ) );

    my $err = $session->{store}->saveTopic($web, $logTopic, $log, $meta, "",  1 );

    $session->redirect($session->getViewUrl($web, $logTopic));
}

=pod

---++ _registerSingleBulkUser($rowHashRef, %settings)
    Process a single user, parameters passed as a hash

    * receives row and a fieldNamesOrderedList
    * sets LoginName to be WikiName if not present
    * rearranges the row to comply with the ordered list
    * if using htpasswd, calls _addUserToPasswordSystem()
    * makes newUserFromTemplate
    * calls addUserToTWikiUsersTopic()

=cut

# SMELL could be made much more efficient if needed, as calls to addUserToTWikiUsersTopic()
# are quite expensive when doing 300 in succession!
sub _registerSingleBulkUser {
    my ($session, $row, %settings) = @_;

    my @fieldNames = @{$settings{fieldNames} || throw Error::Simple( "No fieldNames" )};
    my $doUseHtPasswd = defined $settings{doUseHtPasswd} || throw Error::Simple( "No doHtPasswd" );
    my $doOverwriteTopics = defined $settings{doOverwriteTopics} || throw Error::Simple( "No doOverwriteTopics" );
    my $log;
    #-- call to the registrationHandler (to amend fields) should really happen in here.


    #-- TWiki:Codev.LoginNamesShouldNotBeWikiNames - but use it if not supplied

    unless ($row->{LoginName}) {
        $row->{LoginName} = $row->{WikiName};
        $log = "\t* No TWiki.LoginName specified - setting to $row->{LoginName}\n";
    }

    #-- Ensure every required field exists
    # NB. LoginName is OPTIONAL
    my @requiredFields = qw(WikiName FirstName LastName);
    if (_missingElements($settings{fieldNames}, \@requiredFields)) {
        throw Error::Simple( join(" ", @{$settings{fieldNames}})." does not contain \nthe full set of ".join(" ", @requiredFields) );
    }

    #-- Generation of the page is done from the {form} subhash, so align the two
    $row->{form} = [_makeFormFieldOrderMatch(
                                             fieldNames => \@fieldNames,
                                             data=>$row)
                   ];

    # SMELL - Auth should be extensible
    if ($doUseHtPasswd) {
        my $passResult = _addUserToPasswordSystem( session=>$session, %$row );
        $log .= "$b Password set: ".$passResult." (1 = success)\n";
        #TODO: need a path for if it doesn't succeed.
    }

    if( $doOverwriteTopics or !$session->{store}->topicExists( $row->{webName}, $row->{WikiName} ) ) {
        $log .= _newUserFromTemplate($session,"NewUserTemplate", $row);
    } else {
        $log .= "$b Not writing topic ".$row->{WikiName}."\n";
	}

    my $userTopic = $session->{users}->addUserToTWikiUsersTopic( $row->{WikiName}, $row->{LoginName} );

    if ($TWiki::doEmailUserDetails) {
        # _sendEmail(session=>$session, \%data, template => "registernotifybulk"); # If you want it, write it.
        $log .= "$b Password email disabled\n";
    }
    return ($userTopic, $log);
}

=pod

---++ _missingElements(\@present, \@required) 
ensures all named fields exist in hash
returns array containing any that are missing

=cut

sub _missingElements {
    my ($presentArrRef, $requiredArrRef) = @_;
    my %present;
    my @missing;

    $present{$_} = 1 for @$presentArrRef;
    foreach my $required (@$requiredArrRef) {
        if (! $present{$required}) {
            push @missing, $required;
        }
    }
    return @missing;
}

=pod

---++ _makeFormFieldOrderMatch(rearranges the fields in settings->{data}->{form} so that they match settings->{fieldNames}
returns a new ordered form

=cut

sub _makeFormFieldOrderMatch {
    my (%settings) =@_;
    my @fieldNames = @{$settings{fieldNames}};
    my %data = %{$settings{data}};
    my @form = ();
    foreach my $field (@fieldNames) {
        push @form, {name => $field, value => $data{$field}};
    }
    return @form;
}

=pod

---++ RegisterDotPm::register
This is called through: TWikiRegistration -> RegisterCgiScript -> here
   1 gets rows and fields as an InTopicTable using IntopicTable::populateEntries()
   2 calls _validateRegistration()
   3 generates a activation password
   4 calls UnregisteredUser::putRegDetailsByCode(activation password)
   5 sends them a "registerconfirm" email.
   5 redirects browser to "regconfirm"

=cut

sub register {
    my %params = @_;
    %params or throw Error::Simple( "No parameters" );

    my $session = $params{session};
    my ( $query, $sendActivationCode, $tmpuserDir ) =
      ( $session->{cgiQuery}, $params{sendActivationCode}, $params{tempUserDir} );

    my %data;    # this is persisted in the storable.

    my $topic = $session->{topicName};
    my $web = $session->{webName};

    %data = IntopicTable::populateEntries( $query, $query->param() );
    $data{webName} = $web;

    $data{debug} = 1;

    $data{WikiName} = TWiki::Sandbox::untaintUnchecked($data{WikiName});

    _validateRegistration( $session, \%data, $query, $topic );

    $data{VerificationCode} = "$data{WikiName}." . _randomPassword();
    UnregisteredUser::setDir($tmpuserDir);
    UnregisteredUser::putRegDetailsByCode(  \%data );

    _sendEmail( session=>$session, template => "registerconfirm", %data );

    throw TWiki::UI::OopsException( $data{webName}, $topic,
                                    "regconfirm", $data{Email} );
}

=pod

---++ Register::resetPassword

Generates a password. Mails it to them and asks them to change it. Entry
point intended to be called from TWiki::UI::run

   1 tries to locate account - uses getUserByEitherLoginOrWikiName
   2 checks we have an email address for the user, dies otherwise.
   3 removes any existing password
   3 generates new password
   4 sends it to them
   5 redirects browser to "resetpasswd"

=cut

sub resetPassword {
    my $session = shift;
    my $query = $session->{cgiQuery};
    my $action = $query->param('action');
    my $topic = $session->{topicName};
    my $web = $session->{webName};
    my $remoteUser = $session->{userName};

    my $introduction = $query->{Introduction}[0];
    my @userNames = @{$query->{LoginName}};
    my @wikiNames = ();

    my $wikiName = $session->{wikiUserName};
    if ( @userNames && ( $#userNames > 0 || $userNames[0] ne $remoteUser )) {
        TWiki::UI::checkAdmin( $session, $web, $topic, $wikiName );
        foreach my $userName (@userNames) {
            resetUserPassword($session, $userName, $introduction);
        }
    } else {
        my( $p, $m ) = resetUserPassword($session, $remoteUser, $introduction);
        throw TWiki::UI::OopsException( undef, $wikiName, "resetpasswd",
                                        $m, $p, $remoteUser );
    }
}

=pod

This should be in User

=cut

sub resetUserPassword {
    my ($session, $userName, $introduction) = @_;
    my ($wikiName, $loginName) =
      _getUserByEitherLoginOrWikiName( $session, $userName);

    unless ($wikiName) {
        # couldn't work out who they are, its neither loginName nor wikiName
        # They have the wrong LoginName
        throw TWiki::UI::OopsException( undef, $wikiName, "notwikiuser" );
    }

    my $email = ($session->{users}->getEmail($wikiName))[0];
    unless ($email) {
        throw TWiki::UI::OopsException( undef, $wikiName, "regemail",
                                        "Can't get an email address for $wikiName, LoginName = $loginName" );
    }

    my $message = "";
    if ($session->{users}->userPasswordExists($loginName)) {
        $session->{users}->removeUser($loginName);
    } else {
        # Assume the htpasswd file is out of sync with TWikiUsers, and generate a new one.
        # Would be nice to 
        # We could do with an integrity checker for loginname <-> twikiusers <-> home topics <-> .htpasswd
        $message = "ResetPassword created new htpasswd entry for ".$loginName." as it was missing in .htpasswd";
    }

    my $password = _randomPassword();
    my $err = $session->{users}->addUserPassword( $loginName, $password );
    if ($err) {
        $message = $err;
    }

    _sendEmail( session=>$session,
                LoginName => $loginName,
                WikiName => $wikiName,
                Email => $email,
                PasswordA => $password,
                Introduction => $introduction,
                template => "mailresetpassword"
              );

    return ( $password, $message );
}

=pod

---++ _getUserByEitherLoginOrWikiName
tries to get a mapping from either WikiName or LoginName: 
first against LoginName then WikiName
(but does not match against email address because there is no cache of these)

=cut

sub _getUserByEitherLoginOrWikiName {
    my ($session, $eitherLoginOrWikiName) = @_;
    return (undef, undef) unless $eitherLoginOrWikiName;

    my $loginName = $eitherLoginOrWikiName;
    my $wikiName = $session->{users}->userToWikiName($eitherLoginOrWikiName, 2);
    # YUCK SMELL: 1 = Don't add web name. Very unintuitive.
    unless ($wikiName) {
        # Did they use their WikiName instead of LoginName?

        # So do it using the inverse function
        my $probablyWikiName = $eitherLoginOrWikiName;
        $loginName = $session->{users}->wikiToUserName($probablyWikiName);
        if ($loginName eq $probablyWikiName) {
            # the function didn't map: returning the same means lookup failure
            return (undef, undef);
        } else {
            # They just used the wrong one, so map it back to get the login name
            $wikiName = $probablyWikiName;
        }
    }
    return ($wikiName, $loginName);
}

=pod

---+++ changePassword( $session )
Change the user's password. Details of the user and password
are passed in CGI parameters.

   1 Checks required fields have values
   2 get wikiName and userName from getUserByEitherLoginOrWikiName(username)
   3 check passwords match each other, and that the password is correct, otherwise "wrongpassword"
   4 TWiki::User::updateUserPassword
   5 "oopschangepasswd"

The NoPasswdUser case is not handled

=cut

sub changePassword {
    my $session = shift;

    my $topic = $session->{topicName};
    my $webName = $session->{webName};
    my $query = $session->{cgiQuery};

    my $username = $query->param( 'username' );
    my $passwordA = $query->param( 'password' );
    my $passwordB = $query->param( 'passwordA' );
    my $topicName = $query->param( 'TopicName' );

    # check if required fields are filled in
    if( ! $username || ! $passwordA ) {
        throw TWiki::UI::OopsException( $webName, $topic, "regrequ" );
    }

    my ($wikiName, $loginName) = _getUserByEitherLoginOrWikiName( $session, $username);
    # check if user entry exists

    unless ($wikiName) {
        throw TWiki::UI::OopsException( $webName, $topic, "notwikiuser",
                                        $loginName );
    }

    # check if passwords are identical
    if( $passwordA ne $passwordB ) {
        throw TWiki::UI::OopsException( $webName, $topic, "regpasswd" );
    }

    # c h a n g e
    my $oldpassword = $query->param( 'oldpassword' );
    
    # check if required fields are filled in
    if( ! $oldpassword ) {
        throw TWiki::UI::OopsException( $webName, $topic, "regrequ" );
    }

    my $pw = $session->{users}->checkUserPasswd( $loginName, $oldpassword );
    if( ! $pw ) {
        # NO - wrong old password
        throw TWiki::UI::OopsException( $webName, $topic, "wrongpassword");
    }

    # OK - password may be changed
    $session->{users}->updateUserPassword($loginName,  $oldpassword, $passwordA );

    # OK - password changed
    throw TWiki::UI::OopsException( $webName, $topic, "changepasswd" );
}

=pod

---++ RegisterDotPm::verifyEmailAddress
This is called: on receipt of the activation password -> RegisterCgiScript -> here
   1 calls UnregisteredUser::reloadUserContext(activation password)
   2 redirects to an oops if appropriate
   3 calls emailRegistrationConfirmations
   4 still calls "oopssendmailerr" if a problem, but this is not done uniformly 

=cut

sub verifyEmailAddress {
    my %params = @_;
    my $session = $params{session};

    my $code = $session->{cgiQuery}->param('code');
    UnregisteredUser::setDir($params{tempUserDir});
    my %data = UnregisteredUser::reloadUserContext($code );

    # TODO: refactor with BlockB 
    if (! exists $data{WikiName}) {
        my $err = UnregisteredUser::getLastError();
        if ($err =~ /oops/) {
            #SMELL - what web? We've not initialised because no wikiname
            throw TWiki::UI::OopsException("", "TWikiRegistration",
                                           $err, $code );
        } else {
            throw Error::Simple( "verifyEmailAddress:". $err );
        }
    }

    my $topic = $session->{topicName};
    my $web = $session->{webName};

    _emailRegistrationConfirmations( $session, \%data );
}

=pod

---++ finish

Presently this is called in RegisterCgiScript directly after a call to verify. The separation is intended for the RegistrationApprovals functionality
   1 calls UnregisteredUser::reloadUserContext
   2 redirects to an oops if appropriate
   3 calls newUserFromTemplate()
   4 if using the htpasswdFormatFamily, calls _addUserToPasswordSystem
   5 calls the misnamed RegistrationHandler to set cookies
   6 calls addUserToTWikiUsersTopic
   7 writes the logEntry (if wanted :/)
   8 redirects browser to "oopsregthanks"


reloads the context by code
these two are separate in here to ease the implementation of administrator approval 

=cut

sub finish {
    my %params = @_;
    my %data;
    my $dataRef;
    my $session = $params{session};

    my $topic = $session->{topicName};
    my $web = $session->{webName};

    #    unless (%data) { #### SMELL HACK
    my $code = $session->{cgiQuery}->param('code');
    UnregisteredUser::setDir($params{tempUserDir});
    %data = UnregisteredUser::reloadUserContext($code);
    UnregisteredUser::deleteUserContext($code);

    # TODO: refactor with BlockB 
    if (! exists $data{WikiName}) {
        my $err = UnregisteredUser::getLastError();
        if ($err =~ /oops/) {
            #SMELL - what web? We've not initialised because no wikiname
            throw TWiki::UI::OopsException("", "TWikiRegistration",
                                           $err, $code );
        } else {
            throw Error::Simple( "verifyEmailAddress:". $err );
        }
    }

    # create user topic if it does not exist
    #    unless( TWiki::Store::topicExists( $TWiki::mainWebname, $data{WikiName} ) ) {
    my $log = _newUserFromTemplate($session, "NewUserTemplate", \%data);

    #  }

    # SMELL - needs generalising to password delegate - what does it mean if you register when Basicauth is not used?
    if ( $TWiki::htpasswdFormatFamily eq "htpasswd" ) {
        my $success = _addUserToPasswordSystem( session=>$session, %data );
        # SMELL - error condition? surely need a way to flag an error?
        unless ( $success ) {
            throw TWiki::UI::OopsException( $data{webName}, $topic,
                                            "regerr" );
        }
    }

    # Plugin callback to set cookies.
    $session->{plugins}->registrationHandler( $data{webName},
                                              $data{WikiName},
                                              $data{remoteUser} );
    
    # add user to TWikiUsers topic
    my $userTopic =
      $session->{users}->addUserToTWikiUsersTopic( $data{WikiName}, $data{LoginName} );
    
    # write log entry
    if ($TWiki::doLogRegistration) {
        $session->writeLog( "register", "$data{webName}.$data{WikiName}",
                         $data{Email}, $data{WikiName} );
    }
    

    # and finally display thank you page
    throw TWiki::UI::OopsException( $data{webName}, $data{WikiName},
                                    "regthanks", $data{Email} );
}

=pod

--++ _newUserFromTemplate($template, $row)
Given a template and a hash, creates a new topic for a user
   1 reads the template topic
   2 calls RegistrationHandler::register with the row details, so that a plugin can augment/delete/change the entries

I use RegistrationHandler::register to prevent certain fields (like password) 
appearing in the homepage and to fetch photos into the topic

=cut

sub _newUserFromTemplate {
    my ($session, $template, $row) = @_;
    my ( $meta, $text ) = TWiki::UI::readTemplateTopic($session, $template);
    
    my $log = "$b Writing topic ".$row->{webName}.".".$row->{WikiName}."\n";
    
    $log .= "$b2 RegistrationHandler: ";
    my $regLog;
    ($row, $meta, $text, $regLog) = RegistrationHandler::register($row, $meta, $text);
    $log .= join("$b2 ", split /\n/, $regLog)."\n";
    
    $log .= "$b2 ".join("$b2 ", split /\n/, _writeRegistrationDetailsToTopic( $session, $row, $meta, $text ))."\n";
    return $log;
}

=pod

---++ _writeRegistrationDetailsToTopic($dataRef, $meta, $text)
Writes the registration details passed as a hash to either BulletFields or FormFields
on the user's topic.

Returns "BulletFields" or "FormFields" depending on what it chose.

=cut 

sub _writeRegistrationDetailsToTopic {
    my ($session, $dataRef, $meta, $text) = @_;
    my %data = %$dataRef;

    # TODO - there should be some way of overwriting meta without blatting the content.

    my $form = $meta->findOne("FORM");
    $text = "%SPLIT%\n\t* %KEY%: %VALUE%%SPLIT%\n" unless $text;
    my ( $before, $repeat, $after ) = split( /%SPLIT%/, $text );

    my $log;
    my $addText;
    if ($form) {
        ( $meta, $addText ) = _getRegFormAsTopicForm( $meta, \%data );
        $log = "Using Form Fields";
    } else {
        $addText = _getRegFormAsTopicContent( \%data );
        $log = "Using Bullet Fields";
    }
    $text = $before . $addText . $after;

    my $userName = $data{remoteUser} || $data{WikiName};
    $text =
      $session->expandVariablesOnTopicCreation( $text, $userName, $data{WikiName},
                                             "$data{webName}.$data{WikiName}" );

    $meta->put( "TOPICPARENT", ( "name" => $TWiki::wikiUsersTopicname ) );

    $session->{store}->saveTopic( $data{webName}, $data{WikiName}, $text, $meta, "",  1 );
    return $log;
}

=pod

---+++ Caveats
 Ideally we'd put any fields mentioned on the registration form
 but not in the UserForm into the text. However there is no API to 
 through which to determine what is legal. So I can't

=cut

sub _getRegFormAsTopicForm {
    my ( $meta, $dataRef ) = @_;
    my %data = %$dataRef;
    if ( !defined $data{form} ) {
        $data{debug} = 1;
        ::dumpIfDebug( \%data, "In _getRegFormAsTopicForm" );
    }
    
    return _getKeyValuePairsAsTopicForm($meta, @{$data{form}});
}

=pod

---++ _getKeyValuePairsAsTopicForm ($meta, @fieldArray)
# SMELL
# problem now is that the fields are ordered by the HTML form
# not by the order of the template form definition. Hence they are arguably in the wrong order.

=cut

sub _getKeyValuePairsAsTopicForm {
    my ($meta, @fieldArray)     = @_;   # SMELL - why is this an array? surely a hash is better?
    my $leftoverText = "";
    foreach my $fd (@fieldArray) {
        my $name  = $fd->{name};
        my $value = $fd->{value};
        my $title = $name;
        $title =~ s/([a-z0-9])([A-Z0-9])/$1 $2/go;    # Spaced
        
        #### SMELL I want to write:
        #     if (field is on form) {
        #	$meta->put("FIELD", ( "name" => $name, "value" => $value, "title" =>$title));
        #     } else {
        # accumulate it in $leftoverText
        #     }
        #### but SMELL instead we write this ugliness
        # not least because although I can see a key with a value, I can't distinguish those one without one.
        # from no key at all.
        if ( $name eq "Comment" ) {
            $leftoverText .= "\t* $name: $value\n"; #SMELL - tab not 3 spaces
        } else {
            $meta->put( "FIELD",
                        ( "name" => $name, "value" => $value, "title" => $title ) );
        }
        #### end workaround SMELL
    }
    return ( $meta, $leftoverText );
}

=pod

---++ _getRegFormAsTopicContent($row) 
Registers a user using the old bullet field code

=cut

sub _getRegFormAsTopicContent {
    my ($dataRef) = @_;
    my %data = %$dataRef;
    my $text;
    foreach my $fd ( @{ $data{form} } ) {
        my $name  = $fd->{name};
        my $title = $name;
        $title =~ s/([a-z0-9])([A-Z0-9])/$1 $2/go;    # Spaced
        my $value = $fd->{value};
        $value =~ s/[\n\r]//go;
        $text .= "\t* $title\: $value\n";    # SMELL - tabs but stored as tabs.
    }
    return $text;
}

=pod

---++ _emailRegistrationConfirmations

Sends to both the WIKIWEBMASTER and the USER notice of the registration
emails both the admin "registernotifyadmin" and the user "registernotify", 
in separate emails so they both get targeted information (and no password to the admin).

=cut

sub _emailRegistrationConfirmations {
    my ( $session, $dataHashRef ) = @_;
    my %data = %$dataHashRef;

    my $skin = $session->{cgiQuery}->param("skin") || $session->{prefs}->getPreferencesValue("SKIN");
    my $email;

    $email =
      _buildConfirmationEmail( $session,
                              \%data,
                              $session->{templates}->readTemplate( "registernotify", $skin ),
                              $TWiki::doHidePasswdInRegistration
                             );

    my $err = 
      $session->{net}->sendEmail($email);

    # SMELL: This needs to log to tell the admin.
    throw TWiki::UI::OopsException( $data{webName}, $data{WikiName},
                                    "sendmailerr", $err )
      if ( $err && ! $unitTestMode );

    # Furthermore it would be better if it returned
    # A template to give to the user.

    $email =
      _buildConfirmationEmail( $session,
                              \%data,
                              $session->{templates}->readTemplate( "registernotifyadmin", $skin ),
                              1 );

    $err = $session->{net}->sendEmail($email);
    throw TWiki::UI::OopsException( $data{webName}, $data{WikiName},
                                    "sendmailerr", $err )
      if ( $err && ! $unitTestMode );
}

=pod

---++ builds a confirmation using a named template

The template dictates the to: field

=cut

sub _buildConfirmationEmail {
    my ( $session, $dataHashRef, $templateText, $hidePassword ) = @_;
    my %data = %$dataHashRef;

    $templateText =~ s/%FIRSTLASTNAME%/$data{Name}/go;
    $templateText =~ s/%WIKINAME%/$data{WikiName}/go;
    $templateText =~ s/%EMAILADDRESS%/$data{Email}/go;

    my ( $before, $after ) = split( /%FORMDATA%/, $templateText );
    foreach my $fd ( @{ $data{form} } ) {
        my $name  = $fd->{name};
        my $value = $fd->{value};
        if ( ( $name eq "Password" ) && ($hidePassword) ) {
            $value = "*******";
        }
        if ( $name ne "Confirm" ) {
            $before .= "   * $name\: $value\n";
        }
    }
    $templateText = "$before$after";
    $templateText = $session->handleCommonTags( $templateText, $data{WikiName} );
    $templateText =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois
      ;    # remove <nop> and <noautolink> tags

    return $templateText;
}

=pod

--++ _validateRegistration
Returns a url if there is a problem.

=cut

sub _validateRegistration {
    my ( $session, $dataRef, $query, $topic ) = @_;
    my %data = %$dataRef;

    # DELETED CHECK: check for wikiName field.

    unless ( $data{form} && ( $#{ $data{form} } > 1 ) ) {
        throw TWiki::UI::OopsException( $data{webName}, $topic,
                                        "regrequ", $data{WikiName} );
    }

    if ($session->{store}->topicExists( $data{webName}, $data{WikiName} )) {
        throw TWiki::UI::OopsException( $data{webName}, $topic,
                                        "regexist", $data{WikiName} );
    }

    if ($session->{users}->userPasswordExists( $data{LoginName} ) ) {
        throw TWiki::UI::OopsException( $data{webName}, $topic,
                                        "regexist", $data{LoginName} );
    }

    # check if required fields are filled in
    foreach my $fd ( @{ $data{form} } ) {
        if ( ( $fd->{required} ) && ( !$fd->{value} ) ) {
            # TODO - add all fields that are missing their values
            throw TWiki::UI::OopsException( $data{webName}, $topic,
                                            "regrequ" );
        }
    }

    # check if WikiName is a WikiName
    if ( !TWiki::isValidWikiWord( $data{WikiName} ) ) {
        throw TWiki::UI::OopsException( $data{webName}, $topic,
                                        "regwiki" );
    }

    if (exists $data{PasswordA}) {
        # check if passwords are identical
        if ( $data{passwordA} ne $data{passwordB} ) {
            throw TWiki::UI::OopsException( $data{webName}, $topic,
                                            "regpasswd" );
        }
    }

    # check valid email address
    if ( $data{Email} !~ $TWiki::regex{emailAddrRegex} ) {
        throw TWiki::UI::OopsException( $data{webName}, $topic,
                                        "regemail" );
    }
}

sub _randomPassword {
    return $TWiki::UI::Register::password || int( rand(9999) ); # global is used by test harness to give predictable results
}

=pod

 generate user entry
 If a password exists (either in Data{PasswordA} or data{CryptPassword}, use it.
 Otherwise generate a random one, and store it back in the user record.

=cut

#SMELL - when should they get notified of the password?
sub _addUserToPasswordSystem {
    my %p = @_;
    my $session = $p{session};

    if ($session->{users}->userPasswordExists($p{LoginName})) {
        $session->{users}->removeUser($p{LoginName});
    }

    my $success;
    if ($p{CryptPassword})  {
        throw Error::Simple( "No API to install crypted password" );
        #	$success = $session->{users}->installCryptedPassword($p{LoginName},
        #						   $p{CryptPassword});
    } else {
        my $password = $p{Password};
        unless ($password) {
            $password = _randomPassword(); 
            $session->writeWarning("No password specified for ".$p{LoginName}." - using random=".$password);
        }
        $success = $session->{users}->addUserPassword( $p{LoginName}, $password );
    }
    return $success;
}

=pod

---++ _sendEmail(%p)
sends $p{template} to $p{Email} with a bunch of substitutions.

=cut

sub _sendEmail {
    my %p = @_;
    my $session = $p{session};

    throw Error::Simple("no template in _sendEmail ".Dumper(\%p)) unless $p{template};
    my $text      = $session->{templates}->readTemplate($p{template});

    $p{Introduction} = '' unless $p{Introduction}; # ugly? See Footnote [1]

    $text =~ s/%LOGINNAME%/$p{LoginName}/go;
    $text =~ s/%FIRSTLASTNAME%/$p{Name}/go;
    $text =~ s/%WIKINAME%/$p{WikiName}/go;
    $text =~ s/%EMAILADDRESS%/$p{Email}/go;
    $text =~ s/%INTRODUCTION%/$p{Introduction}/go;
    $text =~ s/%VERIFICATIONCODE%/$p{VerificationCode}/go;
    $text =~ s/%PASSWORD%/$p{PasswordA}/go;
    $text = $session->handleCommonTags( $text, $p{WikiName} );

    my $senderr = $session->{net}->sendEmail($text);
    if ($senderr) {
        $session->writeWarning("Couldn't send message:\n\n$text\n\n - $senderr");
        throw TWiki::UI::OopsException( undef, $p{WikiName},
                                        "sendmailerr", $senderr )
          unless $unitTestMode;
    }
}

##############################################################################
##############################################################################

package main;

sub dumpIfDebug {
    my ( $dataRef, $string ) = @_;
    my %data = %$dataRef;
    if ( $data{debug} ) {
        use Data::Dumper;
        my $dump = Data::Dumper::Dumper($dataRef);
        #  croak join( ",", caller ) . ":\n" . $string . "\n" . $dump;
    }
}

=pod

sub stackTrace - needs CPAN module not installed by default

=cut

sub stackTrace {
    require Devel::StackTrace;
    my $trace = Devel::StackTrace->new;
    my $place = $trace->as_string;     # like carp
    # from top (most recent) of stack to bottom.
    while ( my $frame = $trace->next_frame ) {
        $place .= "Has args\n" if $frame->hasargs;
    }
}

##############################################################################
##############################################################################
package UnregisteredUser;

use Storable;    # SMELL - put into a topic readable by admins,  and not binary!
use Data::Dumper;
my $tmpDir; # Storage for unregistered user records
my $error; # 

#SMELL - writes directly to filespace, should go via attachments.

=pod

---++ getLastError
Get the last error that occured after reloadUserContext

=cut

sub getLastError {
  return $error;
}

=pod

---++ putRegDetailsByCode 
| In | reference to the users data structure |
| Out | none |

dies if fails to store

=cut

sub putRegDetailsByCode {
    my ($dataRef) = @_;

    #    ::dumpIfDebug($dataRef, "putRegDetailsByCode");

    my %data = %$dataRef;

    # write tmpuser file
    my $file = _verificationCodeFilename($data{VerificationCode} );

    #    ::dumpIfDebug($dataRef, "putRegDetailsByCode: ".$file);
    store( $dataRef, $file ) or throw Error::Simple( $! );
}

=pod 

---++ _verificationCodeFilename 

=cut

sub _verificationCodeFilename {
    my ($code) = @_;
    return $tmpDir . "/$code";
}

=pod

---++ _getRegDetailsByCode 
| In | activation code |
| Out | reference to user the user's data structure
Dies if fails to get

=cut

sub _getRegDetailsByCode {
    my ($code) = @_;
    my $file   = _verificationCodeFilename($code);
    my $ref    = retrieve $file;                    # SMELL throws?
    return $ref;
}

sub setDir {
    my ($dir) = @_;
    $tmpDir = $dir;
    unless (-d $tmpDir) {
        mkdir ($tmpDir) || warn "Cannot make the directory $dir";
    }
}

=pod

Redirects user and dies if cannot load.
Dies if loads and does not match.
Returns the users data hash if succeeded.
Returns () if not found.

=cut

sub reloadUserContext {
    my ($code) = @_;


    unless (-f _verificationCodeFilename($code)){
        $error = "oopsregcode"; 
        return ();
    }

    my %data = %{ _getRegDetailsByCode($code) };
    $error = _validateUserContext($code);

    return () if $error;

    #   $data{debug} = 1;
    #    ::dumpIfDebug(\%data, "reload check");

    return %data;
}

=pod

Returns undef if no problem, else returns what's wrong

=cut

sub _validateUserContext {
    my ($code) = @_;
    my ($name) = $code =~ /^([^.]+)\./;
    my %data   = %{ _getRegDetailsByCode($code) };    #SMELL - expensive?
    return "Invalid activation code" unless $code eq $data{VerificationCode};
    return "Name in activation code does not match"
      unless $name eq $data{WikiName};
    return;
}

#SMELL: "Context"?
sub deleteUserContext {
    my ($code) = @_;
    my ($name) = $code =~ /^([^.]+)\./;
    foreach (<$tmpDir/$name.*>) {
        unlink TWiki::Sandbox::untaintUnchecked($_);
    }
    # ^^ In case a user registered twice, etc...
}


##############################################################################
##############################################################################

=pod

# TWiki::Data::IntopicTable

TWiki deals a lot with in-topic tables. This class would represent them.
It could be subclassed into tables that are inheritently ordered, etc.

=cut

package IntopicTable;

sub populateEntries {
    my $query = shift;
    # get all parameters from the form
    my @paramNames    = @_;
    my %formData      = ();
    my $name          = undef;    #SMELL - not needed?
    my $value         = undef;
    my @orderedFields = ();
    my %data;
    foreach (@paramNames) {
        if (/^(Twk)([0-9])(.*)/) {
            $value = $query->param("$1$2$3");
            $formData{required} = $2;
            $name               = $3;
            $formData{name}  = $name;
            $formData{value} = $value;
            if ( $name eq "Password" ) {
                #TODO: get rid of this; move to removals and generalise.
                $data{passwordA} = $value;
            } elsif ( $name eq "Confirm" ) {
                $data{passwordB} = $value;
            }
            #  $name eq "Password"
            #  $name eq "Confirm"

            push @orderedFields, {%formData}
              unless (($name eq "WikiName") or 
                      ($name eq "Confirm")
                     );    # (1) omitted because they can't change it, and (2) is a duplicate
            $data{$name} = $value;
        }
    }
    $data{form} = \@orderedFields;
    return %data;
}

package RegistrationHandler;

use Data::Dumper;
#sub deleteKey {}; 

# SMELL: absolute pathname to a home directory!!!!
my $photoBase = "/home/mrjc/conceptmapping.net";

sub deleteKey {
    my ($row, $key) = @_;		  
    #-- We delete only the field in the {form} array - this makes the original value still there should 
    #-- we want it
    #-- i.e. it must still be available via $row->{$key} even though $row-{form}[] does not contain it
    #warn "BEFORE:". Dumper(\@_);
    my @formArray = @{$row->{form}};

    foreach my $index (0..$#formArray) {
        my $a = $formArray[$index];
        my $name = $a->{name};
        my $value = $a->{value};
        if ($name eq $key) {
            #       warn  "Found $key! $value at $index";
            splice (@{$row->{form}}, $index, 1);
            last;
        }

        # delete would this leave an undef entry in the form array, which translates as a ":" when output as bullet fields.
    }		  
    #warn "AFTER:". Dumper($row);
    return $row;  
};

sub register {
    my ($session, $row, $meta, $text) = @_;
    my $log = "";
    throw Error::Simple( "No row! " .Dumper($row)) unless $row;

    if ($row->{Photo}) {
        $row->{Photo} = $photoBase."/".$row->{Photo};
        if (-d $row->{Photo}) {
            $meta = addPhotoToTopic(session=>$session,
                                    web => $row->{webName}, 
                                    topic => $row->{WikiName}, 
                                    meta => $meta, 
                                    photoDir => $row->{Photo},
                                    user => $row->{WikiName}, #SMELL - correct?
                                   );
            $log .= "%Y% Added photoDir ".$row->{Photo};
        } else {
            $log .= "%X% No such dir ".$row->{Photo};
        }
    } else {
        $log .= "No photo";
    }
    
    $row = deleteKey($row, "Photo");
    $row = deleteKey($row, "WikiName");
    $row = deleteKey($row, "LoginName");
    $row = deleteKey($row, "Password");

    return ($row, $meta, $text, $log);
}

sub addPhotoToTopic {
    my %p = @_;
    my $session = $p{session};
    my $dirName = $p{photoDir};
    my $meta = $p{meta};

    opendir(D,$dirName);
    my @fileNames = sort(
                         grep(
                              /.jpg/,
                              !/^\.\.?$/,
                              readdir(D)  # need to check that is a file.
                             )
                        );
    closedir(D);

    foreach my $fileName (@fileNames) {
        my $error =
          $session->{store}->saveAttachment( $p{web}, $p{topic}, "", "",
                                        $fileName, 0, 1,
                                        1, "", $dirName."/".$fileName );

        throw Error::Simple( $error ) if $error;

        my @stats = stat $fileName;

        my %attrs = (
                     "name"    => $fileName,
                     "version" => "", # WHERE DOES $fileVersion COME FROM?
                     "path"    => $p{photo},
                     "size"    => $stats[7],
                     "date"    => $stats[9],
                     "user"    => "$p{user}",
                     "comment" => "",
                     "attr"    => "",
                    );

        $meta->put( "FILEATTACHMENT", %attrs );
    }
    #     $session->{store}->saveTopic($p{web}, $p{user}, $text, $meta, "",  1 );
    return $meta;
}

# Footnote [1]
# #perl 30/11/2004
#(00:00:57) MRJC: If $p{Introduction} might not be set, how to minimally change  
#   $text =~ s/%INTRODUCTION%/$p{Introduction}/go; to not produce a warning?  
#(00:02:58) merlyn: Why not use a real templating system?
#(00:03:04) merlyn: stop inventing your own
#(00:03:10) MRJC: ok, how to simply mass set a bunch of keys?
#(00:03:12) merlyn: eventually, you'll end up wanting IF and WHILE
#(00:03:14) pjcj: $text =~ s|%INTRODUCTION%|$p{Introduction}//""|geo in bleadperl, or use TemplateToolkit

1;
