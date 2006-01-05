#
# Copyright (C) Motorola 2003 - All rights reserved
# Copyright (C) Crawford Currie 2004
#
use strict;

use Time::ParseDate;

=begin text

---++ class Search
Search operators work on the fields of a TWiki::Contrib::DBCacheContrib::Map. The fields are given by name, and the values by strings. Strings should always be surrounded by 'single-quotes'. String which are regular expressions use 'perl' re syntax (see =man perlre= for help)

*Warning* single and double quotes are not allowed in values!

The following operators are available:

| *Operator* | *LHS* | *RHS* | *Meaning* |
| <code>=</code> | field name | regular expression | Value exactly matches this regular expression. The expression must match the whole string. |
| <code>!=</code> | field name | regular expression | Field is not this RE. Inverse of = |
| <code>=~</code> | field name | regular expression | Value contains this regular expression i.e. the RE is found somewhere in the field value. |
| <code>&lt;</code> | field name | integer (string containing an integer e.g '4') | Number is < |
| <code>&gt;</code> | field name | integer | Number is > |
| <code>&gt;=</code> | field name | integer | Number is >= |
| <code>&lt;=</code> | field name | integer | Number is <= |
| <code>EARLIER_THAN</code> | field name | date (string containing a date e.g. '1 Apr 2003' | Date is earlier than the given date |
| <code>LATER_THAN</code> | field name | date | Date is later than the given date |
| <code>WITHIN_DAYS</code> | field name | integer | Date (which must be in the future) is within n _working_ days of todays date |
| <code>!</code> | none | expr | Boolean NOT |
| <code>AND</code> | expr | expr | Boolean AND |
| <code>OR</code> | expr | expr | Boolean OR |
| <code>()</code> | N/A | N/A | Bracketed subexpression |

Dates for =EARLIER_THAN=, =LATER_THAN= and =WITHIN_DAYS= must be dates in the format expected by =Time::ParseDate= (like the ActionTrackerPlugin). =WITHIN_DAYS= works out the number of _working_ days (i.e. excluding Saturday and Sunday). Apologies in advance if your weekend is offset &plusmn; a day!

A search object implements the "matches" method as its general
contract with the rest of the world.

---+++ Example
Get a list of attachments that have a date earlier than 1st January 2000
<verbatim>
  $db = new TWiki::Contrib::DBCacheContrib::DBCache( $web ); # always done
  $db->load();
  my $search = new TWiki::Contrib::DBCacheContrib::Search("date EARLIER_THAN '1st January 2000'");

  foreach my $topic ($db->getKeys()) {
     my $attachments = $topic->get("attachments");
     foreach my $val ($attachments->getValues()) {
       if ($search->matches($val)) {
          print $val->get("name") . "\n";
       }
     }
  }
</verbatim>

=cut

{ package TWiki::Contrib::DBCacheContrib::Search;

  # Operator precedences
  my %prec =
    (
     '='            => 4,
     '=~'           => 4,
     '!='           => 4,
     '>='           => 4,
     '<='           => 4,
     '<'            => 4,
     '>'            => 4,
     'EARLIER_THAN' => 4,
     'LATER_THAN'   => 4,
     'WITHIN_DAYS'  => 4,
     'IS_DATE'      => 4,
     '!'            => 3,
     'AND'          => 2,
     'OR'           => 1
    );

  my $bopRE =
    "AND\\b|OR\\b|!=|=~?|<=?|>=?|LATER_THAN\\b|EARLIER_THAN\\b|WITHIN_DAYS\\b|IS_DATE\\b";
  my $uopRE = "!";

  my $now = time();

  # PUBLIC STATIC used for testing only; force 'now' to be a particular
  # time.
  sub forceTime {
    my $t = shift;
    $now = Time::ParseDate::parsedate( $t );
  }

=begin text

---+++ =new($string)=
   * =$string= - string containing an expression to parse
Construct a new search node by parsing the passed expression.

=cut

  sub new {
    my ( $class, $string, $left, $op, $right ) = @_;
    my $this;
    if ( defined( $string )) {
      if ( $string =~ m/^\s*$/o ) {
		return new TWiki::Contrib::DBCacheContrib::Search( undef, undef, "TRUE", undef );
      } else {
		my $rest;
		( $this, $rest ) = _parse( $string );
		return $this;
      }
    } else {
      $this = {};
      $this->{right} = $right;
      $this->{left} = $left;
      $this->{op} = $op;
      return bless( $this, $class );
    }
  }

  # PRIVATE STATIC generate a Search by popping the top two operands
  # and the top operator. Push the result back onto the operand stack.
  sub _apply {
    my ( $opers, $opands ) = @_;
    my $o = pop( @$opers );
    my $r = pop( @$opands );
    die "Bad search" unless defined( $r );
    my $l = undef;
    if ( $o =~ /^$bopRE$/o ) {
      $l = pop( @$opands );
      die "Bad search" unless defined( $l );
    }
    my $n = new TWiki::Contrib::DBCacheContrib::Search( undef, $l, $o, $r );
    push( @$opands, $n);
  }

  # PRIVATE STATIC simple stack parser for grabbing boolean expressions
  sub _parse {
    my $string = shift;
    $string .= " ";
    my @opands;
    my @opers;
    while ( $string !~ m/^\s*$/o ) {
      if ( $string =~ s/^\s*($bopRE)//o ) {
	# Binary comparison op
	my $op = $1;
	while ( scalar( @opers ) > 0 && $prec{$op} < $prec{$opers[$#opers]} ) {
	  _apply( \@opers, \@opands );
	}
	push( @opers, $op );
      } elsif ( $string =~ s/^\s*($uopRE)//o ) {
	# unary op
	push( @opers, $1 );
      } elsif ( $string =~ s/^\s*\'(.*?)\'//o ) {
	push( @opands, $1 );
      } elsif ( $string =~ s/^\s*([\w\.]+)//o ) {
	push( @opands, $1 );
      } elsif ( $string =~ s/\s*\(//o ) {
	my $oa;
	( $oa, $string ) = _parse( $string );
	push( @opands, $oa );
      } elsif ( $string =~ s/^\s*\)//o ) {
	last;
      } else {
	return ( undef, "Parser stuck at $string" );
      }
    }
    while ( scalar( @opers ) > 0 ) {
      _apply( \@opers, \@opands );
    }
    die "Bad search" unless ( scalar( @opands ) == 1 );
    return ( pop( @opands ), $string );
  }

=begin text

---+++ =matches($object)= -> boolean
   * =$object= - object to test; must implement =get=
See if object matches the search. =$object= can actually be any object that provides
the method "get" that returns a value given a string key.

=cut
  sub matches {
    my ( $this, $map ) = @_;

    my $op = $this->{op};

    return 1 if ( $op eq "TRUE" );

    my $r = $this->{right};
    return 0 unless ( defined( $r ));

    if ($op eq "!") { return !( $r->matches( $map )) };

    my $l = $this->{left};
    return 0 unless ( defined( $l ));

    if ($op eq "OR" ) {  return ( $l->matches( $map ) ||
				  $r->matches( $map )) };
    if ($op eq "AND" ) { return ( $l->matches( $map ) &&
				  $r->matches( $map )) };

    return 0 unless ( defined( $map ));

    my $val = $map->get( $l );
    # Compatibility: values have now moved down into the form for topics,
    # but we need this just in case the search specifier is "old style"
    unless ($val) {
      $val = $map->get($map->get("form"))->get( $l );
    }
    return 0 unless ( defined( $val ));

    if ( $op eq "=" )  { return ( $val =~ m/^$r$/ ) };
    if ( $op eq "!=" ) { return ( $val !~ m/^$r$/ ) };
    if ( $op eq "=~" ) { return ( $val =~ m/$r/ ) };
    if ( $op eq ">" )  { return ( $val > $r ) };
    if ( $op eq "<" )  { return ( $val < $r ) };
    if ( $op eq ">=" ) { return ( $val >= $r ) };
    if ( $op eq "<=" ) { return ( $val <= $r ) };

    my $lval = Time::ParseDate::parsedate( $val );
    return 0 unless ( defined( $lval ));

    if ( $op eq "WITHIN_DAYS" ) {
      return ( $lval >= $now && workingDays( $now, $lval ) <= $r );
    }

    my $rval = Time::ParseDate::parsedate( $r );
    return 0 unless ( defined( $rval ));

    if ( $op eq "LATER_THAN" )   { return ( $lval > $rval ) };
    if ( $op eq "EARLIER_THAN" ) { return ( $lval < $rval ) };
    if ( $op eq "IS_DATE")       { return ( $lval == $rval ) };

    return 0;
  }

  # PUBLIC STATIC calculate working days between two times
  # Published because it's useful elsewhere
  sub workingDays {
    my ( $start, $end ) = @_;

    use integer;
    my $elapsed_days = ( $end - $start ) / ( 60 * 60 * 24 );
    # total number of elapsed 7-day weeks
    my $whole_weeks = $elapsed_days / 7;
    my $extra_days = $elapsed_days - ( $whole_weeks * 7 );
    if ( $extra_days > 0 ) {
      my @lt = localtime( $start );
      my $wday = $lt[6]; # weekday, 0 is sunday

      if ($wday == 0) {
	$extra_days-- if ( $extra_days > 0 );
      } else {
	$extra_days-- if ($extra_days > (6 - $wday));
	$extra_days-- if ($extra_days > (6 - $wday));
      }
    }
    return $whole_weeks * 5 + $extra_days;
  }

=begin text

---+++ =toString()= -> string
Generates a string representation of the object.

=cut

  sub toString {
    my $this = shift;

    my $text = "";
    if ( defined( $this->{left} )) {
      if ( !ref($this->{left}) ) {
	$text .= $this->{left}; 
      } else {
	$text .= "(" . $this->{left}->toString() . ")";
      }
      $text .= " ";
    }
    $text .= $this->{op} . " ";
    if ( !ref($this->{right}) ) {
      $text .= "'" . $this->{right} . "'"; 
    } else {
      $text .= "(" . $this->{right}->toString() . ")";
    }
    return $text;
  }
}

1;
