use strict;

package UsersTests;

# Some basic tests for adding/removing users in the TWiki users topic,
# and finding them again.

use base qw(TWikiTestCase);

use TWiki;
use TWiki::Users;
use Error qw( :try );

my $twiki;
my $me;
my $saveTopic;
my $ttpath;

my $testSysWeb = 'TemporaryTestUsersSystemWeb';
my $testNormalWeb = "TemporaryTestUsersWeb";
my $testUsersWeb = "TemporaryTesUsersUsersWeb";
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
    $TWiki::cfg{LocalSitePreferences} = "$testUsersWeb.TWikiPreferences";

    $topicquery = new CGI( "" );
    $topicquery->path_info("/$testNormalWeb/$testTopic");
    try {
        $twiki = new TWiki('AdminUser');
        my $twikiUserObject = $twiki->{user};
        $twiki->{store}->createWeb($twikiUserObject, $testUsersWeb);
        # the group is recursive to force a recursion block
        $twiki->{store}->saveTopic(
            $twiki->{user}, $testUsersWeb, 'TWikiAdminGroup',
            '   * Set GROUP = '.$twikiUserObject->wikiName().", TWikiAdminGroup\n");

        $twiki->{store}->createWeb($twikiUserObject, $testSysWeb, $original);
        $twiki->{store}->createWeb($twikiUserObject, $testNormalWeb, '_default');

        $twiki->{store}->copyTopic(
            $twikiUserObject, $original, $TWiki::cfg{SitePrefsTopicName},
            $testSysWeb, $TWiki::cfg{SitePrefsTopicName} );

        $testUser = $this->createFakeUser($twiki);
    } catch TWiki::AccessControlException with {
        my $e = shift;
        die "FUCK" unless $e;
        $this->assert(0,$e->stringify());
    } catch Error::Simple with {
        $this->assert(0,shift->stringify()||'');
    };
}

sub tear_down {
    my $this = shift;

    $this->SUPER::tear_down();
    $this->assert_str_equals($original, $TWiki::cfg{SystemWebName});
    $twiki->{store}->removeWeb($twiki->{user}, $testUsersWeb);
    $twiki->{store}->removeWeb($twiki->{user}, $testSysWeb);
    $twiki->{store}->removeWeb($twiki->{user}, $testNormalWeb);
    $this->assert($original, $TWiki::cfg{SystemWebName});
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

sub testAddUsers {
    my $this = shift;
    $twiki = new TWiki();
    $ttpath = "$TWiki::cfg{DataDir}/$TWiki::cfg{UsersWebName}/$testTopic.txt";
    $TWiki::cfg{UsersTopicName} = $testTopic;
    $me =  $twiki->{users}->findUser("TWikiRegistrationAgent");

    open(F,">$ttpath") || $this->assert(0,  "open $ttpath failed");
    print F $initial;
    close(F);
    chmod(0777, $ttpath);
    my $user1 = $twiki->{users}->findUser("auser", "AaronUser");
    my $user2 = $twiki->{users}->findUser("guser", "GeorgeUser");
    my $user3 = $twiki->{users}->findUser("zuser", "ZebediahUser");
    $twiki->{users}->addUserToTWikiUsersTopic($user2, $me);
    open(F,"<$ttpath");
    undef $/;
    my $text = <F>;
    close(F);
    $this->assert_matches(qr/\n\s+\* GeorgeUser - guser - \d\d \w\w\w \d\d\d\d\n/s, $text);
    $twiki->{users}->addUserToTWikiUsersTopic($user1, $me);
    open(F,"<$ttpath");
    undef $/;
    $text = <F>;
    close(F);
    $this->assert_matches(qr/AaronUser.*GeorgeUser/s, $text);
    $twiki->{users}->addUserToTWikiUsersTopic($user3, $me);
    open(F,"<$ttpath");
    undef $/;
    $text = <F>;
    close(F);
    $this->assert_matches(qr/Aaron.*George.*Zebediah/s, $text);
#    unlink($ttpath);
    print $ttpath."\n";
}

sub testLoad {
    my $this = shift;

    $twiki = new TWiki();
    $me =  $twiki->{users}->findUser("TWikiRegistrationAgent");
    $ttpath = "$TWiki::cfg{DataDir}/$TWiki::cfg{UsersWebName}/$testTopic.txt";
    $TWiki::cfg{UsersTopicName} = $testTopic;

    open(F,">$ttpath") || $this->assert(0,  "open $ttpath failed");
    print F $initial;
    close(F);

    my $user1 = $twiki->{users}->findUser("auser", "AaronUser");
    my $user2 = $twiki->{users}->findUser("guser","GeorgeUser");
    my $user3 = $twiki->{users}->findUser("zuser","ZebediahUser");
    $twiki->{users}->addUserToTWikiUsersTopic($user1, $me);
    $twiki->{users}->addUserToTWikiUsersTopic($user2, $me);
    $twiki->{users}->addUserToTWikiUsersTopic($user3, $me);
    $twiki->{users}->addUserToTWikiUsersTopic($user1, $me);
    $twiki->{users}->addUserToTWikiUsersTopic($user2, $me);
    $twiki->{users}->addUserToTWikiUsersTopic($user3, $me);
    # find a nonexistent user to force a cache read
    $twiki = new TWiki();
    $twiki->{users}->findUser("hogwash");
    my $k = join(",",sort keys %{$twiki->{users}->{W2U}});
    $this->assert($k =~ s/^$TWiki::cfg{UsersWebName}\.AaronUser,//,$k);
    $this->assert($k =~ s/^$TWiki::cfg{UsersWebName}\.AttilaTheHun,//,$k);
    $this->assert($k =~ s/^$TWiki::cfg{UsersWebName}\.BungditDin,//,$k);
    $this->assert($k =~ s/^$TWiki::cfg{UsersWebName}\.GeorgeUser,//,$k);
    $this->assert($k =~ s/^$TWiki::cfg{UsersWebName}\.GungaDin,//,$k);
    $this->assert($k =~ s/^$TWiki::cfg{UsersWebName}\.SadOldMan,//,$k);
    $this->assert($k =~ s/^$TWiki::cfg{UsersWebName}\.SorryOldMan,//,$k);
    $this->assert($k =~ s/^$TWiki::cfg{UsersWebName}\.StupidOldMan,//,$k);
    $this->assert($k =~ s/^$TWiki::cfg{UsersWebName}\.ZebediahUser//,$k);
    $this->assert_str_equals("",$k);
    $k = join(",",sort keys %{$twiki->{users}->{U2W}});
    $this->assert($k =~ s/^AttilaTheHun,//,$k);
    $this->assert($k =~ s/^BungditDin,//,$k);
    $this->assert($k =~ s/^GungaDin,//,$k);
    $this->assert($k =~ s/^SadOldMan,//,$k);
    $this->assert($k =~ s/^SorryOldMan,//,$k);
    $this->assert($k =~ s/^StupidOldMan,//,$k);
    $this->assert($k =~ s/^auser,//,$k);
    $this->assert($k =~ s/^guser,//,$k);
    $this->assert($k =~ s/^zuser//,$k);
    $this->assert_str_equals("", $k);

#    unlink($ttpath);
}

1;
