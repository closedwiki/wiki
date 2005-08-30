package TableFormatTest;

use TWiki::Plugins::FormQueryPlugin::TableFormat;
use TWiki::Plugins::FormQueryPlugin::ColourMap;
use TWiki::Contrib::DBCacheContrib::Map;
use TWiki::Contrib::DBCacheContrib::Array;
use base qw(Test::Unit::TestCase);

sub new {
  my $self = shift()->SUPER::new(@_);
  # your state for fixture here
  return $self;
}

sub set_up {
  my $this = shift;

  $this->{cmap} = new  TWiki::Plugins::FormQueryPlugin::ColourMap(<<'HERE'
   * /\s*(1)\s*/ = r$1r
   * /\s*(0)\s*/ = g$1g
HERE
);
}

my $tableP = 'class="twikiTable fqpTable"';
my $trhP = $tableP;
my $trdP = $tableP;
my $thP = $tableP;
my $tdP = $tableP;

sub test_1 {
  my $this = shift;

  my $tf = new  TWiki::Plugins::FormQueryPlugin::TableFormat(new TWiki::Contrib::DBCacheContrib::Map('header="|*X*|*Y*|" format="|$X|$Y|" sort="X"'));

  my $data = new TWiki::Contrib::DBCacheContrib::Array();
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=0 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=0 Y=1"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=1 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=1 Y=1"));

  my $res = $tf->formatTable($data, $this->{cmap});

  $res =~ s/<table $tableP>(.*)<\/table>/$1/so;
  $res =~ s/<tr $trhP><th $thP> \*X\* <\/th><th $thP> \*Y\* <\/th><\/tr>//o;
  $res =~ s/<tr $trdP><td $tdP> g0g <\/td><td $tdP> g0g <\/td><\/tr>/1/o;
  $res =~ s/<tr $trdP><td $tdP> g0g <\/td><td $tdP> r1r <\/td><\/tr>/2/o;
  $res =~ s/<tr $trdP><td $tdP> r1r <\/td><td $tdP> g0g <\/td><\/tr>/3/o;
  $res =~ s/<tr $trdP><td $tdP> r1r <\/td><td $tdP> r1r <\/td><\/tr>/4/o;

  $this->assert_matches(qr/^\s*1\s*2\s*3\s*4\s*$/, $res);
}

sub test_1reverse {
  my $this = shift;

  my $tf = new  TWiki::Plugins::FormQueryPlugin::TableFormat(new TWiki::Contrib::DBCacheContrib::Map("header=\"|*X*|*Y*|\" format=\"|\$X|\$Y|\" sort=\"-X\""));

  my $data = new TWiki::Contrib::DBCacheContrib::Array();
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=0 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=0 Y=1"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=1 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=1 Y=1"));

  my $res = $tf->formatTable($data, $this->{cmap});

  $res =~ s/<table $tableP>(.*)<\/table>/$1/so;
  $res =~ s/<tr $trhP><th $thP> \*X\* <\/th><th $thP> \*Y\* <\/th><\/tr>//o;
  $res =~ s/<tr $trdP><td $tdP> g0g <\/td><td $tdP> g0g <\/td><\/tr>/1/o;
  $res =~ s/<tr $trdP><td $tdP> g0g <\/td><td $tdP> r1r <\/td><\/tr>/2/o;
  $res =~ s/<tr $trdP><td $tdP> r1r <\/td><td $tdP> g0g <\/td><\/tr>/3/o;
  $res =~ s/<tr $trdP><td $tdP> r1r <\/td><td $tdP> r1r <\/td><\/tr>/4/o;
  $res =~ s/\s//go;

  $this->assert_str_equals("3412", $res);
}

sub test_2 {
  my $this = shift;

  my $tf = new  TWiki::Plugins::FormQueryPlugin::TableFormat(new TWiki::Contrib::DBCacheContrib::Map("header=\"|*X*|*Y*|\" format=\"|\$X|\$Y|\" sort=\"Y,X\""));

  my $data = new TWiki::Contrib::DBCacheContrib::Array();
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=0 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=0 Y=1"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=1 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=1 Y=1"));

  my $res = $tf->formatTable($data);

  $res =~ s/<table $tableP>(.*)<\/table>/$1/so;
  $res =~ s/<tr $trhP><th $thP> \*X\* <\/th><th $thP> \*Y\* <\/th><\/tr>//o;
  $res =~ s/<tr $trdP><td $tdP> 0 <\/td><td $tdP> 0 <\/td><\/tr>/1/o;
  $res =~ s/<tr $trdP><td $tdP> 0 <\/td><td $tdP> 1 <\/td><\/tr>/2/o;
  $res =~ s/<tr $trdP><td $tdP> 1 <\/td><td $tdP> 0 <\/td><\/tr>/3/o;
  $res =~ s/<tr $trdP><td $tdP> 1 <\/td><td $tdP> 1 <\/td><\/tr>/4/o;
  $res =~ s/\s//go;

  $this->assert_str_equals("1324", $res);
}

sub test_2reverse {
  my $this = shift;

  my $tf = new  TWiki::Plugins::FormQueryPlugin::TableFormat(new TWiki::Contrib::DBCacheContrib::Map("header=\"|*X*|*Y*|\" format=\"|\$X|\$Y|\" sort=\"-Y,-X\""));

  my $data = new TWiki::Contrib::DBCacheContrib::Array();
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=0 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=0 Y=1"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=1 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=1 Y=1"));

  my $res = $tf->formatTable($data);

  $res =~ s/<table $tableP>(.*)<\/table>/$1/so;
  $res =~ s/<tr $trhP><th $thP> \*X\* <\/th><th $thP> \*Y\* <\/th><\/tr>//o;
  $res =~ s/<tr $trdP><td $tdP> 0 <\/td><td $tdP> 0 <\/td><\/tr>/1/o;
  $res =~ s/<tr $trdP><td $tdP> 0 <\/td><td $tdP> 1 <\/td><\/tr>/2/o;
  $res =~ s/<tr $trdP><td $tdP> 1 <\/td><td $tdP> 0 <\/td><\/tr>/3/o;
  $res =~ s/<tr $trdP><td $tdP> 1 <\/td><td $tdP> 1 <\/td><\/tr>/4/o;
  $res =~ s/\s//go;

  $this->assert_str_equals("4231", $res);
}

sub test_3numeric {
  my $this = shift;

  my $tf = new  TWiki::Plugins::FormQueryPlugin::TableFormat(new TWiki::Contrib::DBCacheContrib::Map("header=\"|*X*|*Y*|\" format=\"|\$X|\$Y|\" sort=\"#X\""));

  my $data = new TWiki::Contrib::DBCacheContrib::Array();
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=3 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=20 Y=1"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=110 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=005 Y=1"));

  my $res = $tf->formatTable($data);

  $res =~ s/<table $tableP>(.*)<\/table>/$1/so;
  $res =~ s/<tr $trhP><th $thP> \*X\* <\/th><th $thP> \*Y\* <\/th><\/tr>//o;
  $res =~ s/<tr $trdP><td $tdP> 3 <\/td><td $tdP> 0 <\/td><\/tr>/1/o;
  $res =~ s/<tr $trdP><td $tdP> 005 <\/td><td $tdP> 1 <\/td><\/tr>/2/o;
  $res =~ s/<tr $trdP><td $tdP> 20 <\/td><td $tdP> 1 <\/td><\/tr>/3/o;
  $res =~ s/<tr $trdP><td $tdP> 110 <\/td><td $tdP> 0 <\/td><\/tr>/4/o;
  $res =~ s/\s//go;

  $this->assert_str_equals("1234", $res);
}

sub test_4numericreverse {
  my $this = shift;

  my $tf = new  TWiki::Plugins::FormQueryPlugin::TableFormat(new TWiki::Contrib::DBCacheContrib::Map("header=\"|*X*|*Y*|\" format=\"|\$X|\$Y|\" sort=\"-#X\""));

  my $data = new TWiki::Contrib::DBCacheContrib::Array();
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=3 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=20 Y=1"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=110 Y=0"));
  $data->add(new TWiki::Contrib::DBCacheContrib::Map("X=005 Y=1"));

  my $res = $tf->formatTable($data);

  $res =~ s/<table $tableP>(.*)<\/table>/$1/so;
  $res =~ s/<tr $trhP><th $thP> \*X\* <\/th><th $thP> \*Y\* <\/th><\/tr>//o;
  $res =~ s/<tr $trdP><td $tdP> 3 <\/td><td $tdP> 0 <\/td><\/tr>/1/o;
  $res =~ s/<tr $trdP><td $tdP> 005 <\/td><td $tdP> 1 <\/td><\/tr>/2/o;
  $res =~ s/<tr $trdP><td $tdP> 20 <\/td><td $tdP> 1 <\/td><\/tr>/3/o;
  $res =~ s/<tr $trdP><td $tdP> 110 <\/td><td $tdP> 0 <\/td><\/tr>/4/o;
  $res =~ s/\s//go;

  $this->assert_str_equals("4321", $res);
}

sub test_5 {
  my $this = shift;

  my $tfi = new  TWiki::Plugins::FormQueryPlugin::TableFormat(new TWiki::Contrib::DBCacheContrib::Map("header=\"|*Xb*|*Ya*|\" format=\"|\$X|\$Y|\" sort=\"Y,X\""));
  $tfi->addToCache("FF");

  my $tfa = new  TWiki::Plugins::FormQueryPlugin::TableFormat(new TWiki::Contrib::DBCacheContrib::Map("header=\"|*Xa*|*Yb*|\" format=\"|\$X|\$Y|\" sort=\"X,Y\""));
  $tfa->addToCache("GG");

  my $tfo = new  TWiki::Plugins::FormQueryPlugin::TableFormat(new TWiki::Contrib::DBCacheContrib::Map("header=\"|*T1*|*T2*|\" format=\"|\$T1[format=FF]|\$T2[format=GG]|\""));

  my $datao = new TWiki::Contrib::DBCacheContrib::Array();
  my $submap = new TWiki::Contrib::DBCacheContrib::Map();
  $datao->add($submap);

  my $dataX = new TWiki::Contrib::DBCacheContrib::Array();
  $dataX->add(new TWiki::Contrib::DBCacheContrib::Map("X=0 Y=0"));
  $dataX->add(new TWiki::Contrib::DBCacheContrib::Map("X=0 Y=1"));
  $dataX->add(new TWiki::Contrib::DBCacheContrib::Map("X=1 Y=0"));
  $dataX->add(new TWiki::Contrib::DBCacheContrib::Map("X=1 Y=1"));
  $submap->set( "T1", $dataX );

  my $dataY = new TWiki::Contrib::DBCacheContrib::Array();
  $dataY->add(new TWiki::Contrib::DBCacheContrib::Map("X=2 Y=2"));
  $dataY->add(new TWiki::Contrib::DBCacheContrib::Map("X=2 Y=3"));
  $dataY->add(new TWiki::Contrib::DBCacheContrib::Map("X=3 Y=2"));
  $dataY->add(new TWiki::Contrib::DBCacheContrib::Map("X=3 Y=3"));
  $submap->set( "T2", $dataY );

  my $res = $tfo->formatTable($datao, $this->{cmap});
  my $TS = "<table $tableP>";
  my $TE = "</table>";
  my $RS = "<tr $trdP>";
  my $RH = "<tr $trhP>";
  my $RE = "</tr>";
  my $DS = "<td $tdP>";
  my $HS = "<th $thP>";
  my $DE = "</td>";
  my $HE = "</th>";
  $res =~ s/\n//go;
  # Take out the top level table
  $this->assert_not_null($res =~ s/^$TS(.*)$TE$/$1/mo);
  # Take out the first row
  $this->assert_not_null($res =~ s/^$RH$HS \*T1\* $HE$HS \*T2\* $HE$RE//o);
  # And the end of the second row
  $this->assert_not_null($res =~ s/^$RS(.*)\<\/tr\>$/$1/o);
  # Split the subsidiary tables
  $this->assert_not_null($res =~ s/^$DS $TS(.*)$TE $DE$DS $TS(.*)$TE $DE$//o, $res);
  my $t1 = $1;
  my $t2 = $2;
  $this->assert_str_equals("", $res);
  $this->assert_not_null($t2 =~ s/^$TS(.*)$TE$/$1/o, $res);

  $this->assert_not_null($t2 =~ s/^$RH$HS \*Xa\* $HE$HS \*Yb\* $HE$RE//o);
  $this->assert_not_null($t2 =~ s/^$RS$DS 2 $DE$DS 2 $DE$RE//o);
  $this->assert_not_null($t2 =~ s/^$RS$DS 2 $DE$DS 3 $DE$RE//o);
  $this->assert_not_null($t2 =~ s/^$RS$DS 3 $DE$DS 2 $DE$RE//o);
  $this->assert_not_null($t2 =~ s/^$RS$DS 3 $DE$DS 3 $DE$RE//o);
  $this->assert_str_equals("", $t2);

  $this->assert_not_null($t1 =~ s/^$RH$HS \*Xb\* $HE$HS \*Ya\* $HE$RE//o);

  $this->assert_not_null($t1 =~ s/^$RS$DS g0g $DE$DS g0g $DE$RE//o);
  $this->assert_not_null($t1 =~ s/^$RS$DS r1r $DE$DS g0g $DE$RE//o);
  $this->assert_not_null($t1 =~ s/^$RS$DS g0g $DE$DS r1r $DE$RE//o);
  $this->assert_not_null($t1 =~ s/^$RS$DS r1r $DE$DS r1r $DE$RE//o);
  $this->assert_str_equals("", $t1);

}

1;
