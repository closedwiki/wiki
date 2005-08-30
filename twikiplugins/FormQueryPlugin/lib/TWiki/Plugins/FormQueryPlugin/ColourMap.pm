#
# Copyright (C) Motorola 2003 - All rights reserved
#
use strict;

# Mapping between an RE and an interpretation. Originally a simple
# colour map, it has now been morphed to be more powerful, with
# the ability to embed the matched string inside a more complex
# formatting statement.
package TWiki::Plugins::FormQueryPlugin::ColourMap;

# Load the colour map by parsing a newline-separated list of
# mappings from re to colour. For example,
# * /pass/ = green
# * /fail.*/ = #FF0000
# * /[Nn]ot [Ss]tarted/ = yellow
#
sub new {
    my ( $class, $text ) = @_;
    my $this = bless( {}, $class );

    $text =~ s/^\s+\*\s+\/(.*?)\/\s*=\s*(.*)$/$this->{map}{$1} = $2/gem;

    return $this;
}

# PUBLIC map the test string into a formatted string
# Always maps the first map statement that the string matches.
sub map {
    my ( $this, $test ) = @_;

    no strict 'refs'; # for $$i
    foreach my $e ( keys %{$this->{map}} ) {
        # expand $1..$n in colourmap entry
        if ( $test =~ m/^$e$/ ) {
            my @matches;
            my $i = 1;
            while ( defined( $$i )) {
                push( @matches, $$i );
                $i++;
            }
            my $c = $this->{map}{$e};
            while ( --$i ) {
                $c =~ s/\$$i/$matches[$i-1]/g;
            }
            return $c;
        }
    }

    return $test;
}

1;

