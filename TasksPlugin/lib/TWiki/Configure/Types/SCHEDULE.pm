# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.

use warnings;
use strict;

=pod

---+ package TWiki::Configure::Types::SCHEDULE
GUI module implementing SCHEDULE variables

This attempts to provide a tolerable GUI for crontab time schedules. I think this is an improvement over the raw table
strings in both comprehensibility and in error avoidance.

See lib/TWiki/Contrib/PeriodicTasks/Config.spec for the on-screen text and variable definitions.

The corresponding checker abstract class is TWiki::Configure::Checkers::Tasks::ScheduleChecker.

This item type is unusual in that it assembles its value from multiple form fields.

It is important that SCHEDULE items are checked for validity.

By default, the makeChecker routine will associate a Wiki::Configure::Checkers::Tasks::ScheduleChecker with all SCHEDULE items.

However, if there is some additional checking that a particular item requires, you can use
Twiki::Configure::Checkers::CleanupSchedule as a template for creating a specialized  instance.
Name it TWiki::Configure::Checkers::Plugins::<plugin-name>::<YourSchedule>.pm
It's only a dozen lines of perl, and you only need to change the package name to get the default checker.

Prior to TWiki 5.1.0, requires patches in lib/TWiki/Configure/Valuer.pm and lib/TWiki/Configure/UI.pm, which can be found
at http://twiki.org/p/pub/Codev/ConfigureSupportForTaskFramework/tfwconfigure.patch.  These are checked-for and errors
raised if missing.

Loose ends:

   * If integrated into core, remove checks for patches.  Look for $patched below and in the prompt() and string2value() methods.
   *  We don't currently handle */interval on-screen as I haven't found a reasonable html presentation.
   * There are a couple of hardcoded -styles that a purist might want to css-ify.  They don't bother me...much.

=cut

package TWiki::Configure::Types::SCHEDULE;
use base 'TWiki::Configure::Type';

my $patched = 1;
if( 1 ) { # Would be nice to test for release and skip check.  Can't, but can remove this if integrated into core.
    # Verify that UI patch to provide checkers for SCHEDULE objects is present

    $patched = 0;
    if( open( my $ui, '<', $INC{'TWiki/Configure/UI.pm'} ) ) {
        while( <$ui> ) {
            if( /->\s*makeChecker\s*\(/ ) {
                $patched = 1;
                last;
            }
        }
        close $ui;
    }
}

# Sorting alphas:
my %dayMap = (
	      '*' => '*', '_*' => '*',
	      sun => 0, 0 => 0, 7 => 7, _0 => 'sun', _7 => 'sun',
	      mon => 1, 1 => 1, _1 => 'mon',
	      tue => 2, 2 => 2, _2 => 'tue',
	      wed => 3, 3 => 3, _3 => 'wed',
	      thu => 4, 4 => 4, _4 => 'thu',
	      fri => 5, 5 => 5, _5 => 'fri',
	      sat => 6, 6 => 6, _6 => 'sat',
	     );

my %monMap = (
	      '*' => '*', '_*' => '*',
	      jan => 1, 1 => 1, _1 => 'jan',
	      feb => 2, 2 => 2, _2 => 'feb',
	      mar => 3, 3 => 3, _3 => 'mar',
	      apr => 4, 4 => 4, _4 => 'apr',
	      may => 5, 5 => 5, _5 => 'may',
	      jun => 6, 6 => 6, _6 => 'jun',
	      jul => 7, 7 => 7, _7 => 'jul',
	      aug => 8, 8 => 8, _8 => 'aug',
	      sep => 9, 9 => 9, _9 => 'sep',
	      oct => 10, 10 => 10, _10 => 'oct',
	      nov => 11, 11 => 11, _11 => 'nov',
	      dec => 12, 12 => 12, _12 => 'dec',
	     );
my %numMap = (
	      '*' => '*', '_*' => '*',
	      map { ($_ => $_, '_'.$_ => $_) } (0..59),
	     );
my %map = ( %dayMap, %monMap );


=pod

---++ ClassMethod new( $id )
Constructor for a new TWiki::Configure::Types::SCHEDULE object
   * =$id= - unique name of element

=cut

sub new {
    my ($class, $id) = @_;

    # Make Valuer.pm call string2value with query and item name
    # This enables us to find all the sub-fields in POST data

    my $self = bless( {
                       name => $id,
                       NeedsQuery => 1,
                      }, $class);

    return $self;
}

=pod

---++ ObjectMethod prompt( $id, $opts, $value )
Generate GUI for a schedule configuration item
   * =$id= - unique name of element, using hash key syntax
   * =$opts= - field options string from spec file (e.g. width)
   * =$value= - Current value of field

Called by GUI to obtain the HTML for a SCHEDULE.  The GUI expects a single form field, but crontab entries are not user-friendly.
So, the fields of the crontab entry are split out into individual CGI elements, ordered more intuitively, and mapped onto select
boxes that hide the crontab syntax.  The select boxes are wrapped in a table for placement.

The value for the GUI is a hidden field; the subfield names are based on the GUI id, but with parentheses instead of braces, and
with the subfield mnemonic as a suffix for uniqueness.  This convention is internal to this module although an ambitions CSS
designer might care.

Returns HTML implementing the input fields for this item.

=cut

sub prompt {
    my( $this, $id, $opts, $value ) = @_;

    # Check for required patch in UI & complain if missing.  See module heading for details.
    # Remove next 3 lines if integrated into core
    $patched or
      return CGI::span( { -style=>'font-weight:bold; color:red;' },
                        "SCHEDULE item $id not rendered: $INC{'TWiki/Configure/UI.pm'} is not up-to-date\n" );

    # Generate safe ID for sub-fields of form.
    my $xid = $id;
    $xid =~ tr /\{\}/()/;

    # Handle late defaulting.
    # Shouldn't happen if the checker is active.

    defined $value or
	$value = eval "\$TWiki::defaultCfg->$id" || "1 15 1-31/4 * * 15";

    # Generate a hidden variable for the actual schedule

    my $boxes = CGI::hidden( -name => $id, -value => $value );

    # Break the value, a crontab string, into 5 or 6 fields

    my @vals = split( /\s/, $value );

    # Build a table to hold headings and pulldown boxes

    $boxes .= CGI::start_table();

    # Debug: Display the actual crontab string in 'Expert' mode

    if( 0 &&  CGI::param( 'expert') ) {
	$boxes .= CGI::Tr(
                          CGI::td( { colspan => 6 }, CGI::b( 'Crontab: ' )  .
                                   CGI::textfield( -name => $xid.'Summary', -size => length($value),
                                                   -style => 'font-family:monospace;',
                                                   -default => $value, -readonly => 1 ) ) );
    }

    # Human display order; indexes in @vals are crontab order

    $boxes .= CGI::start_Tr();
    foreach my $field (qw/Days Months Days Hours Minutes Seconds/ ) {
	$boxes .= CGI::td( CGI::b(CGI::u($field)) );
    }
    $boxes .= CGI::end_Tr();

    # This shows the raw crontab lists - so it's not necessary to scroll the listboxes for an overview.

    $boxes .= CGI::start_Tr();
    for my $field ( 4, 3, 2, 1, 0, 5 ) {
	$boxes .= CGI::td( $vals[$field] );
    }
    $boxes .= CGI::end_Tr();

    $boxes .= CGI::start_Tr( );
    $boxes .= CGI::td( { -style=>'vertical-align:top;' },
                       CGI::popup_menu( -name => $xid.'dow', -override =>1,
                                        -default => [_expand( \%dayMap, $vals[4], 0, 6 )],
					-values => [qw/* Sun Mon Tue Wed Thu Fri Sat/],
					-size => 8, -multiple => 1 ) );
    $boxes .= CGI::td( { -style=>'vertical-align:top;' },
		       CGI::popup_menu( -name => $xid.'mon', -override =>1,
					-default => [_expand( \%monMap, $vals[3], 1, 12 )],
					-values => [qw/* Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/],
					-size => 13, -multiple => 1 ) );
    $boxes .= CGI::td( { -style=>'vertical-align:top;' },
		       CGI::popup_menu( -name => $xid.'dom', -override =>1, 
					-default => [_expand( \%numMap, $vals[2], 1, 31 )],
					-values => ['*', 1..31],
					-size => 16, -multiple => 1 ) );

    $boxes .= CGI::td( { -style=>'vertical-align:top;' },
		       CGI::popup_menu( -name => $xid.'hour', -override =>1, 
					-default => [_expand( \%numMap, $vals[1], 0, 23 )],
					-values => ['*', 0..23],
					-size => 16, -multiple => 1 ) );
    $boxes .= CGI::td( { -style=>'vertical-align:top;' },
		       CGI::popup_menu( -name => $xid.'min', -override =>1,
					-default => [_expand( \%numMap, $vals[0], 0, 59 )],
					-values => ['*', 0..59],
					-size => 16, -multiple => 1 ) );
    $boxes .= CGI::td( { -style=>'vertical-align:top;' },
		       CGI::popup_menu( -name => $xid.'sec', -override =>1,
					-default => [_expand( \%numMap, $vals[5], 0, 59 )],
					-values => ['*', 0..59],
					-size => 16, -multiple => 1 ) );
    $boxes .= CGI::end_Tr();

    $boxes .= CGI::end_table();

    return $boxes;
}

=pod

---++ ObjectMethod string2value( $query, $name ) -> $value
Used to process input values from CGI. Values taken from the query are run through this method before being saved in
the value store.  It should *not* be used to do validation.
   * =$query= - the CGI query object
   * =$name= - the configuration item name

This is normally a trivial routine.  However, here it is used to assemble the item value from the multiple form fields.  This
requires that we have access to the query object, not just the value of one config item.  Getting the query object requires
a version of Valuer from TWiki 5.1.0 or greater (or a patch).  We check for that here.

However, this routine is also called when the config change form wasn't on the previously displayed page.  In that case,
return the value stored previously.

In assembling the value, we optimize the cron entry by creating ranges and using wildcards and stepcounts wherever possible.

Returns the value of the configuration item.

=cut

sub string2value {
    my( $this, $query, $name ) = @_;

    my $xid = $name;
    $xid =~ tr /\{\}/()/;

    # Can remove next two lines if integrated into core
    ref $query  eq 'CGI' or
      die "Value for SCHEDULE item $name unavailable: $INC{'TWiki/Configure/Valuer.pm'} is not up-to-date\n";

    # If we don't have the selectbox values (dow is an arbitrary indicator), we use whatever's in the full string.
    # We computed that in a previous screen.
    # If we do have the selectbox values, it's a config change form, so we must piece the string together.

    return $query->param($name) unless( defined $query->param( $xid.'dow' ) );

    my $value = '';

    # Build record from each field - in crontab order

    foreach my $field (qw /min hour dom mon dow sec/) {
	$value .= ' ' unless( length $value == 0 );
	my @values = $query->param( $xid.$field );
	@values = '*' unless( @values );
	$query->delete( $xid.$field );

	# condense the value list using ranges and repeat counts

	$value .= _condense( @{ {
	                            hour => [ \%numMap, 0, 23 ],
				    dom =>  [ \%numMap, 1, 31 ],
				    dow =>  [ \%dayMap, 0, 6 ],
				    mon => [ \%monMap, 1, 12 ],
				}->{$field} || [ \%numMap, 0, 59 ]
			      }, @values );
    }

    # Update the config item's value with the computed crontab data

    $query->param($name,$value);

    return $value;
}

=pod

---++ ObjectMethod equals( $val, $def ) -> $equal
Test to determine if two schedules are equal
   * =$val= - one schedule
   * =$def= - the other schedule

We rely on the fact that condensing the schedule value in string2value puts any schedule into a canonical form.

Thus, a simple string compare suffices - except that we also need to deal with undefined values.

Returns true if the values are the same; false if they differ.

=cut


sub equals {
    my ($this, $val, $def) = @_;

    return $val eq $def if( defined($val) && defined($def) );

    return !(defined($val) xor defined($def));
}

=pod

---++ ClassMethod new( $item, $keys )
Constructor for a new X object
   * =$item= - Item object
   * =$keys= - Item configuration hash keys (e.g. {a}{b})

The UI calls this method when no item-specific checker class (TWiki::Confiugre::Checkers::key[::subkey...]) exists.

It generates a default checker, since ScheduleChecker is generic (doesn't need any key-specific information).

This approach reduces the clutter (module sprawl) and effor of creating one trivial class per SCHEDULE key.

You can still define an item-specific checker if required (e.g. to enforce a maximum frequency).

Returns a TWiki::Configure::Checker object for this schedule.

=cut

sub makeChecker {
    my $class = shift;
#    my( $item, $keys ) = @_;

    require TWiki::Configure::Checkers::Tasks::ScheduleChecker;
    my $checker = TWiki::Configure::Checkers::Tasks::ScheduleChecker->new( @_ );

    return $checker;
}

# ##################################################
#
# Subroutines below this point are private
#
# ##################################################

# ---++ StaticMethod _remdups( @list ) -> @newList
# Remove duplicate values from a list
#   * =@list= - List of field values
#
# Removes duplicate values from a list.  Duplicate values may arise from overlapping ranges or simply duplicate values in a
# schedule field.  Removing them makes it simpler to check for schedule equality, to generate valid HTML OPTION elements, as
# well as reducing the cost of processing.
#
# Returns list with duplicates removed (and in sorted order)

sub _remdups {
    my @list = sort _cronsort @_;

    my @out = ();

    @out = shift @list;
    while( @list ) {
	if( lc $out[-1] eq lc $list[0] ) {
	    shift @list;
	} else {
	    push @out, shift( @list );
	}
    }
    return @out;
}

# ---++ StaticMethod _cronsort $a $b -> $order
# Sort method for sorting schedule (crontab field) elements
#  Inputs are the sort $a and $b globals
#
# Wildcard ('*') sorts less than anything else
#
# Comparision is numeric if the input is numeric
# Otherwise, keywords are mapped to numerics
#
# Returns -1, 0, or +1 according to <=> or cmp

sub _cronsort {
    return 0 if( $a eq $b );
    return -1 if( $a eq '*' );
    return 1 if( $b eq '*' );
    return $a <=> $b if( $a =~ /^[0-9]+$/ && $b =~ /^[0-9]+$/ );
    my ($ma, $mb) = ( $map{lc $a}, $map{lc $b} );
    return $ma <=> $mb if( defined $ma && defined $mb );
    return $a cmp $b;
}

# ---++ StaticMethod _expand( $map, $field, $min, $max )
#   * =$map= - hash for mapping keywords to numeric values and back
#   * =$field= - schedule field as text - may include multiple values, ranges and/or interval repeats
#   * =$min= - minimum (numeric) value allowed for field
#   * =$max= - maximum (numeric) value allowed for field
#
# Expands any ranges and interval repeats found in a schedule field & removes duplicates.
#
# Returns value list suitable for generating CGI form element values.

sub _expand {
    my( $map, @list ) = ( $_[0], split( /,/, $_[1] ) );
    my( $min, $max ) = ( @_[2..3] );

    return ( '*', )  unless( @list ); # Empty list?

    my @expanded = ();

    # Scan for ranges and expand
    # Normalize to numeric for duplicate detection

    foreach my $ele (@list) {
	if( $ele =~ m!^(\w+)-(\w+)(?:/(\d+))?$! ) {
	    my $start = $map->{lc $1} || 0;
	    my $end = $map->{lc $2} || 0;
	    my $step = $3 || 1;

	    for( my $v = $start; $v <= $end; $v += $step ) {
		push @expanded, $v;
	    }
	} elsif( $ele =~ m!^\*/(\d+)$! ) {
	    my $step = $1 || 1;

	    for( my $v = $min; $v <= $max; $v += $step ) {
		push @expanded, $v;
	    }

	} elsif( exists $map->{lc $ele} ) {
	    push @expanded, $map->{lc $ele};
	} else {
	    push @expanded, $ele;
	}
    }

    # Remove duplicates and remap to text

    @list = map { ucfirst $map->{'_' . $_} } _remdups( @expanded );

    return @list;
}

# ---++ StaticMethod _condense( $map, $min, $max, @values ) -> $fieldString
# Condense a value list into ranges and return a string usable as a crontab entry field.
#   * =$map= - hash for mapping keywords to numeric values and back
#   * =$min= - minimum (numeric) value allowed for field
#   * =$max= - maximum (numeric) value allowed for field
#   * =@values= = Values selected for field
#
# Converting a selection list into a field value string can be done trivially by join( ',', @list ).
# However, we attempt to produce a compact, readable list.  That's a bit tricker...
#
# Returns a schedule field string.

sub _condense {
    my( $map, $min, $max, @values ) = ( @_ );

    return '*' unless( @values );

    my $value = '';

    # Sorted list of numeric (or '*') values with no duplicates

    @values = _remdups( map { (exists $map->{lc $_})? $map->{lc $_} : $_ } @values );

    # '*' can only be first, can't be combined so just move to output

    if( $values[0] eq '*' ) {
	$value = '*';
	shift @values;
	return $value unless( @values );
    }

    return '*/1' unless( $values[0] =~ /^\d+$/ ); # Garbage in, * out - /1 is to indicate error for debug

    # Initialize last item/working range with first value

   my $last = {
	       start => $values[0], # Start of interval
	       end => $values[0],   # End of interval
	       interval => 0,       # Interval width
	       n => 1,              # Number of values in the range
	      };
    shift(@values);

    # Build condensed string by merging items into ranges when profitable

    while( my $next = shift @values ) {
	return '*/1' unless( $next =~ /^\d+$/ ); # Garbage in, * out - /1 is to indicate error for debug

	my $gap = $next - $last->{end};
	if( $last->{interval} == 0 ) {
	    # Second element starts a new interval sequence
	    $last->{interval} = $gap;
	    $last->{end} = $next;
	    $last->{n} = 2;
	    next;
	}
	if( $gap == $last->{interval} ) {
	    # Continuing at same interval, update range
	    $last->{end} = $next;
	    $last->{n}++;
	    next;
	}
	if( $last->{n} < 3 ) {
	    # m-n & m-n/i aren't worthwhile.  Dump all but last of old as a list.
	    # The last may work as the start of a new interval sequence.
	    while( $last->{n} > 1 ) {
		$value .= ',' if( length $value );
		$value .= ucfirst $map->{'_' . $last->{start}};
		$last ->{start} += $last->{interval};
		$last->{n}--;
	    }
	    $last->{interval} = $gap;
	    $last->{end} = $next;
	    $last->{n} = 2;
	    next;
	}
	$value = _outrange( $map, $value, $last, $min, $max );

	# Start a new interval range with this value
	$last->{start} = $next;
	$last->{end} = $next;
	$last->{interval} = 0;
	$last->{n} = 1;
    }

    # Out of values, dump final element
    if( $last->{n} < 3 ) {
	while( $last->{n} ) {
	    $value .= ',' if( length $value );
	    $value .= ucfirst $map->{'_' . $last->{start}};
	    $last ->{start} += $last->{interval};
	    $last->{n}--;
	}
    } else {
	$value = _outrange( $map, $value, $last, $min, $max );
    }

    return $value;
}

# ---++ StaticMethod _outrange( $map, $value, $last, $min, $max ) -> $subfieldString
# Output a subfield
#   * =$map= - hash for mapping keywords to numeric values and back
#   * =$value= - Field string constructed so far
#   * =$last= - Reference to state hash
#   * =$min= - minimum (numeric) value allowed for field
#   * =$max= - maximum (numeric) value allowed for field
#
# Helps  _condense to generate subfield strings using */interval or range.
# Output is appended to input value.  Text fields are re-mapped from numbers to the prefered text.
#
# Returns updated string.

sub _outrange {
    my( $map, $value, $last, $min, $max ) = @_;

    # Ending long interval, output range (m-n), and if interval isn't 1, /i
    # However, if the range runs from min to max (accounting for interval, which can
    # overhang the useful part of the range), we can use */interval instead.
    #
    # e.g. 1, 3, 5 selected from an item with (min,max) = (1, 6) can be expressed as */2.

    my( $start, $end, $interval ) = ( $last->{start}, $last->{end}, $last->{interval} );

    $value .= ',' if( length $value );
    {
	use integer;

	if( $start <= $min && $end >= ((($max - $start)
							/ $interval) * $interval)
		                      + $start ) {
	    $value .= '*';
	} else {
	    $value .= ucfirst( $map->{'_' . $start } ) . '-' . ucfirst $map->{'_' . $end};
	}
    }
    $value .= '/' . $interval unless( $interval == 1 );

    return $value;
}

1;

__END__

This is an original work by Timothe Litt.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 3
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at
http://www.gnu.org/copyleft/gpl.html
