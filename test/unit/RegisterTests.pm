# This causes ntwiki to barf
#require 5.008;

package RegisterTests;

# Tests not implemented:
		#notest_registerTwiceWikiName
		#notest_registerTwiceEmailAddress
		#notest_bulkResetPassword
		#notest_registerIllegitimateBypassApprove
                #notest_registerVerifyAndFinish
                #test_DoubleRegistration (loginname already used)

#Uncomment to isolate 
#our @TESTS = qw(notest_registerVerifyOk); #notest_UnregisteredUser);

use base qw(TWikiTestCase);
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
use File::Path;
use Carp;
use Cwd;

my $testUserWikiName = 'TestUser';
my $testUserLoginName = 'testuser';
my $testUserEmail = 'kakapo@ground.dwelling.parrot.net';

my $guestLoginName = 'guest';

my $testWeb = "TemporaryRegisterTestsTestWeb";
my $peopleWeb = "TemporaryRegisterTestsPeopleWeb";
my $systemWeb = "TemporaryRegisterTestsSystemWeb";

# SMELL: the sent mails are never checked in the tests
my @mails;

$TWiki::User::password = "foo";

sub new {
    my $this = shift()->SUPER::new(@_);
    # your state for fixture here
    return $this;
}

my $session;
my $save;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $session = new TWiki();

    $SIG{__DIE__} = sub { confess $_[0] };

    try {
        $session->{store}->createWeb($session->{user}, $testWeb);
        $session->{store}->createWeb($session->{user}, $peopleWeb,
                                     $TWiki::cfg{UsersWebName});
        $TWiki::cfg{UsersWebName} = $peopleWeb;
        $session->{store}->saveTopic($session->{user}, $peopleWeb,
                                     'TWikiAdminGroup',
                                     "   * Set GROUP = TestAdmin\n");
        $session->{store}->saveTopic($session->{user}, $peopleWeb,
                                     'NewUserTemplate',
                                     '%NOP{Ignore this}%
But not this
%SPLIT%
\t* Set %KEY% = %VALUE%
%SPLIT%
%WIKIUSERNAME%
%WIKINAME%
%USERNAME%
AFTER');
        my $user = $session->{users}->findUser("TestAdmin", "TestAdmin");
        $session->{store}->createWeb($user, $systemWeb,
                                     $TWiki::cfg{SystemWebName});
        $TWiki::cfg{SystemWebName} = $systemWeb;
    } catch TWiki::AccessControlException with {
        $this->assert(0,shift->stringify());
    } catch Error::Simple with {
        $this->assert(0,shift->stringify());
    };

    $TWiki::cfg{HtpasswdFileName} = "/tmp/htpasswd";
    $TWiki::cfg{RegistrationApprovals} = '/tmp/RegistrationApprovals';

    $Error::Debug = 1;

    setupUnregistered();

    @mails = ();
}

sub tear_down {
    my $this = shift;

    $session->{store}->removeWeb($session->{user},$testWeb);
    $session->{store}->removeWeb($session->{user},$peopleWeb);
    $session->{store}->removeWeb($session->{user},$systemWeb);
    File::Path::rmtree($TWiki::cfg{RegistrationApprovals});
    unlink($TWiki::cfg{HtpasswdFileName});
    @mails = ();

    $this->SUPER::tear_down();
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
        TWiki::UI::Register::finish( $session, $TWiki::cfg{RegistrationApprovals} );
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention", $e->{template});
        $this->assert_str_equals("thanks", $e->{def});
        $this->assert_equals(2, scalar(@mails));
        my $done = '';
        foreach my $mail ( @mails ) {
            if( $mail =~ /^Subject:.*Registration for/m ) {
                if( $mail =~ /^To: .*\b$testUserEmail\b/m ) {
                    $this->assert(!$done, $done."\n---------\n".$mail);
                    $done = $mail;
                } else {
                    $this->assert_matches(qr/To: %WIKIWEBMASTER/, $mail );
                }
            } else {
                $this->assert(0, $mail);
            }
        }
        $this->assert($done);
        @mails = ();
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } catch Error::Simple with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    }
}

sub test_userTopic {
    my $this = shift;
    $this->registerAccount();
    my( $meta, $text ) = $session->{store}->readTopic(
        undef, $TWiki::cfg{UsersWebName}, $testUserWikiName);
    $this->assert($text !~ /Ignore this%/, $text);
    $this->assert($text =~ s/But not this//,$text);
    $this->assert($text =~ s/\t*\* First Name: Test\n//,$text);
    $this->assert($text =~ s/\t*\* Email: kakapo\@ground.dwelling.parrot.net\n//,$text);
    $this->assert($text =~ s/\t*\* Comment:\s*\n//,$text);
    $this->assert($text =~ s/\t*\* Last Name: User\n//,$text);
    $this->assert($text =~ s/\t*\* Name: Test User\n//,$text);
    $this->assert($text =~ s/$TWiki::cfg{UsersWebName}\.$testUserWikiName//,$text);
    $this->assert($text =~ s/$testUserWikiName//,$text);
    $this->assert_matches(qr/\s*AFTER\s*/, $text);
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

    $query->path_info( "/$peopleWeb/TWikiRegistration" );
    $session = new TWiki( $TWiki::cfg{DefaultUserName}, $query);
    $session->{net}->setMailHandler(\&sentMail);

    try {
        TWiki::UI::Register::register_cgi($session);
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention", $e->{template},$e->stringify());
        $this->assert_str_equals("confirm", $e->{def});
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
    $query->path_info( "/$peopleWeb/TWikiRegistration" );
    $session = new TWiki( $TWiki::cfg{DefaultUserName},$query);
    $session->{net}->setMailHandler(\&sentMail);

    try {
        TWiki::UI::Register::verifyEmailAddress($session, $TWiki::cfg{RegistrationApprovals});
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);

    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert( 0, $e->stringify );
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    };
    $this->assert_equals(1, scalar(@mails));
    my $done = '';
    foreach my $mail ( @mails ) {
        if( $mail =~ /Your verification code is /m ) {
            $this->assert(!$done, $done."\n---------\n".$mail);
            $done = $mail;
        } else {
            $this->assert(0, $mail);
        }
    }
    $this->assert($done);
    @mails = ();
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
    $query->path_info( "/$peopleWeb/TWikiRegistration" );
    $session = new TWiki( $TWiki::cfg{DefaultUserName}, $query);
    $session->{net}->setMailHandler(\&sentMail);
    try {
        TWiki::UI::Register::register_cgi($session);
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_matches(qr/$testUserEmail/, $e->stringify());
        $this->assert_str_equals("attention", $e->{template});
        $this->assert_str_equals("confirm", $e->{def});
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
    $query->path_info( "/$peopleWeb/TWikiRegistration" );
    $session = new TWiki( $TWiki::cfg{DefaultUserName}, $query);
    $session->{net}->setMailHandler(\&sentMail);

    try {
        TWiki::UI::Register::verifyEmailAddress($session,$TWiki::cfg{RegistrationApprovals});
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);

    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention",$e->{template});
        $this->assert_str_equals("bad_ver_code",$e->{def});
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "Expected a redirect" );
    };
    $this->assert_equals(1, scalar(@mails));
    my $mess = $mails[0];
    $this->assert_matches(qr/From: %WIKIWEBMASTER/,$mess);
    $this->assert_matches(qr/To: .*\b$testUserEmail\b/,$mess);
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

    $query->path_info( '/'.$peopleWeb.'/WebHome' );
    $session = new TWiki( $guestLoginName, $query);
    $session->{net}->setMailHandler(\&sentMail);

    try {
        TWiki::UI::Register::resetPassword($session);
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention", $e->{template});
        $this->assert_str_equals("reset_ok", $e->{def});
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };
    $this->assert_equals(1, scalar(@mails));
    my $mess = $mails[0];
    $this->assert_matches(qr/From: %WIKIWEBMASTER/,$mess);
    $this->assert_matches(qr/To: .*\b$testUserEmail/,$mess);
}

sub test_resetPasswordNoSuchUser {
    my $this = shift;
    # This time we don't set up the testWikiName, so it should fail.

    my $query = new CGI (
                         {
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

    $query->path_info( '/.'.$peopleWeb.'/WebHome' );
    $session = new TWiki( $guestLoginName, $query);
    $session->{net}->setMailHandler(\&sentMail);

    try {
        TWiki::UI::Register::resetPassword($session);
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);

    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention", $e->{template}, $e->stringify());
        $this->assert_str_equals("reset_bad", $e->{def});
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

    $query->path_info( '/.'.$peopleWeb.'/WebHome' );
    $session = new TWiki( $guestLoginName, $query);
    $session->{net}->setMailHandler(\&sentMail);

    try {
        TWiki::UI::Register::resetPassword($session);
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);

    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_matches(qr/$peopleWeb\.TWikiAdminGroup/, $e->stringify());
        $this->assert_str_equals('accessdenied', $e->{template});
        $this->assert_str_equals('only_group', $e->{def});
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

    $query->path_info( '/'.$peopleWeb.'/WebHome' );
    unlink $TWiki::cfg{HtpasswdFileName};

    $session = new TWiki( $guestLoginName, $query);
    $session->{net}->setMailHandler(\&sentMail);

    try {
        TWiki::UI::Register::resetPassword($session);
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0, $e->stringify);

    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("attention", $e->{template});
        $this->assert_str_equals("reset_ok", $e->{def});
    } catch Error::Simple with {
        $this->assert(0, shift->stringify());
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };
    my $mess = $mails[0];
    $this->assert_matches(qr/From: %WIKIWEBMASTER/,$mess);
    $this->assert_matches(qr/To: .*\b$testUserEmail/,$mess);
    $this->assert_matches(qr/Subject: TWiki password reset/,$mess);
    $this->assert_equals(1, scalar(@mails));
    @mails = ();
}


my $name;
my $code;
my $dir;
my $regSave;

sub setupUnregistered {
    $name = "MartinCleaver";
    $code = "$name.ba";


    $regSave = {
                doh => "homer",
                VerificationCode => $code,
                WikiName => $name
               };
}

=pod
Create an incomplete registration, and try to finish it off.
Once complete, try again - the second attempt at completion should fail.
=cut

sub test_UnregisteredUser {
    my $this = shift;

    TWiki::UI::Register::_putRegDetailsByCode($regSave, $TWiki::cfg{RegistrationApprovals});

    my $result = TWiki::UI::Register::_getRegDetailsByCode($code, $TWiki::cfg{RegistrationApprovals});
    $this->assert_equals("homer", $result->{doh} );

    my $result2 = TWiki::UI::Register::_reloadUserContext($code, $TWiki::cfg{RegistrationApprovals});
    $this->assert_deep_equals($result2, $regSave);

    try {
        # this is a deliberate attempt to reload an already used token.
        # this should fail!
        TWiki::UI::Register::_deleteUserContext( $code, $TWiki::cfg{RegistrationApprovals} );
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
    my $file = $TWiki::cfg{DataDir}.'/'.$testWeb.'/'.$regTopic.'.txt';
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

    $query->path_info( "/$testWeb/$regTopic" );
    $session = new TWiki( "testuser", $query);
    $session->{net}->setMailHandler(\&sentMail);
    $session->{users}->findUser( "testuser" )->{isKnownAdmin} = 1;
    $session->{topicName} = $regTopic;
    $session->{webName} = $testWeb;
    try {
        $this->capture( \&TWiki::UI::Register::bulkRegister, $session);
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

    $session = new TWiki( $TWiki::cfg{DefaultUserName});
    $session->{net}->setMailHandler(\&sentMail);

    my $actual = TWiki::UI::Register::_buildConfirmationEmail
       ($session,
        \%data,
        "%FIRSTLASTNAME% - %WIKINAME% - %EMAILADDRESS%\n\n%FORMDATA%",0);
    $expected =~ s/\s+//g;
    $actual =~ s/\s+//g;
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


