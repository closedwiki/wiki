#
# Copyright (C) Motorola 2003 - All rights reserved
#
use strict;

use TWiki::Func;

use TWiki::Plugins::FormQueryPlugin::WebDB;
use TWiki::Plugins::FormQueryPlugin::Map;

# Extra stuff specific to the application of the FormQueryPlugin to it's
# role as a requirements database - though still generally useful, so
# left in.
{ package FormQueryPlugin::ReqDBSupport;

  my %macros;
  my %macro_times; # TimSlidel 1/4/04

  # PUBLIC STATIC
  # Expand a macro. The macro is identified by the 'topic' parameter
  # and is loaded from the named topic. The remaining parameters have
  # their values replaced into the macro and the expanded macro body
  # is returned.
  sub callMacro {
    my ( $macro, $params, $web, $topic ) = @_;
    my $attrs = new FormQueryPlugin::Map( $params );
    my $dataDir = TWiki::Func::getDataDir() . "/$web"; #TimSlidel 1/4/04

    my $mtop = $attrs->fastget( "topic" );
    my $filename = "$dataDir/$mtop.txt"; # TimSlidel 1/4/04

    if ( !defined( $macros{$mtop} ) ||
       !$macro_times{$mtop}->uptodat() ) { # TimSlidel 1/4/04
      if ( !TWiki::Func::topicExists( $web, $mtop )) {
	return FormQueryPlugin::WebDB::moan( $macro, $params, "No such macro $mtop ", "" );
      }
      my $text = TWiki::Func::readTopicText( $web, $mtop );
      $macro_times{$mtop} = new FormQueryPlugin::FileTime( $filename );
      $text =~ s/%META:\w+{.*?}%//go;
      $macros{$mtop} = $text;
    }

    my $m = $macros{$mtop};

    foreach my $vbl ( $attrs->getKeys() ) {
      my $val = $attrs->fastget( $vbl );
      $m =~ s/%$vbl%/$val/g;
    }

    #$m = TWiki::Func::expandCommonVariables( $m, $topic, $web );

    if ( $m =~ s/%STRIP%//go ) {
      $m =~ s/[\r\n]+//go;
    }

    return $m;
  }

  # Calculate number of working days between two dates.
  sub workingDays {
    my ( $macro, $params, $web, $topic ) = @_;

    my $attrs = new FormQueryPlugin::Map( $params );

    my $start = $attrs->fastget( "start" );
    $start = Time::ParseDate::parsedate( $start );
    if ( !defined( $start )) {
      return FormQueryPlugin::WebDB::moan( $macro, $params, "'start' not defined, or bad date format", 0 );
    }

    my $end = $attrs->fastget( "end" );
    $end = Time::ParseDate::parsedate( $end );
    if ( !defined( $end )) {
      return FormQueryPlugin::WebDB::moan( $macro, $params, "'end' not defined, or bad date format", 0 );
    }

    return FormQueryPlugin::Search::workingDays( $start, $end );
  }

  # Shows a progress bar given
  # 1. A total length
  # 2. A target along the length
  # 3. An actual progress along the length.
  # If target and actual are the same, or actual isn't defined, works like
  # a standard progress bar.
  sub progressBar {
    my ( $macro, $params, $web, $topic ) = @_;
    $params = TWiki::Func::expandCommonVariables( $params, "NoTopic", $web );

    my $attrs = new FormQueryPlugin::Map( $params );

    my $total = $attrs->fastget( "total" );
    if ( !defined( $total ) || $total <= 0 ) {
      return FormQueryPlugin::WebDB::moan( $macro, $params, "'total' not defined, or is <= zero", 0 );
    }

    my $target = $attrs->fastget( "target" );
    my $actual = $attrs->fastget( "actual" );
    if ( !defined( $target ) && !defined( $actual )) {
      return moan( $macro, $params, "At least one of 'target' or 'actual must be defined", 0 );
    }

    $actual = $target unless ( defined( $actual ));
    $target = $actual unless ( defined( $target ));

    if ( $actual !~ m/^\s*\d+/o &&
	 $target !~ m/^\s*\d+/o &&
	 $total !~ m/^\s*\d+/o ) {
      return moan( $macro, $params, "One of the parameters was non-numeric", 0 );
    }

    my $tp = int(0.5 + 100 * $target / $total);
    my $ap = int(0.5 + 100 * $actual / $total);
    
    # block 1 always dark grey
    # block 2 red if late, black if ahead
    # block 3 black if late, green if ahead
    # block 4 always light grey
    my ( $block1, $block2, $block3, $block4 );
    my ( $block1text, $block2text, $block3text, $block4text );
    my ( $block1tcol, $block2tcol, $block3tcol, $block4tcol );
    my ( $block1bcol, $block2bcol, $block3bcol, $block4bcol );
    $block1bcol = "#999999";
    $block1tcol = "white";
    $block1text = "&nbsp;";
    # Round target and actual to integer percentages
    if ( $actual < $target ) {
      # late
      $block1 = $ap;

      $block2 = $tp - $ap;
      $block2bcol = "red";
      $block2tcol = "white";
      $block2text = int( $target - $actual );
      if ( $block2text eq 0 ) {
	$block1 += $block2;
	$block2 = 0;
      }

      $block3 = 1;
      $block3bcol = "black";
      $block3tcol = "white";
      $block3text = "&nbsp;";

    } else {
      # ahead
      $block1 = $tp;

      $block2 = 1;
      $block2bcol = "black";
      $block2tcol = "white";
      $block2text = "&nbsp;";

      $block3 = $ap - $tp;
      $block3bcol = "lime";
      $block3tcol = "black";
      $block3text = int( $actual - $target );
      $block3 = 0 if ( $block3text eq 0 );
    }
    $block4 = 100 - ($block1 + $block2 + $block3);
    $block4bcol = "#CCCCCC";
    $block4tcol = "black";
    $block4text = "&nbsp;";

    my $gauge = "<table border=0 cellspacing=0 width=100%><tr>".
      _block( $block1, $block1bcol, $block1tcol, $block1text ) .
      _block( $block2, $block2bcol, $block2tcol, $block2text ) .
      _block( $block3, $block3bcol, $block3tcol, $block3text ) .
      _block( $block4, $block4bcol, $block4tcol, $block4text );
    $gauge .= "</tr></table>";
    return $gauge;
  }

  # PRIVATE STATIC generate a bar block
  sub _block {
    my ( $width, $bcol, $tcol, $text ) = @_;
    if ( $width > 0 ) {
      return "<td width=$width% bgcolor=\"$bcol\" align=center><font color=\"$tcol\">$text</font></td>";
    }
    return "";
  }
}

1;
