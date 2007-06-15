use strict;

package ClientTests;

# This is woefully incomplete, but it does at least check that
# LoginManager.pm compiles okay.

use base qw(TWikiTestCase);

use CGI;
use Error qw( :try );

use TWiki;
use TWiki::LoginManager;
use TWiki::UI::View;
use TWiki::UI::Edit;

my $agent = 'TWikiRegistrationAgent';
my $userLogin;
my $userWikiName;
my $user_id;

sub new {
    my $this = shift()->SUPER::new(@_);
    my $var = $_[0];
    $var =~ s/\W//g;
    $this->{test_web} = 'Temporary'.$var.'TestWeb'.$var;
    $this->{test_topic} = 'TestTopic'.$var;
    $this->{users_web} = 'Temporary'.$var.'UsersWeb';
    $this->{twiki} = undef;
    return $this;
}

sub list_tests {
    my $this = shift;
    my @set = $this->SUPER::list_tests(@_);

    my $clz = new Devel::Symdump(qw(ClientTests));
    for my $i ($clz->functions()) {
        next unless $i =~ /::verify_/;
        foreach my $LoginImpl qw( TWiki::LoginManager::TemplateLogin TWiki::LoginManager::ApacheLogin none) {
            foreach my $userManagerImpl qw( TWiki::Users::TWikiUserMapping TWiki::Users::BaseUserMapping) {
                my $fn = $i;
                $fn =~ s/\W/_/g;
                my $sfn = 'test_'.$fn.$LoginImpl.$userManagerImpl;
                $sfn =~ s/::/_/g;
                $sfn = 'ClientTests::'.$sfn;
                no strict 'refs';
                *$sfn = sub {
                    my $this = shift;
                    $TWiki::cfg{LoginManager} = $LoginImpl;
                    $TWiki::cfg{UserMappingManager} = $userManagerImpl;
                    &$i($this);
                };
                use strict 'refs';
                push(@set, $sfn);
            }
        }
    }
    return @set;
}

sub set_up {
#print STDERR "\n------------- set_up -----------------\n";
    my $this = shift;
    $this->SUPER::set_up();

    $this->{twiki} = new TWiki();
    $this->assert($TWiki::cfg{TempfileDir} && -d $TWiki::cfg{TempfileDir});
    $TWiki::cfg{UseClientSessions} = 1;
    $TWiki::cfg{PasswordManager} = "TWiki::Users::HtPasswdUser";
    $TWiki::cfg{Htpasswd}{FileName} = "$TWiki::cfg{TempfileDir}/htpasswd";
    $TWiki::cfg{AuthScripts} = "edit";
    $TWiki::cfg{Register}{EnableNewUserRegistration} = 1;
    $TWiki::cfg{UsersWebName} = $this->{users_web};
}

sub set_up_user {
    my $this = shift;
    if ($this->{twiki}->{users}->supportsRegistration()) {
        $userLogin = 'joe';
        $userWikiName = 'JoeDoe';
	    $user_id = $this->{twiki}->{users}->addUser( $userLogin, $userWikiName, 'secrect_password', 'email@home.org.au');
	    $this->annotate("create $userLogin user - cUID = $user_id\n");
    } else {
        $userLogin = $TWiki::cfg{AdminUserLogin};
        $user_id = $this->{twiki}->{users}->getCanonicalUserID($userLogin);
        $userWikiName = $this->{twiki}->{users}->getWikiName($user_id);
	    $this->annotate("no rego support (using admin)\n");
    }
#print STDERR "\n------------- set_up_user (login: $userLogin) (cUID:$user_id) -----------------\n";
}

sub tear_down {
    my $this = shift;
    eval {$this->{twiki}->finish()};
    $this->SUPER::tear_down();
}

sub capture {
    my $this = shift;
    my( $proc, $twiki ) = @_;
    $twiki->{users}->{loginManager}->checkAccess();
    $this->SUPER::capture( @_ );
}

sub verify_edit {
#print STDERR "\n------------- verify_edit -----------------\n";

    my $this = shift;
    my ( $query, $text );

    #close this TWiki session - its using the wrong mapper and login
    $this->{twiki}->finish();

    $query = new CGI({});
    $query->path_info( "/Main/WebHome" );
    $ENV{SCRIPT_NAME} = "edit";
    $this->{twiki} = new TWiki( undef, $query );
    delete $ENV{SCRIPT_NAME};

    $this->set_up_user();
    try {
        $text = $this->capture( \&TWiki::UI::View::view, $this->{twiki} );
    } catch TWiki::OopsException with {
        $this->assert(0,shift->stringify());
    } catch Error::Simple with {
        $this->assert(0,shift->stringify());
    };

    $query = new CGI ({});
    $query->path_info( "/Main/WebHome?breaklock=1" );
    $this->{twiki}->finish();

    $ENV{SCRIPT_NAME} = "edit";
    $this->{twiki} = new TWiki( undef, $query );
    delete $ENV{SCRIPT_NAME};

    try {
        $text = $this->capture( \&TWiki::UI::Edit::edit, $this->{twiki} );
    } catch TWiki::AccessControlException with {
    } catch Error::Simple with {
        $this->assert(0,shift->stringify());
    } otherwise {
        unless( $TWiki::cfg{LoginManager} eq 'none' ) {
            $this->assert(0, "expected an oops redirect ".
                            $TWiki::cfg{LoginManager});
        }
    };

    $query = new CGI ({});
    $query->path_info( "/Main/WebHome" );
    $this->{twiki}->finish();

    $this->annotate("new session using $userLogin\n");
    $this->{twiki}->finish();

    $ENV{SCRIPT_NAME} = "edit";
    $this->{twiki} = new TWiki( $userLogin, $query );
    delete $ENV{SCRIPT_NAME};

    #clear the lease - one of the previous tests may have different usermapper & thus different user
    TWiki::Func::setTopicEditLock('Main', 'WebHome', 0);
    try {
        $text = $this->capture( \&TWiki::UI::Edit::edit, $this->{twiki} );
    } catch TWiki::OopsException with {
        $this->assert(0,shift->stringify());
    } catch Error::Simple with {
        $this->assert(0,shift->stringify());
    } otherwise {
	    $this->assert(0,shift->stringify());
    };
}


1;
