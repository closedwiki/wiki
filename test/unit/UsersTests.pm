use strict;

package UsersTests;

# Some basic tests for adding/removing users in the TWiki users topic,
# and finding them again.

use base qw(Test::Unit::TestCase);

BEGIN {
    unshift @INC, '../../bin';
    require 'setlib.cfg';
};

use TWiki;
use TWiki::Users;

my $twiki;
my $me;
my $testtopic = "TmpUsersTopic".time();
my $saveTopic;
my $ttpath;

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

sub set_up {
    my $this = shift;
    $this->SUPER::set_up();
    $saveTopic = $TWiki::cfg{UsersTopicName};
}

sub tear_down {
    $TWiki::cfg{UsersTopicName} = $saveTopic;
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
    $ttpath = "$TWiki::cfg{DataDir}/$TWiki::cfg{UsersWebName}/$testtopic.txt";
    $TWiki::cfg{UsersTopicName} = $testtopic;
    $me =  $twiki->{users}->findUser("TWikiRegistrationAgent");

    open(F,">$ttpath") || $this->assert(0,  "open $ttpath failed");
    print F $initial;
    close(F);
    chmod(0777, $ttpath);
    my $user1 = $twiki->{users}->findUser("auser", "AaronUser");
    my $user2 = $twiki->{users}->findUser("guser", "GeorgeUser");
    my $user3 = $twiki->{users}->findUser("zuser", "ZebediahUser");
    $twiki->{users}->addUserToTWikiUsersTopic($user2, $me);
    my $text = `cat $ttpath`;
    $this->assert_matches(qr/\n\s+\* GeorgeUser - guser - \d\d \w\w\w \d\d\d\d\n/s, $text);
    $twiki->{users}->addUserToTWikiUsersTopic($user1, $me);
    $text = `cat $ttpath`;
    $this->assert_matches(qr/AaronUser.*GeorgeUser/s, $text);
    $twiki->{users}->addUserToTWikiUsersTopic($user3, $me);
    $text = `cat $ttpath`;
    $this->assert_matches(qr/Aaron.*George.*Zebediah/s, $text);
    unlink($ttpath);
}

sub testLoad {
    my $this = shift;

    $twiki = new TWiki();
    $me =  $twiki->{users}->findUser("TWikiRegistrationAgent");
    $ttpath = "$TWiki::cfg{DataDir}/$TWiki::cfg{UsersWebName}/$testtopic.txt";
    $TWiki::cfg{UsersTopicName} = $testtopic;

    open(F,">$ttpath") || $this->assert(0,  "open $ttpath failed");
    print F $initial;
    close(F);
    `chmod 777 $ttpath`;

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
    $this->assert($k =~ s/^Main\.AaronUser,//,$k);
    $this->assert($k =~ s/^Main\.AttilaTheHun,//,$k);
    $this->assert($k =~ s/^Main\.BungditDin,//,$k);
    $this->assert($k =~ s/^Main\.GeorgeUser,//,$k);
    $this->assert($k =~ s/^Main\.GungaDin,//,$k);
    $this->assert($k =~ s/^Main\.SadOldMan,//,$k);
    $this->assert($k =~ s/^Main\.SorryOldMan,//,$k);
    $this->assert($k =~ s/^Main\.StupidOldMan,//,$k);
    $this->assert($k =~ s/^Main\.ZebediahUser//,$k);
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

    unlink($ttpath);
}

1;
