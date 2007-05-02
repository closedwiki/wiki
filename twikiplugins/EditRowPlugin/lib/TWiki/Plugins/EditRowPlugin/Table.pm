# See bottom of file for copyright and pod
package TWiki::Plugins::EditRowPlugin::Table;

use strict;
use Assert;

use TWiki::Func;
use TWiki::Plugins::EditRowPlugin::TableRow;
use TWiki::Plugins::EditRowPlugin::TableCell;

use vars qw($ADD_ROW $DELETE_ROW $QUIET_SAVE $NOISY_SAVE $EDIT_ROW $CANCEL_ROW $UP_ROW $DOWN_ROW);
$ADD_ROW    = 'Add new row after this row / at the end';
$DELETE_ROW = 'Delete this row / last row';
$QUIET_SAVE = 'Quiet Save';
$NOISY_SAVE = 'Save';
$EDIT_ROW   = 'Edit';
$CANCEL_ROW = 'Cancel';
$UP_ROW     = 'Move this row up';
$DOWN_ROW   = 'Move this row down';

# Static method that parses tables out of a block of text
# Returns an array of lines, with those lines that represent editable
# tables plucked out and replaced with references to table objects
sub parseTables {
    my ($text, $topic, $web, $meta, $urps) = @_;
    my $active_table = undef;
    my @tables;
    my $nTables = 0;
    my $disable = 0;
    my $openRow = undef;

    foreach my $line (split(/\r?\n/, $text)) {
        if ($line =~ /<(verbatim|literal)>/) {
            $disable++;
        }
        if ($line =~ m#</(verbatim|literal)>#) {
            $disable-- if $disable;
        }
        if (defined $openRow) {
            $line = "$openRow$line";
            $openRow = undef;
        }
        if (!$disable && $line =~ /%EDITTABLE{([^\n]*)}%/ ) {
            # Editable table
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
                my $params = '';
                if ($text =~ m/%EDITTABLE{([^\n]*)}%/s) {
                    $params = $1;
                }
                if ($params) {
                    $params = TWiki::Func::expandCommonVariables(
                        $params, $iw, $it);
                }
                $attrs = new TWiki::Attrs($params);
            }
            # is there a format in the query? if there is,
            # override the format we just parsed
            if ($urps) {
                my $format = $urps->{"erp_${nTables}_format"};
                if (defined($format)) {
                    # undo the encoding
                    $format =~ s/-([a-z\d][a-z\d])/chr(hex($1))/gie;
                    $attrs->{format} = $format;
                }
                if (defined($urps->{"erp_${nTables}_headerrows"})) {
                    $attrs->{headerrows} =
                      $urps->{"erp_${nTables}_headerrows"};
                }
                if (defined($urps->{"erp_${nTables}_footerrows"})) {
                    $attrs->{footerrows} =
                      $urps->{"erp_${nTables}_footerrows"};
                }
            }
            $active_table =
              new TWiki::Plugins::EditRowPlugin::Table(
                  $nTables, 1, $line, $attrs, $_[2], $_[1]);
            push(@tables, $active_table);
            next;
        }
        elsif (!$disable && $line =~ /^\s*\|/) {
            if ($line =~ s/\\$//) {
                # Continuation
                $openRow = $line;
                next;
            }
            my $precruft = '';
            $precruft = $1 if $line =~ s/^(\s*\|)//;
            my $postcruft = '';
            $postcruft = $1 if $line =~ s/(\|\s*)$//;
            if (!$active_table) {
                # Uneditable table
                $nTables++;
                my $attrs => new TWiki::Attrs('');
                $active_table =
                  new TWiki::Plugins::EditRowPlugin::Table(
                      $nTables, 0, $line, $attrs, $_[2], $_[1]);
                push(@tables, $active_table);
            }
            # Note use of -1 on the split so we don't lose empty columns
            my @cols = split(/\|/, $line, -1);
            my $row = new TWiki::Plugins::EditRowPlugin::TableRow(
                $active_table, scalar(@{$active_table->{rows}}) + 1,
                $precruft, $postcruft,
                \@cols);
            push(@{$active_table->{rows}}, $row);
            next;
        }

        $active_table = undef;
        push(@tables, $line);
    }
    return \@tables;
}

sub new {
    my ($class, $tno, $editable, $spec, $attrs, $web, $topic) = @_;

    my $this = bless({}, $class);
    $this->{editable} = $editable;
    $this->{number} = $tno;
    $this->{spec} = $spec;
    $this->{rows} = [];
    $this->{topic} = $topic;
    $this->{web} = $web;

    if ($attrs->{format}) {
        $this->{colTypes} = $this->_parseFormat($attrs->{format});
    } else {
        $this->{colTypes} = [];
    }

    # if headerislabel true but no headerrows, set headerrows = 1
    if ($attrs->{headerislabel} && !defined($attrs->{headerrows})) {
        $attrs->{headerrows} = TWiki::isTrue($attrs->{headerislabel}) ? 1 : 0;
    }

    $attrs->{headerrows} ||= 0;
    $attrs->{footerrows} ||= 0;

    $this->{attrs} = $attrs;

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

    my $s = '';
    if ($this->{editable}) {
        $s .= "$this->{spec}\n";
    }
    foreach my $row (@{$this->{rows}}) {
        $s .= $row->stringify()."\n";
    }
    return $s;
}

# Run after all rows have been added to set header and footer rows
sub _finalise {
    my $this = shift;
    my $heads = $this->{attrs}->{headerrows};

    while ($heads > 0) {
        $this->{rows}->[--$heads]->{isHeader} = 1;
    }
    my $tails = $this->{attrs}->{footerrows};
    while ($tails > 0) {
        $this->{rows}->[-$tails]->{isFooter} = 1;
        $tails--;
    }
    # Assign row index numbers to body cells
    my $index = 0;
    foreach my $row (@{$this->{rows}}) {
        unless ($row->{isHeader} || $row->{isFooter}) {
            $row->{index} = $index++;
        }
    }
}

sub getLabelRow() {
    my $this = shift;

    my $labelRow;
    foreach my $row (@{$this->{rows}}) {
        if ($row->{isHeader}) {
            $labelRow = $row;
        } else {
            # the last header row is always taken as the label row
            last;
        }
    }
    return $labelRow;
}

sub renderForEdit {
    my ($this, $activeRow) = @_;

    if (!$this->{editable}) {
        return $this->renderForDisplay(0);
    }

    $this->_finalise();

    my $wholeTable = ($activeRow <= 0);
    my @out = ( "<a name='erp_$this->{number}'></a>" );
    my $orientation = $this->{attrs}->{orientrowedit} || 'horizontal';

    # Disallow vertical display for whole table edits
    $orientation = 'horizontal' if $wholeTable;

    # no special treatment for the first row unless requested
    my $attrs = $this->{attrs};

    my $format = $attrs->{format} || '';
    # SMELL: Have to double-encode the format param to defend it
    # against the rest of TWiki. We use the escape char '-' as it
    # isn't used by TWiki.
    $format =~ s/([][@\s%!:-])/sprintf('-%02x',ord($1))/ge;
    # it will get encoded again as a URL param
    push(@out, CGI::hidden("erp_$this->{number}_format", $format));
    if ($attrs->{headerrows}) {
        push(@out, CGI::hidden("erp_$this->{number}_headerrows",
                               $attrs->{headerrows}));
    }
    if ($attrs->{footerrows}) {
        push(@out, CGI::hidden("erp_$this->{number}_footerrows",
                               $attrs->{footerrows}));
    }

    my $n = 0; # displayed row index
    my $r = 0; # real row index
    foreach my $row (@{$this->{rows}}) {
        $n++ unless ($row->{isHeader} || $row->{isFooter});
        if (++$r == $activeRow ||
              $wholeTable && !$row->{isHeader} && !$row->{isFooter}) {
            push(@out, $row->renderForEdit(
                $this->{colTypes}, !$wholeTable, $orientation));
        } else {
            push(@out, $row->renderForDisplay(
                $this->{colTypes}, !$wholeTable));
        }
    }
    if ($wholeTable) {
        push(@out, $this->generateEditButtons(0, 0));
    }
    return join("\n", @out);
}

sub renderForDisplay {
    my ($this, $showControls) = @_;
    my @out;

    $showControls = 0 unless $this->{editable};

    $this->_finalise();

    my $attrs = $this->{attrs};

    my $n = 0;
    foreach my $row (@{$this->{rows}}) {
        $n++ unless ($row->{isHeader} || $row->{isFooter});
        push(@out, $row->renderForDisplay(
            $this->{colTypes}, $showControls));
    }

    my $button =
      CGI::img({
          -name => "erp_edit_$this->{number}",
          -border => 0,
          -src => '%PUBURLPATH%/TWiki/EditRowPlugin/edittable.gif'
         });

    my $script = 'view';
    unless ($showControls || TWiki::Func::getContext()->{authenticated}) {
        # A  bit of a hack. If the user isn't logged in, then show the
        # table edit button anyway, but redirect them to viewauth to force
        # login.
        $script = 'viewauth';
        $showControls = $this->{editable};
    }

    if ($showControls) {
        my $url;
        if ($TWiki::Plugins::VERSION < 1.11) {
            $url = TWiki::Func::getScriptUrl(
                $this->{web}, $this->{topic}, $script)
              ."?erp_active_table=$this->{number}"
                .";erp_active_row=-1"
                  ."#erp_$this->{number}";
        } else {
            $url = TWiki::Func::getScriptUrl(
                $this->{web}, $this->{topic}, $script,
                erp_active_table => $this->{number},
                erp_active_row => -1,
                '#' => "erp_$this->{number}");
        }

        push(@out,
             "<a name='erp_$this->{number}'></a>".
               "<a href='$url'>" . $button . '</a><br />');
    }

    return join("\n", @out);
}

# Get the cols for the given row, padding out with empty cols if
# the row is shorter than the type def for the table.
sub _getCols {
    my ($this, $urps, $row) = @_;
    my $attrs = $this->{attrs};
    my $firstRow = 1;
    $firstRow = 0 unless TWiki::isTrue($attrs->{headerislabel});
    my $n = $firstRow ? 0 : 1;
    my $count = scalar(@{$this->{rows}->[$row - 1]->{cols}});
    my $defs = scalar(@{$this->{colTypes}});
    $count = $defs if $defs > $count;
    my @cols;
    for (my $i = 1; $i <= $count; $i++) {
        my $colDef = $this->{colTypes}->[$i - 1];
        my $cellName = "erp_cell_$this->{number}_${row}_$i";
        # Force numbering if this is an auto-numbered column
        if ($colDef->{type} eq 'row') {
            $urps->{$cellName} = $row - $firstRow;
        }
        # CGI returns multi-values separated by \0. Replace with
        # the TWiki convention, comma
        $urps->{$cellName} =~ s/\0/, /g;
        push(@cols, $urps->{$cellName} || '');
    }
    return \@cols;
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
            # Skip the header row
            if ($i == 1 && $this->{attrs}->{headerislabel}) {
                next;
            }
            $this->{rows}->[$i - 1]->set($this->_getCols($urps, $i));
        }
    }
}

# Action on move up; save and shift row
sub moveUp {
    my ($this, $urps) = @_;
    change($this, $urps);
    my $row = $urps->{erp_active_row};
    my $tmp = $this->{rows}->[$row - 1];
    $this->{rows}->[$row - 1] = $this->{rows}->[$row - 2];
    $this->{rows}->[$row - 2] = $tmp;
    $urps->{erp_active_row}--;
}

# Action on move down; save and shift row
sub moveDown {
    my ($this, $urps) = @_;
    change($this, $urps);
    my $row = $urps->{erp_active_row};
    my $tmp = $this->{rows}->[$row - 1];
    $this->{rows}->[$row - 1] = $this->{rows}->[$row];
    $this->{rows}->[$row] = $tmp;
    $urps->{erp_active_row}++;
}

# Action on row added
sub addRow {
    my ($this, $urps) = @_;
    my @cols;
    my $row = $urps->{erp_active_row};
    if ($row > 0) {
        # Clone of a specific row
        my $newRow = new TWiki::Plugins::EditRowPlugin::TableRow(
            $this, $row, '|', '|', $this->_getCols($urps, $row));
        splice(@{$this->{rows}}, $row, 0, $newRow);
        # renumber lower rows
        for (my $i = $row + 1; $i < scalar(@{$this->{rows}}); $i++) {
            $this->{rows}->[$i]->{number}++;
        }
        $urps->{erp_active_row}++;

    } else {
        # new, empty last row
        my @cols = map { '' } @{$this->{colTypes}};
        my $newRow = new TWiki::Plugins::EditRowPlugin::TableRow(
            $this, scalar(@{$this->{rows}}), '|', '|', \@cols);
        push(@{$this->{rows}}, $newRow);
        $urps->{erp_active_row} = scalar(@{$this->{rows}});
    }
}

# Action on row deleted
sub deleteRow {
    my ($this, $urps) = @_;
    my $row = $urps->{erp_active_row};
    my @dead;
    if ($row > 0) {
        @dead = splice(@{$this->{rows}}, $urps->{erp_active_row} - 1, 1);
        $urps->{erp_active_row}-- if $urps->{erp_active_row} >= scalar(@{$this->{rows}});
    } else {
        push(@dead, pop(@{$this->{rows}}));
    }
    map { $_->finish() } @dead;
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
    my ($this, $id, $multirow) = @_;
    my $attrs = $this->{attrs};
    my $labelled = $attrs->{headerislabel};
    my $topRow = ($id == 1);
    my $sz = scalar(@{$this->{rows}});
    my $q = defined($attrs->{quietsave}) ? $attrs->{quietsave} :
      TWiki::Func::getPreferencesValue('QUIETSAVE');
    my $changerows = defined($attrs->{changerows}) ? $attrs->{changerows} :
      TWiki::Func::getPreferencesValue('CHANGEROWS');
    my $bottomRow = ($id == $sz && !$labelled
                       || $id == $sz - 1 && $labelled);
    $id = "_$id" if $id;

    my $buttons = '';
    $buttons .=
      CGI::image_button({
          name => 'erp_save',
          value => $NOISY_SAVE,
          title => $NOISY_SAVE,
          src => '%PUBURLPATH%/TWiki/TWikiDocGraphics/save.gif'
         }, '');
    if (TWiki::isTrue($q)) {
        $buttons .= CGI::image_button({
            name => 'erp_quietSave',
            value => $QUIET_SAVE,
            title => $QUIET_SAVE,
            src => '%PUBURLPATH%/TWiki/EditRowPlugin/quiet.gif'
           }, '');
    }
    $buttons .= CGI::image_button({
        name => 'erp_cancel',
        value => $CANCEL_ROW,
        title => $CANCEL_ROW,
        src => '%PUBURLPATH%/TWiki/TWikiDocGraphics/stop.gif',
    }, '');

    if (TWiki::isTrue($changerows)) {
        $buttons .= '<br />' if $multirow;
        if ($id) {
            if (!$topRow) {
                $buttons .= CGI::image_button({
                    name => 'erp_upRow',
                    value => $UP_ROW,
                    title => $UP_ROW,
                    src => '%PUBURLPATH%/TWiki/TWikiDocGraphics/arrowup.gif'
                   }, '');
            }
            if (!$bottomRow) {
                $buttons .= CGI::image_button({
                    name => 'erp_downRow',
                    value => $DOWN_ROW,
                    title => $DOWN_ROW,
                    src => '%PUBURLPATH%/TWiki/TWikiDocGraphics/arrowdown.gif'
                   }, '');
            }
        }
        $buttons .= CGI::image_button({
            name => 'erp_addRow',
            value => $ADD_ROW,
            title => $ADD_ROW,
            src => '%PUBURLPATH%/TWiki/TWikiDocGraphics/plus.gif'
           }, '');
        if (TWiki::isTrue($changerows)) {
            $buttons .= CGI::image_button({
                name => 'erp_deleteRow',
                value => $DELETE_ROW,
                title => $DELETE_ROW,
                src => '%PUBURLPATH%/TWiki/TWikiDocGraphics/minus.gif'
               }, '');
        }
    }
    return $buttons;
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
newif (ref($line) eq 'TWiki::Plugins::EditRowPlugin::Table') {

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

