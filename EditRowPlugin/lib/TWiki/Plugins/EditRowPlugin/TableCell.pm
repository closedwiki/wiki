# See bottom of file for copyright
package TWiki::Plugins::EditRowPlugin::TableCell;

use strict;

use TWiki::Func;

# Default format if no other format is defined for a cell
my $defCol ||= { type => 'text', size => 20, values => [] };

sub new {
    my ($class, $row, $text, $number) = @_;
    my $this = bless({}, $class);
    $this->{row} = $row;
    $this->{number} = $number;
    $text =~ s/^(\s*)//;
    $this->{precruft} = $1 || '';
    $text =~ s/(\s*)$//;
    $this->{postcruft} = $1 || '';
    if ($text =~ s/^\*(.*)\*$/$1/) {
        $this->{precruft} .= '*';
        $this->{postcruft} = '*'.$this->{postcruft};
        $this->{isHeader} = 1;
    }
    $this->{text} = $text;
    return $this;
}

sub finish {
    my $this = shift;
    $this->{row} = undef;
}

sub stringify {
    my $this = shift;

    return $this->{precruft}.$this->{text}.$this->{postcruft};
}

# Generate a sort command suitable for sorting the table columns
sub _getCell {
    my ($this, $isHeader) = @_;

    my $text = $this->{text};
    if ($isHeader) {
        $text = CGI::span(
            { class => 'erpSort',
              onclick => "javascript: return sortTable(this, $this->{number}, false);",
          }, $text);
    }
    return $this->{precruft}.$text.$this->{postcruft};
}

sub renderForDisplay {
    my ($this, $colDefs, $isHeader) = @_;
    my $colDef = $colDefs->[$this->{number} - 1] || $defCol;

    if ($colDef->{type} eq 'row') {
        $this->{text} = $this->{row}->{index};
    }
    return $this->_getCell($isHeader);
}

sub renderForEdit {
    my ($this, $colDefs, $isHeader) = @_;
    my $colDef = $colDefs->[$this->{number} - 1] || $defCol;

    my $expandedValue = TWiki::Func::expandCommonVariables(
        $this->{text} || '');
    $expandedValue =~ s/^\s*(.*?)\s*$/$1/;

    my $text = '';
    my $cellName = 'erp_cell_'.$this->{row}->{table}->{number}.'_'.
      $this->{row}->{number}.'_'.$this->{number};

    if( $colDef->{type} eq 'select' ) {

        $text = "<select name='$cellName' size='$colDef->{size}'>";
        foreach my $option ( @{$colDef->{values}} ) {
            my $expandedOption =
              TWiki::Func::expandCommonVariables($option);
            $expandedOption =~ s/^\s*(.*?)\s*$/$1/;
            my %opts;
            if ($expandedOption eq $expandedValue) {
                $opts{selected} = 'selected';
            }
            $text .= CGI::option(\%opts, $option);
        }
        $text .= "</select>";

    } elsif( $colDef->{type} =~ /^(radio|checkbox)$/ ) {

        $expandedValue = ",$expandedValue,";
        my $i = 0;
        foreach my $option (@{$colDef->{values}}) {
            my $expandedOption =
              TWiki::Func::expandCommonVariables($option);
            $expandedOption =~ s/^\s*(.*?)\s*$/$1/;
            $expandedOption =~ s/(\W)/\\$1/g;
            my %opts = (
                type => $colDef->{type},
                name => $cellName,
                value => $option,
               );
            $opts{checked} = 'checked'
              if ($expandedValue =~ /,$expandedOption,/);
            $text .= CGI::input(\%opts);
            $text .= " $option ";
            if( $colDef->{size} > 1 ) {
                if ($i % $colDef->{size}) {
                    $text .= '<br />';
                }
            }
            $i++;
        }

    } elsif( $colDef->{type} eq 'row' ) {

        $text = $this->{row}->{index};

    } elsif( $colDef->{type} eq 'textarea' ) {

        my ($rows, $cols) = split( /x/i, $colDef->{size} );
        $rows =~ s/[^\d]//;
        $cols =~ s/[^\d]//;
        $rows = 3 if $rows < 1;
        $cols = 30 if $cols < 1;

        $text = CGI::textarea(
            -rows => $rows,
            -columns => $cols,
            -name => $cellName,
            -default => $this->{text});

    } elsif( $colDef->{type} eq 'date' ) {

        eval 'use TWiki::Contrib::JSCalendarContrib';

        if ($@) {
            # Calendars not available
            $text = CGI::textfield(-name => $cellName, -size => 10);
        } else {
            $text = TWiki::Contrib::JSCalendarContrib::renderDateForEdit(
                $cellName, $this->{text}, $colDef->{values}->[0]);
        }

    } else { #  if( $colDef->{type} =~ /^(text|label)$/)

        my $val = $this->{text};
        $text = CGI::textfield({
            name => $cellName,
            size => $colDef->{size},
            value => $val });

    }
    return $this->{precruft}.TWiki::Plugins::EditRowPlugin::defend($text)
      .$this->{postcruft};
}

1;
__END__

Author: Crawford Currie http://c-dot.co.uk

Copyright (C) 2007 WindRiver Inc. and TWiki Contributors.
All Rights Reserved. TWiki Contributors are listed in the
AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

Do not remove this copyright notice.

This is an object that represents a single cell in a table.

=pod

---++ new(\$row, $cno)
Constructor
   * \$row - pointer to the row
   * $cno - what cell number this is (start at 1)

---++ finish()
Must be called to dispose of the object. This method disconnects internal pointers that would
otherwise make a Table and its rows and cells self-referential.

---++ stringify()
Generate a TML representation of the cell

---++ renderForEdit() -> $text
Render the cell for editing. Standard TML is used to construct the table.

---++ renderForDisplay() -> $text
Render the cell for display. Standard TML is used to construct the table.

=cut
