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

my $session;
my $agent = 'TWikiRegistrationAgent';
my $userLogin;
my $userWikiName;
my $user_id;

sub new {
    my $this = shift()->SUPER::new(@_);
    return $this;
}

sub list_tests {
    my $this = shift;
    my @set = $this->SUPER::list_tests();

    my $clz = new Devel::Symdump(qw(ClientTests));
    for my $i ($clz->functions()) {
        next unless $i =~ /::verify_/;
        foreach my $LoginImpl qw( TWiki::LoginManager::TemplateLogin TWiki::LoginManager::ApacheLogin none) {
            foreach my $userManagerImpl qw( TWiki::Users::TWikiUserMapping TWiki::Users::BaseUserMapping) {
                my $fn = $i;
                $fn =~ s/\W/_/g;
                my $sfn = 'ClientTests::test_'.$fn.$LoginImpl.$userManagerImpl;
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

    $session = new TWiki();

    $TWiki::cfg{UseClientSessions} = 1;
    $TWiki::cfg{PasswordManager} = "TWiki::Users::HtPasswdUser";
    $TWiki::cfg{Htpasswd}{FileName} = "/tmp/junkhtpasswd";      #TODO: um, shouldn't we have a private dir, that is deleteable
    $TWiki::cfg{AuthScripts} = "edit";
    $TWiki::cfg{Register}{EnableNewUserRegistration} = 1;
}

sub set_up_user {
    my $this = shift;
    if ($session->{users}->supportsRegistration()) {
        $userLogin = 'joe';
        $userWikiName = 'JoeDoe';    
	    $user_id = $session->{users}->addUser( $userLogin, $userWikiName, 'secrect_password', 'email@home.org.au');
	    $this->annotate("create $userLogin user - cUID = $user_id\n");
	    #TODO: figure out why $user_id is comming back as the password..
    } else {
        $userLogin = 'admin';
        $user_id = $session->{users}->getCanonicalUserID($userLogin);
        $userWikiName = $session->{users}->getWikiName($user_id);
	    $this->annotate("no rego support (using admin)\n");
    }
#print STDERR "\n------------- set_up_user (login: $userLogin) (cUID:$user_id) -----------------\n";
}

sub tear_down {
    my $this = shift;
    eval {$session->finish()};
    $this->SUPER::tear_down();
}

sub capture {
    my $this = shift;
    my( $proc, $session ) = @_;
    $session->{users}->{loginManager}->checkAccess();
    $this->SUPER::capture( @_ );
}

sub verify_edit {
#print STDERR "\n------------- verify_edit -----------------\n";

    my $this = shift;
    my ( $query, $text );

    $query = new CGI ({});
    $query->path_info( "/Main/WebHome" );
    $ENV{SCRIPT_NAME} = "view";
    $session->finish();#close this TWiki session - its using the wrong mapper and login
    $session = new TWiki( undef, $query );
    $this->set_up_user();
    try {
        $text = $this->capture( \&TWiki::UI::View::view, $session );
    } catch TWiki::OopsException with {
        $this->assert(0,shift->stringify());
    } catch Error::Simple with {
        $this->assert(0,shift->stringify());
    };

    $query = new CGI ({});
    $query->path_info( "/Main/WebHome?breaklock=1" );
    $ENV{SCRIPT_NAME} = "edit";
    $session->finish();
    $session = new TWiki( undef, $query );

    try {
        $text = $this->capture( \&TWiki::UI::Edit::edit, $session );
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
    $ENV{SCRIPT_NAME} = "edit";
    $session->finish();

    $this->annotate("new session using $userLogin\n");
    $session = new TWiki( $userLogin, $query );
    
    #clear the lease - one of the previous tests may have different usermapper & thus different user
    TWiki::Func::setTopicEditLock('Main', 'WebHome', 0);
    try {
        $text = $this->capture( \&TWiki::UI::Edit::edit, $session );
    } catch TWiki::OopsException with {
        $this->assert(0,shift->stringify());
    } catch Error::Simple with {
        $this->assert(0,shift->stringify());
    } otherwise {
	    $this->assert(0,shift->stringify());
    };
}


1;
