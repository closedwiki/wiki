#
# Copyright (C) Motorola 2003 - All rights reserved
#
use strict;
use POSIX;

# An Arithmetic is an evaluator for simple arithmetic expressions
package TWiki::Plugins::FormQueryPlugin::Arithmetic;

# Operator precedences
my %prec =
  (
      '#+'           => 3,
      '#-'           => 3,
      '#round'       => 3,
      '*'            => 2,
      '/'            => 2,
      '+'            => 1,
      '-'            => 1,
     );

my $bopRE = "[\\+\\-\\*\\/]";
my $uopRE = "[\\-\\+]|round";
my $number = "[\\d\\.]+";

sub evaluate {
    my @tokens = split( /($bopRE|$uopRE|$number|\(|\))|\s+/, shift );
    @tokens = reverse( @tokens );
    my $r;
    eval { $r = _eval( \@tokens ) };
    if ( $@ ) {
        $r = "Arithmetic failed at " . join(" ", @tokens) . ": $@";
    } elsif ( !$r ) {
        $r = 0;
    }

    return $r;
}

sub _eval {
    my $tokens = shift;
    my $lastWasOper = 1;
    my @opers = ();
    my @opands;

    while ( scalar( @$tokens )) {
        my $token = pop( @$tokens );
        if ( !defined( $token ) || $token eq "" ) {
        } elsif ( $token =~ /$bopRE|$uopRE/ ) {
            if ( $lastWasOper && $token =~ m/^($uopRE)$/o ) {
                $token = "\#$token";
            }
            while ( scalar( @opers ) > 0 &&
                      $prec{$token} < $prec{$opers[$#opers]} ) {
                _apply( \@opers, \@opands );
            }
            push( @opers, $token );
            $lastWasOper = 1;
        } elsif ( $token eq "(" ) {
            push( @opands, _eval( $tokens ));
            $lastWasOper = 0;
        } elsif ( $token eq ")" ) {
            last;
        } elsif ( $token =~ m/[\d\.]+/o ) {
            push( @opands, $token );
            $lastWasOper = 0;
        } else {
            die( "Bad token '$token' ".join("",reverse(@$tokens)) );
        }
    }
    while ( scalar( @opers ) > 0 ) {
        _apply( \@opers, \@opands );
    }
    die "Left on stack: ".join(",",@opands) unless ( scalar( @opands ) == 1 );
    #print STDERR "Finish\n";
    return $opands[0];
}

# PRIVATE STATIC generate a Search by popping the top two operands
# and the top operator. Push the result back onto the operand stack.
sub _apply {
    my ( $opers, $opands ) = @_;
    my $o = pop( @$opers );
    die "No operator" unless defined( $o );
    my $r = pop( @$opands );
    die "No right operand for $o" unless defined( $r );
    my $l = 0;
    if ( $o !~ m/^\#/o ) {
        $l = pop( @$opands );
        die "No left operand for $o $r" unless defined( $l );
    }
    #print STDERR "apply $l $o $r\n";
    if ( $o =~ /-/ ) {
        push( @$opands, $l - $r );
    } elsif ( $o =~ /\+/ ) {
        push( @$opands, $l + $r );
    } elsif ( $o eq "*" ) {
        push( @$opands, $l * $r );
    } elsif ( $o eq "/" ) {
        my $res = ( $r == 0 ) ? 0x7fffffff : ( $l / $r );
        push( @$opands, $res );
    } elsif ( $o eq "#round" ) {
        push( @$opands, int( $r + ( $r < 0 ? -0.5 : 0.5 )));
    } else {
        die "Major problem $o";
    }
}

1;
