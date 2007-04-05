# See bottom of file for copyright and pod
package TWiki::Plugins::EditRowPlugin::Table;

use strict;

use TWiki::Func;
use TWiki::Plugins::EditRowPlugin::TableRow;
use TWiki::Plugins::EditRowPlugin::TableCell;

# Static method that parses tables out of a block of text
sub parseTables {
    my ($text, $topic, $web, $meta, $urps) = @_;
    my $active_table = undef;
    my @tables;
    my $nTables = 0;
    my $disable = 0;

    foreach my $line (split(/\r?\n/, $text)) {
        if ($line =~ /<(verbatim|literal)>/) {
            $disable++;
        }
        if ($line =~ m#</(verbatim|literal)>#) {
            $disable-- if $disable;
        }
        if (!$disable && $line =~ /%EDITTABLE{([^\n]*)}%/) {
            $nTables++;
            my $attrs;
            $attrs = new TWiki::Attrs($1);
            my %read = ( "$web.$topic" => 1 );
            while ($attrs->{include}) {
                my ($iw, $it) = TWiki::Func::normalizeWebTopicName(
                    $web, $attrs->{include});
                # This check is missing from EditTablePlugin
                unless (TWiki::Func::topicExists($iw, $it)) {
                    $line = CGI::span(
                        { class=>'twikiAlert' },
                        "Could not find format topic $attrs->{include}");
                }
                if ($read{"$iw.$it"}) {
                    $line = CGI::span(
                        { class=>'twikiAlert' },
                        "Recursive include of $attrs->{include}");
                }
                $read{"$iw.$it"} = 1;
                my ($meta, $text) = TWiki::Func::readTopic($iw, $it);
                $text =~ m/%EDITTABLE{([^\n]*)}%/s;
                my $params = $1 || '';
                if ($params) {
                    $params = TWiki::Func::expandCommonVariables(
                        $params, $iw, $it);
                }
                $attrs = new TWiki::Attrs($params);
            }
            # is there a format in the query? if there is,
            # override the format we just parsed
            if ($urps) {
                my $format = $urps->{erp_active_format};
                if (defined($format)) {
                    # undo the encoding
                    $format =~ s/-([a-z\d][a-z\d])/chr(hex($1))/gie;
                    $attrs->{format} = $format;
                }
            }
            $active_table =
              new TWiki::Plugins::EditRowPlugin::Table(
                  $nTables, $line, $attrs, $_[2], $_[1]);
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

    if ($attrs->{headerislabel}) {
        $attrs->{headerislabel} =~ s/^(off|false|no)$//i;
    }

    return $this;
}

# break cycles to ensure we release back to garbage
sub finish {
    my $this = shift;
    foreach my $row (@{$this->{rows}}) {
        $row->finish();
    }
    undef($this->{rows});
    undef($this->{colTypes});
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
    my $wholeTable = ($activeRow <= 0);
    my @out;
    my $n = 1;
    foreach my $row (@{$this->{rows}}) {
        if ($n == $activeRow ||
              $wholeTable && !($n == 1 && $this->{attrs}->{headerislabel})) {
            push(@out, $row->renderForEdit($this->{colTypes}, !$wholeTable));
        } else {
            push(@out, $row->renderForDisplay($this->{colTypes}));
        }
        $n++;
    }
    if ($wholeTable) {
        push(@out, $this->generateEditButtons(0));
    }
    return join("\n", @out);
}

sub renderForDisplay {
    my ($this, $displayOnly) = @_;
    my @out;

    foreach my $row (@{$this->{rows}}) {
        push(@out, $row->renderForDisplay($this->{colTypes}, $displayOnly));
    }
    unless ($displayOnly) {
        my $url;
        if ($TWiki::Plugins::VERSION < 1.11) {
            $url = TWiki::Func::getScriptUrl(
                $this->{web}, $this->{topic}, 'view')
              ."?erp_active_table=$this->{number}"
                .";erp_active_row=-1"
                  ."#erp_$this->{number}";
        } else {
            $url = TWiki::Func::getScriptUrl(
                $this->{web}, $this->{topic}, 'view',
                erp_active_table => $this->{number},
                erp_active_row => -1,
                '#' => "erp_$this->{number}");
        }
        my $button =
          CGI::img({
              -name => "erp_edit_$this->{number}",
              -border => 0,
              -src => '%PUBURLPATH%/TWiki/EditRowPlugin/edittable.gif'
             });
        push(
            @out,
            "<a name='erp_$this->{number}'></a>".
              "<a href='$url'>" . $button . "</a>");
    }
    return join("\n", @out);
}

# Get the cols for the given row, padding out with empty cols if
# the row is shorter than the type def for the table.
sub _getCols {
    my ($this, $urps, $row) = @_;
    my $count = scalar(@{$this->{rows}->[$row - 1]->{cols}});
    my $defs = scalar(@{$this->{colTypes}});
    $count = $defs if $defs > $count;
    my @cols;
    for (my $i = 1; $i <= $count; $i++) {
        my $cellName = "erp_cell_$this->{number}_${row}_$i";
        push(@cols, $urps->{$cellName} || '');
    }
    return @cols;
}

# Action on row saved
sub change {
    my ($this, $urps) = @_;
    my $row = $urps->{erp_active_row};
    if ($row > 0) {
        # Single row
        $this->{rows}->[$row - 1]->set($this->_getCols($urps, $row));
    } else {
        # Whole table
        for (my $i = 1; $i <= scalar(@{$this->{rows}}); $i++) {
            # Skip the header row if there is no data for it in the query
            next if ($i == 1 &&
                       !defined($urps->{"erp_cell_$this->{number}_${row}_1"}));
            $this->{rows}->[$i - 1]->set($this->_getCols($urps, $i));
        }
    }
}

# Action on row added
sub addRow {
    my ($this, $urps) = @_;
    my @cols;
    my $row = $urps->{erp_active_row};
    my $newRow = new TWiki::Plugins::EditRowPlugin::TableRow(
        $this, $row, $this->_getCols($urps, $row));
    splice(@{$this->{rows}}, $row, 0, $newRow);
    # renumber lower rows
    for (my $i = $row + 1; $i < scalar(@{$this->{rows}}); $i++) {
        $this->{rows}->[$i]->{number}++;
    }
}

# Action on row deleted
sub deleteRow {
    my ($this, $urps) = @_;
    splice(@{$this->{rows}}, $urps->{erp_active_row} - 1, 1);
}

# Action on edit cancelled
sub cancel {
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

sub generateEditButtons {
    my ($this, $id) = @_;
    $id = "_$id" if $id;
    my $buttons = "<a name='erp_$this->{number}$id'></a>";
    $buttons .=
      CGI::image_button({
          name => 'erp_save',
          value => $TWiki::Plugins::EditRowPlugin::NOISY_SAVE,
          title => $TWiki::Plugins::EditRowPlugin::NOISY_SAVE,
          src => '%PUBURLPATH%/TWiki/TWikiDocGraphics/save.gif'
         }, '');
    my $attrs = $this->{attrs};
    if (TWiki::isTrue($attrs->{quietsave})) {
        $buttons .= CGI::image_button({
            name => 'erp_quietSave',
            value => $TWiki::Plugins::EditRowPlugin::QUIET_SAVE,
            title => $TWiki::Plugins::EditRowPlugin::QUIET_SAVE,
            src => '%PUBURLPATH%/TWiki/EditRowPlugin/quiet.gif'
           }, '');
    }
    if ($id && $attrs->{changerows}) {
        $buttons .= CGI::image_button({
            name => 'erp_addRow',
            value => $TWiki::Plugins::EditRowPlugin::ADD_ROW,
            title => $TWiki::Plugins::EditRowPlugin::ADD_ROW,
            src => '%PUBURLPATH%/TWiki/TWikiDocGraphics/plus.gif'
           }, '');
        if ($attrs->{changerows} eq 'on') {
            $buttons .= CGI::image_button({
                name => 'erp_deleteRow',
                value => $TWiki::Plugins::EditRowPlugin::DELETE_ROW,
                title => $TWiki::Plugins::EditRowPlugin::DELETE_ROW,
                src => '%PUBURLPATH%/TWiki/TWikiDocGraphics/minus.gif'
               }, '');
        }
    }
    $buttons .= CGI::image_button({
        name => 'erp_cancel',
        value => $TWiki::Plugins::EditRowPlugin::CANCEL_ROW,
        title => $TWiki::Plugins::EditRowPlugin::CANCEL_ROW,
        src => '%PUBURLPATH%/TWiki/TWikiDocGraphics/stop.gif',
    }, '');
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

