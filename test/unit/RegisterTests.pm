require 5.008;

package RegisterTests;

# Tests not implemented:
		#test_registerTwiceWikiName
		#test_registerTwiceEmailAddress
		#test_bulkResetPassword
		#test_registerIllegitimateBypassApprove
                #test_registerVerifyAndFinish

#Uncomment to isolate 
#our @TESTS = qw(test_UnregisteredUser);

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

my $scriptUrl = "http://registertesttwiki.mrjc.com/twiki/bin";

my $testUserWikiName = 'TestUser';
my $testUserLoginName = 'testuser';
my $testUserEmail = 'martin.cleaver@BCS.org.uk';

my $adminLoginName = 'mrjcleaver';
my $guestLoginName = 'guest';

my $temporaryWeb = "Temporary";
my $peopleWeb = "Main";
my $mainweb = "$peopleWeb";
my $tempUserDir;
my $twikiUsersFile;

$TWiki::User::password = "foo";

sub new {
    my $self = shift()->SUPER::new(@_);
    # your state for fixture here
    return $self;
}

my $myDataDir;
my $myPubDir;
my $saveDD;
my $savePD;
my $saveHP;

sub set_up {
    my $self = shift;
    my $here = `pwd`;
    $here =~ s/\s//g;;
    $myDataDir = "$here/tmpRegisterTestData";
    $myPubDir =  "$here/tmpRegisterTestPub";

    # SMELL: should be a better way to do this. Copy deeply?
    $saveDD = $TWiki::cfg{DataDir};
    $savePD = $TWiki::cfg{PubDir};
    $saveHP = $TWiki::cfg{HtpasswdFileName};

    $TWiki::cfg{DataDir} = $myDataDir;
    $TWiki::cfg{PubDir} = $myPubDir;
    $TWiki::cfg{HtpasswdFileName} = "$myDataDir/htpasswd";

    $tempUserDir = $TWiki::cfg{DataDir};

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
    $TWiki::UI::Register::unitTestMode = 1;
    setupUnregistered();

    $twikiUsersFile = "$TWiki::cfg{DataDir}/Main/TWikiUsers.txt";
}

sub tear_down {
    # clean up after test
    `rm -rf $myDataDir $myPubDir`;
    $TWiki::cfg{DataDir} = $saveDD;
    $TWiki::cfg{PubDir} = $savePD;
    $TWiki::cfg{HtpasswdFileName} = $saveHP;
}

sub initialise {
    my ( $query, $remoteUser ) = @_;
    my $topic = $query->param( 'topic' ) || $query->param( 'TopicName' ); # SMELL - why both? what order?
    return new TWiki("Main", $remoteUser, $topic, $query->url, $query);
}

sub register {
    my $self = shift;

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
    my $session = initialise($query, $TWiki::cfg{DefaultUserName});
    TWiki::UI::Register::register($session, 1, $tempUserDir);
}

sub j {
    return join("\r\n",@_);
}

=pod
---++ Calls verify

=cut

sub verify {
    my $self = shift;
    my $code = shift || $testUserWikiName.".foo";
    my $query = new CGI ({ 
                          'code' => [
                                     $code
                                    ],
                          'action' => [
                                       'verify'
                                      ]
                         });

    my $session = initialise($query, $TWiki::cfg{DefaultUserName});

    TWiki::UI::Register::verifyEmailAddress($session,$tempUserDir,1);
}

=pod
---++ finish
Calls 

=cut 

sub finish {
    my $self = shift;
    my $code = shift;

    my $query = new CGI({
                         'code' => [
                                    $testUserWikiName.".foo"
                                   ],
                         'action' => [
                                      'verify'
                                     ]
                        });
    my $session = initialise($query, $TWiki::cfg{DefaultUserName});
    try {
        TWiki::UI::Register::finish ( $session, $tempUserDir, 1 );
    } catch TWiki::UI::OopsException with {
        my $e = shift;
        $self->assert_matches(qr/$testUserEmail/, $e->{-text});
        $self->assert_str_equals("regthanks", $e->{-template});
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $self->assert(0, $e->stringify);
    } catch Error::Simple with {
        my $e = shift;
        $self->assert(0, $e->stringify);
    } otherwise {
        $self->assert(0, "expected an oops redirect");
    }
}

sub registerAccount {
    my $self = shift;
    $self->test_registerVerifyOk();
    $self->finish();
}

=pod
---++ test_registerVerifyOk
Register a user, and then verify it
Assumes the verification code is foo

=cut

sub test_registerVerifyOk {
    my $self = shift;
    try {
        $self->register();
    } catch TWiki::UI::OopsException with {
        my $e = shift;
        $self->assert_str_equals("regconfirm", $e->{-template});
        $self->assert_matches(qr/$testUserEmail/, $e->{-text});
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $self->assert(0, $e->stringify);
    } otherwise {
        $self->assert(0, "expected an oops redirect");
    };

    try {
        $self->verify();
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $self->assert(0, $e->stringify);

    } catch TWiki::UI::OopsException with {
        my $e = shift;
        $self->assert(0, $e->stringify );
    }
}

=pod 
---++ test_registerBadVerify()

Register a user, then give a bad verification code. It should barf.

=cut

sub test_registerBadVerify {
    my $self = shift;
    try {
        $self->register();
    } catch TWiki::UI::OopsException with {
        my $e = shift;
        $self->assert_matches(qr/$testUserEmail/, $e->{-text});
        $self->assert_str_equals("regconfirm", $e->{-template});
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $self->assert(0, $e->stringify);

    } otherwise {
        $self->assert(0, "expected an oops redirect");
    }
    try {
        $self->verify($testUserWikiName.'.bad');
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $self->assert(0, $e->stringify);

    } catch TWiki::UI::OopsException with {
    } otherwise {
        $self->assert(0, "Expected a redirect" );
    }
}

################################################################################
################################ RESET PASSWORD TESTS ##########################

sub test_resetPasswordOkay {
    my $self = shift;

    ## Need to create an account (else oopsnotwikiuser)
    ### with a known email address (else oopsregemail)

    $self->registerAccount();

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

    my $session = initialise($query, $guestLoginName);
    try {
        TWiki::UI::Register::resetPassword($session);
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $self->assert(0, $e->stringify);

    } catch TWiki::UI::OopsException with {
        my $e = shift;
        $self->assert_str_equals("resetpasswd", $e->{-template});
    } otherwise {
        $self->assert(0, "expected an oops redirect");
    }
}

sub test_resetPasswordNoSuchUser {
    my $self = shift;
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

    my $session = initialise($query, $guestLoginName);
    try {
        TWiki::UI::Register::resetPassword($session);
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $self->assert(0, $e->stringify);

    } catch TWiki::UI::OopsException with {
        my $e = shift;
        $self->assert_str_equals("notwikiuser", $e->{-template});
    } otherwise {
        $self->assert(0, "expected an oops redirect");
    }
}


sub test_resetPasswordNeedPrivilegeForMultipleReset {
    my $self = shift;
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

    my $session = initialise($query, $guestLoginName);
    try {
        TWiki::UI::Register::resetPassword($session);
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $self->assert(0, $e->stringify);

    } catch TWiki::UI::OopsException with {
        my $e = shift;
        $self->assert_matches(qr/Main\.TWikiAdminGroup/, $e->{-text});
        $self->assert_str_equals("accessgroup", $e->{-template});
    } otherwise {
        $self->assert(0, "expected an oops redirect");
    }
}

# This test is supposed to ensure that the system can reset passwords for a user
# currently absent from .htpasswd
sub test_resetPasswordNoPassword {
    my $self = shift;

    $self->registerAccount();

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

    my $session = initialise($query, $guestLoginName);
    try {
        TWiki::UI::Register::resetPassword($session);
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $self->assert(0, $e->stringify);

    } catch TWiki::UI::OopsException with {
        my $e = shift;
        $self->assert_str_equals("notwikiuser", $e->{-template});
    } otherwise {
        $self->assert(0, "expected an oops redirect");
    }
}


################################################################################

my $name;
my $code;
my $dir;
my %regSave;

sub setupUnregistered {
    $name = "MartinCleaver";
    $code = "$name.ba";
    $dir = $tempUserDir;

    %regSave = (doh => "homer",
                VerificationCode => $code,
                WikiName => $name
               );
    UnregisteredUser::setDir("$dir/TWiki/RegistrationApprovals"); #mirrors real situation
}

=pod
Create an incomplete registration, and try to finish it off.
Once complete, try again - the second attempt at completion should fail.
=cut

sub test_UnregisteredUser {
    my $self = shift;

    UnregisteredUser::putRegDetailsByCode(\%regSave);

    my %result = %{UnregisteredUser::_getRegDetailsByCode($code)};
    $self->assert_equals("homer", $result{doh} );

    my %result2 = UnregisteredUser::reloadUserContext($code);
    $self->assert_deep_equals(\%result2, \%regSave);

    UnregisteredUser::deleteUserContext( $code );
    # if _deleteUserContext is commented out this will fail!
    $self->assert_null( UnregisteredUser::reloadUserContext($code));
}

sub test_missingElements {
    my $self = shift;
    my @present = ("one","two","three");
    my @required = ("one","two","six");


    $self->assert_deep_equals([TWiki::UI::Register::_missingElements(\@present, \@required)], ["six"]);
    $self->assert_deep_equals( [TWiki::UI::Register::_missingElements(\@present, \@present)], []);
}

sub test_bulkRegister {
    my $self = shift;

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
                         });
    #  $ENV{'SCRIPT_URL'} = "/bin/view";
    $query->script_name("/bin/view");
    $query->remote_user($adminLoginName);
    $query->path_info($regTopic);
    my $session = initialise($query, $adminLoginName);
    $session->{topicName} = $regTopic;
    $session->{webName} = $temporaryWeb;
    try {
        TWiki::UI::Register::bulkRegister($session)

    } catch TWiki::UI::OopsException with {
        my $e = shift;
        $self->assert_matches(qr/Moved.*$logTopic/, $e->{-text});

    } catch Error::Simple with {
        my $e = shift;
        $self->assert(0, $e->stringify);

    } catch TWiki::AccessControlException with {
        my $e = shift;
        $self->assert(0, $e->stringify);

    } otherwise {
        $self->assert(0, "expected an oops redirect");
    };
}

sub test_buildRegistrationEmail {
    my ($self) = shift;

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

    my $session = initialise(new CGI(""), $TWiki::cfg{DefaultUserName});
    $self->assert_equals( TWiki::UI::Register::_buildConfirmationEmail ($session, \%data,
                                                                        "%FIRSTLASTNAME% - %WIKINAME% - %EMAILADDRESS%\n\n%FORMDATA%",0), $expected);  
    
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


