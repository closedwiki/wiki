use strict;

package MdrepoScriptTests;

use base qw(TWikiFnTestCase);

use strict;
use TWiki;
use TWiki::UI::MdrepoUI;
use Error qw( :try );
use IO::Handle;

my $testWeb = 'TemporaryTestWeb'; # name of the test web
my $testTopic = 'TestTopic';      # name of a topic
my $testUsersWeb = 'TemporaryTestUsersUsersWeb';
 # Name of a %USERSWEB% for our test users
my $twiki;

my $siteAmRec = {server => 'strawman',  datadir => '/d/twiki/data',     pubdir => '/d/twiki/pub'};
my $siteEuRec = {server => 'woodenman', datadir => '/var/twiki/data',   pubdir => '/var/twiki/pub'};
my $siteAsRec = {server => 'tinman',    datadir => '/share/twiki/data', pubdir => '/share/twiki/pub'};
my %siteData = (
    am => $siteAmRec,
    eu => $siteEuRec,
    as => $siteAsRec,,
);
my $siteAmShow = <<'END';
am
    datadir=/d/twiki/data
    pubdir=/d/twiki/pub
    server=strawman

END
my $siteAsShow = <<'END'; 
as
    datadir=/share/twiki/data
    pubdir=/share/twiki/pub
    server=tinman

END
my $siteEuShow = <<'END';
eu
    datadir=/var/twiki/data
    pubdir=/var/twiki/pub
    server=woodenman

END
my $siteList = $siteAmShow . $siteAsShow . $siteEuShow;

my $webOneRec   = {admin => 'GodelGroup',  master => 'am'};
my $webTwoRec   = {admin => 'EscherGroup', master => 'eu'};
my $webThreeRec = {admin => 'BachGroup',   master => 'as'};
my %webData = (
    WebOne =>   $webOneRec,
    WebTwo =>   $webTwoRec,
    WebThree => $webThreeRec,
);
my $webOneShow = <<'END';
WebOne
    admin=GodelGroup
    master=am

END
my $webThreeShow = <<'END';
WebThree
    admin=BachGroup
    master=as

END
my $webTwoShow = <<'END';
WebTwo
    admin=EscherGroup
    master=eu

END
my $webList = $webOneShow . $webThreeShow . $webTwoShow;

# Set up the test fixture
sub set_up {
    my $this = shift;

    $ENV{REMOTE_USER} = 'scum';
    # Settings for mdrepo
    $TWiki::cfg{MdrepoStore} = 'DB_File';
    my $rootDir = $TWiki::cfg{DataDir};
    $rootDir =~ s:/[^/]+$::;
    my $mdrepoDir = "$rootDir/mdrepo_test";
    mkdir($mdrepoDir, 0770) unless ( -d $mdrepoDir );
    $TWiki::cfg{MdrepoDir} = $mdrepoDir;
    $TWiki::cfg{MdrepoTables} = [qw(sites webs:b)];

    $this->SUPER::set_up();
    my $twiki = $this->{twiki};
    $twiki->{store}->saveTopic($twiki->{user}, $this->{users_web}, 'TWikiAdminGroup', <<'END');
   * Set GROUP = ScumBag
END
    $twiki->finish();
    $this->{twiki} = new TWiki($this->{test_user_login}, $this->{request});
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    system("/bin/rm -rf $TWiki::cfg{MdrepoDir}");
}

sub mdrepo_cli_test {
    my $this = shift;
    my $expected = shift;
    my $twiki = $this->{twiki};

    $twiki->enterContext( 'command_line' );
    @ARGV = @_;
    my ($text, $result) = $this->capture( \&TWiki::UI::MdrepoUI::mdrepo, $twiki);
    $this->assert_equals($expected, $result);
    $twiki->leaveContext( 'command_line' );
}

sub mdrepo_cgi_test {
    my $this = shift;
    my ($expected, $cmd, $table, $recId, $rec) = @_;
    my $twiki = $this->{twiki};
    my $request = $this->{request};
    my $mdrepo = $twiki->{mdrepo};

    $request->param(-name => '_' . $cmd, -value => $cmd);
    $request->param(-name => '_table', -value => $table);
    $request->param(-name => '_recid', -value => $recId);
    if ( $rec ) {
	for my $i ( keys %$rec ) {
	    $request->param(-name => ('__' . $i), -value => $rec->{$i});
	}
    }
    my ($text, $result) = $this->capture( \&TWiki::UI::MdrepoUI::mdrepo, $twiki);
    $this->assert_equals($expected, $result);
    $request->delete_all;
}

sub test_list_rset_sites {
    my $this = shift;
    my $mdrepo = $this->{twiki}{mdrepo};

    $this->mdrepo_cli_test('',
		       'list', 'sites');
    for my $i ( keys %siteData ) {
	$mdrepo->putRec('sites', $i, $siteData{$i});
    }
    $this->mdrepo_cli_test($siteList,
		       'list', 'sites');
    $this->mdrepo_cli_test('',
		       'rset', 'sites');
    $this->mdrepo_cli_test('',
		       'list', 'sites');
}

sub test_list_rset_webs {
    my $this = shift;
    my $mdrepo = $this->{twiki}{mdrepo};

    $this->mdrepo_cli_test('',
		       'list', 'webs');
    for my $i ( keys %webData ) {
	$mdrepo->putRec('webs', $i, $webData{$i});
    }
    $this->mdrepo_cli_test($webList,
		       'list', 'webs');
    $this->mdrepo_cli_test('',
		       'rset', 'webs');
    $this->mdrepo_cli_test('',
		       'list', 'webs');
}

sub test_show_sites {
    my $this = shift;
    my $mdrepo = $this->{twiki}{mdrepo};

    $this->mdrepo_cli_test('',
		       'show', 'sites', 'am');
    for my $i ( keys %siteData ) {
	$mdrepo->putRec('sites', $i, $siteData{$i});
    }
    $this->mdrepo_cli_test($siteAmShow,
		       'show', 'sites', 'am');

    $mdrepo->resetTable('sites');
}

sub test_show_webs {
    my $this = shift;
    my $mdrepo = $this->{twiki}{mdrepo};

    $this->mdrepo_cli_test('',
		       'show', 'webs', 'WebOne');
    for my $i ( keys %webData ) {
	$mdrepo->putRec('webs', $i, $webData{$i});
    }
    $this->mdrepo_cli_test($webOneShow,
		       'show', 'webs', 'WebOne');

    $mdrepo->resetTable('webs');
}

sub rec2list {
    my $rec = shift;
    my @retval;
    for my $i ( keys %$rec ) {
	push(@retval, "$i=$rec->{$i}");
    }
    @retval;
}

sub test_add_updt_del_sites {
    my $this = shift;
    my $mdrepo = $this->{twiki}{mdrepo};

    $this->mdrepo_cli_test("REC_ID am does not exist\n",
	'del', 'sites', 'am');
    $this->mdrepo_cli_test("REC_ID am does not exist\n",
	'updt', 'sites', 'am', rec2list($siteAmRec));
    $this->mdrepo_cli_test('',
	'add', 'sites', 'am', rec2list($siteAmRec));
    $this->mdrepo_cli_test($siteAmShow,
	'show', 'sites', 'am');
    $this->mdrepo_cli_test("REC_ID am already exists\n",
	'add', 'sites', 'am', rec2list($siteAmRec));
    $this->mdrepo_cli_test('',
	'updt', 'sites', 'am', rec2list($siteAmRec));
    $this->mdrepo_cli_test('',
	'del', 'sites', 'am');

    $mdrepo->resetTable('sites');
}

sub test_add_updt_del_webss {
    my $this = shift;
    my $mdrepo = $this->{twiki}{mdrepo};

    $this->mdrepo_cli_test("REC_ID WebOne does not exist\n",
	'del', 'webs', 'WebOne');
    $this->mdrepo_cli_test("REC_ID WebOne does not exist\n",
	'updt', 'webs', 'WebOne', rec2list($webOneRec));
    $this->mdrepo_cli_test('',
	'add', 'webs', 'WebOne', rec2list($webOneRec));
    $this->mdrepo_cli_test($webOneShow,
	'show', 'webs', 'WebOne');
    $this->mdrepo_cli_test("REC_ID WebOne already exists\n",
	'add', 'webs', 'WebOne', rec2list($webOneRec));
    $this->mdrepo_cli_test('',
	'updt', 'webs', 'WebOne', rec2list($webOneRec));
    $this->mdrepo_cli_test('',
	'del', 'webs', 'WebOne');

    $mdrepo->resetTable('webs');
}

sub test_load_sites {
    my $this = shift;
    my $mdrepo = $this->{twiki}{mdrepo};

    my $fileName = "$TWiki::cfg{WorkingDir}/tmp/sites";
    open(my $fh, '>', $fileName) or
	die "open: $fileName: $!\n";
    $fh->print($siteList);
    $fh->close;
    $this->mdrepo_cli_test('',
	'load', 'sites', $fileName);
    $this->mdrepo_cli_test($siteList,
	'list', 'sites');
    $mdrepo->resetTable('sites');
}

sub test_load_webs {
    my $this = shift;
    my $mdrepo = $this->{twiki}{mdrepo};

    my $fileName = "$TWiki::cfg{WorkingDir}/tmp/webs";
    open(my $fh, '>', $fileName) or
	die "open: $fileName: $!\n";
    $fh->print($webList);
    $fh->close;
    $this->mdrepo_cli_test('',
	'load', 'webs', $fileName);
    $this->mdrepo_cli_test($webList,
	'list', 'webs');
    $mdrepo->resetTable('webs');
}

sub test_cgi_add_del_updt {
    my $this = shift;
    my $mdrepo = $this->{twiki}{mdrepo};

    $this->mdrepo_cgi_test("REC_ID WebOne does not exist\n",
	'del', 'webs', 'WebOne');
    $this->mdrepo_cgi_test("REC_ID WebOne does not exist\n",
	'updt', 'webs', 'WebOne', $webOneRec);
    $this->mdrepo_cgi_test('',
	'add', 'webs', 'WebOne', $webOneRec);
    my $rec = $mdrepo->getRec('webs', 'WebOne');
    $this->assert_deep_equals($webOneRec, $rec);
    $this->mdrepo_cgi_test("REC_ID WebOne already exists\n",
	'add', 'webs', 'WebOne', $webOneRec);
    $this->mdrepo_cgi_test('',
	'del', 'webs', 'WebOne');
    $mdrepo->resetTable('webs');
    $this->mdrepo_cgi_test("table sites is not allowed to be modified via CGI.\n",
	'add', 'sites', 'am', $siteAmRec);
    $mdrepo->resetTable('sites');
}

1;
