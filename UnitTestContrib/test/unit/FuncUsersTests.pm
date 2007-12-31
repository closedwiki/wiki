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

sub AllowLoginName {
    my $this = shift;
    $TWiki::cfg{Register}{AllowLoginName} = 1;
}
sub DontAllowLoginName {
    my $this = shift;
    $TWiki::cfg{Register}{AllowLoginName} = 0;
}

sub TemplateLoginManager {
    $TWiki::cfg{LoginManager} = 'TWiki::LoginManager::TemplateLogin';
}

sub ApacheLoginManager {
    $TWiki::cfg{LoginManager} = 'TWiki::LoginManager::ApacheLogin';
}

sub NoLoginManager {
    $TWiki::cfg{LoginManager} = 'TWiki::LoginManager';
}

sub BaseUserMapping {
    my $this = shift;
    $TWiki::cfg{UserMappingManager} = 'TWiki::Users::BaseUserMapping';
    $this->set_up_for_verify();
}

sub TWikiUserMapping {
    my $this = shift;
    $TWiki::cfg{UserMappingManager} = 'TWiki::Users::TWikiUserMapping';
    $this->set_up_for_verify();
}

sub NonePasswordManager {
    $TWiki::cfg{PasswordManager} = 'none';
}

sub HtPasswordPasswordManager {
    $TWiki::cfg{PasswordManager} = 'TWiki::Users::HtPasswdUser';
}


# See the pod doc in Unit::TestCase for details of how to use this
sub fixture_groups {

    return (
        [ 'NoLoginManager', 'ApacheLoginManager', 'TemplateLoginManager' ],
        [ 'AllowLoginName', 'DontAllowLoginName'],
        [ 'TWikiUserMapping' ],
        [ 'NonePasswordManager', 'HtPasswordPasswordManager' ]);

=pod

    return (
        [ 'TemplateLoginManager', 'ApacheLoginManager', 'NoLoginManager' ],
        [ 'AllowLoginName', 'DontAllowLoginName'],
#        [ 'TWikiUserMapping', 'BaseUserMapping' ] );
        [ 'TWikiUserMapping' ] );

=cut

}

#delay the calling of set_up til after the cfg's are set by above closure
sub set_up_for_verify {
    my $this = shift;

    $this->{twiki}->finish();
    $this->{twiki} = new TWiki($TWiki::cfg{AdminUserLogin});

    if ($this->{twiki}->inContext('registration_supported') && $this->{twiki}->inContext('registration_enabled'))  {
        try {
            $this->registerUser('usera', 'User', 'A', 'user@example.com');
            $this->registerUser('usera86', 'User', 'A86', 'user86@example.com');
            $this->registerUser('user86a', 'User86', 'A', 'user86a@example.com');
            #this should fail... as its the same as the one above
            #$this->registerUser('user862a', 'User', '86A', 'user862a@example.com');
            #this one does fail..
            #$this->registerUser('86usera', '86User', 'A', 'user86a@example.com');
            $this->registerUser('userb', 'User', 'B', 'user@example.com');
            $this->registerUser('userc', 'User', 'C', 'userc@example.com;userd@example.com');
            $this->{twiki}->{store}->saveTopic(
                $this->{twiki}->{user},
                $this->{users_web}, 'AandBGroup',
                "   * Set GROUP = UserA, UserB, $TWiki::cfg{AdminUserWikiName}");
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
                "   * Set GROUP = UserA, $TWiki::cfg{DefaultUserWikiName}");
            $this->{twiki}->{store}->saveTopic(
                $this->{twiki}->{user},
                $this->{users_web}, $TWiki::cfg{SuperAdminGroup},
                "   * Set GROUP = UserA, $TWiki::cfg{AdminUserWikiName}");
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
    }
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
         @correctList = qw/TWikiContributor TWikiGuest TWikiRegistrationAgent UnknownUser ScumBag User86A UserA UserA86 UserB UserC/;
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
#TODO: should reture WikiName's - trouble is that this means wikiname==loginname - and they were registered with them different
         @correctList = qw/TWikiContributor TWikiGuest TWikiRegistrationAgent UnknownUser scum user86a usera usera86 userb userc/;
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
         @correctList = qw/AdminGroup AandBGroup AandCGroup BandCGroup ScumGroup TWikiAdminGroup TWikiBaseGroup/;
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
         @correctList = qw/AdminGroup AandBGroup AandCGroup BandCGroup ScumGroup TWikiBaseGroup/; 
    }
    push @correctList, $TWiki::cfg{SuperAdminGroup};
    my $correct = join(',', sort @correctList);
    $this->assert_str_equals($correct, $ulist);
}


# SMELL: nothing tests if we are an admin!
sub verify_isAnAdmin {
    my $this = shift;
    my $iterator = TWiki::Func::eachUser();
    while ($iterator->hasNext()) {
        my $u = $iterator->next();
        $u =~ /.*\.(.*)/;
        $TWiki::Plugins::SESSION->{user} = $u;
        if (($u eq $TWiki::cfg{AdminUserWikiName}) ||
           ($u eq 'UserA')) {
	        $this->assert(TWiki::Func::isAnAdmin($u), $u);
        } else {
	        $this->assert(!TWiki::Func::isAnAdmin($u), $u);
        }
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
    $this->assert(TWiki::Func::isGroupMember('ScumGroup', 'TWikiGuest'));
}

sub verify_eachMembership {
    my $this = shift;

    my @list;
    my $it = TWiki::Func::eachMembership('UserA');
    while ($it->hasNext()) {
        my $g = $it->next();
        push(@list, $g);
    }
    $this->assert_str_equals('AandBGroup,AandCGroup,AdminGroup,ScumGroup', join(',', sort @list));
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
    
    $it = TWiki::Func::eachMembership('TWikiGuest');
    @list = ();
    while ($it->hasNext()) {
        my $g = $it->next();
        push(@list, $g);
    }
    $this->assert_str_equals('TWikiBaseGroup,ScumGroup', sort join(',', @list));
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
    $this->assert_str_equals("UserA,UserB,$TWiki::cfg{AdminUserWikiName}", sort join(',', @list));
    
    $it = TWiki::Func::eachGroupMember('ScumGroup');
    @list = ();
    while ($it->hasNext()) {
        my $g = $it->next();
        push(@list, $g);
    }
    $this->assert_str_equals("UserA,$TWiki::cfg{DefaultUserWikiName}", sort join(',', @list));    
    
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
    $this->assert_str_equals($admin_cUID, TWiki::Func::getCanonicalUserID($TWiki::cfg{AdminUserWikiName}));
    $this->assert_str_equals($admin_cUID, TWiki::Func::getCanonicalUserID($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}));

    my $usera_cUID = $this->{twiki}->{users}->getCanonicalUserID('usera');
    $this->assert_str_equals($usera_cUID, TWiki::Func::getCanonicalUserID($usera_cUID));
    $this->assert_str_equals($usera_cUID, TWiki::Func::getCanonicalUserID('usera'));
    $this->assert_str_equals($usera_cUID, TWiki::Func::getCanonicalUserID('UserA'));
    $this->assert_str_equals($usera_cUID, TWiki::Func::getCanonicalUserID($TWiki::cfg{UsersWebName}.'.'.'UserA'));


#            $this->registerUser('usera86', 'User', 'A86', 'user86@example.com');
    my $usera86_cUID = $this->{twiki}->{users}->getCanonicalUserID('usera86');
    $this->assert_str_equals($usera86_cUID, TWiki::Func::getCanonicalUserID($usera86_cUID));
    $this->assert_str_equals($usera86_cUID, TWiki::Func::getCanonicalUserID('usera86'));
    $this->assert_str_equals($usera86_cUID, TWiki::Func::getCanonicalUserID('UserA86'));
    $this->assert_str_equals($usera86_cUID, TWiki::Func::getCanonicalUserID($TWiki::cfg{UsersWebName}.'.'.'UserA86'));
#            $this->registerUser('user86a', 'User86', 'A', 'user86a@example.com');
    my $user86a_cUID = $this->{twiki}->{users}->getCanonicalUserID('user86a');
    $this->assert_str_equals($user86a_cUID, TWiki::Func::getCanonicalUserID($user86a_cUID));
    $this->assert_str_equals($user86a_cUID, TWiki::Func::getCanonicalUserID('user86a'));
    $this->assert_str_equals($user86a_cUID, TWiki::Func::getCanonicalUserID('User86A'));
    $this->assert_str_equals($user86a_cUID, TWiki::Func::getCanonicalUserID($TWiki::cfg{UsersWebName}.'.'.'User86A'));
#            $this->registerUser('user862a', 'User', '86A', 'user862a@example.com');
#            $this->registerUser('86usera', '86User', 'A', 'user86a@example.com');

    #TODO: consider how to render unkown user's
    $this->assert_null($this->{twiki}->{users}->getCanonicalUserID('nonexistantuser'));
    $this->assert_null(TWiki::Func::getCanonicalUserID('nonexistantuser'));
    $this->assert_null(TWiki::Func::getCanonicalUserID('NonExistantUser'));
    $this->assert_null(TWiki::Func::getCanonicalUserID($TWiki::cfg{UsersWebName}.'.'.'NonExistantUser'));
    $this->assert_null(TWiki::Func::getCanonicalUserID($TWiki::cfg{UsersWebName}.'.'.'NonExistantUser86'));

    #TODO: consider what to return for GROUPs
#    $this->assert_null($this->{twiki}->{users}->getCanonicalUserID('AandBGroup'));
#    $this->assert_null(TWiki::Func::getCanonicalUserID('AandBGroup'));
#    $this->assert_null(TWiki::Func::getCanonicalUserID($TWiki::cfg{UsersWebName}.'.'.'AandBGroup'));

    #TODO: consider what to return for GROUPs
#    $this->assert_null($this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{SuperAdminGroup}));
#    $this->assert_null(TWiki::Func::getCanonicalUserID($TWiki::cfg{SuperAdminGroup}));
#    $this->assert_null(TWiki::Func::getCanonicalUserID($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{SuperAdminGroup}));
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
    $this->assert_str_equals($TWiki::cfg{AdminUserWikiName}, TWiki::Func::getWikiName($TWiki::cfg{AdminUserLogin}));
    $this->assert_str_equals($TWiki::cfg{AdminUserWikiName}, TWiki::Func::getWikiName($TWiki::cfg{AdminUserWikiName}));
    $this->assert_str_equals($TWiki::cfg{AdminUserWikiName}, TWiki::Func::getWikiName($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}));

    my $usera_cUID = $this->{twiki}->{users}->getCanonicalUserID('usera');
    $this->assert_str_equals('UserA', TWiki::Func::getWikiName($usera_cUID));
    $this->assert_str_equals('UserA', TWiki::Func::getWikiName('usera'));
    $this->assert_str_equals('UserA', TWiki::Func::getWikiName('UserA'));
    $this->assert_str_equals('UserA', TWiki::Func::getWikiName($TWiki::cfg{UsersWebName}.'.'.'UserA'));
    
#            $this->registerUser('usera86', 'User', 'A86', 'user86@example.com');
    my $usera86_cUID = $this->{twiki}->{users}->getCanonicalUserID('usera86');
    $this->assert_str_equals('UserA86', TWiki::Func::getWikiName($usera86_cUID));
    $this->assert_str_equals('UserA86', TWiki::Func::getWikiName('usera86'));
    $this->assert_str_equals('UserA86', TWiki::Func::getWikiName('UserA86'));
    $this->assert_str_equals('UserA86', TWiki::Func::getWikiName($TWiki::cfg{UsersWebName}.'.'.'UserA86'));
#            $this->registerUser('user86a', 'User86', 'A', 'user86a@example.com');
    my $user86a_cUID = $this->{twiki}->{users}->getCanonicalUserID('user86a');
    $this->assert_str_equals('User86A', TWiki::Func::getWikiName($user86a_cUID));
    $this->assert_str_equals('User86A', TWiki::Func::getWikiName('user86a'));
    $this->assert_str_equals('User86A', TWiki::Func::getWikiName('User86A'));
    $this->assert_str_equals('User86A', TWiki::Func::getWikiName($TWiki::cfg{UsersWebName}.'.'.'User86A'));
#            $this->registerUser('user862a', 'User', '86A', 'user862a@example.com');
#            $this->registerUser('86usera', '86User', 'A', 'user86a@example.com');

    #TODO: consider how to render unkown user's
    #$TWiki::cfg{RenderLoggedInButUnknownUsers} is false, or undefined
    $this->assert_str_equals('TWikiUserMapping_NonExistantUser', TWiki::Func::getWikiName('TWikiUserMapping_NonExistantUser'));
    my $nonexistantuser_cUID = $this->{twiki}->{users}->getCanonicalUserID('nonexistantuser');
    $this->annotate($nonexistantuser_cUID);			#returns guest
    $this->assert_str_equals($TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiName($nonexistantuser_cUID));
    $this->assert_str_equals('nonexistantuser', TWiki::Func::getWikiName('nonexistantuser'));
    $this->assert_str_equals('NonExistantUser', TWiki::Func::getWikiName('NonExistantUser'));
    $this->assert_str_equals('NonExistantUser', TWiki::Func::getWikiName($TWiki::cfg{UsersWebName}.'.'.'NonExistantUser'));
    $this->assert_str_equals('NonExistantUser86', TWiki::Func::getWikiName($TWiki::cfg{UsersWebName}.'.'.'NonExistantUser86'));

    #TODO: consider how to render unkown user's
    #my $AandBGroup_cUID = $this->{twiki}->{users}->getCanonicalUserID('AandBGroup');
    #$this->annotate($AandBGroup_cUID);
    #$this->assert_str_equals('AandBGroup', TWiki::Func::getWikiName($AandBGroup_cUID));
    #$this->assert_str_equals('AandBGroup', TWiki::Func::getWikiName('AandBGroup'));
    #$this->assert_str_equals('AandBGroup', TWiki::Func::getWikiName('AandBGroup'));
    #$this->assert_str_equals('AandBGroup', TWiki::Func::getWikiName($TWiki::cfg{UsersWebName}.'.'.'AandBGroup'));
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
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}, TWiki::Func::getWikiUserName($TWiki::cfg{AdminUserLogin}));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}, TWiki::Func::getWikiUserName($TWiki::cfg{AdminUserWikiName}));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}, TWiki::Func::getWikiUserName($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}));

    my $usera_cUID = $this->{twiki}->{users}->getCanonicalUserID('usera');
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'UserA', TWiki::Func::getWikiUserName($usera_cUID));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'UserA', TWiki::Func::getWikiUserName('usera'));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'UserA', TWiki::Func::getWikiUserName('UserA'));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'UserA', TWiki::Func::getWikiUserName($TWiki::cfg{UsersWebName}.'.'.'UserA'));

#            $this->registerUser('usera86', 'User', 'A86', 'user86@example.com');
    my $usera86_cUID = $this->{twiki}->{users}->getCanonicalUserID('usera86');
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'UserA86', TWiki::Func::getWikiUserName($usera86_cUID));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'UserA86', TWiki::Func::getWikiUserName('usera86'));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'UserA86', TWiki::Func::getWikiUserName('UserA86'));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'UserA86', TWiki::Func::getWikiUserName($TWiki::cfg{UsersWebName}.'.'.'UserA86'));
#            $this->registerUser('user86a', 'User86', 'A', 'user86a@example.com');
    my $user86a_cUID = $this->{twiki}->{users}->getCanonicalUserID('user86a');
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'User86A', TWiki::Func::getWikiUserName($user86a_cUID));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'User86A', TWiki::Func::getWikiUserName('user86a'));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'User86A', TWiki::Func::getWikiUserName('User86A'));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'User86A', TWiki::Func::getWikiUserName($TWiki::cfg{UsersWebName}.'.'.'User86A'));
#            $this->registerUser('user862a', 'User', '86A', 'user862a@example.com');
#            $this->registerUser('86usera', '86User', 'A', 'user86a@example.com');


    #TODO: consider how to render unkown user's
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'NonExistantUserAsdf', TWiki::Func::getWikiUserName('NonExistantUserAsdf'));
    my $nonexistantuser_cUID = $this->{twiki}->{users}->getCanonicalUserID('nonexistantuserasdf');
    $this->annotate($nonexistantuser_cUID);			#returns guest
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}, TWiki::Func::getWikiUserName($nonexistantuser_cUID));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'nonexistantuserasdf', TWiki::Func::getWikiUserName('nonexistantuserasdf'));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'nonexistantuserasdfqwer', TWiki::Func::getWikiUserName('nonexistantuserasdfqwer'));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'NonExistantUserAsdf', TWiki::Func::getWikiUserName('NonExistantUserAsdf'));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'NonExistantUserAsdf', TWiki::Func::getWikiUserName($TWiki::cfg{UsersWebName}.'.'.'NonExistantUserAsdf'));
    $this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'NonExistantUserAsdf86', TWiki::Func::getWikiUserName($TWiki::cfg{UsersWebName}.'.'.'NonExistantUserAsdf86'));

    #TODO: consider how to render unkown user's
    #my $AandBGroup_cUID = $this->{twiki}->{users}->getCanonicalUserID('AandBGroup');
    #$this->annotate($AandBGroup_cUID);
    #$this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'AandBGroup', TWiki::Func::getWikiUserName($AandBGroup_cUID));
    #$this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'AandBGroup', TWiki::Func::getWikiUserName('AandBGroup'));
    #$this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'AandBGroup', TWiki::Func::getWikiUserName('AandBGroup'));
    #$this->assert_str_equals($TWiki::cfg{UsersWebName}.'.'.'AandBGroup', TWiki::Func::getWikiUserName($TWiki::cfg{UsersWebName}.'.'.'AandBGroup'));
}

sub verify_wikiToUserName_extended {
	my $this = shift;
	
#TODO: not sure that this method needs to be able to convert _any_ to login
    my $guest_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{DefaultUserLogin});
    $this->assert_str_equals($TWiki::cfg{DefaultUserLogin}, TWiki::Func::wikiToUserName($guest_cUID));
    $this->assert_str_equals($TWiki::cfg{DefaultUserLogin}, TWiki::Func::wikiToUserName($TWiki::cfg{DefaultUserLogin}));
    $this->assert_str_equals($TWiki::cfg{DefaultUserLogin}, TWiki::Func::wikiToUserName($TWiki::cfg{DefaultUserWikiName}));
    $this->assert_str_equals($TWiki::cfg{DefaultUserLogin}, TWiki::Func::wikiToUserName($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}));
	
    my $admin_cUID = $this->{twiki}->{users}->getCanonicalUserID($TWiki::cfg{AdminUserLogin});
    $this->assert_str_equals($TWiki::cfg{AdminUserLogin}, TWiki::Func::wikiToUserName($admin_cUID));
    $this->assert_str_equals($TWiki::cfg{AdminUserLogin}, TWiki::Func::wikiToUserName($TWiki::cfg{AdminUserLogin}));
    $this->assert_str_equals($TWiki::cfg{AdminUserLogin}, TWiki::Func::wikiToUserName($TWiki::cfg{AdminUserWikiName}));
    $this->assert_str_equals($TWiki::cfg{AdminUserLogin}, TWiki::Func::wikiToUserName($TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}));

    my $usera_cUID = $this->{twiki}->{users}->getCanonicalUserID('usera');
    $this->assert_str_equals('usera', TWiki::Func::wikiToUserName($usera_cUID));
    $this->assert_str_equals('usera', TWiki::Func::wikiToUserName('usera'));
    $this->assert_str_equals('usera', TWiki::Func::wikiToUserName('UserA'));
    $this->assert_str_equals('usera', TWiki::Func::wikiToUserName($TWiki::cfg{UsersWebName}.'.'.'UserA'));

#            $this->registerUser('usera86', 'User', 'A86', 'user86@example.com');
    my $usera86_cUID = $this->{twiki}->{users}->getCanonicalUserID('usera86');
    $this->assert_str_equals('usera86', TWiki::Func::wikiToUserName($usera86_cUID));
    $this->assert_str_equals('usera86', TWiki::Func::wikiToUserName('usera86'));
    $this->assert_str_equals('usera86', TWiki::Func::wikiToUserName('UserA86'));
    $this->assert_str_equals('usera86', TWiki::Func::wikiToUserName($TWiki::cfg{UsersWebName}.'.'.'UserA86'));
#            $this->registerUser('user86a', 'User86', 'A', 'user86a@example.com');
    my $user86a_cUID = $this->{twiki}->{users}->getCanonicalUserID('user86a');
    $this->assert_str_equals('user86a', TWiki::Func::wikiToUserName($user86a_cUID));
    $this->assert_str_equals('user86a', TWiki::Func::wikiToUserName('user86a'));
    $this->assert_str_equals('user86a', TWiki::Func::wikiToUserName('User86A'));
    $this->assert_str_equals('user86a', TWiki::Func::wikiToUserName($TWiki::cfg{UsersWebName}.'.'.'User86A'));
#            $this->registerUser('user862a', 'User', '86A', 'user862a@example.com');
#            $this->registerUser('86usera', '86User', 'A', 'user86a@example.com');

    #TODO: consider how to render unkown user's
    $this->assert_null(TWiki::Func::wikiToUserName('TWikiUserMapping_NonExistantUser'));
    $this->assert_null(TWiki::Func::wikiToUserName('nonexistantuser'));
    $this->assert_null(TWiki::Func::wikiToUserName('NonExistantUser'));
    $this->assert_null(TWiki::Func::wikiToUserName($TWiki::cfg{UsersWebName}.'.'.'NonExistantUser'));
    $this->assert_null(TWiki::Func::wikiToUserName($TWiki::cfg{UsersWebName}.'.'.'NonExistantUser86'));

    #TODO: consider how to render unkown user's
    #my $AandBGroup_cUID = $this->{twiki}->{users}->getCanonicalUserID('AandBGroup');
    #$this->annotate($AandBGroup_cUID);
    #$this->assert_str_equals('AandBGroup', TWiki::Func::wikiToUserName($AandBGroup_cUID));
    #$this->assert_str_equals('AandBGroup', TWiki::Func::wikiToUserName('AandBGroup'));
    #$this->assert_str_equals('AandBGroup', TWiki::Func::wikiToUserName('AandBGroup'));
    #$this->assert_str_equals('AandBGroup', TWiki::Func::wikiToUserName($TWiki::cfg{UsersWebName}.'.'.'AandBGroup'));
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
    $this->assert(TWiki::Func::isAnAdmin($usera_cUID));
    $this->assert(TWiki::Func::isAnAdmin('usera'));
    $this->assert(TWiki::Func::isAnAdmin('UserA'));
    $this->assert(TWiki::Func::isAnAdmin($TWiki::cfg{UsersWebName}.'.'.'UserA'));

    $this->assert(!TWiki::Func::isAnAdmin($TWiki::cfg{UsersWebName}.'.'.'UserB'));
    my $userb_cUID = $this->{twiki}->{users}->getCanonicalUserID('userb');
    $this->assert(!TWiki::Func::isAnAdmin($userb_cUID));
    $this->assert(!TWiki::Func::isAnAdmin('userb'));
    $this->assert(!TWiki::Func::isAnAdmin('UserB'));


    #TODO: consider how to render unkown user's
    $this->assert(!TWiki::Func::isAnAdmin('TWikiUserMapping_NonExistantUser'));
    my $nonexistantuser_cUID = $this->{twiki}->{users}->getCanonicalUserID('nonexistantuser');
    $this->annotate($nonexistantuser_cUID);
    $this->assert(!TWiki::Func::isAnAdmin($nonexistantuser_cUID));
    $this->assert(!TWiki::Func::isAnAdmin('nonexistantuser'));
    $this->assert(!TWiki::Func::isAnAdmin('NonExistantUser'));
    $this->assert(!TWiki::Func::isAnAdmin($TWiki::cfg{UsersWebName}.'.'.'NonExistantUser'));

    #TODO: consider how to render unkown user's
    #my $AandBGroup_cUID = $this->{twiki}->{users}->getCanonicalUserID('AandBGroup');
    #$this->annotate($AandBGroup_cUID);
    #$this->assert(!TWiki::Func::isAnAdmin($AandBGroup_cUID));
    #$this->assert(!TWiki::Func::isAnAdmin('AandBGroup'));
    #$this->assert(!TWiki::Func::isAnAdmin('AandBGroup'));
    #$this->assert(!TWiki::Func::isAnAdmin($TWiki::cfg{UsersWebName}.'.'.'AandBGroup'));
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
    $this->assert(TWiki::Func::isGroupMember('AandBGroup', $admin_cUID));
    $this->assert(TWiki::Func::isGroupMember('AandBGroup', $TWiki::cfg{AdminUserLogin}));
    $this->assert(TWiki::Func::isGroupMember('AandBGroup', $TWiki::cfg{AdminUserWikiName}));
    $this->assert(TWiki::Func::isGroupMember('AandBGroup', $TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}));

    $this->assert(!TWiki::Func::isGroupMember('AandCGroup', $admin_cUID));
    $this->assert(!TWiki::Func::isGroupMember('AandCGroup', $TWiki::cfg{AdminUserLogin}));
    $this->assert(!TWiki::Func::isGroupMember('AandCGroup', $TWiki::cfg{AdminUserWikiName}));
    $this->assert(!TWiki::Func::isGroupMember('AandCGroup', $TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}));


    my $usera_cUID = $this->{twiki}->{users}->getCanonicalUserID('usera');
    $this->assert(TWiki::Func::isGroupMember('AandBGroup', $usera_cUID));
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
    #my $AandBGroup_cUID = $this->{twiki}->{users}->getCanonicalUserID('AandBGroup');
    #$this->annotate($AandBGroup_cUID);
    #$this->assert(!TWiki::Func::isGroupMember('AandBGroup', $AandBGroup_cUID));
    #$this->assert(!TWiki::Func::isGroupMember('AandBGroup', 'AandBGroup'));
    #$this->assert(!TWiki::Func::isGroupMember('AandBGroup', 'AandBGroup'));
    #$this->assert(!TWiki::Func::isGroupMember('AandBGroup', $TWiki::cfg{UsersWebName}.'.'.'AandBGroup'));

#baseusermapping group
    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $TWiki::cfg{DefaultUserLogin}));
    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $guest_cUID));
    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $TWiki::cfg{DefaultUserWikiName}));
    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{DefaultUserWikiName}));
	
    $this->assert(TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $admin_cUID));
    $this->assert(TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $TWiki::cfg{AdminUserLogin}));
    $this->assert(TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $TWiki::cfg{AdminUserWikiName}));
    $this->assert(TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{AdminUserWikiName}));

    $this->assert(TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $usera_cUID));
    $this->assert(TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, 'usera'));
    $this->assert(TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, 'UserA'));
    $this->assert(TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $TWiki::cfg{UsersWebName}.'.'.'UserA'));

    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, 'userb'));
    my $userb_cUID = $this->{twiki}->{users}->getCanonicalUserID('userb');
    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $userb_cUID));
    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, 'UserB'));
    $this->assert(!TWiki::Func::isGroupMember($TWiki::cfg{SuperAdminGroup}, $TWiki::cfg{UsersWebName}.'.'.'UserB'));

}

1;
