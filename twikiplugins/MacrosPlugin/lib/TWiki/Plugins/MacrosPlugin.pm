package TWiki::Plugins::MacrosPlugin;

use vars qw( $VERSION $pluginName );

use TWiki::Attrs;

$VERSION = '1.010';

my $pluginName = 'MacrosPlugin';  # Name of this Plugin
my %macros;
my %macro_times; # TimSlidel 1/4/04

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.000 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    return 1;
}

sub commonTagsHandler {
  ### my ( $text, $topic, $web ) = @_;

  # First expand all macros and macro parameters
  $_[0] =~ s/%CALLMACRO{(.*?)}%/&_callMacro($1,$_[2],$_[1])/ge;

  return unless ( $_[0] =~ m/%SET\s+/mo );

  # Now process in order to ensure correct SET ordering
  my %sets; # scope of this topic only
  my $res;

  foreach my $block ( split( /\n%SET\s+/, "\n$_[0]" )) {
    foreach my $set ( keys %sets ) {
      $block =~ s/\%$set\%/$sets{$set}/g;
    }

    if ( $block =~ s/^(\w+)[ \t]*=[ \t]*([^\r\n]*)\r*\n//o ) {
      my $setname = $1;
      my $setval = $2;
      $setval = TWiki::Func::expandCommonVariables( $setval, $topic, $web );
      $sets{$setname} = $setval;
      $block =~ s/\%$setname\%/$setval/g;
    }
	$res .= $block;
  }
  $res =~ s/^\n//o;
  $_[0] = $res;
}

# Expand a macro. The macro is identified by the 'topic' parameter
# and is loaded from the named topic. The remaining parameters have
# their values replaced into the macro and the expanded macro body
# is returned.
sub _callMacro {
  my ( $params, $web, $topic ) = @_;
  my $attrs = new TWiki::Attrs( $params );
  my $mtop = $attrs->get( "topic" );
  my $mweb = $web;

  if ( $mtop =~ s/^(.*)[\.\/](.*)$/$2/o ) {
	$mweb = $1;
  }
  my $dataDir = TWiki::Func::getDataDir() . "/$mweb"; # TimSlidel 1/4/04
  my $filename = "$dataDir/$mtop.txt"; # TimSlidel 1/4/04

  my @sinfo = stat( $filename );
  my $time = $sinfo[9];

  if ( !defined( $macros{$mtop} ) || $macro_times{$mtop} < $time ) {
	if ( !TWiki::Func::topicExists( $mweb, $mtop )) {
	  return " <font color=red> No such macro $mtop in CALLMACRO\{$params\} </font> ";
	}
	my ($meta, $text ) = TWiki::Func::readTopic( $mweb, $mtop );
	$macro_times{$mtop} = $time;
	$macros{$mtop} = $text;
  }

  my $m = $macros{$mtop};

  foreach my $vbl ( keys %$attrs ) {
	my $val = $attrs->get( $vbl );
	$m =~ s/%$vbl%/$val/g;
  }

  $m =~ s/[\r\n]+//go if ( $m =~ s/%STRIP%//go );

  # Recursive expansion
  $m =~ s/%CALLMACRO{(.+?)}%/&_callMacro($1,$web,$topic)/geo;

  return $m;
}

1;
