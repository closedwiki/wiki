package TestRegister;

use TestCaseStdOutCapturer;
use base qw(Test::Unit::TestCase);
use lib "../../lib";
use strict;
use diagnostics;
use TWiki::UI::Register;
use Data::Dumper;
use FileHandle;
use CGI;
use Error qw( :try );

my $temporaryWeb = "Temporary";
my $peopleWeb = "Main";
my $scriptUrl = "http://registertesttwiki.mrjc.com/twiki/bin";
my $email = 'martin.cleaver@BCS.org.uk';
my $userEmail = 'yourtestuser@localhost';
my $testUserWikiName = 'TestUser3';
my $testUserLoginName = 'testuser';
my $tempUserDir = "/tmp";

$TWiki::UI::Register::password = "foo";

# Tests not implemented:
		#test_registerTwiceWikiName
		#test_registerTwiceEmailAddress
		#test_bulkResetPassword
		#test_registerIllegitimateBypassApprove
                #test_registerVerifyAndFinish

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
                                          $email
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
    my $session = initialise($query, "guest");
    TWiki::UI::Register::register(session=>$session,
                                      sendActivationCode=>1,
                                      tempUserDir=>$tempUserDir);
#    }
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

    my $session = initialise($query, "guest");

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
    my $session = initialise($query, "guest");
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
        $self->assert_str_equals($email, $e->{-text});
        $self->assert_str_equals("regconfirm", $e->{-template});
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
Assmes the verification code is foo

=cut

sub test_registerVerifyOk {
    my $self = shift;
    try {
        $self->register();
    } catch TWiki::UI::OopsException with {
        my $e = shift;
        $self->assert_matches(qr/$email/, $e->{-text});
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
        $self->assert_matches(qr/$email/, $e->{-text});
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

sub test_resetPasswordNoSuchUser {
    my $self = shift;

    my $query = new CGI (
                         {
                          '.path_info' => '/.'.$peopleWeb.'/WebHome',
                          'LoginName' => [
                                          'RichCleaver'
                                         ],
                          'TopicName' => [
                                          'ResetPassword'
                                         ],
                          'action' => [
                                       'resetPassword'
                                      ]
                         });

    my $session = initialise($query, 'guest');
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

sub test_resetPasswordNoPassword {
    my $self = shift;
    my $query = new CGI (
                         {
                          '.path_info' => '/'.$peopleWeb.'/WebHome',
                          'LoginName' => [
                                          'TWikiGuest'
                                         ],
                          'TopicName' => [
                                          'ResetPassword'
                                         ],
                          'action' => [
                                       'resetPassword'
                                      ]
                         });

    my $session = initialise($query, 'guest');
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

    my $session = initialise($query, 'guest');
    try {
        TWiki::UI::Register::resetPassword($session);
    } catch TWiki::UI::OopsException with {
        my $e = shift;
        $self->assert_str_equals($email, $e->{-text});
        $self->assert_str_equals("resetpasswd", $e->{-template});
    } otherwise {
        $self->assert(0, "expected an oops redirect");
    }
}

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
                            'value' => $userEmail,
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
                'Email' => $userEmail,
                'debug' => 1,
                'Confirm' => 'mypassword'
               );
    
    my $expected = <<EOM;
Test User - $testUserWikiName - $userEmail

   * Name: Test User
   * Email: $userEmail
   * CompanyName: 
   * CompanyURL: 
   * Country: Saudi Arabia
   * Comment: 
   * Password: mypassword
EOM

    my $session = initialise(new CGI(""), "guest");
    $self->assert_equals( TWiki::UI::Register::_buildConfirmationEmail ($session, \%data,
                                                                        "%FIRSTLASTNAME% - %WIKINAME% - %EMAILADDRESS%\n\n%FORMDATA%",0), $expected);  
    
}


my $mainweb = "$peopleWeb";


# I added a behaviour but don't want to break the old behaviour.

sub test_userToWikiName {
    my $self = shift;
    my $query = new CGI();
    my $session = initialise($query, 'guest');
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
    my $session = initialise($query, 'guest');

    {
        my ($w, $l) = TWiki::UI::Register::_getUserByEitherLoginOrWikiName($session, "guest");
        $self->assert_equals($w, "TWikiGuest");
        $self->assert_equals($l, "guest");
    }
    {
        my ($w, $l) = TWiki::UI::Register::_getUserByEitherLoginOrWikiName($session, "TWikiGuest");
        $self->assert_equals($w, "TWikiGuest");
        $self->assert_equals($l, "guest");
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
| Test | User | Martin.Cleaver@BCS.org.uk |  TestUser | a | A | B | C |
| Test | User2 | Martin.Cleaver@BCS.org.uk | TestUser2 | b | A | B | C |
| Test | User3 | Martin.Cleaver@BCS.org.uk | TestUser3 | c | A | B | C |
EOM
    
    my $regTopic = '/'.$temporaryWeb.'/UnprocessedRegistrations2';
    my $logTopic = 'UnprocessedRegistrations2Log';
    my $file = $TWiki::dataDir.$regTopic.'.txt';
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
    $query->remote_user("mrjcleaver");
    $query->path_info($regTopic);
    my $session = initialise($query, 'mrjcleaver');
    
    my $ans = Test::Unit::IO::StdoutCapture::do {
        TWiki::UI::Register::bulkRegister($session),
      } || "";


    $self->assert_equals(
                         $ans,
                         "Status: 302 Moved\r\nLocation: ".$scriptUrl."/view/".$temporaryWeb."/".$logTopic."\r\n\r\n"
                        );
}

sub Atest_works {
    my $self = shift;
    $self->assert_equals("a", "a");
}

sub Atest_thisFaultsTestUnit {
    my $self = shift;
    $self->assert_equals( "1", "2" );
}

# Test::Unit segfaults on failure for me, but this at least keeps the interface working
sub assert_equals {
    my ( $self, $compare, $with ) = @_;
    if ( $compare eq $with ) {
        #  print "ok (\n$compare == \n$with)\n";
        return 1;
    }
    else {
        $compare = visible($compare);
        $with = visible($with);
        print "failed ('\n$compare' != '\n$with') \n";
        return -1;
    }
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


