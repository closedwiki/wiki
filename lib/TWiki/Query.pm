# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root
# of this distribution. NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Copyright (C) Motorola 2003 - All rights reserved
# Copyright (C) Crawford Currie 2004
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package TWiki::Query

A Query object is a representation of a METASEARCH query over the form fields
and meta-data of a topic.

Fields are given by name, and values by strings or numbers. Strings should always be surrounded by 'single-quotes'. Strings which are regular expressions (RHS of =, != =~ operators) use 'perl' regular expression syntax (google for =perlre= for help). Numbers can be signed integers or decimals. Single quotes in values may be escaped using backslash (\).

See TWiki.QuerySearch for details of the query language.

A query object implements the =matches= method as its general
contract with the rest of the world.

=cut

package TWiki::Query;

use strict;
use Assert;
use Error qw( :try );

# Operator precedences
my %prec =
  (
      'attachment' => 800,
      '.'   => 700,
      'lc'  => 600,
      'uc'  => 600,
      '='   => 500,
      '~'   => 500,
      '!='  => 500,
      '>='  => 500,
      '<='  => 500,
      '<'   => 500,
      '>'   => 500,
      ':'   => 400,
      '!'   => 300,
      'AND' => 200,
      'OR'  => 100
     );

my $bopRE = 'AND\b|OR\b|!?=|~|<=?|>=?|:|\.';
my $uopRE = '!|[lu]c\b|attachment\b';
my $numberRE = qr/[+-]?(?:\d+\.\d+|\d+\.|\.\d+|\d+)(?:[eE][+-]?\d+)?/;

=pod

---+++ =new($string, $left, $op, $right)=
   * =$string= - string containing an expression to parse (may be undef)
   * =$left= - LHS for this operator
   * =$op= - name of the operator
   * =$right= - rhs for this operator
Construct a new search node by parsing the passed expression.

=cut

sub new {
    my ( $class, $string, $left, $op, $right ) = @_;
    my $this;
    if ( defined( $string )) {
        my( $this, $rest) = _parse( $string );
        throw Error::Simple("Extra text '$rest'") if $rest !~ /^\s*$/;
        return $this;
    } else {
        return bless({
            right => $right,
            left => $left,
            op => $op }, $class );
    }
}

# PRIVATE STATIC generate a Search by popping the top two operands
# and the top operator. Push the result back onto the operand stack.
sub _apply {
    my ( $opers, $opands ) = @_;
    my $o = pop( @$opers );
    my $r = pop( @$opands );
    throw Error::Simple('Bad search')
      unless defined( $r );
    my $l = undef;
    if ( $o =~ /^$bopRE$/o ) {
        $l = pop( @$opands );
        throw Error::Simple('Bad search')
          unless defined( $l );
    }
    my $n = new TWiki::Query( undef, $l, $o, $r );
    push( @$opands, $n);
}

# PRIVATE STATIC simple stack parser for grabbing boolean expressions
sub _parse {
    my $string = shift;

    $string .= ' ';
    my @opands;
    my @opers;
    while( $string !~ m/^\s*$/o ) {
        if( $string =~ s/^\s*($bopRE)//o ) {
            # Binary comparison op
            my $op = $1;
            while ( scalar( @opers ) > 0 &&
                      $prec{$op} < $prec{$opers[$#opers]} ) {
                _apply( \@opers, \@opands );
            }
            push( @opers, $op );
            next;
        }
        if( $string =~ s/^\s*($uopRE)//o ) {
            # unary op
            push( @opers, $1 );
            next;
        }
        if( $string =~ s/^\s*\'(.*?)(?<!\\)\'// ||
              $string =~ s/^\s*($numberRE)//o ||
                $string =~ s/^\s*(\w+)// ) {
            push( @opands, new TWiki::Query(undef, undef, 'TERMINAL', $1 ));
            next;
        }
        if( $string =~ s/^\s*\(//o ) {
            my $oa;
            ( $oa, $string ) = _parse( $string );
            push( @opands, $oa );
            next;
        }
        if( $string =~ s/^\s*\)//o ) {
            last;
        }
        throw Error::Simple( 'Parser stuck at '.$string );
    }
    while( scalar( @opers ) > 0 ) {
        _apply( \@opers, \@opands );
    }
    throw Error::Simple('Stack underflow') unless( scalar( @opands ) == 1 );
    return ( pop( @opands ), $string );
}

=pod

---+++ =matches($meta)= -> $value
   * =$meta= - TWiki::Meta object to test
See if meta-data in =$meta= matches the search. If it does, return
a non-undef value.

=cut

sub matches {
    my( $this, $meta ) = @_;

    my $op = $this->{op};
    my $r = $this->{right};
    my $l = $this->{left};

    return undef unless defined $r;

    if ($op eq 'TERMINAL') {
        return $r;
    }

    if( $op eq '.') {
        my( $lval, $rval );
        if( $l->{op} eq 'attachment' ) {
            my $lval = $l->matches( $meta );
            my $rval = $r->matches( $meta );
            return $lval->{$rval};
        } else {
            my $lval = $l->matches( $meta );
            my $rval = $r->matches( $meta );
            if ($lval =~ /^(TOPIC(INFO|PARENT|MOVED)|FORM)$/) {
                $lval = $meta->get( $lval );
                return undef unless $lval;
                return $lval->{$rval};
            } else {
                # Field
                my $fld = $meta->get( 'FIELD', $lval );
                return undef unless $fld;
                return $fld->{$rval};
            }
        }
    }

    if ($op eq '!') {
        return !( $r->matches( $meta ))
    };
    if ($op eq 'lc') {
        return lc( $r->matches( $meta ));
    };
    if ($op eq 'uc') {
        return uc( $r->matches( $meta ));
    };
    if ($op eq 'attachment') {
        return $meta->get( 'FILEATTACHMENT', $r->matches( $meta ));
    }

    return undef unless (defined $l);

    if ($op eq 'OR' ) {
        return ( $l->matches( $meta ) || $r->matches( $meta ));
    }
    if ($op eq 'AND' ) {
        return ( $l->matches( $meta ) && $r->matches( $meta ))
    }

    if ($op eq ':') {
        return undef unless ($meta && defined $r);
        my $session = $meta->{_session};

        my $node = $l->matches( $meta );

        return undef unless defined $node &&
          $node =~ /^($TWiki::regex{webNameRegex}\.)*$TWiki::regex{wikiWordRegex}$/;

        my( $w, $t ) = $session->normalizeWebTopicName( undef, $node );
        my $result = undef;
        try {
            my( $submeta, $subtext ) = $session->{store}->readTopic(
                undef, $w, $t );

            $result = $r->matches( $submeta );
        } catch Error::Simple with {
        };
        return $result;
    }

    my $lval = $l->matches( $meta );
    my $rval = $r->matches( $meta );

    return undef unless ( defined $lval  && defined $rval);

    if ($lval =~ /^$numberRE$/o && $rval =~ /^$numberRE$/o) {
        if ( $op eq '=' )  { return ( $lval == $rval ) };
        if ( $op eq '!=' ) { return ( $lval != $rval ) };
        if ( $op eq '>' )  { return ( $lval > $rval ) };
        if ( $op eq '<' )  { return ( $lval < $rval ) };
        if ( $op eq '>=' ) { return ( $lval >= $rval ) };
        if ( $op eq '<=' ) { return ( $lval <= $rval ) };
    }
    if ( $op eq '=' )  { return ( $lval eq $rval ) };
    if ( $op eq '!=' ) { return ( $lval ne $rval ) };
    if ( $op eq '~' )  { return ( $lval =~ m/$rval/ ) };
    if ( $op eq '>' )  { return ( $lval cmp $rval ) > 0};
    if ( $op eq '<' )  { return ( $lval cmp $rval ) < 0};
    if ( $op eq '>=' ) { return ( $lval cmp $rval ) >= 0};
    if ( $op eq '<=' ) { return ( $lval cmp $rval ) <= 0};

    return 0;
}

=pod

---+++ =stringify()= -> string
Generates a string representation of the object.

=cut

sub stringify {
    my $this = shift;

    my $text = '';
    if ( defined( $this->{left} )) {
        if ( !ref($this->{left}) ) {
            $text .= $this->{left};
        } else {
            $text .= '(' . $this->{left}->stringify() . ')';
        }
        $text .= ' ';
    }
    $text .= $this->{op} . ' ';
    if ( !ref($this->{right}) ) {
        $text .= "'$this->{right}'";
    } else {
        $text .= '(' . $this->{right}->stringify() . ')';
    }
    return $text;
}

1;
