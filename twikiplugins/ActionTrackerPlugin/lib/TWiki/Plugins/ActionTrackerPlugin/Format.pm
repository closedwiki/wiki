#
# Copyright (C) Motorola 2002 - All rights reserved
#
# TWiki extension that adds tags for action tracking
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
use strict;
use integer;

use TWiki::Func;

# Object that represents a header and fields format
# This is where all formatting should be done; there should
# be no HTML tags anywhere else in the code!
# Formats objects that implement the following contract:
# 1. They provide a "getType" method, that returns a type
#    structure as per Action.pm
# 2. For each of the types they provide a _format_$type
#    method that returns the string representation of the type.
# 3. For each of their fields that require special formatting
#    they provide a _format_$field method that returns a string
#    representation of the field. Field methods override type
#    methods. The function must return a tuple of ( text, colour ).
#    The colour may be undefined.
package TWiki::Plugins::ActionTrackerPlugin::Format;

use vars qw ( $latecol $badcol $hdrcol $border );

# Colour for warning of late actions
$latecol = "yellow";
# Colour for an unparseable date
$badcol = "red";
# Colour for table header rows
$hdrcol = "orange";
# Border width for tables
$border = "1";

# PUBLIC Constructor
# $header is the format of the HTML table header representation
# $fields is the format of the HTML table body representation
# $textform is the format of the text representation
# $changeFields is the comma-separated list of fields to detect changes
# in.
# $orient is the orientation of generated tables; "rows" gives
# data in rows, anything else gives data in columns.
sub new {
    my ( $class, $header, $fields, $orient, $textform, $changeFields ) = @_;

    my $this = {};
    $header =~ s/^\s*\|//so;
    $header =~ s/\|\s*$//so;
    my @heads = split( /\|/, $header );

    $fields =~ s/^\s*\|//so;
    $fields =~ s/\|\s*$//so;
    my @bodies = split( /\|/, $fields );

    while ( $#bodies < $#heads ) {
        push( @bodies, "&nbsp;" );
    }

    while ( $#heads < $#bodies ) {
        push( @heads, "&nbsp;" );
    }

    @{$this->{HEADINGS}} = @heads;
    @{$this->{FIELDS}} = @bodies;

    $this->{TEXTFORM} = $textform;

    if ( $changeFields ) {
        $changeFields =~ s/\s//go;
        $changeFields =~ s/\$//go;
        @{$this->{CHANGEFIELDS}} = split( /,\s*/, $changeFields );
    }

    if ( $orient && $orient eq "rows" ) {
        $this->{ORIENTATION} = "rows";
    } else {
        $this->{ORIENTATION} = "cols";
    }

    return bless( $this, $class );
}

# PUBLIC return the headers in a format suitable for feeding
# back to new.
sub getHeaders {
    my $this = shift;
    return "|" . join( "|", @{$this->{HEADINGS}} ) . "|";
}

# PUBLIC return the fields in a format suitable for feeding
# back to new.
sub getFields {
    my $this = shift;
    return "|" . join( "|", @{$this->{FIELDS}} ) . "|";
}

# PUBLIC get the text form of the format
sub getTextForm {
    my $this = shift;
    return $this->{TEXTFORM};
}

# PUBLIC get the change fields as a comma-separated list
sub getChangeFields {
    my $this = shift;
    if ( defined( $this->{CHANGEFIELDS} ) ) {
        return join( ",", @{$this->{CHANGEFIELDS}} );
    }
    return "";
}

# PUBLIC get the table orientation
sub getOrientation {
    my $this = shift;
    return $this->{ORIENTATION};
}

# PUBLIC return the format as attributes
sub stringify() {
    my $this = shift;
    my $hdrs = $this->getHeaders();
    my $flds = $this->getFields();
    my $tform = $this->getTextForm();
    my $changeFields = $this->getChangeFields();
    my $orient = $this->getOrientation();
    return "header=\"$hdrs\" format=\"$flds\" " .
      "textform=\"$tform\" changefields=\"$changeFields\" ".
        "orientation=\"$orient\"";
}

# PRIVATE expand a var using one of:
# a function called $object->_format_$var()
# the field $object->{$var}
# or return the name of the var
# The function returns a tuple of ( text, colour ). The value 0 is
# treated as the default colour.
sub _expandVar {
    my $object = shift;
    my $vbl = shift;
    my $asHTML = shift;
    if ( defined( &{ref( $object ) . "::_formatField_$vbl"} ) ) {
        # special format for this field
        my $fn = "_formatField_$vbl";
        return $object->$fn( $asHTML, @_ );
    }
    my $type = $object->getType( $vbl );
    my $typename = $type->{type};
    if ( defined( &{ref( $object ) . "::_formatType_$typename"} ) ) {
        # special format for this type
        my $fn = "_formatType_$typename";
        return $object->$fn( $vbl, $asHTML, @_ );
    }

    if ( defined( $object->{$vbl} ) ) {
        # just expand as a string
        return ( $object->{$vbl}, 0 );
    }

    if ( $asHTML ) {
        return ( "&nbsp;", 0 );
    } else {
        return ( "", 0 );
    }
}

# PRIVATE STATIC fill in variable expansions in simple text form
sub _expandString {
    my $object = shift;
    my $var = shift;

    if ( $var eq "dollar") {
        return "\$";
    } elsif ($var eq "nop") {
        return "";
    } elsif ($var eq "n") {
        return "\n";
    } elsif ($var eq "percnt") {
        return "%";
    } elsif ($var eq "quot") {
        return "\"";
    }
    my ( $t, $c ) = _expandVar( $object, $var, @_ );
    return $t;
}

# PUBLIC fill in the text template using values
# extracted from the given object
sub _formatAsString {
    my $this = shift;
    my $object = shift;

    my $fmt = $this->{TEXTFORM};
    $fmt =~ s/\$(\w+\b)(\(\))?/&_expandString( $object, $1, 0, @_ )/geos;

    return $fmt;
}

# PRIVATE STATIC fill in variable expansions. If any of the expansions
# returns a non-zero color, then fill in the passed-by-reference color
# variable $col with the value returned.
sub _expandHTML {
    my $object = shift;
    my $var = shift;
    my $col = shift;

    if ( $var eq "dollar") {
        return "\$";
    } elsif ($var eq "nop") {
        return "";
    } elsif ($var eq "n") {
        return CGI::br();
    } elsif ($var eq "percnt") {
        return "%";
    } elsif ($var eq "quot") {
        return "\"";
    }

    my ( $t, $c ) = _expandVar( $object, $var, @_ );
    $$col = $c if ( $c );
    return "$t";
}

# PUBLIC format a list of actions into a table
sub formatHTMLTable {
    my $this = shift;
    my $data = shift;
    my $jump = shift;
    my $newWindow = shift;
    my $i;
    my @rows;
    my @anchors;

    # make a 2D array of cells
    foreach my $object ( @$data ) {
        my @cols;
        foreach $i ( @{$this->{FIELDS}} ) {
            my $c;
            my $entry = $i;
            $entry =~ s/\$(\w+)(\(\))?/&_expandHTML( $object, $1, \$c, 1, $jump, $newWindow )/geos;
            if ( $c ) {
                $entry = CGI::td( { bgcolor => $c }, $entry );
            } else {
                $entry = CGI::td( $entry );
            }
            $entry ||= '&nbsp;';
            push @cols, $entry;
        }
        if ( $jump eq "name" ) {
            push @anchors, CGI::a( { name=>$object->getAnchor() } );
        }
        push @rows, \@cols;
    }

    return $this->_generateHTMLTable( \@rows, \@anchors );
}

# PRIVATE generate an HTML table from a 2D-array of rows and
# a, optional list of anchors, one for each row. The anchors
# are more useful if the table is oriented as rows.
sub _generateHTMLTable {
    my ( $this, $rows, $anchors ) = @_;
    my $text = CGI::start_table( { border=>$border } )."\n";
    my $i;

    if ( $this->{ORIENTATION} eq "rows" ) {
        if ( defined( $anchors ) ) {
            foreach $i ( @$anchors ) {
                $text .= $i;
            }
        }
        for ( $i = 0; $i <= $#{$this->{HEADINGS}}; $i++ ) {
            my $head = ${$this->{HEADINGS}}[$i];
            my $row = CGI::th({ bgcolor=>$hdrcol }, $head )."\n";
            foreach my $col ( @$rows ) {
                my $datum = @$col[$i];
                $text .= $datum."\n";
            }
            $text .= CGI::Tr( $row )."\n";
        }
    } else {
        my $row = '';
        foreach $i ( @{$this->{HEADINGS}} ) {
            $row .= CGI::th($i)."\n";
        }
        $text .= CGI::Tr({bgcolor=>$hdrcol}, $row)."\n";
        foreach my $r ( @$rows ) {
            if ( defined( $anchors ) ) {
                my $a = shift( @$anchors );
                $text .= $a if ( defined( $a ) );
            }
            $text .= CGI::Tr({ valign=>'top' }, join( '', @$r) );
        }
    }
    $text .= CGI::end_table();

    return $text;
}

# PUBLIC format a list of actions into a table
sub formatStringTable {
    my $this = shift;
    my $data = shift;
    my $text = "";
    foreach my $row ( @$data ) {
        my $horzrow = $this->_formatAsString( $row, @_ );
        $text .= $horzrow."\n";
    }
    return $text;
}

# PUBLIC Get the changes in the selected change fields between
# the old object and the new object.
sub formatChangesAsHTML {
    my ( $this, $old, $new ) = @_;
    my $tbl = "";
    foreach my $field ( @{$this->{CHANGEFIELDS}} ) {
        my $row = '';
        if ( defined( $old->{$field} ) && defined( $new->{$field} )) {
            my ( $oldval, $c ) = _expandVar( $old, $field );
            my ( $newval, $d ) = _expandVar( $new, $field );
            if ( $oldval ne $newval ) {
                $row = CGI::td($field).CGI::td($oldval).CGI::td($newval);
            }
        } elsif ( defined( $old->{$field} ) ) {
            my ( $oldval, $c ) = _expandVar( $old, $field );
            $row = CGI::td($field).CGI::td($oldval).CGI::td(' *removed* ');
        } elsif ( defined( $new->{$field} )) {
            my ( $newval, $c ) = _expandVar( $new, $field );
            $row = CGI::td($field).CGI::td(' *missing* ').CGI::td($newval);
        }
        $tbl .= CGI::Tr( $row )."\n" if $row;
    }
    if ( $tbl ne "" ) {
        return CGI::start_table({ border=>$border }).
          CGI::Tr({bgcolor=>$badcol},
                  CGI::th('Attribute').
                  CGI::th('Old').
                  CGI::th('New').$tbl.CGI::end_table()."\n");
    }
    return $tbl;
}

# PUBLIC Get the changes in the change fields between the old object and
# the new object.
sub formatChangesAsString {
    my ( $this, $old, $new ) = @_;
    my $tbl = "";
    foreach my $field ( @{$this->{CHANGEFIELDS}} ) {
        if ( defined( $old->{$field} ) && defined( $new->{$field} ) ) {
            my ( $oldval, $c ) = _expandVar( $old, $field );
            my ( $newval, $d ) = _expandVar( $new, $field );
            if ( $oldval ne $newval ) {
                $tbl .= "\t- Attribute \"$field\" changed, was \"$oldval\", now \"$newval\"\n";
            }
        } elsif ( defined( $old->{$field} ) ) {
            my ( $oldval, $c ) = _expandVar( $old, $field );
            $tbl .= "\t- Attribute \"$field\" was \"$oldval\" now removed\n";
        } elsif ( defined( $new->{$field} ) ) {
            my ( $newval, $c ) = _expandVar( $new, $field );
            $tbl .= "\t- Attribute \"$field\" added with value \"$newval\"\n";
        }
    }
    return $tbl;
}

# Format the editable fields of $object for editing.
sub formatEditableFields {
    my ( $this, $object, $expanded ) = @_;

    # for each of the fields in EDITFORMAT, create an appropriate
    # parameter.
    my @fields;
    foreach my $col ( @{$this->{FIELDS}} ) {
        my $entry = $col;
        $entry =~ s/\$(\w+\b)(\(\))?/&_expandEditField( $this, $object, $1, $expanded )/geos;
        $entry = CGI::td( $entry );
        push @fields, $entry;
    }
    my @rows;
    push @rows, \@fields;

    return $this->_generateHTMLTable( \@rows );
}

# PRIVATE STATIC fill in variable expansions. If any of the expansions
# returns a non-zero color, then fill in the passed-by-reference color
# variable $col with the value returned.
sub _expandEditField {
    my ( $this, $object, $var, $expanded ) = @_;

    # record the fact that we expanded this field, so it doesn't get
    # generated as a hidden
    $expanded->{$var} = 1;

    if ( $var eq "dollar") {
        return "\$";
    } elsif ($var eq "nop") {
        return "";
    } elsif ($var eq "n") {
        return CGI::br();
    } elsif ($var eq "percnt") {
        return "%";
    } elsif ($var eq "quot") {
        return "\"";
    }

    return $this->_formatFieldForEdit( $object, $var );
}

# PRIVATE format the given attribute for edit, using values given
# in 
sub _formatFieldForEdit {
    my ( $this, $object, $attrname ) = @_;
    my $type = $object->getType( $attrname );
    return $attrname unless ( defined( $type ));
    my $size = $type->{size};
    if ( $type->{type} eq 'select' ) {
        my $fields = '';
        foreach my $option ( @{$type->{values}} ) {
            my @extras = ();
            if ( defined( $object->{$attrname} ) &&
                 $object->{$attrname} eq $option ) {
                push( @extras, selected => "selected" );
            }
            $fields .= CGI::option({ value=>$option, @extras }, $option)."\n";
        }
        return CGI::Select( { name=>$attrname, size=>$size }, $fields )."\n";
    } elsif ( $type->{type} !~ m/noload/ ) {
        my ( $val, $c ) = _expandVar( $object, $attrname );
        my $content = '';
        my @extras = ();
        if ( $type->{type} eq 'date' ) {
            $val =~ s/ \(LATE\)//o;
        }
        if ( $type->{type} eq 'date') {
            # make sure JSCalendar is there
            eval 'use TWiki::Contrib::JSCalendarContrib';
            if ( $@ ) {
                print STDERR "WARNING: JSCalendar not installed: $@\n";
            } else {
                @extras = ( id => "date_$attrname" );
                $content = CGI::button
                  ( { type=>'reset',
                      onclick=>"return showCalendar('date_$attrname','\%e \%B \%Y')" },
                    CGI::img({ src=> TWiki::Func::getPubUrlPath() . '/' .
                               TWiki::Func::getTwikiWebname() .
                               '/JSCalendarContrib/img.gif',
                               alt=>'Calendar'} ) );
            }
        }
        return CGI::textfield( { name => $attrname,
                                 value => $val,
                                 size => $size,
                                 @extras } ).
                                   $content;
    }
    return $attrname;
}

# PUBLIC generate and return a hidden editable field
sub formatHidden {
    my ( $this, $object, $attrname ) = @_;

    my ( $v, $c ) = _expandVar( $object, $attrname, 0 );
    if ( defined( $v ) ) {
        return CGI::hidden( { name=>$attrname, value=>$v } )."\n";
    }
    return "";
}

1;
