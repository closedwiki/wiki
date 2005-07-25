use strict;

package ClientTests;

# This is woefully incomplete, but it does at least check that
# Client.pm compiles okay.

use base qw(TWikiTestCase);

use CGI;
use Error qw( :try );

use TWiki;
use TWiki::Client;
use TWiki::UI::View;
use TWiki::UI::Edit;

my $session;
my $twikiRegistrationAgent = 'TWikiRegistrationAgent';
my ( $joe, $agent, $userTopic );

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
        foreach my $impl qw( TWiki::Client::TemplateLogin TWiki::Client::ApacheLogin none) {
            my $fn = $i;
            $fn =~ s/\W/_/g;
            my $sfn = 'ClientTests::test_'.$fn.$impl;
            no strict 'refs';
            *$sfn = sub {
                my $this = shift;
                $TWiki::cfg{LoginManager} = $impl;
                &$i($this);
            };
            use strict 'refs';
            push(@set, $sfn);
        }
    }
    return @set;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $session = new TWiki();

    $TWiki::cfg{UseClientSessions} = 1;
    $TWiki::cfg{PasswordManager} = "TWiki::Users::HtPasswdUser";
    $TWiki::cfg{Htpasswd}{FileName} = "/tmp/htpasswd";
    $TWiki::cfg{AuthScripts} = "edit";

    # $this->setup_user();
}

sub set_up_user {
    $joe = $session->{users}->findUser( "joe", "Main.JoeDoe" );
    $agent = $session->{users}->findUser( $twikiRegistrationAgent,
                                          $twikiRegistrationAgent);
    $userTopic = 
      $session->{users}->addUserToTWikiUsersTopic( $joe, $agent);
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
}

sub capture {
    my $this = shift;
    my( $proc, $session ) = @_;
    $session->{client}->checkAccess();
    $this->SUPER::capture( @_ );
}

sub verify_edit {
    my $this = shift;
    my ( $query, $text );

    $query = new CGI ({});
    $query->path_info( "/Main/WebHome" );
    $ENV{SCRIPT_NAME} = "view";
    $session = new TWiki( undef, $query );
    try {
        $text = $this->capture( \&TWiki::UI::View::view, $session );
    } catch TWiki::OopsException with {
        $this->assert(0,shift->stringify());
    } catch Error::Simple with {
        $this->assert(0,shift->stringify());
    };

    $query = new CGI ({});
    $query->path_info( "/Main/WebHome" );
    $ENV{SCRIPT_NAME} = "edit";
    $session = new TWiki( undef, $query );

    try {
        $text = $this->capture( \&TWiki::UI::Edit::edit, $session );
    } catch TWiki::AccessControlException with {
    } catch Error::Simple with {
        $this->assert(0,shift->stringify());
    } otherwise {
        $this->assert(0, "expected an oops redirect");
    };

    $query = new CGI ({});
    $query->path_info( "/Main/WebHome" );
    $ENV{SCRIPT_NAME} = "edit";
    $session = new TWiki( "joe", $query );

    try {
        $text = $this->capture( \&TWiki::UI::Edit::edit, $session );
    } catch TWiki::OopsException with {
        $this->assert(0,shift->stringify());
    } catch Error::Simple with {
        $this->assert(0,shift->stringify());
    };
}

1;
