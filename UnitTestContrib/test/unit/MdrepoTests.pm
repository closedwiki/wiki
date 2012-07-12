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
    my $expanded =
        $twiki->handleCommonTags($var, $twiki->{webName}, $twiki->{topicName});
    $this->assert_equals($expected, $expanded);
}

my %siteTable = (
    am => {server => 'strawman',
           datadir => '/d/twiki/data',
           pubdir => '/d/twiki/pub',
    },
    eu => {server => 'woodenman',
           datadir => '/var/twiki/data',
           pubdir => '/var/twiki/pub',
    },
    as => {server => 'tinman',
           datadir => '/share/twiki/data',
           pubdir => '/share/twiki/pub',
    },
);

my %webTable = (
    WebOne =>   {admin => 'GodelGroup',  master => 'am'},
    WebTwo =>   {admin => 'EscherGroup', master => 'eu'},
    WebThree => {admin => 'BachGroup',   master => 'as'},
);

sub load_sites {
    my $this = shift;
    my $mdrepo = $twiki->{mdrepo};

    # putting and getting data to/from the sites table
    for my $i ( keys %siteTable ) {
	$mdrepo->putRec('sites', $i, $siteTable{$i});
    }
}

sub load_webs {
    my $this = shift;
    my $mdrepo = $twiki->{mdrepo};

    # putting and getting data to/from the webs table
    for my $i ( keys %webTable ) {
	$mdrepo->putRec('webs', $i, $webTable{$i});
    }
}

sub test_010_webs_empty {
    my $this = shift;
    my $mdrepo = $twiki->{mdrepo};

    # new empty table is expected to be created
    my @webs = $mdrepo->getList('webs');
    $this->assert_equals(0, scalar(@webs));
}

sub test_020_webs_nonexistent_record {
    my $this = shift;
    my $mdrepo = $twiki->{mdrepo};

    # retrieving nonexistent record
    my $rec = $mdrepo->getRec('webs', 'foo');
    $this->assert_str_equals('', $rec);
}

sub test_030_sites_empty {
    my $this = shift;
    my $mdrepo = $twiki->{mdrepo};

    # another new empty table is expected to be created
    my @sites = $mdrepo->getList('sites');
    $this->assert_equals(0, scalar(@sites));
}

sub test_040_nonexistent_table {
    my $this = shift;
    my $mdrepo = $twiki->{mdrepo};

    my @nonexistent = $mdrepo->getList('nonexistent');
    $this->assert_equals(0, scalar(@nonexistent));
    my $rec = $mdrepo->getRec('nonexistent', 'bar');
    $this->assert_str_equals('', $rec);
}

sub test_050_reset_table {
    my $this = shift;
    my $mdrepo = $twiki->{mdrepo};

    # nothing should break by resetting empty and nonexistent tables
    $mdrepo->resetTable('webs');
    $mdrepo->resetTable('nonexistent');
}

sub test_060_put_sites_rec {
    my $this = shift;
    my $mdrepo = $twiki->{mdrepo};

    # putting and getting data to/from the sites table
    $this->load_sites();
    for my $i ( keys %siteTable ) {
	my $rec = $mdrepo->getRec('sites', $i);
	$this->assert_deep_equals($siteTable{$i}, $rec);
    }
}

sub test_070_MDREPO_sites_vanilla {
    my $this = shift;

    $this->load_sites();
    $this->var_test('%MDREPO{"sites"}%',
'| am | datadir=/d/twiki/data pubdir=/d/twiki/pub server=strawman |
| as | datadir=/share/twiki/data pubdir=/share/twiki/pub server=tinman |
| eu | datadir=/var/twiki/data pubdir=/var/twiki/pub server=woodenman |');
}

sub test_075_MDREPO_sites_custom {
    my $this = shift;

    $this->load_sites();
    $this->var_test(
        '%MDREPO{"sites" format="?pubdir?$_=$server()?" separator=", "}%',
        'am=strawman, as=tinman, eu=woodenman'
    );
}

sub test_080_put_webs_rec {
    my $this = shift;
    my $mdrepo = $twiki->{mdrepo};

    # putting and getting data to/from the webs table
    $this->load_webs();
    for my $i ( keys %webTable ) {
	my $rec = $mdrepo->getRec('webs', $i);
	$this->assert_deep_equals($webTable{$i}, $rec);
    }
}

sub test_090_MDREPO_webs {
    my $this = shift;
    my $mdrepo = $twiki->{mdrepo};

    $this->load_webs();
    $this->var_test('%MDREPO{"webs"}%',
'| WebOne | admin=GodelGroup master=am |
| WebThree | admin=BachGroup master=as |
| WebTwo | admin=EscherGroup master=eu |');
}

sub test_100_put_nonexistent_table {
    my $this = shift;
    my $mdrepo = $twiki->{mdrepo};

    # confirming nothing breaks by putting a record to a nonexistent table
    $mdrepo->putRec('nonexistent', 'foo', {bar => 123});
    my $rec = $mdrepo->getRec('nonexistent', 'foo');
    $this->assert_equals('', $rec);
}

sub test_110_del_webs_rec {
    my $this = shift;
    my $mdrepo = $twiki->{mdrepo};

    $this->load_webs();
    $mdrepo->delRec('webs', 'WebThree');
    my $rec = $mdrepo->getRec('webs', 'WebThree');
    $this->assert_str_equals('', $rec);
    my @list = $mdrepo->getList('webs');
    $this->assert_equals(2, scalar(@list));
}

sub test_120_del_sites_rec {
    my $this = shift;
    my $mdrepo = $twiki->{mdrepo};

    $this->load_sites();
    $mdrepo->delRec('sites', 'as');
    my $rec = $mdrepo->getRec('sites', 'as');
    $this->assert_str_equals('', $rec);
    my @list = $mdrepo->getList('sites');
    $this->assert_equals(scalar(@list), 2);
}

sub test_130_updt_sites_rec {
    my $this = shift;
    my $mdrepo = $twiki->{mdrepo};

    $this->load_sites();
    my $siteAm1 = {
        server  => 'strawma',
        datadir => '/d/twiki/dat',
        pubdir  => '/d/twiki/pu',
    };
    $mdrepo->putRec('sites', 'am', $siteAm1);
    my $rec = $mdrepo->getRec('sites', 'am');
    $this->assert_deep_equals($rec, $siteAm1);
}

sub test_140_updt_webs_rec {
    my $this = shift;
    my $mdrepo = $twiki->{mdrepo};

    $this->load_webs();
    my $webTwo1 = {
        admin => 'EscheGroup',
        master => 'as',
    };
    $mdrepo->putRec('webs', 'WebTwo', $webTwo1);
    my $rec = $mdrepo->getRec('webs', 'WebTwo');
    $this->assert_deep_equals($rec, $webTwo1);
}

sub test_150_reset_webs_again {
    my $this = shift;
    my $mdrepo = $twiki->{mdrepo};

    $this->load_webs();
    $mdrepo->resetTable('webs');
    $this->assert_equals(0, scalar($mdrepo->getList('webs')));
    my $rec = $mdrepo->getRec('webs', 'WebOne');
    $this->assert_str_equals('', $rec);
}

sub test_160_reset_sites_again {
    my $this = shift;
    my $mdrepo = $twiki->{mdrepo};

    $this->load_sites();
    $mdrepo->resetTable('sites');
    $this->assert_equals(scalar($mdrepo->getList('sites')), 0);
    my $rec = $mdrepo->getRec('sites', 'am');
    $this->assert_str_equals('', $rec);
}

1;
