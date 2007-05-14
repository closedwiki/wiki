# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2007 Peter Thoeny, peter@thoeny.org
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
#           (c) 2004-2007 Crawford Currie c-dot.co.uk
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
use TWiki::Form;
use Data::Dumper;
use Error qw( :try );
use TWiki::UI;
use TWiki::OopsException;
use Assert;

my $agent = 'TWikiRegistrationAgent';

# Keys from the user data that should *not* be included in
# the user topic.
my %SKIPKEYS = (
    'Photo' => 1,
    'WikiName' => 1,
    'LoginName' => 1,
    'Password' => 1,
    'Email' => 1
   );

=pod

---++ StaticMethod register_cgi( $session )

=register= command handler.
This method is designed to be
invoked via the =TWiki::UI::run= method.

=cut

sub register_cgi {
    my $session = shift;

    # absolute URL context for email generation
    $session->enterContext('absolute_urls');

    my $tempUserDir = $TWiki::cfg{RegistrationApprovals};
    my $needApproval = 0;

    # Register -> Verify -> Approve -> Finish

    # NB. bulkRegister invoked from ManageCgiScript.

    my $action = $session->{cgiQuery}->param('action') || '';

    if ($action eq 'register') {
      if (!$session->inContext('registration_supported')) {
        throw TWiki::OopsException( 'attention',
                                    web => $session->{webName},
                                    topic => $session->{topicName},
                                    def => 'registration_not_supported' );
      }
      if (!$TWiki::cfg{Register}{EnableNewUserRegistration}) {
        throw TWiki::OopsException( 'attention',
                                    web => $session->{webName},
                                    topic => $session->{topicName},
                                    def => 'registration_disabled' );
      }
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
        resetPassword( $session );
    }
    elsif ($action eq 'approve') {
        finish($session, $tempUserDir );
    }
    else {
        registerAndNext($session, $tempUserDir);
    }

    $session->leaveContext('absolute_urls');

    # Output of register:
    #    UnsavedUser, accessible by username.$verificationCode

    # Output of reset password:
    #    unaffected user, accessible by username.$verificationCode

    # Output of verify:
    #    UnsavedUser, accessible by username.$approvalCode (only sent to administrator)

    # Output of approve:
    #    RegisteredUser, all related UnsavedUsers deleted
}

my $b1 = "\t* ";
my $b2 ="\t$b1";

=pod

---++ StaticMethod bulkRegister($session)

  Called by ManageCgiScript::bulkRegister (requires authentication) with topic = the page with the entries on it.

=cut

sub bulkRegister {
    my $session = shift;

    my $user = $session->{user};
    my $topic = $session->{topicName};
    my $web = $session->{webName};
    my $userweb = $TWiki::cfg{UsersWebName};
    my $query = $session->{cgiQuery};

    # absolute URL context for email generation
    $session->enterContext('absolute_urls');

    my $settings = {};
    # This gets set from the value in the BulkRegistrations topic
    $settings->{doOverwriteTopics} =
      $query->param('OverwriteHomeTopics') || 0;
    $settings->{doEmailUserDetails} =
      $query->param('EmailUsersWithDetails') || 0;

    unless( $session->{users}->isAdmin( $user ) ) {
        throw TWiki::OopsException(
            'accessdenied', def => 'only_group',
            web => $web, topic => $topic,
            params => [ $TWiki::cfg{SuperAdminGroup} ] );
    }

    #-- Read the topic containing the table of people to be registered

    my ($meta, $text) = $session->{store}->readTopic(
        undef, $web, $topic, undef );
    my @fields;
    my @data;
    my $gotHdr = 0;
    foreach my $line ( split( /\r?\n/, $text ) ) {
        if( $line =~ /^\|\s*(.*?)\s*\|$/) {
            if( $gotHdr ) {
                my $i = 0;
                my %row = map { $fields[$i++] => $_ } split( /\s*\|\s*/, $1 );
                push(@data, \%row);
            } else {
                foreach my $field ( split( /\s*\|\s*/, $1 )) {
                    $field =~ s/^[\s*]*(.*?)[\s*]*$/$1/;
                    push( @fields, $field);
                }
                $gotHdr = 1;
            }
        }
    }

    my $log = "---+ Report for Bulk Register\n";

    #-- Process each row, generate a log as we go
    for( my $n = 0; $n < scalar(@data); $n++) {
        my $row = $data[$n];
        $row->{webName} = $userweb;

        #-- Following two lines untaint WikiName as required and verify it is
        #-- not zero length
        if (!$row->{WikiName}) {
            $log .= "---++ Failed to register user on row $n; no !WikiName\n";
            next;
        }
        $row->{WikiName} = TWiki::Sandbox::untaintUnchecked($row->{WikiName});
        $row->{LoginName} = $row->{WikiName} unless $row->{LoginName};

        $log .= _registerSingleBulkUser(
            $session, \@fields, $row, $settings );
    }

    $log .= "----\n";

    my $logWeb;
    my $logTopic =  $query->param('LogTopic') || $topic.'Result';
    ( $logWeb, $logTopic ) = $session->normalizeWebTopicName( '', $logTopic );

    #-- Save the LogFile as designated, link back to the source topic 
    $meta->put( 'TOPICPARENT', { name => $web.'.'.$topic } );
    my $err = $session->{store}->saveTopic($user, $logWeb, $logTopic, $log, $meta );

    $session->leaveContext('absolute_urls');

    $session->redirect($session->getScriptUrl( 1, 'view', $web, $logTopic ));
}

# Register a single user during a bulk registration process
sub _registerSingleBulkUser {
    my ($session, $fieldNames, $row, $settings) = @_;
    ASSERT( $row ) if DEBUG;

    my $doOverwriteTopics = defined $settings->{doOverwriteTopics} ||
      throw Error::Simple( 'No doOverwriteTopics' );

    my $log = "---++ Registering $row->{WikiName}\n";

    try {
        _validateRegistration( $session, $row, 0 );
    } catch TWiki::OopsException with {
        my $e = shift;
        $log .= '<blockquote>'.$e->stringify( $session )."</blockquote>\n";
        return $log."$b1 Registration failed\n";
    };

    #-- call to the registrationHandler (to amend fields) should
    # really happen in here.

    #-- Ensure every required field exists
    # NB. LoginName is OPTIONAL
    my @requiredFields = qw(WikiName FirstName LastName);
    if (_missingElements( $fieldNames, \@requiredFields )) {
        $log .= $b1.join(' ', @{$settings->{fieldNames}}).
          ' does not contain the full set of required fields '.
            join(' ', @requiredFields)."\n";
        return (undef, $log);
    }

    #-- Generation of the page is done from the {form} subhash,
    # so align the two
    $row->{form} = _makeFormFieldOrderMatch( $fieldNames, $row);

    my $users = $session->{users};

    if( $settings->{doOverwriteTopics} ||
          !$session->{store}->topicExists( $row->{webName},
                                           $row->{WikiName} ) ) {
        $log .= _createUserTopic($session, 'NewUserTemplate', $row);
    } else {
        $log .= "$b1 Not writing user topic $row->{WikiName}\n";
    }

    try {
        # Add the user to the user management system. May throw an exception
        my ( $user, $pass ) = $users->addUser(
            $row->{LoginName}, $row->{WikiName},
            $row->{Password}, $row->{Email} );
        $log .= "$b1 $row->{WikiName} has been added to the password and user mapping managers\n";

        $session->writeLog('bulkregister',
                           $row->{webName}.'.'.$row->{WikiName},
                           $row->{Email}, $row->{WikiName} );
    } catch Error::Simple with {
        my $e = shift;
        $log .= "$b1 Failed to add user: ".$e->stringify()."\n";
    };

    #if ($TWiki::cfg{EmailUserDetails}) {
    # If you want it, write it.
    # _sendEmail($session, 'registernotifybulk', $data );
    #    $log .= $b1.' Password email disabled\n';
    #}

    return $log;
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
    my( $fieldNames, $data ) = @_;
    my @form = ();
    foreach my $field ( @$fieldNames ) {
        push @form, {name => $field, value => $data->{$field}};
    }
    return \@form;
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

=cut

sub register {
    my( $session ) = @_;

    my $query = $session->{cgiQuery};
    my $data = _getDataFromQuery( $query, $query->param() );

    $data->{webName} = $session->{webName};
    $data->{debug} = 1;

    # SMELL: should perform basic checks that we have e.g. a WikiName

    _validateRegistration( $session, $data, 1 );
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
    $data->{LoginName} ||= $data->{WikiName};
    $data->{webName} = $web;

    $data->{VerificationCode} =
      $data->{WikiName}.'.'.TWiki::Users::randomPassword();
    _putRegDetailsByCode( $data, $tmpDir );

    $session->writeLog(
        'regstart', $TWiki::cfg{UsersWebName}.'.'.$data->{WikiName},
        $data->{Email}, $data->{WikiName} );

    my $err = _sendEmail( $session, 'registerconfirm', $data );
    my $em = TWiki::entityEncode( $data->{Email} );

    if($err) {
        throw TWiki::OopsException(
            'attention',
            def => 'registration_mail_failed',
            web => $data->{webName},
            topic => $topic,
            params => [ $em, $err ]);
    };


    throw TWiki::OopsException(
        'attention',
        def => 'confirm',
        web => $data->{webName},
        topic => $topic,
        params => [ $em ] );
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
        unless( $session->{users}->isAdmin( $user )) {
            throw TWiki::OopsException
              ( 'accessdenied', def => 'only_group',
                web => $web, topic => $topic,
                params => [ $TWiki::cfg{SuperAdminGroup} ] );
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
                                    params => [ $message ] );
    } else {
        throw TWiki::OopsException( 'attention',
                                    topic => $TWiki::cfg{UsersTopicName},
                                    def => 'reset_bad',
                                    params => [ $message ] );
    }
}

# return status
sub _resetUsersPassword {
    my( $session, $user, $introduction, $pMess ) = @_;

    my $users = $session->{users};

    unless( $user ) {
        $$pMess .= $session->inlineAlert( 'alerts', 'bad_user', '' );
        return 0;
    }

    my $message = '';
    unless( $users->userExists( $user )) {
        # Not an error.
        $$pMess .= $session->inlineAlert( 'alerts', 'missing_user', $user);
        return 0;
    }

    my $password = TWiki::Users::randomPassword();

    unless( $users->setPassword( $user, $password, 1 )) {
        $$pMess .= $session->inlineAlert( 'alerts', 'reset_bad', $user);
        return 0;
    }

    # absolute URL context for email generation
    $session->enterContext('absolute_urls');

    my @em = $users->getEmails($user);
    my $sent = 0;
    if (!scalar(@em)) {
        $$pMess .= $session->inlineAlert( 'alerts', 'no_email_for', $user);
    } else {
        my $ln = $users->getLoginName($user);
        my $wn = $users->getWikiName($user);
        foreach my $email ( @em ) {
            my $err = _sendEmail(
                $session,
                'mailresetpassword',
                {
                    webName => $TWiki::cfg{UsersWebName},
                    LoginName => $ln,
                    Name => TWiki::spaceOutWikiWord($wn),
                    WikiName => $wn,
                    Email => $email,
                    PasswordA => $password,
                    Introduction => $introduction,
                } );

            if( $err ) {
                $$pMess .= $session->inlineAlert( 'alerts', 'generic', $err );
            } else {
                $sent = 1;
            }
        }
    }

    $session->leaveContext('absolute_urls');

    if ($sent ) {
        $$pMess .= $session->inlineAlert(
            'alerts',
            'new_sys_pass',
            $users->getLoginName($user),
            $users->getWikiName( $user ));
    }

    return $sent;
}

=pod

---++ StaticMethod changePassword( $session )

Change the user's password and/or email. Details of the user and password
are passed in CGI parameters.

   1 Checks required fields have values
   2 get wikiName and userName from getUserByEitherLoginOrWikiName(username)
   3 check passwords match each other, and that the password is correct, otherwise 'wrongpassword'
   4 TWiki::User::updateUserPassword
   5 'oopschangepasswd'

The NoPasswdUser case is not handled.

An admin user can change other user's passwords.

=cut

sub changePassword {
    my $session = shift;

    my $topic = $session->{topicName};
    my $webName = $session->{webName};
    my $query = $session->{cgiQuery};
    my $requestUser = $session->{user};

    my $oldpassword = $query->param( 'oldpassword' );
    my $user = $query->param( 'username' );
    my $passwordA = $query->param( 'password' );
    my $passwordB = $query->param( 'passwordA' );
    my $email = $query->param( 'email' );

    my $topicName = $query->param( 'TopicName' );

    # check if required fields are filled in
    unless( $user ) {
        throw TWiki::OopsException( 'attention',
                                    web => $webName,
                                    topic => $topic,
                                    def => 'missing_fields',
                                    params => [ 'username' ] );
    }

    my $users = $session->{users};

    unless ($user) {
        throw TWiki::OopsException( 'attention',
                                    web => $webName,
                                    topic => $topic,
                                    def => 'notwikiuser',
                                    params => [ $user ] );
    }

    my $changePass = 0;
    if( defined $passwordA || defined $passwordB ) {
        unless( defined $passwordA ) {
            throw TWiki::OopsException( 'attention',
                                        web => $webName,
                                        topic => $topic,
                                        def => 'missing_fields',
                                        params => [ 'password' ] );
        }

        # check if passwords are identical
        if( $passwordA ne $passwordB ) {
            throw TWiki::OopsException( 'attention',
                                        web => $webName,
                                        topic => $topic,
                                        def => 'password_mismatch' );
        }
        $changePass = 1;
    }

    # check if required fields are filled in
    unless( defined $oldpassword || $users->isAdmin( $requestUser )) {
        throw TWiki::OopsException( 'attention',
                                    web => $webName,
                                    topic => $topic,
                                    def => 'missing_fields',
                                    params => [ 'oldpassword' ] );
    }

    unless( $users->isAdmin( $requestUser ) ||
              $users->checkPassword( $user, $oldpassword)) {
        throw TWiki::OopsException( 'attention',
                                    web => $webName,
                                    topic => $topic,
                                    def => 'wrong_password');
    }

    if( defined $email ) {
        $users->setEmails($user, split(/\s+/, $email) );
    }

    # OK - password may be changed
    if( $changePass ) {
        if (length($passwordA) < $TWiki::cfg{MinPasswordLength}) {
            throw TWiki::OopsException(
                'attention',
                web => $webName,
                topic => $topic,
                def => 'bad_password',
                params => [ $TWiki::cfg{MinPasswordLength} ] );
        }

        unless( $users->setPassword( $user, $passwordA, $oldpassword )) {
            throw TWiki::OopsException( 'attention',
                                        web => $webName,
                                        topic => $topic,
                                        def => 'password_not_changed');
        } else {
            $session->writeLog('changepasswd', $user);
        }
        # OK - password changed
        throw TWiki::OopsException( 'attention',
                                    web => $webName, topic => $topic,
                                    def => 'password_changed' );
    }

    # must be just email
    throw TWiki::OopsException( 'attention',
                                 web => $webName, topic => $topic,
                                 def => 'email_changed',
                                 params => [ $email ] );
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

    if (! exists $data->{Email}) {
        throw Error::Simple( 'verifyEmailAddress: no email address!');
    }

    my $topic = $session->{topicName};
    my $web = $session->{webName};

}

=pod

---++ StaticMethod finish

Presently this is called in RegisterCgiScript directly after a call to verify.
The separation is intended for the RegistrationApprovals functionality

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
        throw Error::Simple( 'no WikiName after reload');
    }

    if (! exists $data->{LoginName}) {
        if( $TWiki::cfg{AllowLoginName} ) {
            # This should have been populated
            throw Error::Simple( 'no LoginName after reload');
        }
        $data->{LoginName} ||= $data->{WikiName};
    }

    # Create the user topic. We have to do this before adding the
    # user to the user management system, because some user mappers
    # use the user topic to store data.
    my $log = _createUserTopic($session, 'NewUserTemplate', $data);

    my $users = $session->{users};
    try {
        $users->addUser( $data->{LoginName}, $data->{WikiName},
                         $data->{Password}, $data->{Email} );
    } catch Error::Simple with {
        my $e = shift;
        # Log the error
        $session->writeWarning( 'Registration failed: '.$e->stringify() );
        throw TWiki::OopsException( 'attention',
                                    web => $data->{webName},
                                    topic => $topic,
                                    def => 'problem_adding',
                                    params => [ $data->{WikiName},
                                                $e->stringify() ] );
    };

    # Plugin callback to set cookies.
    $session->{plugins}->registrationHandler( $data->{WebName},
                                              $data->{WikiName},
                                              $data->{LoginName} );

    # let the client session know that we're logged in. (This probably
    # eliminates the need for the registrationHandler call above,
    # but we'll leave them both in here for now.)
    $session->{loginManager}->userLoggedIn( $data->{LoginName}, $data->{WikiName} );

    # inform user and admin about the registration.
    my $status = _emailRegistrationConfirmations( $session, $data );

    # write log entry
    if ($TWiki::cfg{Log}{register}) {
        $session->writeLog(
            'register', $TWiki::cfg{UsersWebName}.'.'.$data->{WikiName},
            $data->{Email}, $data->{WikiName} );
    }

    if( $status ) {
        $status = $session->{i18n}->maketext(
            'Warning: Could not send confirmation email')."\n\n$status";
    } else {
        $status = $session->{i18n}->maketext(
            'A confirmation e-mail has been sent to [_1]',
            TWiki::entityEncode( $data->{Email} ));
    }

    # and finally display thank you page
    throw TWiki::OopsException( 'attention',
                                web => $TWiki::cfg{UsersWebName},
                                topic => $data->{WikiName},
                                def => 'thanks',
                                params => [ $status ] );
}

#Given a template and a hash, creates a new topic for a user
#   1 reads the template topic
#   2 calls RegistrationHandler::register with the row details, so that a plugin can augment/delete/change the entries
#
#I use RegistrationHandler::register to prevent certain fields (like password) 
#appearing in the homepage and to fetch photos into the topic
sub _createUserTopic {
    my ($session, $template, $row) = @_;
    my ( $meta, $text ) = TWiki::UI::readTemplateTopic($session, $template);
    my $log = $b1 . ' Writing topic '.$TWiki::cfg{UsersWebName} . '.'
      . $row->{WikiName}."\n"
        . "$b1 !RegistrationHandler:\n"
          . _writeRegistrationDetailsToTopic( $session, $row, $meta, $text );
    return $log;
}

# Writes the registration details passed as a hash to either BulletFields
# or FormFields on the user's topic.
#
sub _writeRegistrationDetailsToTopic {
    my ($session, $data, $meta, $text) = @_;

    ASSERT($data->{WikiName}) if DEBUG;

    # TODO - there should be some way of overwriting meta without
    # blatting the content.

    my( $before, $repeat, $after ) = split( /%SPLIT%/, $text, 3 );
    $before = '' unless defined( $before );
    $after = '' unless defined( $after );

    my $log;
    my $addText;
    my $form = $meta->get( 'FORM' );
    if( $form ) {
        ( $meta, $addText ) =
          _populateUserTopicForm( $session, $form->{name}, $meta, $data );
        $log = "$b2 Using Form Fields\n";
    } else {
        $addText = _getRegFormAsTopicContent( $data );
        $log = "$b2 Using Bullet Fields\n";
    }
    $text = $before . $addText . $after;

    my $user = $data->{WikiName};
    $text = $session->expandVariablesOnTopicCreation( $text, $user );

    $meta->put( 'TOPICPARENT', { 'name' => $TWiki::cfg{UsersTopicName}} );

    $session->{store}->saveTopic($agent, $TWiki::cfg{UsersWebName},
                                 $user, $text, $meta );
    return $log;
}

# Puts form fields into the topic form
sub _populateUserTopicForm {
    my ( $session, $formName, $meta, $data ) = @_;

    my %inform;
    my $form =
      new TWiki::Form( $session, $TWiki::cfg{UsersWebName}, $formName );

    return ($meta, '' ) unless $form;

    foreach my $field ( @{$form->getFields()} ) {
        foreach my $fd (@{$data->{form}}) {
            next unless $fd->{name} eq $field->{name};
            next if $SKIPKEYS{$fd->{name}};
            my $item = $meta->get( 'FIELD', $fd->{name} );
            $item->{value} = $fd->{value};
            $meta->putKeyed( 'FIELD', $item );
            $inform{$fd->{name}} = 1;
            last;
        }
    }
    my $leftoverText = '';
    foreach my $fd (@{$data->{form}}) {
        unless( $inform{$fd->{name}} || $SKIPKEYS{$fd->{name}} ) {
            $leftoverText .= "   * $fd->{name}: $fd->{value}\n";
        }
    }
    return ( $meta, $leftoverText );
}

# Registers a user using the old bullet field code
sub _getRegFormAsTopicContent {
    my $data = shift;
    my $text;
    foreach my $fd ( @{ $data->{form} } ) {
        next if $SKIPKEYS{$fd->{name}};
        my $title = $fd->{name};
        $title =~ s/([a-z0-9])([A-Z0-9])/$1 $2/go;    # Spaced
        my $value = $fd->{value};
        $value =~ s/[\n\r]//go;
        $text .= "   * $title\: $value\n";
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

    my $warnings = $session->{net}->sendEmail( $email);

    $template =
      $session->{templates}->readTemplate( 'registernotifyadmin', $skin );
    $email =
      _buildConfirmationEmail( $session,
                               $data,
                               $template,
                               1 );

    my $err = $session->{net}->sendEmail( $email );
    if( $err ) {
        # don't tell the user about this one
        $session->writeWarning('Could not confirm registration: '.$err);
    }

    return $warnings;
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
            $before .= $b1.' '.$name.': '.$value."\n";
        }
    }
    $templateText = $before.($after||'');
    $templateText = $session->handleCommonTags(
        $templateText, $TWiki::cfg{UsersWebName}, $data->{WikiName} );
    $templateText =~ s/( ?) *<\/?(nop|noautolink)\/?>\n?/$1/gois;
    # remove <nop> and <noautolink> tags

    return $templateText;
}

# Throws an Oops exception if there is a problem.
sub _validateRegistration {
    my ( $session, $data, $requireForm ) = @_;

    if( !defined( $data->{LoginName} ) &&
          $TWiki::cfg{Register}{AllowLoginName} ) {
        # Login name is required, barf
        throw TWiki::OopsException( 'attention',
                                    web => $data->{webName},
                                    topic => $session->{topicName},
                                    def => 'bad_loginname',
                                    params => [ 'undefined' ] );
    } elsif( !defined( $data->{LoginName} ) ) {
        # Login name is optional, default to the wikiname
        $data->{LoginName} = $data->{WikiName};
    }

    # Check if login name matches expectations
    unless( $data->{LoginName} =~ /$TWiki::cfg{LoginNameFilterIn}/ ) {
        throw TWiki::OopsException( 'attention',
                                    web => $data->{webName},
                                    topic => $session->{topicName},
                                    def => 'bad_loginname',
                                    params => [ $data->{LoginName} ] );
    }

    # Check if the login name is already registered
    my $users = $session->{users};
    if( $users->userExists( $data->{LoginName}) ) {
        throw TWiki::OopsException( 'attention',
                                    web => $data->{webName},
                                    topic => $session->{topicName},
                                    def => 'already_exists',
                                    params => [ $data->{LoginName} ] );
    }

    # Check if WikiName is a WikiName
    if ( !TWiki::isValidWikiWord( $data->{WikiName} ) ) {
        throw TWiki::OopsException( 'attention',
                                    web => $data->{webName},
                                    topic => $session->{topicName},
                                    def => 'bad_wikiname',
                                    params => [ $data->{WikiName} ] );
    }

    if (exists $data->{passwordA}) {
        # check password length
        my $doCheckPasswordLength  =
          ( $TWiki::cfg{PasswordManager} ne 'none'  &&
              $TWiki::cfg{MinPasswordLength} );

        if ($doCheckPasswordLength &&
            length($data->{passwordA}) < $TWiki::cfg{MinPasswordLength}) {
            throw TWiki::OopsException(
                'attention',
                web => $data->{webName},
                topic => $session->{topicName},
                def => 'bad_password',
                params => [ $TWiki::cfg{MinPasswordLength} ] );
        }

        # check if passwords are identical
        if ( $data->{passwordA} ne $data->{passwordB} ) {
            throw TWiki::OopsException( 'attention',
                                        web => $data->{webName},
                                        topic => $session->{topicName},
                                        def => 'password_mismatch' );
        }
    }

    # check valid email address
    if ( $data->{Email} !~ $TWiki::regex{emailAddrRegex} ) {
        throw TWiki::OopsException(
            'attention',
            web => $data->{webName},
            topic => $session->{topicName},
            def => 'bad_email',
            params => [ TWiki::entityEncode( $data->{Email} ) ] );
    }

    return unless $requireForm;

    # check if required fields are filled in
    unless ( $data->{form} && ( $#{ $data->{form} } > 1 ) ) {
        throw TWiki::OopsException( 'attention',
                                    web => $data->{webName},
                                    topic => $session->{topicName},
                                    def => 'missing_fields',
                                    params => [ 'form' ] );
    }
    my @missing = ();
    foreach my $fd ( @{ $data->{form} } ) {
        if ( ( $fd->{required} ) && ( !$fd->{value} ) ) {
            push( @missing, $fd->{name} );
        }
    }

    if( scalar( @missing )) {
        throw TWiki::OopsException( 'attention',
                                    web => $data->{webName},
                                    topic => $session->{topicName},
                                    def => 'missing_fields',
                                    params => [ join(', ', @missing) ] );
    }
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
    $text = $session->handleCommonTags(
        $text, $TWiki::cfg{UsersWebName}, $p->{WikiName} );

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
    # SMELL: wierd jiggery-pokery required, otherwise Data::Dumper screws
    # up the form fields when it saves. Perl bug? Probably to do with
    # chucking around arrays, instead of references to them.
    my $form = $data->{form};
    $data->{form} = undef;
    print F Dumper( $data, $form );
    $data->{form} = $form;
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
    use vars qw( $VAR1 $VAR2 );
    do $file;
    $VAR1->{form} = $VAR2 if $VAR2;
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
                                    params => [ $code, '.' ] );
    }

    my $data = _getRegDetailsByCode($code, $tmpDir);
    my $error = _validateUserContext($code, $tmpDir);

    if( $error ) {
        throw TWiki::OopsException( 'attention',
                                    def => 'bad_ver_code',
                                    params => [ $code, $error ] );
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
    my $code = shift;
    my $tmpDir = TWiki::Sandbox::untaintUnchecked( shift );
    $code =~ s/^([^.]+)\.//;
    my $name = TWiki::Sandbox::untaintUnchecked( $1 );

    foreach (<$tmpDir/$name.*>) {
        unlink( TWiki::Sandbox::untaintUnchecked( $_ ));
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
            }

            # 'WikiName' omitted because they can't
            # change it, and 'Confirm' is a duplicate
            push( @{$data->{form}}, $form )
              unless ($name eq 'WikiName' || $name eq 'Confirm');

            $data->{$name} = $value;
        }
    }
    $data->{WikiName} = TWiki::Sandbox::untaintUnchecked($data->{WikiName});
    if( !$data->{Name} &&
          defined $data->{FirstName} && defined $data->{LastName}) {
        $data->{Name} = $data->{FirstName}.' '.$data->{LastName};
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

1;
