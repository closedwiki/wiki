#
# Copyright (C) Motorola 2003 - All rights reserved
#
use strict;

use TWiki::Plugins::DBCachePlugin::Map;

{ package FormQueryPlugin::TableFormat;

  # PRIVATE cache of table formats
  my %cache;

  # PUBLIC
  # A new TableFormat is either generated or may be satisfied from
  # the cache
  sub new {
    my ( $class, $attrs ) = @_;
    my $this = {};

    my $header = $attrs->get( "header" );
    my $footer = $attrs->get( "footer" );
    my $sort = $attrs->get( "sort" );
    my $format = $attrs->get( "format" );

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

  # PRIVATE STATIC fields used in sorting; entries are hashes
  my @compareFields;

  # PRIVATE STATIC compare function for sorting
  sub _compare {
    my ( $va, $vb );
    foreach my $field ( @compareFields ) {
      if ( $field->{reverse} ) {
	# reverse sort this field
	$va = $b->get( $field->{name} );
	$vb = $a->get( $field->{name} );
      } else {
	$va = $a->get( $field->{name} );
	$vb = $b->get( $field->{name} );
      }
      if ( defined( $va ) && defined( $vb )) {
	my $cmp;
	if ( $field->{numeric} ) {
	  $cmp = $va <=> $vb;
	} else {
	  $cmp = $va cmp $vb;
	}
	return $cmp unless ( $cmp == 0 );
      }
    }
    return 0;
  }

  # PUBLIC
  # Format an array as a table according to the formatting
  # instructions in {format}
  sub formatTable {
    my ( $this, $entries, $cmap, $sr, $rc ) = @_;
	
    return "<font color=red>Empty table</font>" if ( $entries->size() == 0 );
	
    if ( $entries->size() > 1 && defined( $this->{sort} )) {
      @compareFields = ();
      foreach my $field ( split( /\s*,\s*/, $this->{sort} )) {
		my $numeric = 0;
		my $reverse = 0;
		$field =~ s/^\#-/-\#/o;
		$reverse = 1 if ( $field =~ s/^-//o );
		$numeric = 1 if ( $field =~ s/^\#//o );
		push( @compareFields, { name=>$field,
								reverse=>$reverse,
								numeric=>$numeric } );
      }
      @{$entries->{values}} = sort _compare @{$entries->{values}};
    }
	
	$sr = 0 if ( !defined( $sr) || $sr < 0 );
	$rc = $entries->size() if ( !defined( $rc ) || $rc < 0 );
    my $rows = "";
	my $cnt = 0;
    foreach my $sub ( $entries->getValues() ) {
	  if ( $cnt >= $sr && $cnt < $sr + $rc) {
		my $row = $this->{format};
		$row =~ s/\$([\w\.]+)\[(.*?)\]/&_expandTable($this, $1, $2, $sub, $cmap)/geo;
		$row =~ s/\$([\w\.]+)/&_expandField($this, $1, $sub, $cmap )/geo;
		$rows .= "$row\n";
	  }
	  $cnt++;
    }
    $rows = $this->{header} . $rows if ( defined( $this->{header} ));
    $rows = $rows . $this->{footer} if ( defined( $this->{footer} ));
    return $rows;
  }

  sub _expandField {
    my ( $this, $vbl, $map, $cmap ) = @_;
    my $ret = $map->get( $vbl );
    if ( !defined( $ret ) ) {
	  # backward compatibility; if the vbl is not defined in the
	  # hash, and it has a field called "form" that expands to the
	  # name of another subfield that is a hash, then look that up instead.
	  # This copes with the "old" style whereby form fields were
	  # placed direct in the topic, though this usage is not documented.
	  my $form = $map->get("form");
	  if (defined($form)) {
		$form = $map->get($form);
		if (defined($form)) {
		  $ret = $form->get( $vbl );
		}
	  }
	}

	if (!defined( $ret )) {
      $ret = "<font color=\"red\">Undefined field <nop>$vbl</font> _(defined fields are: <code>" . join ( ', <nop>', grep(!/^\./, $map->getKeys()) ) . "</code>)_";
    }
    if ( defined( $cmap )) {
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
      return "<font color=\"red\">UNDEFINED field <nop>$vbl</font> _(defined fields are: <code>" . join ( ', <nop>', $map->getKeys()) . "</code>)_";
    }
    my $attrs = new DBCachePlugin::Map( $fmt );
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
