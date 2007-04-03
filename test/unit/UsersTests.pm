use strict;

package UsersTests;

# Some basic tests for TWiki::Users::TWikiUserMapping
#
# The tests are performed using the APIs published by the facade class,
# TWiki:Users, not the actual TWiki::Users::TWikiuserMapping

use base qw(TWikiTestCase);

use TWiki;
use TWiki::Users;
use Error qw( :try );

my $twiki;
my $saveTopic;
my $ttpath;

my $testSysWeb = 'TemporaryTestUsersSystemWeb';
my $testNormalWeb = "TemporaryTestUsersWeb";
my $testUsersWeb = "TemporaryTestUsersUsersWeb";
my $testTopic = "TmpUsersTopic".time();
my $testUser;

my $topicquery;

my $original;

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $original = $TWiki::cfg{SystemWebName};
    $TWiki::cfg{UsersWebName} = $testUsersWeb;
    $TWiki::cfg{SystemWebName} = $testSysWeb;
    $TWiki::cfg{SuperAdminGroup} = 'ArfleBarfleGloop';
    $TWiki::cfg{LocalSitePreferences} = "$testUsersWeb.TWikiPreferences";
    $TWiki::cfg{UserMappingManager} = 'TWiki::Users::TWikiUserMapping';
    $TWiki::cfg{MapUserToWikiName} = 1;;
    $topicquery = new CGI( "" );
    $topicquery->path_info("/$testNormalWeb/$testTopic");
    try {
        $twiki = new TWiki($TWiki::cfg{SuperAdminGroup});
        $twiki->{store}->createWeb($twiki->{user}, $testUsersWeb);
        # the group is recursive to force a recursion block
        $twiki->{store}->saveTopic(
            $twiki->{user}, $testUsersWeb, $TWiki::cfg{SuperAdminGroup},
            '   * Set GROUP = '.$twiki->{user}.", ".
              $TWiki::cfg{SuperAdminGroup}."\n");

        $twiki->{store}->createWeb($twiki->{user}, $testSysWeb, $original);
        $twiki->{store}->createWeb($twiki->{user}, $testNormalWeb, '_default');

        $twiki->{store}->copyTopic(
            $twiki->{user}, $original, $TWiki::cfg{SitePrefsTopicName},
            $testSysWeb, $TWiki::cfg{SitePrefsTopicName} );

        $testUser = $this->createFakeUser($twiki);
    } catch TWiki::AccessControlException with {
        my $e = shift;
        $this->assert(0,$e->stringify());
    } catch Error::Simple with {
        $this->assert(0,shift->stringify()||'');
    };
}

sub tear_down {
    my $this = shift;

    $this->removeWebFixture($twiki, $testUsersWeb);
    $this->removeWebFixture($twiki, $testSysWeb);
    $this->removeWebFixture($twiki, $testNormalWeb);
    eval {$twiki->finish()};
    $this->SUPER::tear_down();
}

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

my $initial = <<'THIS';
	* A - <a name="A">- - - -</a>
    * AttilaTheHun - 10 Jan 1601
	* B - <a name="B">- - - -</a>
	* BungditDin - 10 Jan 2004
	* C - <a name="C">- - - -</a>
	* D - <a name="D">- - - -</a>
	* E - <a name="E">- - - -</a>
	* F - <a name="F">- - - -</a>
	* G - <a name="G">- - - -</a>
	* GungaDin - 10 Jan 2004
	* H - <a name="H">- - - -</a>
	* I - <a name="I">- - - -</a>
	* J - <a name="J">- - - -</a>
	* K - <a name="K">- - - -</a>
	* L - <a name="L">- - - -</a>
	* M - <a name="M">- - - -</a>
	* N - <a name="N">- - - -</a>
	* O - <a name="O">- - - -</a>
	* P - <a name="P">- - - -</a>
	* Q - <a name="Q">- - - -</a>
	* R - <a name="R">- - - -</a>
	* S - <a name="S">- - - -</a>
	* SadOldMan - 10 Jan 2004
	* SorryOldMan - 10 Jan 2004
	* StupidOldMan - 10 Jan 2004
	* T - <a name="T">- - - -</a>
	* U - <a name="U">- - - -</a>
	* V - <a name="V">- - - -</a>
	* W - <a name="W">- - - -</a>
	* X - <a name="X">- - - -</a>
	* Y - <a name="Y">- - - -</a>
	* Z - <a name="Z">- - - -</a>
THIS

sub createFakeUser {
    my( $this, $twiki, $text, $name ) = @_;
    $this->assert($twiki->{store}->webExists($TWiki::cfg{UsersWebName}));
    $name ||= '';
    my $base = "TemporaryTestUser".$name;
    my $i = 0;
    while($twiki->{store}->topicExists($TWiki::cfg{UsersWebName},$base.$i)) {
        $i++;
    }
    $text ||= '';
    my $meta = new TWiki::Meta($twiki, $TWiki::cfg{UsersWebName}, $base.$i);
    $meta->put( "TOPICPARENT", {
        name => $TWiki::cfg{UsersWebName}.'.'.$TWiki::cfg{HomeTopicName} } );
    $twiki->{store}->saveTopic($twiki->{user},
                               $TWiki::cfg{UsersWebName},
                               $base.$i,
                               $text, $meta);
    push( @{$this->{fake_users}}, $base.$i);
    return $base.$i;
}

sub testAddUsers {
    my $this = shift;
    $twiki = new TWiki();
    my $ttpath = "$TWiki::cfg{DataDir}/$TWiki::cfg{UsersWebName}/$TWiki::cfg{UsersTopicName}.txt";
    my $me =  "TWikiRegistrationAgent";

    open(F,">$ttpath") || $this->assert(0,  "open $ttpath failed");
    print F $initial;
    close(F);
    chmod(0777, $ttpath);
    $twiki->{users}->{mapping}->addUserToMapping("GeorgeUser", "guser", $me);
    open(F,"<$ttpath");
    local $/ = undef;
    my $text = <F>;
    close(F);
    $this->assert_matches(qr/\n\s+\* GeorgeUser - guser - \d\d \w\w\w \d\d\d\d\n/s, $text);
    $twiki->{users}->{mapping}->addUserToMapping("AaronUser", "auser", $me);
    open(F,"<$ttpath");
    local $/ = undef;
    $text = <F>;
    close(F);
    $this->assert_matches(qr/AaronUser.*GeorgeUser/s, $text);
    $twiki->{users}->{mapping}->addUserToMapping("ZebediahUser", "zuser", $me);
    open(F,"<$ttpath");
    local $/ = undef;
    $text = <F>;
    close(F);
    $this->assert_matches(qr/Aaron.*George.*Zebediah/s, $text);
}

sub testLoad {
    my $this = shift;

    $twiki = new TWiki();
    my $me = "TWikiRegistrationAgent";
    $ttpath = "$TWiki::cfg{DataDir}/$TWiki::cfg{UsersWebName}/$TWiki::cfg{UsersTopicName}.txt";

    open(F,">$ttpath") || $this->assert(0,  "open $ttpath failed");
    print F $initial;
    close(F);

    $twiki->{users}->{mapping}->addUserToMapping("ZebediahUser", "zuser", $me);
    $twiki->{users}->{mapping}->addUserToMapping("AaronUser", "auser", $me);
    $twiki->{users}->{mapping}->addUserToMapping("GeorgeUser", "guser", $me);
    # deliberate repeat
    $twiki->{users}->{mapping}->addUserToMapping("ZebediahUser", "zuser", $me);
    # find a nonexistent user to force a cache read
    $twiki = new TWiki();
    my $n = $twiki->{users}->{mapping}->lookupLoginName("auser");
    $this->assert_str_equals("AaronUser", $n);
    $n = $twiki->{users}->getLoginName("auser");
    $this->assert_str_equals("auser", $n);
    $n = $twiki->{users}->getWikiName("auser");
    $this->assert_str_equals("AaronUser", $n);

    my $i = $twiki->{users}->eachUser();
    my @l = ();
    while ($i->hasNext()) { push(@l, $i->next()) };
    my $k = join(",",sort @l);
    $this->assert($k =~ s/^AaronUser,//,$k);
    $this->assert($k =~ s/^AttilaTheHun,//,$k);
    $this->assert($k =~ s/^BungditDin,//,$k);
    $this->assert($k =~ s/^GeorgeUser,//,$k);
    $this->assert($k =~ s/^GungaDin,//,$k);
    $this->assert($k =~ s/^SadOldMan,//,$k);
    $this->assert($k =~ s/^SorryOldMan,//,$k);
    $this->assert($k =~ s/^StupidOldMan,//,$k);
    $this->assert($k =~ s/^TWikiGuest,//,$k);
    $this->assert($k =~ s/^ZebediahUser//,$k);
    $this->assert_str_equals("",$k);
}

sub groupFix {
    my $this = shift;
    my $me =  "TWikiRegistrationAgent";
    $twiki->{users}->{mapping}->addUserToMapping("AaronUser", "auser", $me);
    $twiki->{users}->{mapping}->addUserToMapping("GeorgeUser", "guser", $me);
    $twiki->{users}->{mapping}->addUserToMapping("ZebediahUser", "zuser", $me);
    $twiki->{users}->{mapping}->addUserToMapping("AaronUser", "auser", $me);
    $twiki->{users}->{mapping}->addUserToMapping("GeorgeUser", "guser", $me);
    $twiki->{users}->{mapping}->addUserToMapping("ZebediahUser", "zuser", $me);
    $twiki->{store}->saveTopic(
        $twiki->{user}, $testUsersWeb, 'AmishGroup',
        "   * Set GROUP = AaronUser,%MAINWEB%.GeorgeUser\n");
    $twiki->{store}->saveTopic(
        $twiki->{user}, $testUsersWeb, 'BaptistGroup',
        "   * Set GROUP = GeorgeUser,$testUsersWeb.ZebediahUser\n");
}

sub test_getListOfGroups {
    my $this = shift;
    $this->groupFix();
    my $i = $twiki->{users}->eachGroup();
    my @l = ();
    while ($i->hasNext()) { push(@l, $i->next()) };
    my $k = join(',', sort @l);
    $this->assert_str_equals("AmishGroup,BaptistGroup", $k);
}

sub test_groupMembers {
    my $this = shift;
    $this->groupFix();
    my $g = "AmishGroup";
    $this->assert($twiki->{users}->isGroup($g));
    my $i = $twiki->{users}->eachGroupMember($g);
    my @l = ();
    while ($i->hasNext()) { push(@l, $i->next()) };
    my $k = join(',', sort @l);
    $this->assert_str_equals("auser,guser", $k);
    $g = "BaptistGroup";
    $this->assert($twiki->{users}->isGroup($g));

    $i = $twiki->{users}->eachGroupMember($g);
    @l = ();
    while ($i->hasNext()) { push(@l, $i->next()) };
    $k = join(',', sort @l);
    $this->assert_str_equals("guser,zuser", $k);

}

1;
