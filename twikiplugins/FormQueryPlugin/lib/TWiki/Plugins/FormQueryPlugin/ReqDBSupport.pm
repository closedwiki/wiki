#
# Copyright (C) Motorola 2003 - All rights reserved
#
use TWiki::Func;

use TWiki::Plugins::FormQueryPlugin::WebDB;
use TWiki::Plugins::FormQueryPlugin::Map;

# Extra stuff specific to the application of the FormQueryPlugin to it's
# role as a requirements database - though still generally useful, so
# left in.
{ package FormQueryPlugin::ReqDBSupport;

  my %macros;

  # PUBLIC STATIC
  # Expand a macro. The macro is identified by the 'topic' parameter
  # and is loaded from the named topic. The remaining parameters have
  # their values replaced into the macro and the expanded macro body
  # is returned.
  sub callMacro {
    my ( $macro, $params, $web, $topic ) = @_;
    my $attrs = new FormQueryPlugin::Map( $params );

    my $mtop = $attrs->get( "topic" );

    if ( !defined( $macros{$mtop} )) {
      if ( !TWiki::Func::topicExists( $web, $mtop )) {
	return FormQueryPlugin::WebDB::moan( $macro, $params, "No such macro '$mtop'", "" );
      }
      my $text = TWiki::Func::readTopicText( $web, $mtop );
      $text =~ s/%META:\w+{.*?}%//go;
      $macros{$mtop} = $text;
    }

    my $m = $macros{$mtop};

    foreach my $vbl ( $attrs->getKeys() ) {
      my $val = $attrs->get( $vbl );
      $m =~ s/%$vbl%/$val/g;
    }

    $m = TWiki::Func::expandCommonVariables( $m, $topic, $web );

    if ( $m =~ s/%STRIP%//go ) {
      $m =~ s/[\r\n]+//go;
    }

    return $m;
  }

  # Calculate number of working days between two dates.
  sub workingDays {
    my ( $macro, $params, $web, $topic ) = @_;
    $params = TWiki::Func::expandCommonVariables( $params, "NoTopic", $web );

    my $attrs = new FormQueryPlugin::Map( $params );

    my $start = $attrs->get( "start" );
    $start = Time::ParseDate::parsedate( $start );
    if ( !defined( $start )) {
      return FormQueryPlugin::WebDB::moan( $macro, $params, "'start' not defined, or bad date format", 0 );
    }

    my $end = $attrs->get( "end" );
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

    my $total = $attrs->get( "total" );
    if ( !defined( $total ) || $total <= 0 ) {
      return FormQueryPlugin::WebDB::moan( $macro, $params, "'total' not defined, or is <= zero", 0 );
    }

    my $target = $attrs->get( "target" );
    my $actual = $attrs->get( "actual" );
    if ( !defined( $target ) && !defined( $actual )) {
      return moan( $macro, $params, "At least one of 'target' or 'actual must be defined", 0 );
    }

    $actual = $target unless ( defined( $actual ));
    $target = $actual unless ( defined( $target ));
    
    # block 1 always dark grey
    # block 2 red if late, black if ahead
    # block 3 black if late, green if ahead
    # block 4 always light grey
    my ( $block1, $block2, $block3, $block4 );
    my ( $block1text, $block2text, $block3text, $block4text );
    my ( $block2col, $block3col );
    
    # Round target and actual to integer percentages
    if ( $actual < $target ) {
      # late
      $block1text = "&nbsp;";
      $block2text = int( $target - $actual );
      $block3text = "&nbsp;";
      $block4text = "&nbsp;";
      $target = int(0.5 + 100 * $target / $total);
      $actual = int(0.5 + 100 * $actual / $total);
      $block1 = $actual;
      $block2 = $target - $actual;
      $block2col = "red";
      $block3 = 1;
      $block3col = "black";
    } else {
      # ahead
      $block1text = "&nbsp;";
      $block2text = "&nbsp;";
      $block3text = int($actual - $target);
      $block4text = "&nbsp;";
      $target = int(0.5 + 100 * $target / $total);
      $actual = int(0.5 + 100 * $actual / $total);
      $block1 = $target;
      $block2 = 1;
      $block2col = "black";
      $block3 = $actual - $target;
      $block3col = "lime";
    }
    $block4 = 100 - ($block1 + $block2 + $block3);
    
    my $gauge = "<table border=0 cellspacing=0 height=10 width=100%><tr>";
    if ( $block1 > 0) {
      $gauge .= "<td width=$block1% bgcolor=\"#666666\" align=center>$block1text</td>";
    }
    if ( $block2 > 0 ) {
      $gauge .= "<td width=$block2% bgcolor=\"$block2col\" align=center>$block2text</td>";
    }
    if ( $block3 > 0 ) {
      $gauge .= "<td width=$block3% bgcolor=\"$block3col\" align=center>$block3text</td>";
    }
    if ( $block4 > 0 ) {
      $gauge .= "<td width=$block4% bgcolor=\"#CCCCCC\" align=center>$block4text</td>";
    }
    $gauge .= "</tr></table>";
    #$gauge .= " DEBUG $block1 $block2 $block3";
    return $gauge;
  }
}

1;
