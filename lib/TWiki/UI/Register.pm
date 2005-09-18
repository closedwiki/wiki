# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Copyright (c) 1999-2004 Peter Thoeny, peter@thoeny.com
#           (c) 2001 Kevin Atkinson, kevin twiki at atkinson dhs org
#           (c) 2003 SvenDowideit
#           (c) 2003 Graeme Pyle graeme@raspberry dot co dot za
#           (c) 2004 Martin Cleaver, Martin.Cleaver@BCS.org.uk
#           (c) 2004 Gilles-Eric Descamps twiki at descamps.org
#           (c) 2004 Crawford Currie c-dot.co.uk
#
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package TWiki::UI::Register

User registration handling.

=cut

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
use TWiki::OopsException;
use Assert;

my $twikiRegistrationAgent = 'TWikiRegistrationAgent';

=pod

---++ StaticMethod register_cgi( $session )
=register= command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.

=cut

sub register_cgi {
    my $session = shift;

    my $tempUserDir = $TWiki::cfg{RegistrationApprovals};
    # SMELL hacked name, and stores in binary format!
    my $needVerification = $TWiki::cfg{Register}{NeedVerification};    
	# NB. No test harness for needVerification = 0.
    my $needApproval = 0;

    # Register -> Verify -> Approve -> Finish

    # NB. bulkRegister invoked from ManageCgiScript.

    my $action = $session->{cgiQuery}->param('action') || '';

    if ($action eq 'register') {
      registerAndNext($session, $tempUserDir);
    }
    elsif ($action eq 'verify') {
        verifyEmailAddress( $session, $tempUserDir );
        if ($needApproval) {
            throw Error::Simple('Approval code has not been written!');
        }
        finish( $session, $tempUserDir);
    }
    elsif ($action eq 'resetPassword') {
        #SMELL - is this still called here, or only by passwd? 
        resetPassword( $session );
    }
    elsif ($action eq 'approve') {
        finish($session, $tempUserDir );
    }
    else {
      registerAndNext($session, $tempUserDir);
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

---++ StaticMethod passwd_cgi( $session )
=passwd= command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.

=cut

sub passwd_cgi {
    my $session = shift;

    my $action = $session->{cgiQuery}->param('action');

    if( $action eq 'changePassword' ) {
        changePassword( $session );
    }
    elsif ( $action eq 'resetPassword' ) {
        resetPassword( $session );
    }
    else {
        throw TWiki::OopsException( 'attention',
                                    web => $session->{webName},
                                    topic => $session->{topicName},
                                    def => 'missing_action' );
    }
}

# TODO: S&R {form} with {ordered}
# TODO: S&R row, data => user
# TODO: Replace LoginName with UserName (NB. templates/topics)
# TODO: During normal registration, a Plugin callback to set cookies,
#       TWiki::Plugins::registrationHandler( $data{webName}, $data{WikiName},
#       $data{remoteUser} );
#       Is called. But this has little to do with registration - it is an authentication rememberer.
#       In fact, isn't my bulkregistration handler just a reg handler?
# TODO: registernotifybulk.tmpl 
# TODO: make it copy the fields it wants before handing off to the RegsitrationPlugin - that way it won't matter if
#       that deletes such keys.
# ISSUE: TWiki::User::addUserToTWikiUsersTopic does not replace the line if you now supply a login name when one 
#       was not needed before.
# TODO: write a plugin that intercepts the change of metadata on a topic and invokes functionality as described on 
#       RegistrationAsPlugin.

# SMELL legacy format - bulletpoint. I'd hardcode it except there is a proposal to change it.
my $b = "\t*";
my $b2 ="\t\t*";
my $indent = "\t"; # SMELL indent legacy

=pod

---++ StaticMethod bulkRegister($session)

  Called by ManageCgiScript::bulkRegister (requires authentication) with topic = the page with the entries on it.
   1 Makes sure you are an admin user ;)
   2 Calls TWiki::Data::DelimitedFile (delimiter => '|', content =>textReadFromTopic)
   3 ensures requiredFieldsPresent()
   4 starts a log file
   5 calls registerSingleBulkUser() for each row 
   6 writes output to log file, sets [[TWiki.TOPICPARENT]] back to page with entries on it.
   7 redirects to log file

=cut

sub bulkRegister {
    my $session = shift;

    my $user = $session->{user};
    my $topic = $session->{topicName};
    my $web = $session->{webName};
    my $userweb = $TWiki::cfg{UsersWebName};
    my $query = $session->{cgiQuery};

    my $settings = {};
    $settings->{doOverwriteTopics} =
      $query->param('OverwriteHomeTopics') || 0;
    $settings->{doEmailUserDetails} =
      $query->param('EmailUsersWithDetails') || 0;

    unless( $session->{user}->isAdmin() ) {
        throw TWiki::OopsException( 'accessdenied', def => 'only_group',
                                    web => $web, topic => $topic,
                                    params => $TWiki::cfg{UsersWebName}.'.'.
                                      $TWiki::cfg{SuperAdminGroup} );
    }

    #-- Read the topic containing a table of people to be registered

    my ($meta, $text) = $session->{store}->readTopic( undef,
                                                      $web, $topic, undef );
    my %data;
    ( $settings->{fieldNames}, %data ) =
      TWiki::Data::DelimitedFile::read(content => $text, delimiter => '|' );

    my $registrationsMade = 0;
    my $log = '---+ Report for Bulk Register'."\n\n%TOC%\n";

    #-- Process each row, generate a log as we go
    foreach my $row ( values %data ) {
        $row->{webName} = $userweb;

        my ($userTopic, $uLog) =
          _registerSingleBulkUser($session, $row, $settings );
        $log .= "\n---++ ". $row->{WikiName}."\n";
        $log .= $b.' Added to users topic '.$userTopic.":\n".
          join("\n".$indent,split /\r?\n/, $uLog)."\n";	
        $registrationsMade++; # SMELL - no detection for failure
    }

    $log .= "----\n";
    $log .= 'registrationsMade: '.$registrationsMade;

    my $logWeb;
    my $logTopic =  $query->param('LogTopic') || $topic.'Result';
    ( $logWeb, $logTopic ) = $session->normalizeWebTopicName( '', $logTopic );

    #-- Save the LogFile as designated, link back to the source topic 

    $meta->put( 'TOPICPARENT', { name => $web.'.'.$topic } );

    my $err = $session->{store}->saveTopic($user, $logWeb, $logTopic, $log, $meta );

    $session->redirect($session->getScriptUrl($web, $logTopic, 'view'));
}

#    Process a single user, parameters passed as a hash
#
#    * receives row and a fieldNamesOrderedList
#    * sets LoginName to be WikiName if not present
#    * rearranges the row to comply with the ordered list
#    * if using htpasswd, calls _addUserToPasswordSystem()
#    * makes newUserFromTemplate
#    * calls addUserToTWikiUsersTopic()
# SMELL could be made much more efficient if needed, as calls to addUserToTWikiUsersTopic()
# are quite expensive when doing 300 in succession!
sub _registerSingleBulkUser {
    my ($session, $row, $settings) = @_;
    ASSERT( $row ) if DEBUG;
    ASSERT( $settings->{fieldNames} ) if DEBUG;
    my $fieldNames = $settings->{fieldNames};
    my $doOverwriteTopics = defined $settings->{doOverwriteTopics} ||
      throw Error::Simple( 'No doOverwriteTopics' );
    my $log;
    #-- call to the registrationHandler (to amend fields) should
    # really happen in here.

    #-- TWiki:Codev.LoginNamesShouldNotBeWikiNames - but use it if not supplied
    unless( $row->{LoginName} ) {
        $row->{LoginName} = $row->{WikiName};
        $log = $b.' No TWiki.LoginName specified - setting to '.
          $row->{LoginName}."\n";
    }

    #-- Ensure every required field exists
    # NB. LoginName is OPTIONAL
    my @requiredFields = qw(WikiName FirstName LastName);
    if (_missingElements( $fieldNames, \@requiredFields )) {
        throw Error::Simple( join(' ', @{$settings->{fieldNames}}).
                             ' does not contain the full set of '.
                             join(' ', @requiredFields) );
    }

    #-- Generation of the page is done from the {form} subhash, so align the two
    $row->{form} = [
                    _makeFormFieldOrderMatch( $fieldNames, $row)
                   ];

    my $passResult = _addUserToPasswordSystem( $session, $row );
    $log .= $b.' Password set: '.$passResult.' (1 = success)'."\n";
    #TODO: need a path for if it doesn't succeed.

    $session->writeLog('bulkregister', $row->{webName}.'.'.$row->{WikiName},
                       $row->{Email}, $row->{WikiName} );

    if( $doOverwriteTopics or !$session->{store}->topicExists( $row->{webName}, $row->{WikiName} ) ) {
        $log .= _newUserFromTemplate($session, 'NewUserTemplate', $row);
    } else {
        $log .= $b.' Not writing topic '.$row->{WikiName}."\n";
	}

    my $user = $session->{users}->findUser( $row->{LoginName},
                                            $row->{WikiName} );

    my $userTopic =
      $session->{users}->addUserToTWikiUsersTopic( $user,
                                                   $session->{user} );

    #if ($TWiki::cfg{EmailUserDetails}) {
        # If you want it, write it.
        # _sendEmail($session, 'registernotifybulk', $data );
    #    $log .= $b.' Password email disabled\n';
    #}
    return ($userTopic, $log);
}

#ensures all named fields exist in hash
#returns array containing any that are missing
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

# rearranges the fields in $data so that they match settings
# returns a new ordered form
sub _makeFormFieldOrderMatch {
    my( $fieldNames, $data ) =@_;
    my @form = ();
    foreach my $field ( @$fieldNames ) {
        push @form, {name => $field, value => $data->{$field}};
    }
    return @form;
}

=pod

---++ StaticMethod registerAndNext($session, $tempUserDir) 

This is called when action = register or action = ""

It calls register and either Verify or Finish.

Hopefully we will get workflow integrated and rewrite this to be table driven

=cut

sub registerAndNext {
  my ($session, $tempUserDir) = @_;
  register( $session );
  if ($TWiki::cfg{Register}{NeedVerification}) {
     _requireVerification($session, $tempUserDir);
  } else {
     finish($session);
  }
}

=pod
---++ StaticMethod register($session)

This is called through: TWikiRegistration -> RegisterCgiScript -> here

   1 gets rows and fields from the query
   2 calls _validateRegistration() to ensure required fields correct, else OopsException 

=cut

sub register {
    my( $session ) = @_;

    my $query = $session->{cgiQuery};
    my $topic = $session->{topicName};
    my $web = $session->{webName};

    my $data = _getDataFromQuery( $query, $query->param() );

    $data->{webName} = $web;
    $data->{debug} = 1;
    $data->{WikiName} = TWiki::Sandbox::untaintUnchecked($data->{WikiName});

    _validateRegistration( $session, $data, $query, $topic );
}

#   1 generates a activation password
#   2 calls _putRegDetailsByCode(activation password)
#   3 sends them a 'registerconfirm' email.
#   4 redirects browser to 'regconfirm'
sub _requireVerification {
    my ($session, $tmpDir) = @_;

    my $query = $session->{cgiQuery};
    my $topic = $session->{topicName};
    my $web = $session->{webName};

    my $data = _getDataFromQuery( $query, $query->param() );
    $data->{webName} = $web;

    $data->{VerificationCode} =
      $data->{WikiName}.'.'.TWiki::User::randomPassword();
    _putRegDetailsByCode( $data, $tmpDir );

    $session->writeLog( 'regstart', $data->{webName}.'.'.$data->{WikiName},
                        $data->{Email}, $data->{WikiName} );

    my $err = _sendEmail( $session, 'registerconfirm', $data );

    if ( $err ) {
        throw TWiki::OopsException( 'attention',
                                    def => 'send_mail_error',
                                    web => $data->{webName},
                                    topic => $topic,
                                    params => $data->{Email}.' - '.$err);
    }
    throw TWiki::OopsException( 'attention',
                                def => 'confirm',
                                web => $data->{webName},
                                topic => $topic,
                                params => $data->{Email} );
}

=pod

---++ StaticMethod resetPassword($session)

Generates a password. Mails it to them and asks them to change it. Entry
point intended to be called from TWiki::UI::run

=cut

sub resetPassword {
    my $session = shift;
    my $query = $session->{cgiQuery};
    my $topic = $session->{topicName};
    my $web = $session->{webName};
    my $user = $session->{user};

    my @userNames = $query->param( 'LoginName' ) ;
    unless( @userNames ) {
        throw TWiki::OopsException( 'attention',
                                    def => 'no_users_to_reset' );
    }
    my $introduction = $query->param( 'Introduction' ) || '';
    # need admin priv if resetting bulk, or resetting another user
    my $isBulk = ( scalar( @userNames ) > 1 );

    if ( $isBulk ) {
        # Only admin is able to reset more than one password or
        # another user's password.
        unless( $session->{user}->isAdmin()) {
            throw TWiki::OopsException
              ( 'accessdenied', def => 'only_group',
                web => $web, topic => $topic,
                params => $TWiki::cfg{UsersWebName}.'.'.
                $TWiki::cfg{SuperAdminGroup} );
        }
    } else {
        # Anyone can reset a single password - important because by definition
        # the user cannot authenticate
        # Note that the passwd script must NOT authenticate!
    }

    # Collect all messages into one string
    my $message = '';
    my $good = 1;
    foreach my $userName (@userNames) {
        $good = $good &&
          _resetUsersPassword( $session, $userName, $introduction, \$message );
    }

    my $action = '';
    # Redirect to a page that tells what happened
    if( $good ) {
        unless( $isBulk ) {
            # one user; refine the change password link to include their
            # username (can't use logged in user - by definition this won't
            # be them!)
            $action = '?username='. $userNames[0];
        }
        throw TWiki::OopsException( 'attention',
                                    topic => $TWiki::cfg{UsersTopicName},
                                    def => 'reset_ok',
                                    params => $message );
    } else {
        throw TWiki::OopsException( 'attention',
                                    topic => $TWiki::cfg{UsersTopicName},
                                    def => 'reset_bad',
                                    params => $message );
    }
}

# return status
sub _resetUsersPassword {
    my( $session, $userName, $introduction, $pMess ) = @_;

    my $user = $session->{users}->findUser( $userName, undef);
    unless( $user ) {
        # couldn't work out who they are, its neither loginName nor
        # wikiName.
        $$pMess .= $session->inlineAlert( 'alerts', 'notwikiuser', $userName );
        return 0;
    }
    my @em = $user->emails();
    my $email = $em[0];
    unless ($email) {
        $$pMess .= $session->inlineAlert( 'alerts', 'no_email_for',
                                          $user->stringify());
        return 0;
    }

    my $message = '';
    unless( $user->passwordExists() ) {
        # Not an error.
        $$pMess .= $session->inlineAlert( 'alerts', 'missing_user',
                                          $user->stringify());
    }

    my $password = $user->resetPassword();

    my $err = _sendEmail( $session,
                          'mailresetpassword',
                          {
                           webName => $TWiki::cfg{UsersWebName},
                           LoginName => $user->login(),
                           Name => TWiki::spaceOutWikiWord($user->wikiName()),
                           WikiName => $user->wikiName(),
                           Email => $email,
                           PasswordA => $password,
                           Introduction => $introduction,
                          } );

    if( $err ) {
        $$pMess .= $session->inlineAlert( 'alerts', 'generic', $err );
        return 0;
    }
    $$pMess .= $session->inlineAlert( 'alerts',
                                      'new_sys_pass',
                                      $user->login(),
                                      $user->wikiName(),
                                      $email );

    return 1;
}

=pod

---++ StaticMethod changePassword( $session )

Change the user's password. Details of the user and password
are passed in CGI parameters.

   1 Checks required fields have values
   2 get wikiName and userName from getUserByEitherLoginOrWikiName(username)
   3 check passwords match each other, and that the password is correct, otherwise 'wrongpassword'
   4 TWiki::User::updateUserPassword
   5 'oopschangepasswd'

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
        throw TWiki::OopsException( 'attention',
                                    web => $webName,
                                    topic => $topic,
                                    def => 'missing_fields' );
    }

    my $user = $session->{users}->findUser( $username );

    unless ($user) {
        throw TWiki::OopsException( 'attention',
                                    web => $webName,
                                    topic => $topic,
                                    def => 'notwikiuser',
                                    $username );
    }

    # check if passwords are identical
    if( $passwordA ne $passwordB ) {
        throw TWiki::OopsException( 'attention',
                                    web => $webName,
                                    topic => $topic,
                                    def => 'password_mismatch' );
    }

    # c h a n g e
    my $oldpassword = $query->param( 'oldpassword' );

    # check if required fields are filled in
    if( ! $oldpassword ) {
        throw TWiki::OopsException( 'attention',
                                    web => $webName,
                                    topic => $topic,
                                    def => 'missing_fields' );
    }

    unless( $user->checkPassword( $oldpassword )) {
        throw TWiki::OopsException( 'attention',
                                    web => $webName,
                                    topic => $topic,
                                    def => 'wrong_password');
    }

    # OK - password may be changed
    if ($user->changePassword( $oldpassword, $passwordA )) {

      $session->writeLog('changepasswd', $user->stringify());
      #recording the email would be nice

      # OK - password changed
      throw TWiki::OopsException( 'attention',
				  web => $webName, topic => $topic,
				  def => 'password_changed' );
    } else {
      $session->writeLog('changepasswd', $user->stringify(), 'FAILED');
      die 'Problem resetting password';
    }
}

=pod

---++ StaticMethod verifyEmailAddress($session, $tempUserDir)

This is called: on receipt of the activation password -> RegisterCgiScript -> here
   1 calls _reloadUserContext(activation password)
   2 throws oops if appropriate
   3 calls emailRegistrationConfirmations
   4 still calls 'oopssendmailerr' if a problem, but this is not done uniformly

=cut

sub verifyEmailAddress {
    my( $session, $tempUserDir ) = @_;

    my $code = $session->{cgiQuery}->param('code');
    unless( $code ) {
        throw Error::Simple( 'verifyEmailAddress: no verification code!');
    }
    my $data = _reloadUserContext( $code, $tempUserDir );

    if (! exists $data->{WikiName}) {
        throw Error::Simple( 'verifyEmailAddress: no email address!');
    }

    my $topic = $session->{topicName};
    my $web = $session->{webName};

    #    $this->{session}->writeLog('verifyuser', $loginName, $userName);

    _emailRegistrationConfirmations( $session, $data );
}

=pod

---++ StaticMethod finish

Presently this is called in RegisterCgiScript directly after a call to verify. The separation is intended for the RegistrationApprovals functionality
   1 calls _reloadUserContext (throws oops if appropriate)
   3 calls newUserFromTemplate()
   4 if using the htpasswdFormatFamily, calls _addUserToPasswordSystem
   5 calls the misnamed RegistrationHandler to set cookies
   6 calls addUserToTWikiUsersTopic
   7 writes the logEntry (if wanted :/)
   8 redirects browser to 'oopsregthanks'

reloads the context by code
these two are separate in here to ease the implementation of administrator approval 

=cut

sub finish {
    my( $session, $tempUserDir) = @_;

    my $topic = $session->{topicName};
    my $web = $session->{webName};
    my $query = $session->{cgiQuery};
	my $code = $query->param('code');

	my $data;
	if ($TWiki::cfg{Register}{NeedVerification}) {
		$data = _reloadUserContext( $code, $tempUserDir );
		_deleteUserContext( $code, $tempUserDir );
	} else {
	    $data = _getDataFromQuery( $query, $query->param() );
	    $data->{webName} = $web;
	}

    if (! exists $data->{WikiName}) {
        throw Error::Simple( 'No verifyEmailAddress - no WikiName after reload');
    }

    my $log = _newUserFromTemplate($session, 'NewUserTemplate', $data);

    my $success = _addUserToPasswordSystem( $session, $data );
    # SMELL - error condition? surely need a way to flag an error?
    unless ( $success ) {
        throw TWiki::OopsException( 'attention',
                                    web => $data->{webName},
                                    topic => $topic,
                                    def => 'problem_adding',
                                    params => $data->{WikiName} );
    }

    # Plugin callback to set cookies.
    $session->{plugins}->registrationHandler( $data->{WebName},
                                              $data->{WikiName},
                                              $data->{LoginName} );

    # let the client session know that we're logged in. (This probably
    # eliminates the need for the registrationHandler call above,
    # but we'll leave them both in here for now.)
    $session->{client}->userLoggedIn( $data->{LoginName}, $data->{WikiName} );
    
    # add user to TWikiUsers topic
    my $user = $session->{users}->findUser( $data->{LoginName},
                                            $data->{WikiName} );

    my $agent = $session->{users}->findUser( $twikiRegistrationAgent,
                                             $twikiRegistrationAgent);

    my $userTopic = 
      $session->{users}->addUserToTWikiUsersTopic( $user,
                                                   $agent);

    # write log entry
    if ($TWiki::cfg{Log}{register}) {
        $session->writeLog( 'register', $data->{webName}.'.'.$data->{WikiName},
                            $data->{Email}, $data->{WikiName} );
    }
    

    # and finally display thank you page
    throw TWiki::OopsException( 'attention',
                                web => $data->{webName},
                                topic => $data->{WikiName},
                                def => 'thanks',
                                params => $data->{Email} );
}

#Given a template and a hash, creates a new topic for a user
#   1 reads the template topic
#   2 calls RegistrationHandler::register with the row details, so that a plugin can augment/delete/change the entries
#
#I use RegistrationHandler::register to prevent certain fields (like password) 
#appearing in the homepage and to fetch photos into the topic
sub _newUserFromTemplate {
    my ($session, $template, $row) = @_;
    my ( $meta, $text ) = TWiki::UI::readTemplateTopic($session, $template);
    my $log = $b.' Writing topic '.$row->{webName}.'.'.$row->{WikiName}."\n".
      $b2.' RegistrationHandler: ';
    my $regLog = $text;
    _purgeKeys( $row );
    $log .= join($b2.' ', split /\r?\n/, $regLog)."\n";
    $log .= $b2.' '.
      join( $b2.' ',
            split( /\r?\n/,
                   _writeRegistrationDetailsToTopic( $session, $row,
                                                     $meta, $text )))."\n";
    return $log;
}

#Writes the registration details passed as a hash to either BulletFields or FormFields
#on the user's topic.
#
#Returns 'BulletFields' or 'FormFields' depending on what it chose.
sub _writeRegistrationDetailsToTopic {
    my ($session, $data, $meta, $text) = @_;

    ASSERT($data->{WikiName}) if DEBUG;

    # TODO - there should be some way of overwriting meta without
    # blatting the content.

    $text ||= "%SPLIT%\n\t* %KEY%: %VALUE%%SPLIT%\n\t* Set ALLOWTOPICCHANGE = %WIKIUSERNAME%\n";
    my ( $before, $repeat, $after ) = split( /%SPLIT%/, $text );

    my $log;
    my $addText;
    if ($meta->get('FORM')) {
        ( $meta, $addText ) = _getRegFormAsTopicForm( $meta, $data );
        $log = 'Using Form Fields';
    } else {
        $addText = _getRegFormAsTopicContent( $data );
        $log = 'Using Bullet Fields';
    }
    $text = $before . $addText . $after;

    my $userName = $data->{remoteUser} || $data->{WikiName};
    my $user = $session->{users}->findUser( $userName );
    $text = $session->expandVariablesOnTopicCreation( $text, $user );

    $meta->put( 'TOPICPARENT', { 'name' => $TWiki::cfg{UsersTopicName}} );

    $session->{store}->saveTopic($user, $data->{webName},
                                 $data->{WikiName}, $text, $meta );
    return $log;
}

# Caveats
# Ideally we'd put any fields mentioned on the registration form
# but not in the UserForm into the text. However there is no API to 
# through which to determine what is legal. So I can't

sub _getRegFormAsTopicForm {
    my ( $meta, $data ) = @_;
    return _getKeyValuePairsAsTopicForm($meta, @{$data->{form}});
}

# SMELL
# problem now is that the fields are ordered by the HTML form
# not by the order of the template form definition. Hence they are arguably in the wrong order.
sub _getKeyValuePairsAsTopicForm {
    my ($meta, @fieldArray)     = @_;   # SMELL - why is this an array? surely a hash is better?
    my $leftoverText = '';
    foreach my $fd (@fieldArray) {
        my $name  = $fd->{name};
        my $value = $fd->{value};
        my $title = $name;
        $title =~ s/([a-z0-9])([A-Z0-9])/$1 $2/go;    # Spaced

        #### SMELL I want to write:
        #     if (field is on form) {
        #	$meta->putKeyed('FIELD',
        # { 'name' => $name, 'value' => $value, 'title' =>$title});
        #     } else {
        # accumulate it in $leftoverText
        #     }
        #### but SMELL instead we write this ugliness
        # not least because although I can see a key with a value, I can't distinguish those one without one.
        # from no key at all.
        if ( $name eq 'Comment' ) {
            $leftoverText .= "\t* $name: $value\n"; #SMELL - tab not 3 spaces
        } else {
            $meta->putKeyed( 'FIELD',
                        { name => $name, value => $value, title => $title } );
        }
        #### end workaround SMELL
    }
    return ( $meta, $leftoverText );
}

#Registers a user using the old bullet field code
sub _getRegFormAsTopicContent {
    my $data = shift;
    my $text;
    foreach my $fd ( @{ $data->{form} } ) {
        my $name  = $fd->{name};
        my $title = $name;
        $title =~ s/([a-z0-9])([A-Z0-9])/$1 $2/go;    # Spaced
        my $value = $fd->{value};
        $value =~ s/[\n\r]//go;
        $text .= "\t* $title\: $value\n";    # SMELL - tabs but stored as tabs.
    }
    return $text;
}

#Sends to both the WIKIWEBMASTER and the USER notice of the registration
#emails both the admin 'registernotifyadmin' and the user 'registernotify', 
#in separate emails so they both get targeted information (and no password to the admin).
sub _emailRegistrationConfirmations {
    my ( $session, $data ) = @_;

    my $skin = $session->getSkin();
    my $template =
      $session->{templates}->readTemplate( 'registernotify', $skin );
    my $email =
      _buildConfirmationEmail( $session,
                               $data,
                               $template,
                               $TWiki::cfg{Register}{HidePasswd}
                             );

    my $err = 
      $session->{net}->sendEmail( $email);

    # SMELL: This needs to log to tell the admin.
    if ( $err ) {
        throw TWiki::OopsException( 'attention',
                                    web => $data->{webName},
                                    topic => $data->{WikiName},
                                    def => 'send_mail_error',
                                    params => $err );
    }

    # Furthermore it would be better if it returned
    # A template to give to the user.
    $template =
      $session->{templates}->readTemplate( 'registernotifyadmin', $skin );
    $email =
      _buildConfirmationEmail( $session,
                               $data,
                               $template,
                               1 );

    $err = $session->{net}->sendEmail( $email );
    if ( $err ) {
        throw TWiki::OopsException( 'attention',
                                    def => 'send_mail_error',
                                    web => $data->{webName},
                                    topic => $data->{WikiName},
                                    params => $err );
    }
}

#The template dictates the to: field
sub _buildConfirmationEmail {
    my ( $session, $data, $templateText, $hidePassword ) = @_;

    $data->{Name} ||= $data->{WikiName};
    $templateText =~ s/%FIRSTLASTNAME%/$data->{Name}/go;
    $templateText =~ s/%WIKINAME%/$data->{WikiName}/go;
    $templateText =~ s/%EMAILADDRESS%/$data->{Email}/go;

    my ( $before, $after ) = split( /%FORMDATA%/, $templateText );
    foreach my $fd ( @{ $data->{form} } ) {
        my $name  = $fd->{name};
        my $value = $fd->{value};
        if ( ( $name eq 'Password' ) && ($hidePassword) ) {
            $value = '*******';
        }
        if ( $name ne 'Confirm' ) {
            $before .= $b.' '.$name.': '.$value."\n";
        }
    }
    $templateText = $before.$after;
    $templateText = $session->handleCommonTags
      ( $templateText, $data->{webName}, $data->{WikiName} );
    $templateText =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;
    # remove <nop> and <noautolink> tags

    return $templateText;
}

# Returns a url if there is a problem.
sub _validateRegistration {
    my ( $session, $data, $query, $topic ) = @_;

    # DELETED CHECK: check for wikiName field.

    unless ( $data->{form} && ( $#{ $data->{form} } > 1 ) ) {
        throw TWiki::OopsException( 'attention',
                                    web => $data->{webName},
                                    topic => $topic,
                                    def => 'missing_fields' );
    }

    if($session->{store}->topicExists( $data->{webName}, $data->{WikiName} )) {
        throw TWiki::OopsException( 'attention',
                                    web => $data->{webName},
                                    topic => $topic,
                                    def => 'already_exists',
                                    params => $data->{WikiName} );
    }

    if ($session->{users}->lookupLoginName($data->{LoginName})) {
      throw TWiki::OopsException( 'attention',
				  web => $data->{webName},
				  topic => $topic,
				  def => 'already_exists',
				  params => $data->{LoginName} );
    }

    my $user = $session->{users}->findUser( $data->{LoginName}, undef, 1 );
    if ( $user && $user->passwordExists() ) {
        throw TWiki::OopsException( 'attention',
                                    web => $data->{webName},
                                    topic => $topic,
                                    def => 'already_exists',
                                    params => $data->{LoginName} );
    }

    # check if required fields are filled in
    foreach my $fd ( @{ $data->{form} } ) {
        if ( ( $fd->{required} ) && ( !$fd->{value} ) ) {
            # TODO - add all fields that are missing their values
            throw TWiki::OopsException( 'attention',
                                        web => $data->{webName},
                                        topic => $topic,
                                        def => 'missing_fields' );
        }
    }

    # check if WikiName is a WikiName
    if ( !TWiki::isValidWikiWord( $data->{WikiName} ) ) {
        throw TWiki::OopsException( 'attention',
                                    web => $data->{webName},
                                    topic => $topic,
                                    def => 'bad_wikiname' );
    }

    if (exists $data->{PasswordA}) {
        # check if passwords are identical
        if ( $data->{passwordA} ne $data->{passwordB} ) {
            throw TWiki::OopsException( 'attention',
                                        web => $data->{webName},
                                        topic => $topic,
                                        def => 'password_mismatch' );
        }
    }

    # check valid email address
    if ( $data->{Email} !~ $TWiki::regex{emailAddrRegex} ) {
        throw TWiki::OopsException( 'attention',
                                    web => $data->{webName},
                                    topic => $topic,
                                    def => 'bad_email',
                                    params => $data->{Email} );
    }
}

=pod

 generate user entry
 If a password exists (either in Data{PasswordA} or data{CryptPassword}, use it.
 Otherwise generate a random one, and store it back in the user record.

=cut

#SMELL - when should they get notified of the password?
sub _addUserToPasswordSystem {
    my( $session, $p ) = @_;

    my $user = $session->{users}->findUser($p->{LoginName}, $p->{WikiName});
    if ($user && $user->passwordExists()) {
        $user->removePassword();
    }

    my $success;
    if ($p->{CryptPassword})  {
        throw Error::Simple( 'No API to install crypted password' );
        #	$success = $session->{users}->installCryptedPassword($p->{LoginName},
        #						   $p->{CryptPassword});
    } else {
        my $password = $p->{Password};
        unless ($password) {
            $password = TWiki::User::randomPassword();
            $session->writeWarning('No password specified for '.$p->{LoginName}.' - using random='.$password);
        }
        $success = $user->addPassword( $password );
    }
    return $success;
}

# sends $p->{template} to $p->{Email} with a bunch of substitutions.
sub _sendEmail {
    my( $session, $template, $p ) = @_;

    my $text = $session->{templates}->readTemplate( $template );
    $p->{Introduction} ||= '';
    $p->{Name} ||= $p->{WikiName};
    $text =~ s/%LOGINNAME%/$p->{LoginName}/geo;
    $text =~ s/%FIRSTLASTNAME%/$p->{WikiName}/go;
    $text =~ s/%WIKINAME%/$p->{Name}/geo;
    $text =~ s/%EMAILADDRESS%/$p->{Email}/go;
    $text =~ s/%INTRODUCTION%/$p->{Introduction}/go;
    $text =~ s/%VERIFICATIONCODE%/$p->{VerificationCode}/go;
    $text =~ s/%PASSWORD%/$p->{PasswordA}/go;
    $text = $session->handleCommonTags( $text, $p->{webName}, $p->{WikiName} );
    return $session->{net}->sendEmail($text);
}

# | In | reference to the users data structure |
# | Out | none |
# dies if fails to store
sub _putRegDetailsByCode {
    my ($data, $tmpDir) = @_;

    my $file = _verificationCodeFilename( $data->{VerificationCode}, $tmpDir );
    unless( -d $tmpDir ) {
        require File::Path;
        File::Path::mkpath( $tmpDir ) || throw Error::Simple( $! );
    }
    open( F, ">$file" ) or throw Error::Simple( 'Failed to open file: '.$! );
    print F '# Verification code',"\n";
    print F Dumper( $data );
    close( F );
}

sub _verificationCodeFilename {
    my ( $code, $tmpDir ) = @_;
    ASSERT( $code ) if DEBUG;
    my $file = $tmpDir . '/'.$code;
    $file = TWiki::Sandbox::normalizeFileName( $file );
    return $file;
}

#| In | activation code |
#| Out | reference to user the user's data structure
#Dies if fails to get
sub _getRegDetailsByCode {
    my ( $code, $tmpDir ) = @_;
    my $file = _verificationCodeFilename( $code, $tmpDir );
    use vars qw( $VAR1 );
    do $file;
    throw Error::Simple( 'Bad activation code '.$code ) if $!;
    return $VAR1;
}

# Redirects user and dies if cannot load.
# Dies if loads and does not match.
# Returns the users data hash if succeeded.
# Returns () if not found.
sub _reloadUserContext {
    my( $code, $tmpDir ) = @_;

    ASSERT($code) if DEBUG;

    my $verificationFilename = _verificationCodeFilename( $code, $tmpDir );
    unless (-f $verificationFilename){
        throw TWiki::OopsException( 'attention',
                                    def => 'bad_ver_code',
                                    params => [ $code ] );
    }

    my $data = _getRegDetailsByCode($code, $tmpDir);
    my $error = _validateUserContext($code, $tmpDir);

    if ($error) {
        throw TWiki::OopsException( 'attention',
                                    def => 'bad_ver_code',
                                    params => [ $code,
                                                $error ] );
    }

    return $data;
}

# Returns undef if no problem, else returns what's wrong
sub _validateUserContext {
    my ($code, $tmpDir ) = @_;
    my ($name) = $code =~ /^([^.]+)\./;
    my %data   = %{ _getRegDetailsByCode( $code, $tmpDir ) };    #SMELL - expensive?
    return 'Invalid activation code' unless $code eq $data{VerificationCode};
    return 'Name in activation code does not match'
      unless $name eq $data{WikiName};
    return;
}

#SMELL: 'Context'?
sub _deleteUserContext {
    my ( $code, $tmpDir ) = @_;
    my ( $name ) = $code =~ /^([^.]+)\./;
    foreach (<$tmpDir/$name.*>) {
        unlink TWiki::Sandbox::untaintUnchecked($_);
    }
    # ^^ In case a user registered twice, etc...
}

sub _getDataFromQuery {
    my $query = shift;
    # get all parameters from the form
    my $data = {};
    foreach( $query->param() ) {
        if (/^(Twk)([0-9])(.*)/) {
            my $form = {};
            $form->{required} = $2;
            my $name = $3;
            my $value = $query->param($1.$2.$3);
            $form->{name} = $name;
            $form->{value} = $value;
            if ( $name eq 'Password' ) {
                #TODO: get rid of this; move to removals and generalise.
                $data->{passwordA} = $value;
            } elsif ( $name eq 'Confirm' ) {
                $data->{passwordB} = $value;
            } elsif( $name eq 'LoginName' ) {
                # Sanitise login name
                $value =~ s/[^\w]//g;
            }

            # 'WikiName' omitted because they can't
            # change it, and 'Confirm' is a duplicate
            push( @{$data->{form}}, $form )
              unless ($name eq 'WikiName' || $name eq 'Confirm');

            $data->{$name} = $value;
        }
    }
    return $data;
}

# We delete only the field in the {form} array - this leaves
# the original value still there should  we want it i.e. it must
# still be available via $row->{$key} even though $row-{form}[]
# does not contain it
sub _deleteKey {
    my ($row, $key) = @_;
    my @formArray = @{$row->{form}};

    foreach my $index (0..$#formArray) {
        my $a = $formArray[$index];
        my $name = $a->{name};
        my $value = $a->{value};
        if ($name eq $key) {
            splice (@{$row->{form}}, $index, 1);
            last;
        }
    }
};

sub _purgeKeys {
    my $data = shift;

    ASSERT($data) if DEBUG;

    _deleteKey($data, 'Photo');
    _deleteKey($data, 'WikiName');
    _deleteKey($data, 'LoginName');
    _deleteKey($data, 'Password');
}

1;
