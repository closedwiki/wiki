use strict;

# tests for TWiki::Mdrepo

package MdrepoTests;

use base qw( TWikiTestCase );

use TWiki;

sub new {
    my $self = shift()->SUPER::new(@_);
    return bless $self;
}

use Data::Dumper;

my $testWeb = 'TemporaryTestWeb'; # name of the test web
my $testTopic = 'TestTopic';      # name of a topic
my $testUsersWeb = 'TemporaryTestUsersUsersWeb';
 # Name of a %USERSWEB% for our test users
my $twiki; # TWiki instance

sub set_up {
    my $this = shift; # the Test::Unit::TestCase object
    $this->SUPER::set_up();

    # Settings for mdrepo
    $TWiki::cfg{MdrepoStore} = 'DB_File';
    my $rootDir = $TWiki::cfg{DataDir};
    $rootDir =~ s:/[^/]+$::;
    my $mdrepoDir = "$rootDir/mdrepo_test";
    mkdir($mdrepoDir, 0770) unless ( -d $mdrepoDir );
    $TWiki::cfg{MdrepoDir} = $mdrepoDir;
    $TWiki::cfg{MdrepoTables} = [qw(webs sites)];

    $TWiki::cfg{LogFileName} = "$rootDir/logTEST.txt";

    my $query = Unit::Request->new('');
    $query->path_info("/$testWeb/$testTopic");
    $twiki = new TWiki(undef, $query);    
    my $response = Unit::Response->new();
    $response->charset("utf8");
}

sub tear_down {
    my $this = shift;
    eval { $twiki->finish() };
    system("/bin/rm -rf $TWiki::cfg{MdrepoDir}");
    $this->SUPER::tear_down();
}

sub var_test {
    my ($this, $var, $expected) = @_;
    my $expanded = $twiki->handleCommonTags( $var, $twiki->{webName}, $twiki->{topicName} );
    $this->assert_equals($expanded, $expected);
}

sub test_mdrepo {
    my $this = shift;

    my $mdrepo = $twiki->{mdrepo};
    my $rec;

    # new empty table is expected to be created
    my @webs = $mdrepo->getList('webs');
    $this->assert_equals(scalar(@webs), 0);

    # retrieving nonexistent record
    $rec = $mdrepo->getRec('webs', 'foo');
    $this->assert_str_equals($rec, '');

    # another new empty table is expected to be created
    my @sites = $mdrepo->getList('sites');
    $this->assert_equals(scalar(@sites), 0);

    # a nonexistent table
    my @nonexistent = $mdrepo->getList('nonexistent');
    $this->assert_equals(scalar(@nonexistent), 0);
    $rec = $mdrepo->getRec('nonexistent', 'bar');
    $this->assert_str_equals($rec, '');

    # nothing should break by resetting empty and nonexistent tables
    $mdrepo->resetTable('webs');
    $mdrepo->resetTable('nonexistent');

    my %siteTable = (
	am => {server => 'strawman',  datadir => '/d/twiki/data',     pubdir => '/d/twiki/pub'},
	eu => {server => 'woodenman', datadir => '/var/twiki/data',   pubdir => '/var/twiki/pub'},
	as => {server => 'tinman',    datadir => '/share/twiki/data', pubdir => '/share/twiki/pub'},
    );
    my %webTable = (
	WebOne =>   {admin => 'GodelGroup',  master => 'am'},
        WebTwo =>   {admin => 'EscherGroup', master => 'eu'},
        WebThree => {admin => 'BachGroup',   master => 'as'},
    );

    # putting and getting data to/from the sites table
    for my $i ( keys %siteTable ) {
	$mdrepo->putRec('sites', $i, $siteTable{$i});
    }
    for my $i ( keys %siteTable ) {
	$rec = $mdrepo->getRec('sites', $i);
	$this->assert_deep_equals($rec, $siteTable{$i});
    }
    $this->var_test('%MDREPO{"sites"}%',
'| am | datadir=/d/twiki/data pubdir=/d/twiki/pub server=strawman |
| as | datadir=/share/twiki/data pubdir=/share/twiki/pub server=tinman |
| eu | datadir=/var/twiki/data pubdir=/var/twiki/pub server=woodenman |');
    $this->var_test('%MDREPO{"sites" format="?pubdir?$_=$server()?" separator=", "}%',
'am=strawman, as=tinman, eu=woodenman');

    # putting and getting data to/from the webs table
    for my $i ( keys %webTable ) {
	$mdrepo->putRec('webs', $i, $webTable{$i});
    }
    for my $i ( keys %webTable ) {
	$rec = $mdrepo->getRec('webs', $i);
	$this->assert_deep_equals($rec, $webTable{$i});
    }
    $this->var_test('%MDREPO{"webs"}%',
'| WebOne | admin=GodelGroup master=am |
| WebThree | admin=BachGroup master=as |
| WebTwo | admin=EscherGroup master=eu |');

    # confirming nothing breaks by putting a record to a nonexistent table
    $mdrepo->putRec('nonexistent', 'foo', {bar => 123});
    $rec = $mdrepo->getRec('nonexistent', 'foo');
    $this->assert_equals($rec, '');

    $mdrepo->delRec('webs', 'WebThree');
    $rec = $mdrepo->getRec('webs', 'WebThree');
    $this->assert_str_equals($rec, '');
    my @list = $mdrepo->getList('webs');
    $this->assert_equals(scalar(@list), 2);

    $mdrepo->delRec('sites', 'as');
    $rec = $mdrepo->getRec('sites', 'as');
    $this->assert_str_equals($rec, '');
    @list = $mdrepo->getList('sites');
    $this->assert_equals(scalar(@list), 2);

    my $siteAm1 = {server => 'strawma',  datadir => '/d/twiki/dat',     pubdir => '/d/twiki/pu'};
    $mdrepo->putRec('sites', 'am', $siteAm1);
    $rec = $mdrepo->getRec('sites', 'am');
    $this->assert_deep_equals($rec, $siteAm1);

    my $webTwo1 = {admin => 'EscheGroup', master => 'as'};
    $mdrepo->putRec('webs', 'WebTwo', $webTwo1);
    $rec = $mdrepo->getRec('webs', 'WebTwo');
    $this->assert_deep_equals($rec, $webTwo1);

    $mdrepo->resetTable('webs');
    $this->assert_equals(scalar($mdrepo->getList('webs')), 0);
    $rec = $mdrepo->getRec('webs', 'WebOne');
    $this->assert_str_equals($rec, '');

    $mdrepo->resetTable('sites');
    $this->assert_equals(scalar($mdrepo->getList('sites')), 0);
    $rec = $mdrepo->getRec('sites', 'am');
    $this->assert_str_equals($rec, '');
}

1;
