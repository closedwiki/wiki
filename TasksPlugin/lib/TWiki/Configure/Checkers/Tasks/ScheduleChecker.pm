# -*- mode: CPerl; -*-
# TWiki off-line task management framework addon for the TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Timothe Litt <litt at acm dot org>
# License is at end of module.
# Removal of Copyright and/or License prohibited.

use strict;
use warnings;

=pod

---+ package TWiki::Configure::Checkers::Tasks::ScheduleChecker
Configure GUI checker for SCHEDULE items.

SCHEDULE will automagically generate this checker as a default for SCHEDULE items.

It can be subclassed if some schedule needs special treatment.

A SCHEDULE is a crontab-like schedule periodic events, used by Schedule::Cron.

The format is roughly vixie-cron, with the additional seconds column.

=cut

package TWiki::Configure::Checkers::Tasks::ScheduleChecker;
use base 'TWiki::Configure::Checker';

use TWiki::Configure::Load;

# Convert day (of week) names to numeric form

my $dowMap = {
	      sun => 0, 0 => 0, 7 => 7,
	      mon => 1, 1 => 1,
	      tue => 2, 2 => 2,
	      wed => 3, 3 => 3,
	      thu => 4, 4 => 4,
	      fri => 5, 5 => 5,
	      sat => 6, 6 => 6,
	     };

# Convert month names to numeric form

my $monMap = {
	      jan => 1, 1 => 1,
	      feb => 2, 2 => 2,
	      mar => 3, 3 => 3,
	      apr => 4, 4 => 4,
	      may => 5, 5 => 5,
	      jun => 6, 6 => 6,
	      jul => 7, 7 => 7,
	      aug => 8, 8 => 8,
	      sep => 9, 9 => 9,
	      oct => 10, 10 => 10,
	      nov => 11, 11 => 11,
	      dec => 12, 12 => 12,
	     };

# ---++ StaticMethod checkDecValRange( $field, $val, $min, $max )
# Validate that a decimal value is in range

sub checkDecValRange {
    my $field = shift;
    my $val = shift;
    my $min = shift;
    my $max = shift;

    return 1 if( $val =~/^(\d+)$/ && $val >= $min && $val <= $max );

    die "$field value '$val' is out of range\n";
}

# ---++ StaticMethod checkDecRangeList( $field, $val, $min, $max )
# Validate a range list.

sub checkDecRangeList {
    my $field = shift;
    my $val = shift;
    my $min = shift;
    my $max = shift;

    # Singleton *, */n, v

    return 1 if( $val =~ m!^\*(?:/(\d+))?$! && (!defined $1 || $1 < $max) ||
                 $val =~ m!^(\d+)$! && checkDecValRange( $field, $1, $min, $max ) );

    # 1 or more ranges v1-v2, v1-v2/n, v
    # Range endpoints must be valid, and start must be less that end.
    # (I suppose start could equal end, but why wouldn't one use just a v?)
    # If present, /n must be less than max.

    my $n = 0;
    foreach my $v (split( /,/, $val )) {

	die "$field range '$v' is invalid\n" unless( ($v =~ m!^(\d+)-(\d+)(?:/(\d+))?$! && checkDecValRange( $field, $1, $min, $max )
					                                             && checkDecValRange( $field, $2, $min, $max )
			                                                             && $2 > $1 && (!defined $3 || $3 < $max))
						   || $v =~ m!^(\d+)$! && checkDecValRange( $field, $1, $min, $max )
				       );
	$n++;
    }
    die "$field no value specified\n" unless( $n );

    return 1;
}

# ---++ StaticMethod checkNameValRange( $field, $val, $map, $min, $max )
# Validate that a name's value is in range.
#
# Names can also be specified by their numeric equivalent

sub checkNameValRange {
    my $field = shift;
    my $val = shift;
    my $map = shift;
    my $min = shift;
    my $max = shift;

    if( $val !~ m!^\d+$! ) {
	die "$field name '$val' is invalid\n" unless( exists $map->{ lc $val} );
	$val = $map->{ lc $val};
    }

    return checkDecValRange( $field, $val, $min, $max );
}

# ---++ StaticMethod checkNameRangeList( $field, $val, $map, $min, $max )
# Validate a range list of names
#
# Names can also be specified by their numeric equivalent

sub checkNameRangeList {
    my $field = shift;
    my $val = shift;
    my $map = shift;
    my $min = shift;
    my $max = shift;

    # Singleton *, */n, v(min:max)

    return 1 if( $val =~ m!^\*(?:/(\w+))?$! && (!defined $1 || $1 < $max) || $val =~ m!^(\w+)$! && checkNameValRange( $field, $1, $map, $min, $max ) );

    # 1 or more ranges v1-v2, v1-v2/n

    my $n = 0;
    foreach my $v (split( /,/, $val )) {

	die "$field range '$v' is invalid\n" unless( ($v =~ m!^(\w+)-(\w+)(?:/(\d+))?$! && checkNameValRange( $field, $1, $map, $min, $max )
					                                                && checkNameValRange( $field, $2, $map, $min, $max )
			                                                                && ($map->{lc $1} < $map->{lc $2} || $max == 7 &&
											    $map->{lc $2} == 0 && $map->{lc $1} < 7) # Sat-Sun is OK because Sun can be '7'
						                                        && (!defined $3 || $3 < $max))
						   || $v =~ m!^(\w+)$! && checkNameValRange( $field, $1, $map, $min, $max )
				       );
	$n++;
    }
    die "$field no value specified\n" unless( $n );

    return 1;
}

# ---++ StaticMethod checkSchedule( $sched ) -> $result
# Validate an entire schedule
#    * =$sched= - the schedule string in crontab format (except no command is present)
#
# Returns 'OK' or an error string.

sub checkSchedule {
    my $sched = shift;

    # Process left to right, which is what people expect.

    eval {
	# Error on leading or trailing whitespace
	die "Leading or trailing whitespace is present\n" if( $sched =~ m/^\s/ || $sched =~ m/\s$/ );

	# Split spec into fields

	my @fields = split( /\s+/, $sched );
	my $nf = @fields;

	die "Number of fields ($nf), must be 5 or 6\n" unless( $nf == 5 || $nf == 6 );

	my( $min, $hr, $dom, $mon, $dow, $sec ) = @fields;

	# Check minute

	checkDecRangeList( 'Minute', $min, 0, 59 );

	# Check hour

	checkDecRangeList( 'Hour', $hr, 0, 23 );

	# Check day of month

	checkDecRangeList( 'Day of Month', $dom, 1, 31 );

	# Check month

	checkNameRangeList( 'Month', $mon, $monMap, 1, 12 );

	# Check day of week

	checkNameRangeList( 'Day of Week', $dow, $dowMap, 0, 7 );

	# Check Seconds

	checkDecRangeList( "Seconds", $sec, 0, 59 ) if( $nf >= 6 );
    }; if( $@ ) {
	return "Invalid task schedule: $@";
    }

    return 'OK';
}

=pod

---++ ObjectMethod check( $valueObject ) -> $errorString
Validates a SCHEDULE item for the configure GUI
   * =$valueObject= - configure value object

Returns empty string if OK, error string with any errors

=cut

sub check {
    my $this = shift;
    my $valobj = shift;

    my $keys = $valobj->getKeys() or die "No keys for value";
    my $value = eval "\$TWiki::cfg$keys";
    return $this->ERROR( "Can't evaluate current value of $keys: $@" ) if( $@ );
    # The default value may not have been available when  the other defaulting is done.

    unless( defined $value ) {
	$value = eval "\$TWiki::defaultCfg->$keys";
        return $this->ERROR( "Can't evaluate default value of $keys: $@" ) if( $@ );
	$value = "***UNDEF***" unless defined $value;
    }

    # Expand any references to other variables

    TWiki::Configure::Load::expandValue($value);

    my $sts = checkSchedule( $value );

    return '' if( $sts eq 'OK' );

    return $this->ERROR($sts);
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
