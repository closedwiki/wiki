use strict;
use Benchmark;

package WebDBTest;

use base qw(TWikiTestCase);

use TWiki::Plugins::FormQueryPlugin::WebDB;
use TWiki::Func;

my $testweb = "TemporaryTestFormQueryPlugin";
my $db;
my $truesum;
my $twiki;
my $testDir;

BEGIN {
    $testDir = `pwd`; chomp($testDir);
    while( ! -e "$testDir/test/unit/FormQueryPlugin/testDB.dat" ) {
        last unless $testDir =~ s#/[^/]*$##;
    }
}

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    $twiki = new TWiki( "TestUser1" );
    $TWiki::Plugins::SESSION = $twiki;

    $twiki->{store}->createWeb($twiki->{user}, $testweb);

    open(DB,"<$testDir/test/unit/FormQueryPlugin/testDB.dat") ||
      die "No test database";
    undef $/;
    my $dbt = <DB>;
    close(DB);
    foreach my $t ( split(/\<TOPIC\>/,$dbt)) {
        if ( $t =~ m/\"(.*?)\"/o ) {
            TWiki::Func::saveTopicText($testweb, $1, $t);
        }
    }

    $truesum = 0;
    foreach my $t ( split(/\n/,$dbt)) {
        if ( $t =~ /\|\s*(\d+)\s*\|/o ) {
            $truesum += $1;
        }
    }

    # re-init to read preferences
    my $query = new CGI("");
    $query->path_info("/$testweb/WebPreferences");
    $twiki = new TWiki( "TestUser1", $query );
    $TWiki::Plugins::SESSION = $twiki;
    #$ TWiki::Plugins::FormQueryPlugin::WebDB::storable = 0;
    $this->{db} = new TWiki::Plugins::FormQueryPlugin::WebDB( $testweb );

}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    $twiki->{store}->removeWeb($twiki->{user}, $testweb);
}

sub test_formQuery {
  my $this = shift;
  my $db = $this->{db};

  my $res = $db->formQuery("TEST", new TWiki::Attrs("name=fred search=\"topic='Dir1'\"", 1));

  $this->assert_str_equals("", $res);
  my $qr = $db->{_queries}{fred};
  $this->assert_not_null($qr);
  $this->assert_equals(1, $qr->size());
  $qr = $qr->get(0);
  $qr = $qr->get("topic");
  $this->assert_str_equals("Dir1", $qr);

  # check that the subdir relation has been created
  my $dir = $db->{_queries}{fred}->get(0);
  my $subdirs = $dir->get("subdir");
  $this->assert_equals(4,$subdirs->size());
  # and that the reverse relation exists
  for (my $i = 0; $i < 4; $i++) {
    my $subdir = $subdirs->get($i);
    $this->assert_equals($dir,$subdir->get("subdir_of"));
  }
}

sub test_queryGoes {
  my $this = shift;
  my $db = $this->{db};
  my $res = $db->formQuery("TEST", new TWiki::Attrs("name=fred search=\"name='Dir1'\"", 1));
  $this->assert_str_equals("", $res);
  $res = $db->formQuery("TEST", new TWiki::Attrs("name=fred search=\"name='Dir99'\"", 1));
  $this->assert_null($db->{_queries}{fred});
}

sub test_badFQ {
  my $this = shift;
  my $db = $this->{db};
  my $res = $db->formQuery("TEST", new TWiki::Attrs("search=\"name='Dir1'\"", 1));
  $this->assert_str_equals("OK", $res) if ($res !~ m/\'name\' not defined/);

  $res = $db->formQuery("TEST", new TWiki::Attrs("name=fred search=\"name='Dir1\"", 1));
  $this->assert_str_equals("OK", $res) if ($res !~ m/invalid search/);
  $res = $db->formQuery("TEST", new TWiki::Attrs("name=fred search=\"topic='Dir75'\"", 1));
  $this->assert_str_equals("OK", $res) if ($res !~ m/no values/i);
  $res = $db->formQuery("TEST", new TWiki::Attrs("name=fred search=\"name='Dir75'\" moan=off", 1));
  $this->assert_str_equals("", $res);
}

sub noest_extractOnEmpty {
  my $this = shift;
  my $db = $this->{db};

  my $res = $db->formQuery("TEST", new TWiki::Attrs("name=fred search=\"name='NonExistant'\" extract=FileTable moan=off", 1));
  $this->assert_str_equals("", $res);
}

sub test_extractRef {
  my $this = shift;
  my $db = $this->{db};
  my $res = $db->formQuery("TEST", new TWiki::Attrs("name=smee search=\"topic='Dir1_1'\" extract=subdir_of", 1));
  $this->assert_str_equals("", $res);
  my $dir = $db->{_queries}{smee}->get(0);
  $this->assert_str_equals("Dir1",$dir->get("topic"));
}

sub test_tables {
  my $this = shift;
  my $db = $this->{db};

  my $res = $db->formQuery("TEST", new TWiki::Attrs("name=fred search=\"name='Dir1'\"", 1));
  $this->assert_str_equals("", $res);
  my $dir = $db->{_queries}{fred}->get(0);

  $res = $db->formQuery("TEST", new TWiki::Attrs("name=fred search=\"name='Dir1'\" extract=DirTable", 1));
  $this->assert_str_equals("", $res);

  my $table = $db->{_queries}{fred};
  $this->assert_equals(6, $table->size());

  my $list = "Main,TWiki,Test,Trash,_default,";
  foreach my $val ( $table->getValues()) {
    my $top = $val->get("Name");
    $list =~ s/$top,//;
    my $mummy = $val->get("DirTable_of");
    $this->assert_equals($dir, $mummy);
  }
  $this->assert_str_equals("", $list);

  $res = $db->formQuery("TEST", new TWiki::Attrs("name=joe query=fred search=\"Date LATER_THAN '9-sep-2001'\"", 1));
  $this->assert_str_equals("", $res);
  my $qr = $db->{_queries}{joe};
  $this->assert_equals(2, $qr->size());
}

sub test_sumQuery {
  my $this = shift;
  my $db = $this->{db};
  my $res=$db->formQuery("TEST", new TWiki::Attrs('name=fred search="" extract=FileTable', 1));
  $this->assert_str_equals("", $res);
  my $sum = $db->sumQuery("TEST",new TWiki::Attrs("query=fred field=Size", 1));

  $this->assert_equals($truesum, $sum);
}

sub test_tableFormat {
  my $this = shift;
  my $db = $this->{db};
  my $res = $db->tableFormat("TEST", new TWiki::Attrs("name=TF header=\"| *Name* | *Level* |\" format=\"|\$RealName|\$Level|\" sort=\"Level,RealName\"", 1));
  $this->assert_str_equals("", $res);
  $res = $db->formQuery("TEST", new TWiki::Attrs("name=fred search=\"name='.*'\"", 1));
  my $qr = $db->{_queries}{fred};
  $res = $db->showQuery("TEST", new TWiki::Attrs("query=fred format=TF", 1));
  $this->assert_str_equals("OK", $res) unless ( $res =~ /^<table/);
}

sub test_createNewTopic1 {
  my $this = shift;
  my $db = $this->{db};

  my $res = $db->createNewTopic("TEST", new TWiki::Attrs("relation=subdir text=Blah form=DirForm template=FileTemplate", $testweb, "Dir1", 1));

  $this->assert_str_equals("<form name=\"topiccreator0\" action=\"%SCRIPTURL%/autocreate/$testweb/Dir1\"><input type=\"submit\" value=\"Blah\" /><input type=\"hidden\" name=\"relation\" value=\"subdir\" /><input type=\"hidden\" name=\"formtemplate\" value=\"DirForm\" /><input type=\"hidden\" name=\"templatetopic\" value=\"FileTemplate\" /></form>", $res);

  $res = $db->deriveNewTopic( "subdir", "Dir1");
  $this->assert_str_equals("Dir1_\n", $res);
  $res = $db->deriveNewTopic( "copy", "Dir1");
  $this->assert_str_equals("Dir\n", $res);

  $res = $db->createNewTopic("TEST", new TWiki::Attrs("base=Dir75 relation=copy text=Blah form=DirForm template=FileTemplate", $testweb, "TestTopic", 1));

  $this->assert_str_equals("<form name=\"topiccreator1\" action=\"%SCRIPTURL%/autocreate/$testweb/Dir75\"><input type=\"submit\" value=\"Blah\" /><input type=\"hidden\" name=\"relation\" value=\"copy\" /><input type=\"hidden\" name=\"formtemplate\" value=\"DirForm\" /><input type=\"hidden\" name=\"templatetopic\" value=\"FileTemplate\" /></form>", $res);
}

sub test_checkTableParse {
  my $this=shift;
  my $db = $this->{db};
  # Dir1_1 is formatted with \ in the table
  my $res = $db->formQuery("TEST", new TWiki::Attrs("name=fred search=\"name='Dir1_1'\" extract=FileTable", 1));
  $this->assert_str_equals("", $res);
  my $qr = $db->{_queries}{fred};
  $this->assert_equals(26, $qr->size());
}

sub test_fieldSum {
  my $this = shift;
  my $db = $this->{db};

  my $res = $db->formQuery("TEST", new TWiki::Attrs("name=fred search=\"name='Dir1_2'\"", 1));
  $this->assert_str_equals("", $res);

  $res = $db->tableFormat("TEST", new TWiki::Attrs("name=TF header=\"\" format=\"\$FileTable.Size\"", 1));
  $this->assert_str_equals("", $res);

  my $qr = $db->{_queries}{fred};
  $res = $db->showQuery("TEST", new TWiki::Attrs("query=fred format=TF", 1));

  my $truesum = 163+709+281+691+417+987+283+466+942+686+2060+163+280+124+2597+56+729+3146+158+850+572+803+332;

  $this->assert_equals($truesum, $res);
}

my $bmdb;

sub bmFn {
  $bmdb->formQuery("TEST", new TWiki::Attrs("name=q1 search=\"name='Dir\\d_\\d'\" extract=FileTable", 1));
  $bmdb->formQuery("TEST", new TWiki::Attrs("name=q2 query=q1 search=\"Type='text'\"", 1));
}

sub dont_test_benchmarkFormQuery {
  my $this = shift;
  my $db = $this->{db};

  $bmdb = $db;
  my $t = Benchmark::timeit(1000,'&bmFn()');
  print STDERR "\n>>> 1000 queries took ",$t->timestr(),"\n";
}

1;
