use strict;

package FuncUsersTests;

# Some basic tests for adding/removing users in the TWiki users topic,
# and finding them again.

use base qw(TWikiFnTestCase);

use TWiki;
use TWiki::Func;
use TWiki::UI::Register;
use Error qw( :try );
use Data::Dumper;

sub new {
    my $self = shift()->SUPER::new('FuncUsers', @_);
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $this->{twiki} = new TWiki('AdminUser');

    try {
        # Create an admin group/user
        $this->{twiki}->{store}->saveTopic(
            $this->{twiki}->{user}, $this->{users_web}, 'TWikiAdminGroup',
            '   * Set GROUP = '.$this->{twiki}->{user}->wikiName().", TWikiAdminGroup\n");

        $this->registerUser('usera', 'User', 'A', 'user@example.com');
        $this->registerUser('userb', 'User', 'B', 'user@example.com');
        $this->registerUser('userc', 'User', 'C', 'userc@example.com;userd@example.com');

        $this->{twiki}->{store}->saveTopic($this->{twiki}->{user}, $this->{users_web}, 'AandBGroup',
                  "   * Set GROUP = UserA, UserB");
        $this->{twiki}->{store}->saveTopic($this->{twiki}->{user}, $this->{users_web}, 'AandCGroup',
                  "   * Set GROUP = UserA, UserC");
        $this->{twiki}->{store}->saveTopic($this->{twiki}->{user}, $this->{users_web}, 'BandCGroup',
                  "   * Set GROUP = UserC, UserB");

    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0,$e->stringify());
    } catch Error::Simple with {
        $this->assert(0,shift->stringify()||'');
    };
    # Force a re-read
    $this->{twiki} = new TWiki();
    $TWiki::Plugins::SESSION = $this->{twiki};
    @TWikiFntestCase::mails = ();
}

sub test_emailToWikiNames {
    my $this = shift;
    my @users = TWiki::Func::emailToWikiNames('userc@example.com', 1);
    $this->assert_str_equals("UserC", join(',', @users));
    @users = TWiki::Func::emailToWikiNames('userd@example.com', 0);
    $this->assert_str_equals("$this->{users_web}.UserC", join(',', @users));
    @users = TWiki::Func::emailToWikiNames('user@example.com', 1);
    $this->assert_str_equals("UserA,UserB", join(',', sort @users));
}

sub test_wikiNameToEmails {
    my $this = shift;
    my @emails = TWiki::Func::wikinameToEmails('UserA');
    $this->assert_str_equals("user\@example.com", join(',', @emails));
    @emails = TWiki::Func::wikinameToEmails('UserB');
    $this->assert_str_equals("user\@example.com", join(',', @emails));
    @emails = TWiki::Func::wikinameToEmails('UserC');
    $this->assert_str_equals("userd\@example.com,userc\@example.com",
                             join(',', reverse sort @emails));
}

sub test_getAllUsers {
    my $this = shift;
    my @list;
    my $ite = TWiki::Func::getAllUsers();
    while (my $u = $ite->next()) {
        push(@list, $u);
    }
    my $ulist = join(',', sort @list);
    $this->assert_str_equals("ScumBag,UserA,UserB,UserC", $ulist);
}

sub test_getAllGroups {
    my $this = shift;
    my @list;
    my $ite = TWiki::Func::getAllGroups();
    while (my $u = $ite->next()) {
        push(@list, $u);
    }
    my $ulist = join(',', sort @list);
    $this->assert_str_equals('AandBGroup,AandCGroup,BandCGroup,TWikiAdminGroup', $ulist);
}

# SMELL: nothing tests if we are an admin!
sub test_isAdmin {
    my $this = shift;
    my @list = TWiki::Func::getAllUsers();
    foreach my $u ( @list ) {
        $u =~ /.*\.(.*)/;
        $TWiki::Plugins::SESSION->{user} = $TWiki::Plugins::SESSION->{users}->findUser(undef, $u);
        $this->assert(!TWiki::Func::isAdmin(), $u);
    }
}

sub test_isInGroup {
    my $this = shift;
    $TWiki::Plugins::SESSION->{user} = $TWiki::Plugins::SESSION->{users}->findUser('UserA', 'UserA');
    $this->assert(TWiki::Func::isInGroup('AandBGroup'));
    $this->assert(TWiki::Func::isInGroup('AandCGroup'));
    $this->assert(!TWiki::Func::isInGroup('BandCGroup'));
    $this->assert(TWiki::Func::isInGroup('BandCGroup', 'UserB'));
    $this->assert(TWiki::Func::isInGroup('BandCGroup', 'UserC'));
}

sub test_getUsersGroups {
    my $this = shift;

    $this->assert_str_equals('AandBGroup,AandCGroup',
                             join(',', TWiki::Func::getUsersGroups('UserA')));
    $this->assert_str_equals('AandBGroup,BandCGroup',
                             join(',', TWiki::Func::getUsersGroups('UserB')));
    $this->assert_str_equals('AandCGroup,BandCGroup',
                             join(',', TWiki::Func::getUsersGroups('UserC')));

    $TWiki::Plugins::SESSION->{user} =
      $TWiki::Plugins::SESSION->{users}->findUser('UserA', 'UserA');
    $this->assert_str_equals('AandBGroup,AandCGroup',
                             join(',', TWiki::Func::getUsersGroups()));
}

1;
