#
# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2006 TWiki Contributors.
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
# Base class of all types
package TWiki::Configure::Type;

use strict;

use CGI qw( :any );

use vars qw( %knownTypes );

sub new {
    my ($class, $id) = @_;

    return bless({ name => $id }, $class);
}

# Static factory
sub load {
    my $id = shift;
    my $typer = $knownTypes{$id};
    unless ($typer) {
        my $typeClass = 'TWiki::Configure::Types::'.$id;
        $typer = eval 'use '.$typeClass.'; new '.$typeClass.'("'.$id.'")';
        # unknown type - give it default string behaviours
        $typer = new TWiki::Configure::Type($id) unless $typer;
        $knownTypes{$id} = $typer;
    }
    return $typer;
}

sub prompt {
    my( $this, $id, $opts, $value ) = @_;

    my $size = '55%';
    if( $opts =~ /\s(\d+)\s/ ) {
        $size = $1;
        # These numbers are somewhat arbitrary..
        if( $size > 25 ) {
            $size = '55%';
        }
    }
    return CGI::textfield( -name => $id, -size=>$size, -default=>$value );
}

sub equals {
    my ($this, $val, $def) = @_;

    if (!defined $val) {
        return 0 if defined $def;
        return 1;
    } elsif (!defined $def) {
        return 0;
    }
    return $val eq $def;
}

# Used to process input values from CGI
sub string2value {
    my ($this, $val) = @_;
    return $val;
}

1;
