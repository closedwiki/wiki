package TableFormatTest;

use TWiki::Plugins::FormQueryPlugin::TableFormat;
use TWiki::Plugins::DBCachePlugin::Map;
use TWiki::Plugins::DBCachePlugin::Array;
use base qw(Test::Unit::TestCase);

sub new {
  my $self = shift()->SUPER::new(@_);
  # your state for fixture here
  return $self;
}

sub set_up {
  my $this = shift;

  $this->{cmap} = new FormQueryPlugin::ColourMap("
   * /\\s*1\\s*/ = r\$1r
   * /\\s*0\\s*/ = g\$1g
");
}

sub test_1 {
  my $this = shift;

  my $tf = new FormQueryPlugin::TableFormat(new DBCachePlugin::Map("header=\"|*X*|*Y*|\" format=\"|\$X|\$Y|\" sort=\"X\""));

  my $data = new DBCachePlugin::Array();
  $data->add(new DBCachePlugin::Map("X=0 Y=0"));
  $data->add(new DBCachePlugin::Map("X=0 Y=1"));
  $data->add(new DBCachePlugin::Map("X=1 Y=0"));
  $data->add(new DBCachePlugin::Map("X=1 Y=1"));

  my $res = $tf->formatTable($data, $this->{cmap});

  $res =~ s/<table border=2 width="100%">(.*)<\/table>/$1/so;
  $res =~ s/<tr bgcolor=\"\#CCFF99\"><td> \*X\* <\/td><td> \*Y\* <\/td><\/tr>//o;
  $res =~ s/<tr valign=top><td> g0g <\/td><td> g0g <\/td><\/tr>/1/o;
  $res =~ s/<tr valign=top><td> g0g <\/td><td> r1r <\/td><\/tr>/2/o;
  $res =~ s/<tr valign=top><td> r1r <\/td><td> g0g <\/td><\/tr>/3/o;
  $res =~ s/<tr valign=top><td> r1r <\/td><td> r1r <\/td><\/tr>/4/o;
  $res =~ s/\s//go;

  $this->assert_str_equals("1234", $res);
}

sub test_1reverse {
  my $this = shift;

  my $tf = new FormQueryPlugin::TableFormat(new DBCachePlugin::Map("header=\"|*X*|*Y*|\" format=\"|\$X|\$Y|\" sort=\"-X\""));

  my $data = new DBCachePlugin::Array();
  $data->add(new DBCachePlugin::Map("X=0 Y=0"));
  $data->add(new DBCachePlugin::Map("X=0 Y=1"));
  $data->add(new DBCachePlugin::Map("X=1 Y=0"));
  $data->add(new DBCachePlugin::Map("X=1 Y=1"));

  my $res = $tf->formatTable($data, $this->{cmap});

  $res =~ s/<table border=2 width="100%">(.*)<\/table>/$1/so;
  $res =~ s/<tr bgcolor=\"\#CCFF99\"><td> \*X\* <\/td><td> \*Y\* <\/td><\/tr>//o;
  $res =~ s/<tr valign=top><td> g0g <\/td><td> g0g <\/td><\/tr>/1/o;
  $res =~ s/<tr valign=top><td> g0g <\/td><td> r1r <\/td><\/tr>/2/o;
  $res =~ s/<tr valign=top><td> r1r <\/td><td> g0g <\/td><\/tr>/3/o;
  $res =~ s/<tr valign=top><td> r1r <\/td><td> r1r <\/td><\/tr>/4/o;
  $res =~ s/\s//go;

  $this->assert_str_equals("3412", $res);
}

sub test_2 {
  my $this = shift;

  my $tf = new FormQueryPlugin::TableFormat(new DBCachePlugin::Map("header=\"|*X*|*Y*|\" format=\"|\$X|\$Y|\" sort=\"Y,X\""));

  my $data = new DBCachePlugin::Array();
  $data->add(new DBCachePlugin::Map("X=0 Y=0"));
  $data->add(new DBCachePlugin::Map("X=0 Y=1"));
  $data->add(new DBCachePlugin::Map("X=1 Y=0"));
  $data->add(new DBCachePlugin::Map("X=1 Y=1"));

  my $res = $tf->formatTable($data);

  $res =~ s/<table border=2 width="100%">(.*)<\/table>/$1/so;
  $res =~ s/<tr bgcolor=\"\#CCFF99\"><td> \*X\* <\/td><td> \*Y\* <\/td><\/tr>//o;
  $res =~ s/<tr valign=top><td>  0  <\/td><td>  0  <\/td><\/tr>/1/o;
  $res =~ s/<tr valign=top><td>  0  <\/td><td>  1  <\/td><\/tr>/2/o;
  $res =~ s/<tr valign=top><td>  1  <\/td><td>  0  <\/td><\/tr>/3/o;
  $res =~ s/<tr valign=top><td>  1  <\/td><td>  1  <\/td><\/tr>/4/o;
  $res =~ s/\s//go;

  $this->assert_str_equals("1324", $res);
}

sub test_2reverse {
  my $this = shift;

  my $tf = new FormQueryPlugin::TableFormat(new DBCachePlugin::Map("header=\"|*X*|*Y*|\" format=\"|\$X|\$Y|\" sort=\"-Y,-X\""));

  my $data = new DBCachePlugin::Array();
  $data->add(new DBCachePlugin::Map("X=0 Y=0"));
  $data->add(new DBCachePlugin::Map("X=0 Y=1"));
  $data->add(new DBCachePlugin::Map("X=1 Y=0"));
  $data->add(new DBCachePlugin::Map("X=1 Y=1"));

  my $res = $tf->formatTable($data);

  $res =~ s/<table border=2 width="100%">(.*)<\/table>/$1/so;
  $res =~ s/<tr bgcolor=\"\#CCFF99\"><td> \*X\* <\/td><td> \*Y\* <\/td><\/tr>//o;
  $res =~ s/<tr valign=top><td>  0  <\/td><td>  0  <\/td><\/tr>/1/o;
  $res =~ s/<tr valign=top><td>  0  <\/td><td>  1  <\/td><\/tr>/2/o;
  $res =~ s/<tr valign=top><td>  1  <\/td><td>  0  <\/td><\/tr>/3/o;
  $res =~ s/<tr valign=top><td>  1  <\/td><td>  1  <\/td><\/tr>/4/o;
  $res =~ s/\s//go;

  $this->assert_str_equals("4231", $res);
}

sub test_3numeric {
  my $this = shift;

  my $tf = new FormQueryPlugin::TableFormat(new DBCachePlugin::Map("header=\"|*X*|*Y*|\" format=\"|\$X|\$Y|\" sort=\"#X\""));

  my $data = new DBCachePlugin::Array();
  $data->add(new DBCachePlugin::Map("X=3 Y=0"));
  $data->add(new DBCachePlugin::Map("X=20 Y=1"));
  $data->add(new DBCachePlugin::Map("X=110 Y=0"));
  $data->add(new DBCachePlugin::Map("X=005 Y=1"));

  my $res = $tf->formatTable($data);

  $res =~ s/<table border=2 width="100%">(.*)<\/table>/$1/so;
  $res =~ s/<tr bgcolor=\"\#CCFF99\"><td> \*X\* <\/td><td> \*Y\* <\/td><\/tr>//o;
  $res =~ s/<tr valign=top><td>  3  <\/td><td>  0  <\/td><\/tr>/1/o;
  $res =~ s/<tr valign=top><td>  005  <\/td><td>  1  <\/td><\/tr>/2/o;
  $res =~ s/<tr valign=top><td>  20  <\/td><td>  1  <\/td><\/tr>/3/o;
  $res =~ s/<tr valign=top><td>  110  <\/td><td>  0  <\/td><\/tr>/4/o;
  $res =~ s/\s//go;

  $this->assert_str_equals("1234", $res);
}

sub test_4numericreverse {
  my $this = shift;

  my $tf = new FormQueryPlugin::TableFormat(new DBCachePlugin::Map("header=\"|*X*|*Y*|\" format=\"|\$X|\$Y|\" sort=\"-#X\""));

  my $data = new DBCachePlugin::Array();
  $data->add(new DBCachePlugin::Map("X=3 Y=0"));
  $data->add(new DBCachePlugin::Map("X=20 Y=1"));
  $data->add(new DBCachePlugin::Map("X=110 Y=0"));
  $data->add(new DBCachePlugin::Map("X=005 Y=1"));

  my $res = $tf->formatTable($data);

  $res =~ s/<table border=2 width="100%">(.*)<\/table>/$1/so;
  $res =~ s/<tr bgcolor=\"\#CCFF99\"><td> \*X\* <\/td><td> \*Y\* <\/td><\/tr>//o;
  $res =~ s/<tr valign=top><td>  3  <\/td><td>  0  <\/td><\/tr>/1/o;
  $res =~ s/<tr valign=top><td>  005  <\/td><td>  1  <\/td><\/tr>/2/o;
  $res =~ s/<tr valign=top><td>  20  <\/td><td>  1  <\/td><\/tr>/3/o;
  $res =~ s/<tr valign=top><td>  110  <\/td><td>  0  <\/td><\/tr>/4/o;
  $res =~ s/\s//go;

  $this->assert_str_equals("4321", $res);
}

sub test_5 {
  my $this = shift;

  my $tfi = new FormQueryPlugin::TableFormat(new DBCachePlugin::Map("header=\"|*X*|*Y*|\" format=\"|\$X|\$Y|\" sort=\"Y,X\""));
  $tfi->addToCache("FF");
  my $tfa = new FormQueryPlugin::TableFormat(new DBCachePlugin::Map("header=\"|*X*|*Y*|\" format=\"|\$X|\$Y|\" sort=\"X,Y\""));
  $tfa->addToCache("GG");
  my $tfo = new FormQueryPlugin::TableFormat(new DBCachePlugin::Map("header=\"|*T1*|*T2*|\" format=\"|\$T1[format=FF]|\$T2[format=GG]|\""));

  my $datao = new DBCachePlugin::Array();
  my $submap = new DBCachePlugin::Map();
  $datao->add($submap);

  my $dataX = new DBCachePlugin::Array();
  $dataX->add(new DBCachePlugin::Map("X=0 Y=0"));
  $dataX->add(new DBCachePlugin::Map("X=0 Y=1"));
  $dataX->add(new DBCachePlugin::Map("X=1 Y=0"));
  $dataX->add(new DBCachePlugin::Map("X=1 Y=1"));
  $submap->set( "T1", $dataX );

  my $dataY = new DBCachePlugin::Array();
  $dataY->add(new DBCachePlugin::Map("X=2 Y=2"));
  $dataY->add(new DBCachePlugin::Map("X=2 Y=3"));
  $dataY->add(new DBCachePlugin::Map("X=3 Y=2"));
  $dataY->add(new DBCachePlugin::Map("X=3 Y=3"));
  $submap->set( "T2", $dataY );

  my $res = $tfo->formatTable($datao, $this->{cmap});

  my $TS = "<table border=2 width=\"100%\">";
  my $TE = "</table>";
  my $RS = "<tr valign=top>";
  my $RH = "<tr bgcolor=\"\#CCFF99\">";
  my $RE = "</tr>";
  my $DS = "<td>";
  my $DE = "</td>";
  $res =~ s/\n//go;
  # Take out the top level table
  $this->assert_not_null($res =~ s/^$TS(.*)$TE$/$1/mo);
  # Take out the first row
  $this->assert_not_null($res =~ s/^$RH$DS \*T1\* $DE$DS \*T2\* $DE<\/tr>//o);
  # And the end of the second row
  $this->assert_not_null($res =~ s/^$RS(.*)\<\/tr\>$/$1/o);
  # Split the subsidiary tables
  $this->assert_not_null($res =~ s/^$DS $TS(.*)$TE $DE$DS $TS(.*)$TE $DE$//o, $res);
  my $t1 = $1;
  my $t2 = $2;
  $this->assert_str_equals("", $res);
  $this->assert_not_null($t1 =~ s/^$RH$DS \*X\* $DE$DS \*Y\* $DE$RE//o);
  $this->assert_not_null($t1 =~ s/^$RS$DS g0g $DE$DS g0g $DE$RE//o);
  $this->assert_not_null($t1 =~ s/^$RS$DS r1r $DE$DS g0g $DE$RE//o);
  $this->assert_not_null($t1 =~ s/^$RS$DS g0g $DE$DS r1r $DE$RE//o);
  $this->assert_not_null($t1 =~ s/^$RS$DS r1r $DE$DS r1r $DE$RE//o);
  $this->assert_str_equals("", $t1);

  $this->assert_not_null($t2 =~ s/^$TS(.*)$TE$/$1/o, $res);

  $this->assert_not_null($t2 =~ s/^$RH$DS \*X\* $DE$DS \*Y\* $DE$RE//o);
  $this->assert_not_null($t2 =~ s/^$RS$DS 2 $DE$DS 2 $DE$RE//o);
  $this->assert_not_null($t2 =~ s/^$RS$DS 2 $DE$DS 3 $DE$RE//o);
  $this->assert_not_null($t2 =~ s/^$RS$DS 3 $DE$DS 2 $DE$RE//o);
  $this->assert_not_null($t2 =~ s/^$RS$DS 3 $DE$DS 3 $DE$RE//o);
  $this->assert_str_equals("", $t2);
}

1;
