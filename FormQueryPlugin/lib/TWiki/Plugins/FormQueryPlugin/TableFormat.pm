#
# Copyright (C) Motorola 2003 - All rights reserved
#
use strict;

use TWiki::Contrib::DBCacheContrib::Map;

package TWiki::Plugins::FormQueryPlugin::TableFormat;

# PRIVATE cache of table formats
my %cache;
my $stdClass = 'twikiTable fqpTable';

# PUBLIC
# A new TableFormat is either generated or may be satisfied from
# the cache
sub new {
    my ( $class, $attrs ) = @_;
    my $this = bless( {}, $class );
    my $format = $attrs->get( 'format' );

    # Note: We cannot leave TWiki to format tables, because it doesn't handle
    # recursive tables (tables within tables)
    my $header = $attrs->get( 'header' );
    if ( defined( $header ) ) {
        if( $header =~ s/^\|(.*)\|$/$1/ ) {
            $this->{header} =
              CGI::start_table( { class => $stdClass } ).
                  CGI::Tr({ class => $stdClass },
                          join('',
                               map{ CGI::th({ class => $stdClass }," $_ ") }
                                 split(/\|/, $header)));
        } else {
            $this->{header} = $header;
        }
    } elsif( $format && defined( $cache{$format} )) {
        $this->{header} = $cache{$format}->{header};
    } else {
        $this->{header} = CGI::start_table( { class => $stdClass } );
    }

    if( $format && defined( $cache{$format} )) {
        $this->{format} = $cache{$format}->{format};
    } elsif( defined( $format )) {
        if( $format =~ s/^\|(.*)\|$/$1/ ) {
            $this->{format} =
              CGI::Tr({ class => $stdClass },
                      join('',
                           map{ CGI::td({ class => $stdClass }," $_ ") }
                             split(/\|/, $format)));
        } else {
            $this->{format} = $format;
        }
    } else {
        # SMELL: no default for format!
        $this->{format} = '||';
    }

    my $footer = $attrs->get( 'footer' );
    if( defined( $footer )) {
        $this->{footer} = $footer;
    } elsif( $format && defined( $cache{$format} )) {
        $this->{footer} = $cache{$format}->{footer};
    } else {
        $this->{footer} = CGI::end_table();
    }

    my $sort = $attrs->get( 'sort' );
    if( defined( $sort )) {
        $this->{sort} = $sort;
    } elsif ( $format && defined( $cache{$format} )) {
        $this->{sort} = $cache{$format}->{sort};
    }

    $this->{help_undefined} = $attrs->get( 'help' );

    return $this;
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
	
    return CGI::span({class=>'twikiAlert'},'Empty table')
      if ( $entries->size() == 0 );

	
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

	if ( !defined( $ret )) {
        if ( $this->{help_undefined} ) {
            $ret = CGI::span(
                {class=>'twikiAlert'},
                "Undefined field <nop>$vbl").
                  " (defined fields are: ".
                    CGI::code(join( ', <nop>',
                                    grep { !/^\./ } $map->getKeys() ));
        } else {
            $ret = "";
        }
    }
    if ( defined( $cmap ) && $ret ne "" ) {
        $ret = $cmap->map( $ret );
    }
    return $ret;
}

sub _expandTable {
    my ( $this, $vbl, $fmt, $map, $cmap ) = @_;
    my $table = $map->get( $vbl );
    if ( !defined( $table )) {
        if ( $this->{help_undefined} ) {
            return CGI::span(
                {class=>'twikiAlert'},
                "UNDEFINED field <nop>$vbl"),
                " (defined fields are: ".
                  CGI::code(join( ', <nop>',
                                  grep { !/^\./ } $map->getKeys() ));
        } else {
            return "";
        }
    }
    my $attrs = new TWiki::Contrib::DBCacheContrib::Map( $fmt );
    my $format = new  TWiki::Plugins::FormQueryPlugin::TableFormat( $attrs );

    return $format->formatTable( $table, $cmap );
}

sub toString {
    my $this = shift;
    return "Format{ header=\"" . $this->{header} .
      "\" format=\"" . $this->{format} .
        "\" sort=\"" . $this->{sort} . "\"}";
}

1;
