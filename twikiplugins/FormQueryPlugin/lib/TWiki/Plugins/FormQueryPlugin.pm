use strict;

use Benchmark;

use TWiki;
use TWiki::Func;

use TWiki::Plugins::FormQueryPlugin::WebDB;
use TWiki::Plugins::FormQueryPlugin::ReqDBSupport;
use TWiki::Plugins::FormQueryPlugin::Arithmetic;

package TWiki::Plugins::FormQueryPlugin;

use vars qw(
	    $web $topic $user $installWeb $VERSION $pluginName
	    $debug $db $bming
	   );

$VERSION = '1.010';
$pluginName = 'FormQueryPlugin';
$bming = 0;

sub initPlugin {
  ( $topic, $web, $user, $installWeb ) = @_;
  
  # check for Plugins.pm versions
  if( $TWiki::Plugins::VERSION < 1 ) {
    TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
    return 0;
  }
  
  # Get plugin debug flag
  $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

  if ( defined( $WebDB::storable ) &&
       TWiki::Func::getPreferencesFlag( "\U$pluginName\E_STORABLE" )) {
    $WebDB::storable = 1;
  } else {
    $WebDB::storable = 0;
  }

  $db = new FormQueryPlugin::WebDB( $web );
  
  # Plugin correctly initialized
  TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
  
  return 1;
}

sub commonTagsHandler {
  ### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

  my $topic = $_[1];
# THE FOLLOWING SECTION AND THE fixMacro FUNCTION MUST REMAIN UNTIL
# THE OLD PLUGIN IS DEPRECATED!
  $_[0] =~ s/%(PROJ_LISTMILESTONES){(.*?)}%/&deprecatedMacro($1,$2, "MacroListTasks")/geo;
  $_[0] =~ s/%(PROJ_REQOVERVIEW){(.*?)}%/&deprecatedMacro($1,$2,"MacroReqOverview")/geo;
  $_[0] =~ s/%(PROJ_REQINFO)%/&deprecatedMacro($1,"of=$topic","MacroReqInfo")/geo;
  $_[0] =~ s/%(PROJ_TITINFO)%/&deprecatedMacro($1,"of=$topic","MacroTiTInfo")/geo;
  $_[0] =~ s/%(PROJ_EFFORTSUM){(.*?)}%/&deprecatedMacro($1,$2,"MacroEffortSum")/geo;
  $_[0] =~ s/%(PROJ_REQDETAILS){(.*?)}%/&deprecatedMacro($1,$2,"MacroReqDetails")/geo;
  $_[0] =~ s/%(PROJ_TESTSTATUS){(.*?)}%/&deprecatedMacro($1,$2,"MacroTestStatus")/geo;
#PROJ_REQSEARCH
# END OF SECTION

  my $bmstart;

  if ( $debug && !$bming ) {
    $bmstart = new Benchmark;
    $bming = 1;
  }

  my $text = "";

  # flatten out macros
  $_[0] =~ s/%(CALLMACRO){(.+?)}%/&_handleMacroCall($1,$2,$_[2],$_[1])/geo;

  my %sets; # scope of this topic only
  foreach my $line ( split( /\r?\n/, $_[0] )) {
    foreach my $set ( keys %sets ) {
      $line =~ s/\%$set\%/$sets{$set}/g;
    }
    if ( $line =~ m/^%SET\s+(\w+)\s*=\s*(.*)$/mo ) {
      my $setname = $1;
      my $setval = $2;
      $setval = TWiki::Func::expandCommonVariables( $setval, $topic, $web );
      $sets{$setname} = $setval;
    } else {
      $line =~
	s/%(FORMQUERY){(.+?)}%/&_handleFormQuery($1,$2)/geo;
      $line =~
	s/%(WORKDAYS){(.+?)}%/&_handleWorkingDays($1, $2,$_[2],$_[1])/geo;
      $line =~
	s/%(SUMFIELD){(.+?)}%/&_handleSumQuery($1,$2)/geo;
      $line =~
	s/%(ARITH){\"(.+?)\"}%/&_handleCalc($2)/geo;
      $line =~
	s/%(TABLEFORMAT){(.+?)}%/&_handleTableFormat($1,$2)/geo;
      $line =~
	s/%(SHOWQUERY){(.+?)}%/&_handleShowQuery($1,$2)/geo;
      $line =~
	s/%(TOPICCREATOR){(.+?)}%/&_handleTopicCreator($1,$2,$_[2],$_[1])/geo;
      $line =~ s/%(PROGRESS){(.+?)}%/&_handleProgress($1,$2,$_[2],$_[1])/geo;
      $text .= "$line\n";
    }
  }
  chop( $text ); # remove trailing NL
  $_[0] =~ s/^.*$/$text/s;

  if ( $debug && $bmstart ) {
    my $bmend = new Benchmark;
    my $td = Benchmark::timestr( Benchmark::timediff( $bmend, $bmstart ));
    my $mess = "<br><b>--Time: $td";
    $mess .= " MOD_PERL" if ( $ENV{MOD_PERL} );
    $mess .= " Storable" if ( defined( $WebDB::storable ));
    $_[0] .= "$mess</b><br>";
  }
}

sub deprecatedMacro {
  my ( $mn, $params, $macro ) = @_;
  my $ret = "%CALLMACRO{topic=$macro $params}%";
  if ( $mn ne "PROJ_EFFORTSUM" ) {
    $ret = "<br><font color=red><i>DEPRECATED MACRO %<nop>".
	$mn .
	"% USED. Suggest you replace with<br>".
	"%<nop>CALLMACRO{topic=$macro $params}%<br>".
	"(don't forget to check the parameters against the definition ".
	"of $macro)</font></i><br>".
	$ret;
  }
  return $ret;
}

sub _handleCalc {
  return FormQueryPlugin::Arithmetic::evaluate( shift );
}

sub _handleFormQuery {
  return $db->formQuery( @_ );
}

sub _handleTableFormat {
  return $db->tableFormat( @_ );
}

sub _handleShowQuery {
  return $db->showQuery( @_ );
}

sub _handleTopicCreator {
  return $db->createNewTopic( @_ );
}

sub _handleMacroCall {
  return FormQueryPlugin::ReqDBSupport::callMacro( @_ );
}

sub _handleSumQuery {
  return $db->sumQuery( @_ );
}

sub _handleWorkingDays {
  return FormQueryPlugin::ReqDBSupport::workingDays( @_ );
}

sub _handleProgress {
  return FormQueryPlugin::ReqDBSupport::progressBar( @_ );
}

1;
