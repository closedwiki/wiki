package RegisterTests;

# Tests not implemented:
		#test_registerTwiceWikiName
		#test_registerTwiceEmailAddress
		#test_bulkResetPassword
		#test_registerIllegitimateBypassApprove
                #test_registerVerifyAndFinish

#Uncomment to isolate 
#our @TESTS = qw(test_bulkRegister);

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

my $scriptUrl = "http://registertesttwiki.mrjc.com/twiki/bin";

my $testUserWikiName = 'TestUser';
my $testUserLoginName = 'testuser';
my $testUserEmail = 'martin.cleaver@BCS.org.uk';

my $adminLoginName = 'mrjcleaver';
my $guestLoginName = 'guest';

my $temporaryWeb = "Temporary";
my $peopleWeb = "Main";
my $mainweb = "$peopleWeb";
my $tempUserDir = "/tmp";
my $saveHtpasswd = $tempUserDir.'/rcsr$$'; # not saved as '.htpasswd' to minimise onlookers interest.
my $twikiUsersFile = "$TWiki::dataDir/Main/TWikiUsers.txt";
my $saveTWikiUsers = $tempUserDir.'/rcsrUsers$$';

$TWiki::UI::Register::password = "foo";


sub new {
    my $self = shift()->SUPER::new(@_);
    # your state for fixture here
    return $self;
}

sub set_up {
    my $self = shift;
    mkdir "$TWiki::dataDir/$temporaryWeb";
    chmod 0777, "$TWiki::dataDir/$temporaryWeb";
    mkdir "$TWiki::pubDir/$temporaryWeb";
    chmod 0777, "$TWiki::pubDir/$temporaryWeb";
    $Error::Debug = 1;
    $TWiki::UI::Register::unitTestMode = 1;
    setupUnregistered();
    copy ($TWiki::htpasswdFilename, $saveHtpasswd) || die "Can't backup $TWiki::htpasswdFilename to $saveHtpasswd";
    copy ($twikiUsersFile, $saveTWikiUsers) || die "Can't backup $twikiUsersFile to $saveTWikiUsers";

    #print "--------------- ".$self->name()." ----------------------\n";
    # provide fixture
}

sub initialise {
    my ( $query, $remoteUser ) = @_;
    my $topic = $query->param( 'topic' ) || $query->param( 'TopicName' ); # SMELL - why both? what order?
    return new TWiki("Main", $remoteUser, $topic, $query->url, $query);
}

sub tear_down {
    # clean up after test
    my $file = "$TWiki::dataDir/$peopleWeb/$testUserWikiName.txt";
    unlink $file;

    copy ($saveHtpasswd, $TWiki::htpasswdFilename) || die "Can't restore $TWiki::htpasswdFilename from $saveHtpasswd";
    unlink $saveHtpasswd || die "Can't remove backup of $TWiki::htpasswdFilename saved as $saveHtpasswd";

    copy ($saveTWikiUsers, $twikiUsersFile) || die "Can't restore $twikiUsersFile from $saveTWikiUsers";
    unlink $saveTWikiUsers || die "Can't remove backup of $twikiUsersFile saved as $saveTWikiUsers";

    system "rm -rf $TWiki::dataDir/$temporaryWeb"; # smell - deleteweb
    system "rm -rf $TWiki::pubDir/$temporaryWeb"; 

    deleteUsers('TestBulkUser1', 'TestBulkUser2', 'TestBulkUser3'); # should be in test_bulkRegister SMELL

    #  system ("ls -la ".$file);
    # print "\n== done ==\n";
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
    my $session = initialise($query, $TWiki::defaultUserName);
    TWiki::UI::Register::register(session=>$session,
                                      sendActivationCode=>1,
                                      tempUserDir=>$tempUserDir);
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

    my $session = initialise($query, $TWiki::defaultUserName);

    TWiki::UI::Register::verifyEmailAddress(
                                            session => $session,
                                            'code' => $code,
                                            'needApproval' => 1,
                                            'tempUserDir' => $tempUserDir,
                                           );
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
    my $session = initialise($query, $TWiki::defaultUserName);
    try {
        TWiki::UI::Register::finish (
                                     session => $session,
                                     'code' => $code,
                                     'needApproval' => 1,
                                     'tempUserDir' => $tempUserDir,
                                     'query' => $query
                                    );
    } catch TWiki::UI::OopsException with {
        my $e = shift;
        $self->assert_matches(qr/$testUserEmail/, $e->{-text});
        $self->assert_str_equals("regthanks", $e->{-template});
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
        $self->assert_matches(qr/$testUserEmail/, $e->{-text});
        $self->assert_str_equals("regconfirm", $e->{-template});
    } otherwise {
        $self->assert(0, "expected an oops redirect");
    };

    try {
        $self->verify();
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
    } otherwise {
        $self->assert(0, "expected an oops redirect");
    }
    try {
        $self->verify($testUserWikiName.'.bad');
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
    } catch TWiki::UI::OopsException with {
        my $e = shift;
        $self->assert_matches(qr/$testUserEmail/, $e->{-text});
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

    # Now restore the .htpasswd file from before the registration
    copy ($saveHtpasswd, $TWiki::htpasswdFilename) || die "Can't restore $TWiki::htpasswdFilename from $saveHtpasswd";

    my $session = initialise($query, $guestLoginName);
    try {
        TWiki::UI::Register::resetPassword($session);
    } catch TWiki::UI::OopsException with {
        my $e = shift;
        $self->assert_matches(qr/$testUserEmail/, $e->{-text});
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
    UnregisteredUser::setDir($dir);
}

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
    my ($self) = shift;
    my @present = ("one","two","three");
    my @required = ("one","two","six");


    $self->assert_deep_equals([TWiki::UI::Register::_missingElements(\@present, \@required)], ["six"]);
    $self->assert_deep_equals( [TWiki::UI::Register::_missingElements(\@present, \@present)], []);
}




# I added a behaviour but don't want to break the old behaviour.

sub test_userToWikiName {
    my $self = shift;
    my $query = new CGI();
    my $session = initialise($query, $guestLoginName);
    $self->assert_equals(
                         $session->{users}->userToWikiName("NoSuchUser")
                         ,$mainweb.".NoSuchUser");
    $self->assert_equals(
                         $session->{users}->userToWikiName("NoSuchUser",1)
                         ,"NoSuchUser");
    $self->assert_null(
                       $session->{users}->userToWikiName("NoSuchUser",2)
                      );
}

sub test_getUserByEitherLoginOrWikiName {
    my $self = shift;
    my $query = new CGI();
    my $session = initialise($query, $guestLoginName);

    {
        my ($w, $l) = TWiki::UI::Register::_getUserByEitherLoginOrWikiName($session, $TWiki::defaultUserName);
        $self->assert_equals($w, $TWiki::defaultWikiName);
        $self->assert_equals($l, $TWiki::defaultUserName);
    }
    {
        my ($w, $l) = TWiki::UI::Register::_getUserByEitherLoginOrWikiName($session, $TWiki::defaultWikiName);
        $self->assert_equals($w, $TWiki::defaultWikiName);
        $self->assert_equals($l, $TWiki::defaultUserName);
    }
    {
        my ($w, $l) = TWiki::UI::Register::_getUserByEitherLoginOrWikiName($session, "notfound");
        $self->assert_null($w);
        $self->assert_null($l);
    }
    {
        my ($w, $l) = TWiki::UI::Register::_getUserByEitherLoginOrWikiName($session, "NoSuchUser");
        $self->assert_null($w);
        $self->assert_null($l);
    }
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
    my $file = $TWiki::dataDir.'/'.$temporaryWeb.'/'.$regTopic.'.txt';
    my $fh = new FileHandle;
    
    die "Can't write $file" unless ($fh->open(">".$file));
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
    } otherwise {
        $self->assert(0, "expected an oops redirect");
    }

}

sub deleteUsers {
  my (@users) = @_;
  print "Cleaning up: ".join(", ", @users);
  foreach my $user (@users) {
    my $file = $TWiki::dataDir.'/'.$peopleWeb.'/'.$user.'.txt';
    print "deleting '$file'\n";
    unlink $file || die "Can't delete $file";
  }
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

    my $session = initialise(new CGI(""), $TWiki::defaultUserName);
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


