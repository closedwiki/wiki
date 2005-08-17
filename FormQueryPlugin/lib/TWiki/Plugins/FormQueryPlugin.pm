#
# Copyright (C) 2004 Crawford Currie, cc@c-dot.co.uk
#
# TWiki plugin-in module for Form Query Plugin
#
use strict;

use TWiki;
use TWiki::Func;

package TWiki::Plugins::FormQueryPlugin;

use vars qw(
	    $web $topic $user $installWeb $VERSION $pluginName
	    $debug $db $initialised
	   );

$VERSION = '1.201';
$pluginName = 'FormQueryPlugin';
$initialised = 0;
$db = undef;
$debug = 0;

my @dependencies =
  (
   { package => 'TWiki::Plugins', constraint => '>= 1.010' },
   { package => 'TWiki::Contrib::DBCache', constraint => '>= 1.000' },
  );

sub initPlugin {
  ( $topic, $web, $user, $installWeb ) = @_;

  if ( defined( $WebDB::storable ) &&
       TWiki::Func::getPreferencesFlag( "\U$pluginName\E_STORABLE" )) {
    $WebDB::storable = 1;
  } else {
    $WebDB::storable = 0;
  }

  # Get plugin debug flag
  $debug = ( $debug || TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" ));

  # Plugin correctly initialized
  TWiki::Func::writeDebug( "${pluginName} preinitialised" ) if $debug;

  return 1;
}

sub commonTagsHandler {
  ### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

  return unless ( $_[0] =~ m/%(FQPDEBUG|FORMQUERY|WORKDAYS|SUMFIELD|ARITH|TABLEFORMAT|SHOWQUERY|TOPICCREATOR|PROGRESS)/o );

  return unless ( _lazyInit() );

  my $text = "";

  $_[0] =~
	s/%FQPDEBUG{(.*?)}%/&_handleFQPInfo($1)/geo;
  $_[0] =~
	s/%(FORMQUERY){(.+?)}%/&_handleFormQuery($1,$2)/geo;
  $_[0] =~
	s/%(WORKDAYS){(.+?)}%/&_handleWorkingDays($1, $2,$_[2],$_[1])/geo;
  $_[0] =~
	s/%(SUMFIELD){(.+?)}%/&_handleSumQuery($1,$2)/geo;
  $_[0] =~
	s/%(ARITH){\"(.+?)\"}%/&_handleCalc($2)/geo;
  $_[0] =~
	s/%(TABLEFORMAT){(.+?)}%/&_handleTableFormat($1,$2)/geo;
  $_[0] =~
	s/%(SHOWQUERY){(.+?)}%/&_handleShowQuery($1,$2)/geo;
  $_[0] =~
	s/%(TOPICCREATOR){(.+?)}%/&_handleTopicCreator($1,$2,$_[2],$_[1])/geo;

  $_[0] =~ s/%(PROGRESS){(.+?)}%/&_handleProgress($1,$2,$_[2],$_[1])/geo;
}

sub _handleFQPInfo {
  return $db->getInfo( @_ );
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

sub _handleSumQuery {
  return $db->sumQuery( @_ );
}

sub _handleCalc {
  return FormQueryPlugin::Arithmetic::evaluate( shift );
}

sub _handleWorkingDays {
  return FormQueryPlugin::ReqDBSupport::workingDays( @_ );
}

sub _handleProgress {
  return FormQueryPlugin::ReqDBSupport::progressBar( @_ );
}

sub _lazyInit {

  return 1 if ( $initialised );

  # FQP_ENABLE must be set globally or in this web!
  return 0 unless ( TWiki::Func::getPreferencesFlag( "\U$pluginName\E_ENABLE" ));

  if ( defined( &TWiki::Func::checkDependencies ) ) {
    my $err = TWiki::Func::checkDependencies( $pluginName, \@dependencies );
    if( $err ) {
      TWiki::Func::writeWarning( $err );
      print STDERR $err; # print to webserver log file
      return 0; # plugin initialisation failed
    }
  }

  eval 'use TWiki::Plugins::FormQueryPlugin::WebDB;';
  die $@ if $@;
  eval 'use TWiki::Plugins::FormQueryPlugin::ReqDBSupport;';
  die $@ if $@;
  eval 'use TWiki::Plugins::FormQueryPlugin::Arithmetic;';
  die $@ if $@;

  $db = new FormQueryPlugin::WebDB( $web );

  return 0 unless $db;

  $initialised = 1;

  TWiki::Func::writeDebug( "${pluginName} lazy initialised" ) if $debug;

  return 1;
}

1;
