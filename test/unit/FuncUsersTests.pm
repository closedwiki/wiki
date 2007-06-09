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

    $this->{twiki}->finish();
    $this->{twiki} = new TWiki('AdminUser');

    try {
        # Create an admin group/user
        $this->{twiki}->{store}->saveTopic(
            $this->{twiki}->{user}, $this->{users_web}, 'TWikiAdminGroup',
            '   * Set GROUP = '.$this->{twiki}->{user}.", TWikiAdminGroup\n");

        $this->registerUser('usera', 'User', 'A', 'user@example.com');
        $this->registerUser('userb', 'User', 'B', 'user@example.com');
        $this->registerUser('userc', 'User', 'C', 'userc@example.com;userd@example.com');

        $this->{twiki}->{store}->saveTopic(
            $this->{twiki}->{user},
            $this->{users_web}, 'AandBGroup',
            "   * Set GROUP = UserA, UserB");
        $this->{twiki}->{store}->saveTopic(
            $this->{twiki}->{user},
            $this->{users_web}, 'AandCGroup',
            "   * Set GROUP = UserA, UserC");
        $this->{twiki}->{store}->saveTopic(
            $this->{twiki}->{user},
            $this->{users_web}, 'BandCGroup',
            "   * Set GROUP = UserC, UserB");
        $this->{twiki}->{store}->saveTopic(
            $this->{twiki}->{user},
            $this->{users_web}, 'ScumGroup',
            "   * Set GROUP = $TWiki::cfg{DefaultUserWikiName}");

    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0,$e->stringify());
    } catch Error::Simple with {
        $this->assert(0,shift->stringify()||'');
    };
    # Force a re-read
    $this->{twiki}->finish();
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
    @emails = TWiki::Func::wikinameToEmails('AandCGroup');
    $this->assert_str_equals("userd\@example.com,userc\@example.com,user\@example.com",
                             join(',', reverse sort @emails));
}

sub test_eachUserAllowLoginName {
    my $this = shift;
    $TWiki::cfg{Register}{AllowLoginName} = 1;
    # Force a re-read
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki();
    $TWiki::Plugins::SESSION = $this->{twiki};
    @TWikiFntestCase::mails = ();

    my @list;
    my $ite = TWiki::Func::eachUser();
    while ($ite->hasNext()) {
        my $u = $ite->next();
        push(@list, $u);
    }
    my $ulist = join(',', sort @list);
    $this->assert_str_equals("ScumBag,TWikiAdminGroup,TWikiContributor,TWikiGuest,TWikiRegistrationAgent,UnknownUser,UserA,UserB,UserC", $ulist);
}

sub test_eachUserDontAllowLoginName {
    my $this = shift;
    $TWiki::cfg{Register}{AllowLoginName} = 0;
    # Force a re-read
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki();
    $TWiki::Plugins::SESSION = $this->{twiki};
    @TWikiFntestCase::mails = ();

    my @list;
    my $ite = TWiki::Func::eachUser();
    while ($ite->hasNext()) {
        my $u = $ite->next();
        push(@list, $u);
    }
    my $ulist = join(',', sort @list);
    $this->assert_str_equals("TWikiAdminGroup,TWikiContributor,TWikiGuest,TWikiRegistrationAgent,UnknownUser,scum,usera,userb,userc", $ulist);
}


sub test_eachGroupTraditional {
    my $this = shift;
    my @list;

    $TWiki::cfg{SuperAdminGroup} = 'TWikiAdminGroup';
    # Force a re-read
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki();
    $TWiki::Plugins::SESSION = $this->{twiki};
    @TWikiFntestCase::mails = ();

    my $ite = TWiki::Func::eachGroup();
    while ($ite->hasNext()) {
        my $u = $ite->next();
        push(@list, $u);
    }
    my $ulist = join(',', sort @list);
    my @correctList = qw/ AandBGroup AandCGroup BandCGroup ScumGroup TWikiAdminGroup TWikiBaseGroup/;
    my $correct = join(',', sort @correctList);
    $this->assert_str_equals($correct, $ulist);
}

sub test_eachGroupCustomAdmin {
    my $this = shift;
    my @list;

    $TWiki::cfg{SuperAdminGroup} = 'Super Admin';
    # Force a re-read
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki();
    $TWiki::Plugins::SESSION = $this->{twiki};
    @TWikiFntestCase::mails = ();

    my $ite = TWiki::Func::eachGroup();
    while ($ite->hasNext()) {
        my $u = $ite->next();
        push(@list, $u);
    }
    my $ulist = join(',', sort @list);
    my @correctList = qw/ AandBGroup AandCGroup BandCGroup ScumGroup TWikiAdminGroup TWikiBaseGroup/;
    push @correctList, $TWiki::cfg{SuperAdminGroup};
    my $correct = join(',', sort @correctList);
    $this->assert_str_equals($correct, $ulist);
}


# SMELL: nothing tests if we are an admin!
sub test_isAnAdmin {
    my $this = shift;
    my @list = TWiki::Func::eachUser();
    foreach my $u ( @list ) {
        $u =~ /.*\.(.*)/;
        $TWiki::Plugins::SESSION->{user} = $u;
        $this->assert(!TWiki::Func::isAnAdmin(), $u);
    }
}

sub test_isGroupMember {
    my $this = shift;
    $TWiki::Plugins::SESSION->{user} =
      $TWiki::Plugins::SESSION->{users}->getCanonicalUserID('usera');
    $this->assert(TWiki::Func::isGroupMember('AandBGroup'));
    $this->assert(TWiki::Func::isGroupMember('AandCGroup'));
    $this->assert(!TWiki::Func::isGroupMember('BandCGroup'));
    $this->assert(TWiki::Func::isGroupMember('BandCGroup', 'UserB'));
    $this->assert(TWiki::Func::isGroupMember('BandCGroup', 'UserC'));
}

sub test_eachMembership {
    my $this = shift;

    my @list;
    my $it = TWiki::Func::eachMembership('UserA');
    while ($it->hasNext()) {
        my $g = $it->next();
        push(@list, $g);
    }
    $this->assert_str_equals('AandBGroup,AandCGroup', join(',', sort @list));
    $it = TWiki::Func::eachMembership('UserB');
    @list = ();
    while ($it->hasNext()) {
        my $g = $it->next();
        push(@list, $g);
    }
    $this->assert_str_equals('AandBGroup,BandCGroup', join(',', sort @list));
    $it = TWiki::Func::eachMembership('UserC');
    @list = ();
    while ($it->hasNext()) {
        my $g = $it->next();
        push(@list, $g);
    }
    $this->assert_str_equals('AandCGroup,BandCGroup', sort join(',', @list));
}

sub test_eachMembershipDefault {
    my $this = shift;
    my $it = TWiki::Func::eachMembership();
    my @list = ();
    while ($it->hasNext()) {
        my $g = $it->next();
        push(@list, $g);
    }
$this->annotate($TWiki::Plugins::SESSION->{user}." is member of...\n");
    $this->assert_str_equals('TWikiBaseGroup,ScumGroup', sort join(',', @list));
}

sub test_eachGroupMember {
    my $this = shift;
    my $it = TWiki::Func::eachGroupMember('AandBGroup');
    my @list;
    while ($it->hasNext()) {
        my $g = $it->next();
        push(@list, $g);
    }
    $this->assert_str_equals('UserA,UserB', sort join(',', @list));
}

sub test_isGroup {
    my $this = shift;
    $this->assert(TWiki::Func::isGroup('AandBGroup'));
    $this->assert(!TWiki::Func::isGroup('UserA'));
}

1;
