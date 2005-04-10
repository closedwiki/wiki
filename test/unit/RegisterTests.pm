# This causes ntwiki to barf
#require 5.008;

package RegisterTests;

# Tests not implemented:
		#test_registerTwiceWikiName
		#test_registerTwiceEmailAddress
		#test_bulkResetPassword
		#test_registerIllegitimateBypassApprove
                #test_registerVerifyAndFinish

#Uncomment to isolate 
#our @TESTS = qw(test_registerVerifyOk); #test_UnregisteredUser);

use base qw(Test::Unit::TestCase);
BEGIN {
    unshift @INC, '../../bin';
    require 'setlib.cfg';
};
use strict;
use diagnostics;
use TWiki::UI::Register;
use Data::Dumper;
use FileHandle;
use CGI;
use Error qw( :try );
use File::Copy;
use Carp;

my $testUserWikiName = 'TestUser';
my $testUserLoginName = 'testuser';
my $testUserEmail = 'kakapo@ground.dwelling.parrot.net';

my $guestLoginName = 'guest';

my $temporaryWeb = "Temporary";
my $peopleWeb = "Main";
my $mainweb = "$peopleWeb";
my $twikiUsersFile;
# SMELL: the sent mails are never checked in the tests
my @mails;

$TWiki::User::password = "foo";

sub new {
    my $this = shift()->SUPER::new(@_);
    # your state for fixture here
    return $this;
}

my $myDataDir;
my $approvalsDir;
my $myPubDir;
my $saveDD;
my $savePD;
my $saveHP;
my $session;

sub set_up {
    my $this = shift;
    my $here = `pwd`;
    $here =~ s/\s//g;; #SMELL: yuck!
    $myDataDir = "$here/tmpRegisterTestData";
    $myPubDir =  "$here/tmpRegisterTestPub";

    # SMELL: should be a better way to do this. Copy deeply?
    $saveDD = $TWiki::cfg{DataDir};
    $savePD = $TWiki::cfg{PubDir};
    $saveHP = $TWiki::cfg{HtpasswdFileName};

    $TWiki::cfg{DataDir} = $myDataDir;
    $TWiki::cfg{PubDir} = $myPubDir;
    $TWiki::cfg{HtpasswdFileName} = "$myDataDir/htpasswd";

    $approvalsDir = $TWiki::cfg{PubDir}.'/TWiki/RegistrationApprovals';
    $SIG{__DIE__} = sub { confess $_[0] };

    mkdir $myDataDir;
    chmod 0777, $myDataDir;

    mkdir "$myDataDir/$temporaryWeb";
    chmod 0777, "$myDataDir/$temporaryWeb";

    mkdir "$myDataDir/$TWiki::cfg{UsersWebName}";
    chmod 0777, "$myDataDir/$TWiki::cfg{UsersWebName}";

    mkdir $myPubDir;
    chmod 0777, $myPubDir;

    mkdir "$myPubDir/$temporaryWeb";
    chmod 0777, "$myPubDir/$temporaryWeb";

    $Error::Debug = 1;

    setupUnregistered();

    $twikiUsersFile = "$TWiki::cfg{DataDir}/Main/TWikiUsers.txt";
    @mails = ();
}

sub tear_down {
    # clean up after test
    `rm -rf $myDataDir $myPubDir`;
    $TWiki::cfg{DataDir} = $saveDD;
    $TWiki::cfg{PubDir} = $savePD;
    $TWiki::cfg{HtpasswdFileName} = $saveHP;
    @mails = ();
}

# callback used by Net.pm
sub sentMail {
    my($net, $mess ) = @_;
    push( @mails, $mess );
    return undef;
}

# fixture
sub registerAccount {
    my $this = shift;
    $this->test_registerVerifyOk();

    my $query = new CGI({
                         'code' => [
                                    $testUserWikiName.".foo"
                                   ],
                         'action' => [
                                      'verify'
                                     ]
                        });

    try {
        TWiki::UI::Register::finish( $session, $approvalsDir );
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("registerok", $e->{-template});
        $this->assert_str_equals("thanks", $e->{-def});
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } catch Error::Simple with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    }
    $this->assert_equals(0, scalar(@mails));
}

#Register a user, and then verify it
#Assumes the verification code is foo
sub test_registerVerifyOk {
    my $this = shift;
    my $query = new CGI ({
                          'TopicName' => [
                                          'TWikiRegistration'
                                         ],
                          'Twk1Email' => [
                                          $testUserEmail
                                         ],
                          'Twk1WikiName' => [
                                             $testUserWikiName
                                            ],
                          'Twk1Name' => [
                                         'Test User'
                                        ],
                          'Twk0Comment' => [
                                            ''
                                           ],
                          'Twk1LoginName' => [
                                              $testUserLoginName
                                             ],
                          'Twk1FirstName' => [
                                              'Test'
                                             ],
                          'Twk1LastName' => [
                                             'User'
                                            ],
                          'action' => [
                                       'register'
                                      ]
                         });

    $session = new TWiki("Main", $TWiki::cfg{DefaultUserName},
                         'TWikiRegistration', $query->url, $query);
    $session->{net}->setMailHandler(\&sentMail);

    try {
        TWiki::UI::Register::register_cgi($session);
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("registerok", $e->{-template},$e->stringify());
        $this->assert_str_equals("confirm", $e->{-def});
        $this->assert_matches(qr/$testUserEmail/, $e->stringify());
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };

    my $code = shift || $testUserWikiName.".foo";
    $query = new CGI ({
                       'code' => [
                                  $code
                                 ],
                       'action' => [
                                    'verify'
                                   ]
                      });
    $session = new TWiki("Main", $TWiki::cfg{DefaultUserName},
                         'TWikiRegistration', $query->url, $query);
    $session->{net}->setMailHandler(\&sentMail);

    try {
        TWiki::UI::Register::verifyEmailAddress($session, $approvalsDir);
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);

    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    };
    $this->assert_equals(3, scalar(@mails));
    my @done;
    foreach my $mail ( @mails ) {
        if( !$done[0] && $mail =~ /^Subject:.*Registration for/m &&
          $mail =~ /^To: .*$testUserEmail/m ) {
            $done[0] = 1;
        } elsif( !$done[1] && $mail =~ /^Subject: .*Activation code/m ) {
            $done[1] = 1;
        } elsif( !$done[2] && $mail =~ /^Subject:.*Registration for/m &&
               $mail =~ /To: %WIKIWEBMASTER%/ ) {
            $done[2] = 1;
        } else {
            $this->assert(0, $mail);
        }
    }
}

#Register a user, then give a bad verification code. It should barf.
sub test_registerBadVerify {
    my $this = shift;
    my $query = new CGI ({
                          'TopicName' => [
                                          'TWikiRegistration'
                                         ],
                          'Twk1Email' => [
                                          $testUserEmail
                                         ],
                          'Twk1WikiName' => [
                                             $testUserWikiName
                                            ],
                          'Twk1Name' => [
                                         'Test User'
                                        ],
                          'Twk0Comment' => [
                                            ''
                                           ],
                          'Twk1LoginName' => [
                                              $testUserLoginName
                                             ],
                          'Twk1FirstName' => [
                                              'Test'
                                             ],
                          'Twk1LastName' => [
                                             'User'
                                            ],
                          'action' => [
                                       'register'
                                      ]
                         });
    $session = new TWiki("Main", $TWiki::cfg{DefaultUserName},
                         'TWikiRegistration', $query->url, $query);
    $session->{net}->setMailHandler(\&sentMail);
    try {
        TWiki::UI::Register::register_cgi($session);
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_matches(qr/$testUserEmail/, $e->stringify());
        $this->assert_str_equals("registerok", $e->{-template});
        $this->assert_str_equals("confirm", $e->{-def});
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());

    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };

    my $code = $testUserWikiName.'.bad.foo';
    $query = new CGI ({
                       'code' => [
                                  $code
                                 ],
                       'action' => [
                                    'verify'
                                   ]
                      });
    $session = new TWiki("Main", $TWiki::cfg{DefaultUserName},
                         'TWikiRegistration', $query->url, $query);
    $session->{net}->setMailHandler(\&sentMail);

    try {
        TWiki::UI::Register::verifyEmailAddress($session,$approvalsDir);
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);

    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("registerbad",$e->{-template});
        $this->assert_str_equals("no_ver_file",$e->{-def});
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "Expected a redirect" );
    };
    $this->assert_equals(1, scalar(@mails));
    my $mess = $mails[0];
    $this->assert_matches(qr/From: %WIKIWEBMASTER%/,$mess);
    $this->assert_matches(qr/To: $testUserEmail/,$mess);
    # check the verification code
    $this->assert_matches(qr/'TestUser\.foo'/,$mess);
}

################################################################################
################################ RESET PASSWORD TESTS ##########################

sub test_resetPasswordOkay {
    my $this = shift;

    ## Need to create an account (else oopsnotwikiuser)
    ### with a known email address (else oopsregemail)

    $this->registerAccount();

    my $query = new CGI (
                         {
                          '.path_info' => '/'.$peopleWeb.'/WebHome',
                          'LoginName' => [
                                          "testuser"
                                         ],
                          'TopicName' => [
                                          'ResetPassword'
                                         ],
                          'action' => [
                                       'resetPassword'
                                      ]
                         });

    $session = new TWiki("Main", $guestLoginName,
                         'ResetPassword', $query->url, $query);
    $session->{net}->setMailHandler(\&sentMail);

    try {
        TWiki::UI::Register::resetPassword($session);
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("registerok", $e->{-template});
        $this->assert_str_equals("reset_ok", $e->{-def});
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };
    $this->assert_equals(1, scalar(@mails));
    my $mess = $mails[0];
    $this->assert_matches(qr/From: %WIKIWEBMASTER%/,$mess);
    $this->assert_matches(qr/To: $testUserEmail/,$mess);
}

sub test_resetPasswordNoSuchUser {
    my $this = shift;
    # This time we don't set up the testWikiName, so it should fail.

    my $query = new CGI (
                         {
                          '.path_info' => '/.'.$peopleWeb.'/WebHome',
                          'LoginName' => [
                                          $testUserWikiName
                                         ],
                          'TopicName' => [
                                          'ResetPassword'
                                         ],
                          'action' => [
                                       'resetPassword'
                                      ]
                         });

    $session = new TWiki("Main", $guestLoginName,
                         'ResetPassword', $query->url, $query);
    $session->{net}->setMailHandler(\&sentMail);

    try {
        TWiki::UI::Register::resetPassword($session);
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);

    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("registerbad", $e->{-template}, $e->stringify());
        $this->assert_str_equals("reset_bad", $e->{-def});
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };
    $this->assert_equals(0, scalar(@mails));
}


sub test_resetPasswordNeedPrivilegeForMultipleReset {
    my $this = shift;
    # This time we don't set up the testWikiName, so it should fail.

    my $query = new CGI (
                         {
                          '.path_info' => '/.'.$peopleWeb.'/WebHome',
                          'LoginName' => [
                                          $testUserWikiName,
                                          $testUserWikiName
                                         ],
                          'TopicName' => [
                                          'ResetPassword'
                                         ],
                          'action' => [
                                       'resetPassword'
                                      ]
                         });

    $session = new TWiki("Main", $guestLoginName,
                         'ResetPassword', $query->url, $query);
    $session->{net}->setMailHandler(\&sentMail);

    try {
        TWiki::UI::Register::resetPassword($session);
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);

    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_matches(qr/Main\.TWikiAdminGroup/, $e->stringify());
        $this->assert_str_equals('accessdenied', $e->{-template});
        $this->assert_str_equals('group', $e->{-def});
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };
    $this->assert_equals(0, scalar(@mails));
}

# This test is supposed to ensure that the system can reset passwords for a user
# currently absent from .htpasswd
sub test_resetPasswordNoPassword {
    my $this = shift;

    $this->registerAccount();

    my $query = new CGI (
                         {
                          '.path_info' => '/'.$peopleWeb.'/WebHome',
                          'LoginName' => [
                                          $testUserWikiName
                                         ],
                          'TopicName' => [
                                          'ResetPassword'
                                         ],
                          'action' => [
                                       'resetPassword'
                                      ]
                         });

    unlink $TWiki::cfg{HtpasswdFileName};

    $session = new TWiki("Main", $guestLoginName,
                         'ResetPassword', $query->url, $query);
    $session->{net}->setMailHandler(\&sentMail);

    try {
        TWiki::UI::Register::resetPassword($session);
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);

    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("registerok", $e->{-template});
        $this->assert_str_equals("reset_ok", $e->{-def});
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };
    $this->assert_equals(0, scalar(@mails));
}


my $name;
my $code;
my $dir;
my %regSave;

sub setupUnregistered {
    $name = "MartinCleaver";
    $code = "$name.ba";


    %regSave = (doh => "homer",
                VerificationCode => $code,
                WikiName => $name
               );
}

=pod
Create an incomplete registration, and try to finish it off.
Once complete, try again - the second attempt at completion should fail.
=cut

sub test_UnregisteredUser {
    my $this = shift;

    UnregisteredUser::_putRegDetailsByCode(\%regSave, $approvalsDir);

    my %result = %{UnregisteredUser::_getRegDetailsByCode($code, $approvalsDir)};
    $this->assert_equals("homer", $result{doh} );

    my %result2 = UnregisteredUser::reloadUserContext($code, $approvalsDir);
    $this->assert_deep_equals(\%result2, \%regSave);

    try {
        # this is a deliberate attempt to reload an already used token.
        # this should fail!
        UnregisteredUser::deleteUserContext( $code, $approvalsDir );
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_matches(qr/has no file/, $e->stringify());
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    };
    # $this->assert_null( UnregisteredUser::reloadUserContext($code));
    $this->assert_equals(0, scalar(@mails));
}

sub test_missingElements {
    my $this = shift;
    my @present = ("one","two","three");
    my @required = ("one","two","six");


    $this->assert_deep_equals([TWiki::UI::Register::_missingElements(\@present, \@required)], ["six"]);
    $this->assert_deep_equals( [TWiki::UI::Register::_missingElements(\@present, \@present)], []);
}

sub test_bulkRegister {
    my $this = shift;

    my $testReg = <<'EOM';
| FirstName | LastName | Email | WikiName | LoginName | CustomFieldThis | SomeOtherRandomField | WhateverYouLike |
| Test | User | Martin.Cleaver@BCS.org.uk |  TestBulkUser1 | a | A | B | C |
| Test | User2 | Martin.Cleaver@BCS.org.uk | TestBulkUser2 | b | A | B | C |
| Test | User3 | Martin.Cleaver@BCS.org.uk | TestBulkUser3 | c | A | B | C |
EOM
    
    my $regTopic = 'UnprocessedRegistrations2';
    
    my $logTopic = 'UnprocessedRegistrations2Log';
    my $file = $TWiki::cfg{DataDir}.'/'.$temporaryWeb.'/'.$regTopic.'.txt';
    my $fh = new FileHandle;
    
    die "Can't write $file" unless ($fh->open(">$file"));
    print $fh $testReg;
    $fh->close;

    my $query = new CGI ({
                          'LogTopic' => [
                                         $logTopic
                                        ],
                          'EmailUsersWithDetails' => [
                                                      '0'
                                                     ],
                          'OverwriteHomeTopics' => [
                                                    '1'
                                                   ],
                          '.path_info' => "/$temporaryWeb/$regTopic",
                         });

    $session = new TWiki("Main", "testuser",
                         "", $query->url, $query);
    $session->{net}->setMailHandler(\&sentMail);
    $session->{users}->findUser( "testuser" )->{isKnownAdmin} = 1;
    $session->{topicName} = $regTopic;
    $session->{webName} = $temporaryWeb;
    try {
        TWiki::UI::Register::bulkRegister($session)

    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert(0, $e->stringify()." EXPECTED");

    } catch Error::Simple with {
        my $e = shift;
        $this->assert(0, $e->stringify);

    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);

    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };
    $this->assert_equals(0, scalar(@mails));
}

sub test_buildRegistrationEmail {
    my ($this) = shift;

    my %data = (
                'CompanyName' => '',
                'Country' => 'Saudi Arabia',
                'Password' => 'mypassword',
                'form' => [
                           {
                            'value' => 'Test User',
                            'required' => '1',
                            'name' => 'Name'
                           },
                           {
                            'value' => $testUserEmail,
                            'required' => '1',
                            'name' => 'Email'
                           },
                           {
                            'value' => '',
                            'required' => '0',
                            'name' => 'CompanyName'
                           },
                           {
                            'value' => '',
                            'required' => '0',
                            'name' => 'CompanyURL'
                           },
                           {
                            'value' => 'Saudi Arabia',
                            'required' => '1',
                            'name' => 'Country'
                           },
                           {
                            'value' => '',
                            'required' => '0',
                            'name' => 'Comment'
                           },
                           {
                            'value' => 'mypassword',
                            'name' => 'Password',
                           }
                          ],
                'VerificationCode' => $testUserWikiName.'.foo',
                'Name' => 'Test User',
                'webName' => $peopleWeb,
                'WikiName' => $testUserWikiName,
                'Comment' => '',
                'CompanyURL' => '',
                'passwordA' => 'mypassword',
                'passwordB' => 'mypassword',
                'Email' => $testUserEmail,
                'debug' => 1,
                'Confirm' => 'mypassword'
               );

    my $expected = <<EOM;
Test User - $testUserWikiName - $testUserEmail

   * Name: Test User
   * Email: $testUserEmail
   * CompanyName: 
   * CompanyURL: 
   * Country: Saudi Arabia
   * Comment: 
   * Password: mypassword
EOM

    $session = new TWiki("Main", $TWiki::cfg{DefaultUserName});
    $session->{net}->setMailHandler(\&sentMail);

    my $actual = TWiki::UI::Register::_buildConfirmationEmail
       ($session,
        \%data,
        "%FIRSTLASTNAME% - %WIKINAME% - %EMAILADDRESS%\n\n%FORMDATA%",0);

    $this->assert_equals( $expected, $actual );
    $this->assert_equals(0, scalar(@mails));
}


=pod
  call this if you want to make spaces and \ns visible
=cut
sub visible {
  return $_[0];
 my ($a) = @_;
 $a =~ s/\n/NL/g;
 $a =~ s/\r/CR/g;
 $a =~ s/ /SP/g;
 $a;
}

1;


