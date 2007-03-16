# See bottom of file for copyright and pod
package TWiki::Plugins::EditRowPlugin::Table;

use strict;

use TWiki::Func;
use TWiki::Plugins::EditRowPlugin::TableRow;
use TWiki::Plugins::EditRowPlugin::TableCell;

sub parseTables {
    #my $text, $topic, $web = @_
    my $active_table = undef;
    my @tables;
    my $nTables = 0;
    my $disable = 0;

    foreach my $line (split(/\r?\n/, $_[0])) {
        if ($line =~ /<(verbatim|literal)>/) {
            $disable++;
        }
        if ($line =~ m#</(verbatim|literal)>#) {
            $disable-- if $disable;
        }
        if (!$disable && $line =~ /%EDITTABLE{([^\n]*)}%/) {
            my $attrs = new TWiki::Attrs($1);

            if ($attrs->{include}) {
                my( $iw, $it ) = TWiki::Func::normalizeWebTopicName(
                    $_[2], $attrs->{include});
                # This check is missing from EditTablePlugin
                unless( TWiki::Func::topicExists($iw, $it)) {
                    $line = CGI::span(
                        {class=>'twikiAlert'},
                        "Could not find format topic $attrs->{include}");
                }
                my ($meta, $text) = TWiki::Func::readTopic($iw, $it);
                $text =~ m/%EDITTABLE{([^\n]*)}%/s;
                my $params = $1;
                if ($params) {
                    unless ($iw eq $_[2] && $it eq $_[1]) {
                        $params = TWiki::Func::expandCommonVariables(
                            $params, $iw, $it);
                    }
                    $attrs = new TWiki::Attrs($params);
                }
            }
            $active_table =
              new TWiki::Plugins::EditRowPlugin::Table(
                  ++$nTables, $line, $attrs, $_[2], $_[1]);
            push(@tables, $active_table);
            next;
        }

        if ($active_table && $line =~ s/^\s*\|//) {
            $line =~ s/\|\s*$//;
            my $row = new TWiki::Plugins::EditRowPlugin::TableRow(
                $active_table, scalar(@{$active_table->{rows}}) + 1,
                split(/\s*\|\s*/, $line));
            push(@{$active_table->{rows}}, $row);
            next;
        }

        $active_table = undef;
        push(@tables, $line);
    }
    return \@tables;
}

sub new {
    my ($class, $tno, $spec, $attrs, $web, $topic) = @_;

    my $this = bless({}, $class);
    $this->{number} = $tno;
    $this->{spec} = $spec;
    $this->{rows} = [];
    $this->{attrs} = $attrs;
    $this->{topic} = $topic;
    $this->{web} = $web;

    if ($attrs->{format}) {
        $this->{colTypes} = $this->_parseFormat($attrs->{format});
    } else {
        $this->{colTypes} = [];
    }

    return $this;
}

sub finish {
    my $this = shift;
    foreach my $row (@{$this->{rows}}) {
        $row->finish();
    }
}

sub stringify {
    my $this = shift;
    my $s = "$this->{spec}\n";
    foreach my $row (@{$this->{rows}}) {
        $s .= $row->stringify()."\n";
    }
    return $s;
}

sub renderForEdit {
    my ($this, $activeRow) = @_;
    my @out;
    my $n = 1;
    foreach my $row (@{$this->{rows}}) {
        if ($n++ == $activeRow) {
            push(@out, $row->renderForEdit($this->{colTypes}));
        } else {
            push(@out, $row->renderForDisplay($this->{colTypes}));
        }
    }
    return join("\n", @out);
}

sub renderForDisplay {
    my $this = shift;
    my @out;
    foreach my $row (@{$this->{rows}}) {
        push(@out, $row->renderForDisplay($this->{colTypes}));
    }
    return join("\n", @out);
}

sub changeRow {
    my ($this, $urps) = @_;
    my $arow = $this->{rows}->[$urps->{active_row} - 1];
    foreach my $c (@{$arow->{cols}}) {
        my $cellName = "cell_$this->{number}_$arow->{number}_$c->{number}";
        my $cv = $urps->{$cellName} || '';
        $c->{text} = $cv;
    }
    return $this->stringify();
}

sub addRow {
    my ($this, $urps) = @_;
    my @cols;
    my $arow = $this->{rows}->[$urps->{active_row} - 1];
    for (my $i = 1; $i <= scalar(@{$arow->{cols}}); $i++) {
        my $cellName = "cell_$this->{number}_$urps->{active_row}_$i";
        push(@cols, $urps->{$cellName} || '');
    }
    my $newRow = new TWiki::Plugins::EditRowPlugin::TableRow(
        $this, $urps->{active_row}, @cols);
    splice(@{$this->{rows}}, $urps->{active_row}, 0, $newRow);

    return $this->stringify();
}

sub deleteRow {
    my ($this, $urps) = @_;
    splice(@{$this->{rows}}, $urps->{active_row} - 1, 1);
    return $this->stringify();
}

sub cancelRow {
    my ($this, $urps) = @_;
    return $this->stringify();
}

# Private method that parses a column type specification
sub _parseFormat {
    my ($this, $format) = @_;
    my @cols;

    $format =~ s/^\s*\|//;
    $format =~ s/\|\s*$//;

    $format =~ s/\$nop(\(\))?//gs;
    $format =~ s/\$quot(\(\))?/\"/gs;
    $format =~ s/\$percnt(\(\))?/\%/gs;
    $format =~ s/\$dollar(\(\))?/\$/gs;
    $format =~ s/<nop>//gos;
    $format = TWiki::Func::expandCommonVariables(
        $format, $this->{topic}, $this->{web});

    foreach my $column (split ( /\|/, $format ))  {
        my ($type, $size, @values) =
          map { s/^\s*(.*?)\s*$/$1/; $_; } split(/,/, $column);

        $type ||= 'text';
        $type = lc $type;

        $size ||= 0;
        $size =~ s/[^\w.]//g;

        unless( $size ) {
            if( $type eq 'text' ) {
                $size = 20;
            } elsif( $type eq 'textarea' ) {
                $size = '40x5';
            } else {
                $size = 1;
            }
        }

        push(@cols,
             {
                 type => $type,
                 size => $size,
                 values => \@values,
             });
    }

    return \@cols;
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

This is an object that represents a table.

=pod

---+ package TWiki::Plugins::EditRowPlugin::Table
Representation of an editable table

=cut

=pod

---++ parseTables($text, $topic, $web) -> \@list
Static function to extract a topic into a list of lines and embedded table definitions.
Each table definition is an object of type EditTable, and contains
a set of attrs (read from the %EDITTABLE) and a list of rows. You can spot the tables
in the list by doing:
if (ref($line) eq 'TWiki::Plugins::EditRowPlugin::Table') {

---++ new($tno, $attrs, $web, $topic)
Constructor
   * $tno = table number (sequence in data, usually) (start at 1)
   * $attrs - TWiki::Attrs of the relevant %EDITTABLE
   * $web - the web
   * $topic - the topic

---++ finish()
Must be called to dispose of a Table object. This method disconnects internal pointers that would
otherwise make a Table and its rows and cells self-referential.

---++ stringify()
Generate a TML representation of the table

---++ renderForEdit($activeRow) -> $text
Render the table for editing. Standard TML is used to construct the table.
   $activeRow - the number of the row being edited

---++ renderForDisplay() -> $text
Render the table for display. Standard TML is used to construct the table.

---++ changeRow(\%urps)
Commit changes from the query into the table.
   * $urps - url parameters, usually the result of $query->Vars()

---++ addRow(\%urps)
Add a row after the active row containing the data from the query
   * $urps - hash of parameters, usually the result of $query->Vars()
      * =active_row= - the row to add after
      * 

---++ deleteRow(\%urps)
Delete the current row, as defined by active_row in $urps
   * $urps - url parameters, usualy the result of $query->Vars()

=cut

