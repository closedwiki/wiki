#
# Copyright (C) Motorola 2003 - All rights reserved
#
use strict;

# Mapping between an RE and an interpretation. Originally a simple
# colour map, it has now been morphed to be more powerful, with
# the ability to embed the matched string inside a more complex
# formatting statement.
{ package FormQueryPlugin::ColourMap;

  # Load the colour map by parsing a newline-separated list of
  # mappings from re to colour. For example,
  # * /pass/ = green
  # * /fail.*/ = #FF0000
  # * /[Nn]ot [Ss]tarted/ = yellow
  #
  sub new {
    my ( $class, $text ) = @_;
    my $this = {};

    foreach my $line ( split( /\n/, $text )) {
      if ( $line =~ m/\s+\*\s+\/(.*?)\/\s*=\s*(.*)$/ ) {
	my $e = { expr=>"$1", colour=>"$2" };
	push( @{$this->{map}}, $e );
      }
    }

    return bless( $this, $class );
  }

  # PUBLIC map the test string into a formatted string
  # Always maps the first map statement that the string matches.
  sub map {
    my ( $this, $test ) = @_;

    foreach my $entry ( @{$this->{map}} ) {
      my $e = $entry->{expr};
      if ( $test =~ m/^$e$/ ) {
	my $c = $entry->{colour};
	$c =~ s/\$1/$test/o;
	return $c;
      }
    }
    return $test;
  }
}

1;

