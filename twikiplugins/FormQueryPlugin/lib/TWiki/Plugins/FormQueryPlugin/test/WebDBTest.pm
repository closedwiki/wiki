use strict;
use Benchmark;

package WebDBTest;

use TWiki::Plugins::FormQueryPlugin::WebDB;
require 'FuncFixture.pm';
import TWiki::Func;

use base qw(TWiki::Func);

my $db;
my $truesum;

sub new {
  my $self = shift()->SUPER::new(@_);
  return $self;
}

sub set_up {
  my $this = shift;

  $this->SUPER::set_up();

  my $dbt = TWiki::Func::TESTreadFile("./testDB.dat");
  foreach my $t ( split(/\<TOPIC\>/,$dbt)) {
    if ( $t =~ m/\"(.*?)\"/o ) {
      TWiki::Func::TESTwriteTopic("Test", $1, $t);
    }
  }

  $dbt = TWiki::Func::TESTreadFile("./testDB.dat");
  $truesum = 0;
  foreach my $t ( split(/\n/,$dbt)) {
    if ( $t =~ /\|\s*(\d+)\s*\|/o ) {
      $truesum += $1;
    }
  }

  TWiki::Func::TESTsetPreference("FQRELATIONS","Dir%B_%A subdir Dir%B; Dir%A_%C_%B subsubdir Dir%A_%C");
  TWiki::Func::TESTsetPreference("FQTABLES", "FileTable,DirTable");
  TWiki::Func::TESTsetPreference("FQHIGHLIGHTMAP", "PrettyPrint");
  #$FormQueryPlugin::WebDB::storable = 0;
  $this->{db} = new FormQueryPlugin::WebDB( "Test" );
}

sub test_formQuery {
  my $this = shift;
  my $db = $this->{db};

  my $res = $db->formQuery("TEST", "name=fred search=\"topic='Dir1'\"");
  $this->assert_str_equals("", $res);
  my $qr = $db->{queries}{fred};
  $this->assert_equals(1, $qr->size());
  $qr = $qr->get(0);
  $qr = $qr->get("topic");
  $this->assert_str_equals("Dir1", $qr);

  # check that the subdir relation has been created
  my $dir = $db->{queries}{fred}->get(0);
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
  my $res = $db->formQuery("TEST", "name=fred search=\"topic='Dir1'\"");
  $this->assert_str_equals("", $res);
  $res = $db->formQuery("TEST", "name=fred search=\"topic='Dir99'\"");
  $this->assert_null($db->{queries}{fred});
}

sub test_badFQ {
  my $this = shift;
  my $db = $this->{db};
  my $res = $db->formQuery("TEST", "search=\"topic='Dir1'\"");
  $this->assert_str_equals("OK", $res) if ($res !~ m/\'name\' not defined/);

  $res = $db->formQuery("TEST", "name=fred search=\"topic='Dir1\"");
  $this->assert_str_equals("OK", $res) if ($res !~ m/invalid search/);
  $res = $db->formQuery("TEST", "name=fred search=\"topic='Dir75'\"");
  $this->assert_str_equals("OK", $res) if ($res !~ m/no values/i);
  $res = $db->formQuery("TEST", "name=fred search=\"topic='Dir75'\" moan=off");
  $this->assert_str_equals("", $res);
}

sub test_extractOnEmpty {
  my $this = shift;
  my $db = $this->{db};

  my $res = $db->formQuery("TEST", "name=fred search=\"topic='NonExistant'\" extract=FileTable moan=off");
  $this->assert_str_equals("", $res);
}

sub test_extractRef {
  my $this = shift;
  my $db = $this->{db};
  my $res = $db->formQuery("TEST", "name=smee search=\"topic='Dir1_1'\" extract=subdir_of");
  $this->assert_str_equals("", $res);
  my $dir = $db->{queries}{smee}->get(0);
  $this->assert_str_equals("Dir1",$dir->get("topic"));
}

sub test_tables {
  my $this = shift;
  my $db = $this->{db};

  my $res = $db->formQuery("TEST", "name=fred search=\"topic='Dir1'\"");
  $this->assert_str_equals("", $res);
  my $dir = $db->{queries}{fred}->get(0);

  $res = $db->formQuery("TEST", "name=fred search=\"topic='Dir1'\" extract=DirTable");
  $this->assert_str_equals("", $res);

  my $table = $db->{queries}{fred};
  $this->assert_equals(6, $table->size());

  my $list = "Main,TWiki,Test,Trash,_default,";
  foreach my $val ( $table->getValues()) {
    my $top = $val->get("Name");
    $list =~ s/$top,//;
    my $mummy = $val->get("DirTable_of");
    $this->assert_equals($dir, $mummy);
  }
  $this->assert_str_equals("", $list);

  $res = $db->formQuery("TEST", "name=joe query=fred search=\"Date LATER_THAN '9-sep-2001'\"");
  $this->assert_str_equals("", $res);
  my $qr = $db->{queries}{joe};
  $this->assert_equals(2, $qr->size());
}

sub test_sumQuery {
  my $this = shift;
  my $db = $this->{db};
  my $res=$db->formQuery("TEST", "name=fred search=\"\" extract=FileTable");
  $this->assert_str_equals("", $res);
  my $sum = $db->sumQuery("TEST","query=fred field=Size");

  $this->assert_equals($truesum, $sum);
}

sub test_tableFormat {
  my $this = shift;
  my $db = $this->{db};
  my $res = $db->tableFormat("TEST", "name=TF header=\"| *Name* | *Level* |\" format=\"|\$RealName|\$Level|\" sort=\"Level,RealName\"");
  $this->assert_str_equals("", $res);
  $res = $db->formQuery("TEST", "name=fred search=\"topic='.*'\"");
  my $qr = $db->{queries}{fred};
  $res = $db->showQuery("TEST", "query=fred format=TF");
  $this->assert_str_equals("OK", $res) unless ( $res =~ /^<table/);
}

sub test_createNewTopic1 {
  my $this = shift;
  my $db = $this->{db};

  my $res = $db->createNewTopic("TEST", "relation=subdir text=Blah form=DirForm template=FileTemplate", "Test", "Dir1");

  $this->assert_str_equals("<form name=\"topiccreator0\" action=\"%SCRIPTURL%/autocreate/Test/Dir1\"><input type=\"submit\" value=\"Blah\" /><input type=\"hidden\" name=\"relation\" value=\"subdir\" /><input type=\"hidden\" name=\"formtemplate\" value=\"DirForm\" /><input type=\"hidden\" name=\"templatetopic\" value=\"FileTemplate\" /></form>", $res);

  $res = $db->deriveNewTopic( "subdir", "Dir1");
  $this->assert_str_equals("Dir1_\n", $res);
  $res = $db->deriveNewTopic( "copy", "Dir1");
  $this->assert_str_equals("Dir\n", $res);

  $res = $db->createNewTopic("TEST", "base=Dir75 relation=copy text=Blah form=DirForm template=FileTemplate", "Test", "TestTopic");

  $this->assert_str_equals("<form name=\"topiccreator1\" action=\"%SCRIPTURL%/autocreate/Test/Dir75\"><input type=\"submit\" value=\"Blah\" /><input type=\"hidden\" name=\"relation\" value=\"copy\" /><input type=\"hidden\" name=\"formtemplate\" value=\"DirForm\" /><input type=\"hidden\" name=\"templatetopic\" value=\"FileTemplate\" /></form>", $res);
}

sub test_checkTableParse {
  my $this=shift;
  my $db = $this->{db};
  # Dir1_1 is formatted with \ in the table
  my $res = $db->formQuery("TEST", "name=fred search=\"topic='Dir1_1'\" extract=FileTable");
  $this->assert_str_equals("", $res);
  my $qr = $db->{queries}{fred};
  $this->assert_equals(26, $qr->size());
}

sub test_fieldSum {
  my $this = shift;
  my $db = $this->{db};

  my $res = $db->formQuery("TEST", "name=fred search=\"topic='Dir1_2'\"");
  $this->assert_str_equals("", $res);

  $res = $db->tableFormat("TEST", "name=TF header=\"\" format=\"\$FileTable.Size\"");
  $this->assert_str_equals("", $res);

  my $qr = $db->{queries}{fred};
  $res = $db->showQuery("TEST", "query=fred format=TF");

  my $truesum = 163+709+281+691+417+987+283+466+942+686+2060+163+280+124+2597+56+729+3146+158+850+572+803+332;

  $this->assert_equals($truesum, $res);
}

my $bmdb;

sub bmFn {
  $bmdb->formQuery("TEST", "name=q1 search=\"topic='Dir\\d_\\d'\" extract=FileTable");
  $bmdb->formQuery("TEST", "name=q2 query=q1 search=\"Type='text'\"");
}

sub dont_test_benchmarkFormQuery {
  my $this = shift;
  my $db = $this->{db};

  $bmdb = $db;
  my $t = Benchmark::timeit(1000,'&bmFn()');
  print STDERR "\n>>> 1000 queries took ",$t->timestr(),"\n";
}

sub test_saveAndLoad {
  my $this = shift;

  $this->assert_str_equals("Test", $this->{db}->{web});
  # There should be no cache there
  $this->assert_equals(0, $this->{db}->{loaded});
  $this->assert_str_equals("0 14 0", $this->{db}->_load());
  $this->assert_equals(1, $this->{db}->{loaded});
  $this->assert_str_equals("0 0 0", $this->{db}->_load());
  my $initial = $this->{db};
  # There's a cache there now
  $this->{db} = new FormQueryPlugin::WebDB( "Test" );
  $this->assert_equals(0, $this->{db}->{loaded});
  $this->assert_str_equals("14 0 0", $this->{db}->_load());
  $this->assert_equals(1, $this->{db}->{loaded});
  $this->assert_str_equals("0 0 0", $this->{db}->_load());
  $this->checkSameAs($initial,$this->{db});

  # One file in the cache has been touched
  sleep(1);# wait for clock tick
  my $Dir2 = TWiki::Func::readTopicText("Test","Dir2");
  TWiki::Func::TESTwriteTopic("Test", "Dir2", $Dir2);
  $this->{db} = new FormQueryPlugin::WebDB( "Test" );
  $this->assert_str_equals("13 1 0", $this->{db}->_load());
  $this->{db} = new FormQueryPlugin::WebDB( "Test" );
  $this->assert_str_equals("14 0 0", $this->{db}->_load());

  # A new file has been created
  TWiki::Func::TESTwriteTopic("Test", "NewFile", "Blah");
  $this->{db} = new FormQueryPlugin::WebDB( "Test" );
  $this->assert_str_equals("14 1 0", $this->{db}->_load());

  # One file in the cache has been deleted
  my $Dir4 = TWiki::Func::readTopicText("Test","Dir4");
  TWiki::Func::TESTdeleteTopic("Test", "Dir4");
  $this->{db} = new FormQueryPlugin::WebDB( "Test" );
  $this->assert_str_equals("14 0 1", $this->{db}->_load());

  TWiki::Func::TESTdeleteTopic("Test", "NewFile");
  TWiki::Func::TESTwriteTopic("Test", "Dir4", $Dir4);
  $this->{db} = new FormQueryPlugin::WebDB( "Test" );
  $this->assert_str_equals("13 1 1", $this->{db}->_load());
  my $final = $this->{db};
  $this->checkSameAs($initial, $final);
}

sub checkSameAs {
  my ( $this, $first, $second, $cmping, $checked ) = @_;
  
  $cmping = "ROOT" unless ( defined($cmping ));
  $checked = {} unless ( defined( $checked ));
  if ( $checked->{"$first"} ) {
    return;
  }
  $checked->{"$first"} = 1;
  my $type = ref($first);

  $this->assert_str_equals($type,ref($second),$cmping);
  if ($type =~ /Map$/ || $type =~ /WebDB$/) {
    $this->checkSameAsMap($first, $second, $cmping, $checked);
  } elsif ($type =~ /Array$/) {
    $this->checkSameAsArray($first, $second, $cmping, $checked);
  } elsif ($type =~ /FileTime$/) {
    $this->checkSameAsFileTime($first, $second, $cmping, $checked);
  } else {
    $this->assert(0,ref($first));
  }
}

sub checkSameAsMap {
  my ( $this, $first, $second, $cmping, $checked ) = @_;
  
  $this->assert_equals($first->size(), $second->size(), $cmping);
  foreach my $k ($first->getKeys()) {
    my $a = $first->get( $k );
    my $b = $second->get( $k );
    my $c = "$cmping.$k";
    if (ref($a)) {
      $this->checkSameAs($a, $b, $c, $checked );
    } else {
      $this->assert_str_equals($a, $b, "$c $a $b");
    }
  }
}

sub checkSameAsArray {
  my ( $this, $first, $second, $cmping, $checked ) = @_;

  $this->assert_equals($first->size(), $second->size(), $cmping);
  my $i = 0;
  foreach my $a (@{$first->{values}}) {
    my $c = "$cmping\[$i\]";
    my $b = $second->get($i++);
    if ( ref( $a )) {
      $this->checkSameAs($a, $b, $c, $checked );
    } else {
      $this->assert_str_equals($a, $b, "$c ($a!=$b)");
    }
  }
}

sub checkSameAsFileTime {
  my ( $this, $first, $second, $cmping, $checked ) = @_;
  $this->assert_str_equals($first->{file}, $second->{file},$cmping);
}

1;
