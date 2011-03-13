# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2011 TWiki Contributors.
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
#
# Data type for a multiline string

package TWiki::Configure::Types::TEXT;

use strict;

use TWiki::Configure::Type;
use Data::Dumper;

use base 'TWiki::Configure::Type';

sub prompt {
    my( $this, $id, $opts, $value ) = @_;
    my $size = 10;
#    my $v = Data::Dumper->Dump([$value],['x']);
#    $v =~ s/^\$x = (.*);\s*$/$1/s;
#    $v =~ s/^     //gm;
    if( $opts =~ /\b(\d+)\b/ ) {
        $size = $1;
    }
    return CGI::textarea( -name => $id,
                          -value => $value,
                          -rows => $size,
                          -columns => 80);
}

# Test to determine if two values of this type are equal.
sub equals {
    my ($this, $val, $def) = @_;

    if (!defined $val) {
        return 0 if defined $def;
        return 1;
    } elsif (!defined $def) {
        return 0;
    }
    return 1 if $val eq $def;

    # sometimes extra spaces are introduced in eval'ed strings
    # just take out and hope for the best (i.e., that the 
    # difference is not inside an embedded string based on \s
    $val =~ s/\s//g;
    $def =~ s/\s//g;
    return $val eq $def;
}

# Used to process input values from CGI. Values taken from the query
# are run through this method before being saved in the value store.
# It should *not* be used to do validation - use a Checker to do that, or
# JavaScript invoked from the prompt.
sub string2value {
    my ($this, $val) = @_;
    return $val;
}

1;
