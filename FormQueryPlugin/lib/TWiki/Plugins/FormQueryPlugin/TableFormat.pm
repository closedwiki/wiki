#
# Copyright (C) Motorola 2003 - All rights reserved
#
use strict;

use TWiki::Plugins::FormQueryPlugin::Map;

{ package FormQueryPlugin::TableFormat;

  # PRIVATE cache of table formats
  my %cache;

  # PUBLIC
  # A new TableFormat is either generated or may be satisfied from
  # the cache
  sub new {
    my ( $class, $attrs ) = @_;
    my $this = {};

    my $header = $attrs->fastget( "header" );
    my $footer = $attrs->fastget( "footer" );
    my $sort = $attrs->fastget( "sort" );
    my $format = $attrs->fastget( "format" );

    if ( defined( $header ) && $header =~ m/^\|.*\|$/o ) {
      # expand twiki-format table header. We have to format here rather
      # than allowing TWiki to do it because we need to colour and
      # align rows.
      $header =~ s/^\s*\|(.*)\|\s*$/<tr bgcolor=\"\#CCFF99\"><td> $1 <\/td><\/tr>/o;
      $header =~ s/\|/ <\/td><td> /go;
      $header = "<table border=2 width=\"100%\">$header";
      $footer = "</table>" unless ( defined( $footer ));
    }

    if ( defined( $cache{$format} )) {
      $header = $cache{$format}->{header} unless ( defined( $header ));
      $footer = $cache{$format}->{footer} unless ( defined( $footer ));
      $sort = $cache{$format}->{sort} unless ( defined( $sort ));
      $format = $cache{$format}->{format};
    }

    $this->{header} = $header;
    $this->{footer} = $footer;
    $this->{sort} = $sort;
    if ( $format =~ s/^\s*\|(.*)\|\s*$/<tr valign=top><td> $1 <\/td><\/tr>/o ) {
      $format =~ s/\|/ <\/td><td> /go;
    }
    $this->{format} = $format;

    return bless( $this, $class );
  }

  # PUBLIC STATIC add a format to the static cache
  sub addToCache {
    my ( $this, $name ) = @_;

    $cache{$name} = $this;

    return $this;
  }

  # PRIVATE STATIC fields used in sorting
  my @compareFields;

  # PRIVATE STATIC compare function for sorting
  sub _compare {
    my ( $va, $vb );
    foreach my $field ( @compareFields ) {
      if ( $field =~ m/^-/o ) {
	# reverse sort this field
	my $f = substr( $field, 1 );
	$va = $b->get( $f );
	$vb = $a->get( $f );
      } else {
	$va = $a->get( $field );
	$vb = $b->get( $field );
      }
      if ( defined( $va ) && defined( $vb )) {
	my $cmp = $va cmp $vb;
	return $cmp unless ( $cmp == 0 );
      }
    }
    return 0;
  }

  # PUBLIC
  # Format an array as a table according to the formatting
  # instructions in {format}
  sub formatTable {
    my ( $this, $entries, $cmap ) = @_;

    return "<font color=red>Empty table</font>" if ( $entries->size() == 0 );

    if ( $entries->size() > 1 && defined( $this->{sort} )) {
      @compareFields = split( /\s*,\s*/, $this->{sort} );
      @{$entries->{values}} = sort _compare @{$entries->{values}};
    }

    my $rows = "";
    foreach my $sub ( $entries->getValues() ) {
      my $row = $this->{format};
      $row =~ s/\$([\w\.]+)\[(.*?)\]/&_expandTable($this, $1, $2, $sub, $cmap)/geo;
      $row =~ s/\$([\w\.]+)/&_expandField($this, $1, $sub, $cmap )/geo;
      $rows .= "$row\n";
    }
    $rows = $this->{header} . $rows if ( defined( $this->{header} ));
    $rows = $rows . $this->{footer} if ( defined( $this->{footer} ));
    return $rows;
  }

  sub _expandField {
    my ( $this, $vbl, $map, $cmap ) = @_;
    my $ret = $map->get( $vbl );
    if ( !defined( $ret ) || $ret =~ m/^\s*$/o ) {
      $ret = "<font color=red>Undefined <nop>$vbl</font>";
    } elsif ( defined( $cmap )) {
      $ret = $cmap->map( $ret );
    } else {
      $ret = " $ret ";
    }
    return $ret;
  }

  sub _expandTable {
    my ( $this, $vbl, $fmt, $map, $cmap ) = @_;
    my $table = $map->get( $vbl );
    if ( !defined( $table )) {
      return "<font color=red>UNDEFINED <nop>$vbl</font>";
    }
    my $attrs = new FormQueryPlugin::Map( $fmt );
    my $format = new FormQueryPlugin::TableFormat( $attrs );
    return $format->formatTable( $table, $cmap );
  }

  sub toString {
    my $this = shift;
    return "Format{ header=\"" . $this->{header} .
      "\" format=\"" . $this->{format} .
	"\" sort=\"" . $this->{sort} . "\"}";
  }
}

1;
