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

sub list_tests {
    my $this = shift;
    my @set = $this->SUPER::list_tests();

    my $clz = new Devel::Symdump(qw(FuncUsersTests));
    for my $i ($clz->functions()) {
        next unless $i =~ /::verify_/;
        foreach my $LoginImpl qw( TWiki::LoginManager::TemplateLogin TWiki::LoginManager::ApacheLogin none) {
            foreach my $userManagerImpl qw( TWiki::Users::TWikiUserMapping TWiki::Users::BaseUserMapping) {
#TODO: add things like AllowLoginName into the mix
                my $fn = $i;
                $fn =~ s/\W/_/g;
                my $sfn = 'verify_'.$fn.$LoginImpl.$userManagerImpl;
                $sfn =~ s/::/_/g;
                $sfn = 'FuncUsersTests::'.$sfn;
                no strict 'refs';
                *$sfn = sub {
                    my $this = shift;
                    $TWiki::cfg{LoginManager} = $LoginImpl;
                    $TWiki::cfg{UserMappingManager} = $userManagerImpl;
                    verify_set_up($this);
                    &$i($this);
                };
                use strict 'refs';
                push(@set, $sfn);
            }
        }
    }
    return @set;
}
#delay the calling of set_up til after the cfg's are set by above closure
sub set_up {}
sub verify_set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $this->{twiki}->finish();
    $this->{twiki} = new TWiki($TWiki::cfg{AdminUserLogin});

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

sub verify_emailToWikiNames {
    my $this = shift;
    my @users = TWiki::Func::emailToWikiNames('userc@example.com', 1);
    $this->assert_str_equals("UserC", join(',', @users));
    @users = TWiki::Func::emailToWikiNames('userd@example.com', 0);
    $this->assert_str_equals("$this->{users_web}.UserC", join(',', @users));
    @users = TWiki::Func::emailToWikiNames('user@example.com', 1);
    $this->assert_str_equals("UserA,UserB", join(',', sort @users));
}

sub verify_wikiNameToEmails {
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

sub verify_eachUserAllowLoginName {
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

    my @correctList;
    if ($TWiki::cfg{UserMappingManager} eq 'TWiki::Users::BaseUserMapping') {
         @correctList = qw/TWikiContributor TWikiGuest TWikiRegistrationAgent UnknownUser/;
    } else {
         @correctList = qw/TWikiContributor TWikiGuest TWikiRegistrationAgent UnknownUser ScumBag UserA UserB UserC/;
    }
    push @correctList, $TWiki::cfg{AdminUserWikiName};
    my $correct = join(',', sort @correctList);
    $this->assert_str_equals($correct, $ulist);
}

sub verify_eachUserDontAllowLoginName {
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

    my @correctList;
    if ($TWiki::cfg{UserMappingManager} eq 'TWiki::Users::BaseUserMapping') {
         @correctList = qw/TWikiContributor TWikiGuest TWikiRegistrationAgent UnknownUser/;
    } else {
         @correctList = qw/TWikiContributor TWikiGuest TWikiRegistrationAgent UnknownUser scum usera userb userc/;
    }
    push @correctList, $TWiki::cfg{AdminUserWikiName};
    my $correct = join(',', sort @correctList);
    $this->assert_str_equals($correct, $ulist);
}


sub verify_eachGroupTraditional {
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
    my @correctList;
    if ($TWiki::cfg{UserMappingManager} eq 'TWiki::Users::BaseUserMapping') {
         @correctList = qw/TWikiAdminGroup TWikiBaseGroup/;
    } else {
         @correctList = qw/ AandBGroup AandCGroup BandCGroup ScumGroup TWikiAdminGroup TWikiBaseGroup/;
    }
    my $correct = join(',', sort @correctList);
    $this->assert_str_equals($correct, $ulist);
}

sub verify_eachGroupCustomAdmin {
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
    my @correctList;
    if ($TWiki::cfg{UserMappingManager} eq 'TWiki::Users::BaseUserMapping') {
         @correctList = qw/TWikiBaseGroup/;
    } else {
         @correctList = qw/ AandBGroup AandCGroup BandCGroup ScumGroup TWikiAdminGroup TWikiBaseGroup/;     #TWikiAdminGroup is defined as a topic ...
    }
    push @correctList, $TWiki::cfg{SuperAdminGroup};
    my $correct = join(',', sort @correctList);
    $this->assert_str_equals($correct, $ulist);
}


# SMELL: nothing tests if we are an admin!
sub verify_isAnAdmin {
    my $this = shift;
    my @list = TWiki::Func::eachUser();
    foreach my $u ( @list ) {
        $u =~ /.*\.(.*)/;
        $TWiki::Plugins::SESSION->{user} = $u;
        $this->assert(!TWiki::Func::isAnAdmin(), $u);
    }
}

sub verify_isGroupMember {
    my $this = shift;
    $TWiki::Plugins::SESSION->{user} =
      $TWiki::Plugins::SESSION->{users}->getCanonicalUserID('usera');
    $this->assert(TWiki::Func::isGroupMember('AandBGroup'));
    $this->assert(TWiki::Func::isGroupMember('AandCGroup'));
    $this->assert(!TWiki::Func::isGroupMember('BandCGroup'));
    $this->assert(TWiki::Func::isGroupMember('BandCGroup', 'UserB'));
    $this->assert(TWiki::Func::isGroupMember('BandCGroup', 'UserC'));
}

sub verify_eachMembership {
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

sub verify_eachMembershipDefault {
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

sub verify_eachGroupMember {
    my $this = shift;
    my $it = TWiki::Func::eachGroupMember('AandBGroup');
    my @list;
    while ($it->hasNext()) {
        my $g = $it->next();
        push(@list, $g);
    }
    $this->assert_str_equals('UserA,UserB', sort join(',', @list));
}

sub verify_isGroup {
    my $this = shift;
    $this->assert(TWiki::Func::isGroup('AandBGroup'));
    $this->assert(!TWiki::Func::isGroup('UserA'));
}


sub verify_getCanonicalUserID_extended {
	my $this = shift;
	
    my $guest_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{DefaultUserLogin});
    $this->assert_str_equals($guest_cUID, TWiki::Func::getCanonicalUserID());

    $this->assert_str_equals($guest_cUID, TWiki::Func::getCanonicalUserID($TWiki::cfg{DefaultUserLogin}));
    $this->assert_str_equals($guest_cUID, TWiki::Func::getCanonicalUserID($guest_cUID));
    $this->assert_str_equals($guest_cUID, TWiki::Func::getCanonicalUserID($TWiki::cfg{DefaultUserWikiName}));
    $this->assert_str_equals($guest_cUID, TWiki::Func::getCanonicalUserID($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}));
	
    my $admin_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{AdminUserLogin});
    $this->assert_str_equals($admin_cUID, TWiki::Func::getCanonicalUserID($admin_cUID));
    $this->assert_str_equals($admin_cUID, TWiki::Func::getCanonicalUserID($TWiki::cfg{AdminUserLogin}));
#    $this->assert_str_equals($admin_cUID, TWiki::Func::getCanonicalUserID($TWiki::cfg{AdminUserWikiName}));
#    $this->assert_str_equals($admin_cUID, TWiki::Func::getCanonicalUserID($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}));

    my $usera_cUID = $this->{twiki}->{users}->getCanonicalUserID('usera');
    $this->assert_str_equals($usera_cUID, TWiki::Func::getCanonicalUserID($usera_cUID));
#    $this->assert_str_equals($usera_cUID, TWiki::Func::getCanonicalUserID('usera'));
#    $this->assert_str_equals($usera_cUID, TWiki::Func::getCanonicalUserID('UserA'));
#    $this->assert_str_equals($usera_cUID, TWiki::Func::getCanonicalUserID($TWiki::cfg{UsersWebName}.'.'.'UserA'));

    #TODO: consider how to render unkown user's
    my $nonexistantuser_cUID = $this->{twiki}->{users}->getCanonicalUserID('nonexistantuser');
    $this->annotate($nonexistantuser_cUID);
    $this->assert_str_equals($nonexistantuser_cUID, TWiki::Func::getCanonicalUserID($nonexistantuser_cUID));
    $this->assert_str_equals($nonexistantuser_cUID, TWiki::Func::getCanonicalUserID('nonexistantuser'));
#    $this->assert_str_equals($nonexistantuser_cUID, TWiki::Func::getCanonicalUserID('NonExistantUser'));
#    $this->assert_str_equals($nonexistantuser_cUID, TWiki::Func::getCanonicalUserID($TWiki::cfg{UsersWebName}.'.'.'NonExistantUser'));

    #TODO: consider how to render unkown user's
    my $AandBGroup_cUID = $this->{twiki}->{users}->getCanonicalUserID('AandBGroup');
    $this->annotate($AandBGroup_cUID);
    $this->assert_str_equals($AandBGroup_cUID, TWiki::Func::getCanonicalUserID($AandBGroup_cUID));
    $this->assert_str_equals($AandBGroup_cUID, TWiki::Func::getCanonicalUserID('AandBGroup'));
    $this->assert_str_equals($AandBGroup_cUID, TWiki::Func::getCanonicalUserID('AandBGroup'));
    $this->assert_str_equals($AandBGroup_cUID, TWiki::Func::getCanonicalUserID($TWiki::cfg{UsersWebName}.'.'.'AandBGroup'));
}

sub verify_getWikiName_extended {
	my $this = shift;
	
    $this->assert_str_equals($TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiName());

    my $guest_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{DefaultUserLogin});
    $this->assert_str_equals($TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiName($TWiki::cfg{DefaultUserLogin}));
    $this->assert_str_equals($TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiName($guest_cUID));
    $this->assert_str_equals($TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiName($TWiki::cfg{DefaultUserWikiName}));
    $this->assert_str_equals($TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiName($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}));

    my $admin_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{AdminUserLogin});
    $this->annotate($admin_cUID.' => '.$TWiki::cfg{AdminUserLogin}.' => '.$TWiki::cfg{AdminUserWikiName});
    $this->assert_str_equals($TWiki::cfg{AdminUserWikiName}, TWiki::Func::getWikiName($admin_cUID));
#    $this->assert_str_equals($TWiki::cfg{AdminUserWikiName}, TWiki::Func::getWikiName($TWiki::cfg{AdminUserLogin}));
    $this->assert_str_equals($TWiki::cfg{AdminUserWikiName}, TWiki::Func::getWikiName($TWiki::cfg{AdminUserWikiName}));
    $this->assert_str_equals($TWiki::cfg{AdminUserWikiName}, TWiki::Func::getWikiName($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}));

    my $usera_cUID = $this->{twiki}->{users}->getCanonicalUserID('usera');
    $this->assert_str_equals('UserA', TWiki::Func::getWikiName($usera_cUID));
    $this->assert_str_equals('UserA', TWiki::Func::getWikiName('usera'));
    $this->assert_str_equals('UserA', TWiki::Func::getWikiName('UserA'));
    $this->assert_str_equals('UserA', TWiki::Func::getWikiName($TWiki::cfg{UsersWebName}.'.'.'UserA'));

    #TODO: consider how to render unkown user's
    my $nonexistantuser_cUID = $this->{twiki}->{users}->getCanonicalUserID('nonexistantuser');
    $this->annotate($nonexistantuser_cUID);
    $this->assert_str_equals('nonexistantuser', TWiki::Func::getWikiName($nonexistantuser_cUID));
    $this->assert_str_equals('nonexistantuser', TWiki::Func::getWikiName('nonexistantuser'));
    $this->assert_str_equals('NonExistantUser', TWiki::Func::getWikiName('NonExistantUser'));
    $this->assert_str_equals('NonExistantUser', TWiki::Func::getWikiName($TWiki::cfg{UsersWebName}.'.'.'NonExistantUser'));

    #TODO: consider how to render unkown user's
    my $AandBGroup_cUID = $this->{twiki}->{users}->getCanonicalUserID('AandBGroup');
    $this->annotate($AandBGroup_cUID);
    $this->assert_str_equals('AandBGroup', TWiki::Func::getWikiName($AandBGroup_cUID));
    $this->assert_str_equals('AandBGroup', TWiki::Func::getWikiName('AandBGroup'));
    $this->assert_str_equals('AandBGroup', TWiki::Func::getWikiName('AandBGroup'));
    $this->assert_str_equals('AandBGroup', TWiki::Func::getWikiName($TWiki::cfg{UsersWebName}.'.'.'AandBGroup'));
}

sub verify_getWikiUserName_extended {
	my $this = shift;
	
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiUserName());

    my $guest_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{DefaultUserLogin});
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiUserName($TWiki::cfg{DefaultUserLogin}));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiUserName($guest_cUID));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiUserName($TWiki::cfg{DefaultUserWikiName}));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiUserName($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}));
	
    my $admin_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{AdminUserLogin});
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}, TWiki::Func::getWikiUserName($admin_cUID));
#    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}, TWiki::Func::getWikiUserName($TWiki::cfg{AdminUserLogin}));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}, TWiki::Func::getWikiUserName($TWiki::cfg{AdminUserWikiName}));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}, TWiki::Func::getWikiUserName($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}));

    my $usera_cUID = $this->{twiki}->{users}->getCanonicalUserID('usera');
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'UserA', TWiki::Func::getWikiUserName($usera_cUID));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'UserA', TWiki::Func::getWikiUserName('usera'));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'UserA', TWiki::Func::getWikiUserName('UserA'));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'UserA', TWiki::Func::getWikiUserName($TWiki::cfg{UsersWebName}.'.'.'UserA'));

    #TODO: consider how to render unkown user's
    my $nonexistantuser_cUID = $this->{twiki}->{users}->getCanonicalUserID('nonexistantuser');
    $this->annotate($nonexistantuser_cUID);
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'nonexistantuser', TWiki::Func::getWikiUserName($nonexistantuser_cUID));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'nonexistantuser', TWiki::Func::getWikiUserName('nonexistantuser'));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'NonExistantUser', TWiki::Func::getWikiUserName('NonExistantUser'));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'NonExistantUser', TWiki::Func::getWikiUserName($TWiki::cfg{UsersWebName}.'.'.'NonExistantUser'));

    #TODO: consider how to render unkown user's
    my $AandBGroup_cUID = $this->{twiki}->{users}->getCanonicalUserID('AandBGroup');
    $this->annotate($AandBGroup_cUID);
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'AandBGroup', TWiki::Func::getWikiUserName($AandBGroup_cUID));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'AandBGroup', TWiki::Func::getWikiUserName('AandBGroup'));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'AandBGroup', TWiki::Func::getWikiUserName('AandBGroup'));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'AandBGroup', TWiki::Func::getWikiUserName($TWiki::cfg{UsersWebName}.'.'.'AandBGroup'));
}

sub verify_wikiToUserName_extended {
	my $this = shift;
	
#TODO: not sure that this method needs to be able to convert _any_ to login
    my $guest_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{DefaultUserLogin});
##    $this->assert_str_equals($TWiki::cfg{DefaultUserLogin}, TWiki::Func::wikiToUserName($guest_cUID));
    $this->assert_str_equals($TWiki::cfg{DefaultUserLogin}, TWiki::Func::wikiToUserName($TWiki::cfg{DefaultUserLogin}));
    $this->assert_str_equals($TWiki::cfg{DefaultUserLogin}, TWiki::Func::wikiToUserName($TWiki::cfg{DefaultUserWikiName}));
    $this->assert_str_equals($TWiki::cfg{DefaultUserLogin}, TWiki::Func::wikiToUserName($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}));
	
    my $admin_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{AdminUserLogin});
##    $this->assert_str_equals($TWiki::cfg{AdminUserLogin}, TWiki::Func::wikiToUserName($admin_cUID));
    $this->assert_str_equals($TWiki::cfg{AdminUserLogin}, TWiki::Func::wikiToUserName($TWiki::cfg{AdminUserLogin}));
    $this->assert_str_equals($TWiki::cfg{AdminUserLogin}, TWiki::Func::wikiToUserName($TWiki::cfg{AdminUserWikiName}));
    $this->assert_str_equals($TWiki::cfg{AdminUserLogin}, TWiki::Func::wikiToUserName($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}));

    my $usera_cUID = $this->{twiki}->{users}->getCanonicalUserID('usera');
##    $this->assert_str_equals('usera', TWiki::Func::wikiToUserName($usera_cUID));
    $this->assert_str_equals('usera', TWiki::Func::wikiToUserName('usera'));
    $this->assert_str_equals('usera', TWiki::Func::wikiToUserName('UserA'));
    $this->assert_str_equals('usera', TWiki::Func::wikiToUserName($TWiki::cfg{UsersWebName}.'.'.'UserA'));

    #TODO: consider how to render unkown user's
    my $nonexistantuser_cUID = $this->{twiki}->{users}->getCanonicalUserID('nonexistantuser');
    $this->annotate($nonexistantuser_cUID);
##    $this->assert_str_equals('nonexistantuser', TWiki::Func::wikiToUserName($nonexistantuser_cUID));
    $this->assert_str_equals('nonexistantuser', TWiki::Func::wikiToUserName('nonexistantuser'));
    $this->assert_str_equals('NonExistantUser', TWiki::Func::wikiToUserName('NonExistantUser'));
    $this->assert_str_equals('NonExistantUser', TWiki::Func::wikiToUserName($TWiki::cfg{UsersWebName}.'.'.'NonExistantUser'));

    #TODO: consider how to render unkown user's
    my $AandBGroup_cUID = $this->{twiki}->{users}->getCanonicalUserID('AandBGroup');
    $this->annotate($AandBGroup_cUID);
    $this->assert_str_equals('AandBGroup', TWiki::Func::wikiToUserName($AandBGroup_cUID));
    $this->assert_str_equals('AandBGroup', TWiki::Func::wikiToUserName('AandBGroup'));
    $this->assert_str_equals('AandBGroup', TWiki::Func::wikiToUserName('AandBGroup'));
    $this->assert_str_equals('AandBGroup', TWiki::Func::wikiToUserName($TWiki::cfg{UsersWebName}.'.'.'AandBGroup'));
}

sub verify_isAnAdmin_extended {
	my $this = shift;
	
#TODO: not sure that this method needs to be able to convert _any_ to login
    my $guest_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{DefaultUserLogin});
    $this->assert(!TWiki::Func::isAnAdmin($TWiki::cfg{DefaultUserLogin}));
    $this->assert(!TWiki::Func::isAnAdmin($guest_cUID));
    $this->assert(!TWiki::Func::isAnAdmin($TWiki::cfg{DefaultUserWikiName}));
    $this->assert(!TWiki::Func::isAnAdmin($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}));
	
    my $admin_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{AdminUserLogin});
    $this->assert(TWiki::Func::isAnAdmin($admin_cUID));
    $this->assert(TWiki::Func::isAnAdmin($TWiki::cfg{AdminUserLogin}));
    $this->assert(TWiki::Func::isAnAdmin($TWiki::cfg{AdminUserWikiName}));
    $this->assert(TWiki::Func::isAnAdmin($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}));

    my $usera_cUID = $this->{twiki}->{users}->getCanonicalUserID('usera');
    $this->assert(!TWiki::Func::isAnAdmin($usera_cUID));
    $this->assert(!TWiki::Func::isAnAdmin('usera'));
    $this->assert(!TWiki::Func::isAnAdmin('UserA'));
    $this->assert(!TWiki::Func::isAnAdmin($TWiki::cfg{UsersWebName}.'.'.'UserA'));

    #TODO: consider how to render unkown user's
    my $nonexistantuser_cUID = $this->{twiki}->{users}->getCanonicalUserID('nonexistantuser');
    $this->annotate($nonexistantuser_cUID);
    $this->assert(!TWiki::Func::isAnAdmin($nonexistantuser_cUID));
    $this->assert(!TWiki::Func::isAnAdmin('nonexistantuser'));
    $this->assert(!TWiki::Func::isAnAdmin('NonExistantUser'));
    $this->assert(!TWiki::Func::isAnAdmin($TWiki::cfg{UsersWebName}.'.'.'NonExistantUser'));

    #TODO: consider how to render unkown user's
    my $AandBGroup_cUID = $this->{twiki}->{users}->getCanonicalUserID('AandBGroup');
    $this->annotate($AandBGroup_cUID);
    $this->assert(!TWiki::Func::isAnAdmin($AandBGroup_cUID));
    $this->assert(!TWiki::Func::isAnAdmin('AandBGroup'));
    $this->assert(!TWiki::Func::isAnAdmin('AandBGroup'));
    $this->assert(!TWiki::Func::isAnAdmin($TWiki::cfg{UsersWebName}.'.'.'AandBGroup'));
}


sub verify_isGroupMember_extended {
	my $this = shift;
	
#TODO: not sure that this method needs to be able to convert _any_ to login
    my $guest_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{DefaultUserLogin});
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', $TWiki::cfg{DefaultUserLogin}));
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', $guest_cUID));
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', $TWiki::cfg{DefaultUserWikiName}));
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', $TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}));
	
    my $admin_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{AdminUserLogin});
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', $admin_cUID));
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', $TWiki::cfg{AdminUserLogin}));
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', $TWiki::cfg{AdminUserWikiName}));
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', $TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}));

    my $usera_cUID = $this->{twiki}->{users}->getCanonicalUserID('usera');
##    $this->assert(TWiki::Func::isGroupMember('AandBGroup', $usera_cUID));
    $this->assert(TWiki::Func::isGroupMember('AandBGroup', 'usera'));
    $this->assert(TWiki::Func::isGroupMember('AandBGroup', 'UserA'));
    $this->assert(TWiki::Func::isGroupMember('AandBGroup', $TWiki::cfg{UsersWebName}.'.'.'UserA'));

    #TODO: consider how to render unkown user's
    my $nonexistantuser_cUID = $this->{twiki}->{users}->getCanonicalUserID('nonexistantuser');
    $this->annotate($nonexistantuser_cUID);
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', $nonexistantuser_cUID));
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', 'nonexistantuser'));
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', 'NonExistantUser'));
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', $TWiki::cfg{UsersWebName}.'.'.'NonExistantUser'));

    #TODO: consider how to render unkown user's
    my $AandBGroup_cUID = $this->{twiki}->{users}->getCanonicalUserID('AandBGroup');
    $this->annotate($AandBGroup_cUID);
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', $AandBGroup_cUID));
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', 'AandBGroup'));
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', 'AandBGroup'));
    $this->assert(!TWiki::Func::isGroupMember('AandBGroup', $TWiki::cfg{UsersWebName}.'.'.'AandBGroup'));

#baseusermapping group
#    my $guest_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{DefaultUserLogin});
    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $TWiki::cfg{DefaultUserLogin}));
    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $guest_cUID));
    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $TWiki::cfg{DefaultUserWikiName}));
    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}));
	
#    my $admin_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{AdminUserLogin});
##    $this->assert(TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $admin_cUID));
    $this->assert(TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $TWiki::cfg{AdminUserLogin}));
    $this->assert(TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $TWiki::cfg{AdminUserWikiName}));
    $this->assert(TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}));

#    my $usera_cUID = $this->{twiki}->{users}->getCanonicalUserID('usera');
##    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $usera_cUID));
    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, 'usera'));
    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, 'UserA'));
    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $TWiki::cfg{UsersWebName}.'.'.'UserA'));

}

1;
