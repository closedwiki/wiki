# See bottom of file for copyright
package TWiki::Plugins::EditRowPlugin::TableRow;

use strict;

use TWiki::Func;
use TWiki::Plugins::EditRowPlugin::TableCell;

sub new {
    my ($class, $table, $number, @cols) = @_;
    my $this = bless({}, $class);
    $this->{table} = $table;
    $this->{number} = $number;

    # pad out the cols to the width of the format
    my $ncols = scalar(@{$table->{colTypes}});
    while (scalar(@cols) < $ncols) {
        push(@cols, '');
    }
    $this->{cols} = [];
    $this->set(@cols);
    return $this;
}

# break cycles to ensure we release back to garbage
sub finish {
    my $this = shift;
    $this->{table} = undef;
    foreach my $cell (@{$this->{cols}}) {
        $cell->finish();
    }
    undef($this->{cols});
}

# Set the columns in the row. Adapts to widen or narrow the row as required.
sub set {
    my ($this, @cols) = @_;
    while (scalar(@{$this->{cols}}) > scalar(@cols)) {
        pop(@{$this->{cols}})->finish();
    }
    my $n = 0;
    foreach my $val (@cols) {
        if ($n < scalar(@{$this->{cols}})) {
            $this->{cols}->[$n]->{text} = $val;
        } else {
            push(@{$this->{cols}},
                 new TWiki::Plugins::EditRowPlugin::TableCell(
                     $this, $val, $n + 1));
        }
        $n++;
    }
}

sub stringify {
    my $this = shift;

    return '| '.join(' | ', map { $_->stringify() } @{$this->{cols}}).' |';
}

sub renderForEdit {
    my ($this, $colDefs) = @_;

    my @out;

    # Generate the editors for each cell in the row
    my $col = 0;
    foreach my $cell (@{$this->{cols}}) {
        push(@out, $cell->renderForEdit($colDefs->[$col++]));
    }

    my $buttons =
      "<a name='erp_$this->{table}->{number}_$this->{number}'></a>";
    $buttons .=
      CGI::image_button({
          name => 'erp_save',
          value => $TWiki::Plugins::EditRowPlugin::NOISY_SAVE,
          title => $TWiki::Plugins::EditRowPlugin::NOISY_SAVE,
          src => '%PUBURLPATH%/TWiki/TWikiDocGraphics/save.gif'
         }, '');
    my $attrs = $this->{table}->{attrs};
    if (TWiki::isTrue($attrs->{quietsave})) {
        $buttons .= CGI::image_button({
          name => 'erp_quietSave',
          value => $TWiki::Plugins::EditRowPlugin::QUIET_SAVE,
          title => $TWiki::Plugins::EditRowPlugin::QUIET_SAVE,
          src => '%PUBURLPATH%/TWiki/TWikiDocGraphics/quiet.gif'
        }, '');
    }
    # add save button
    if ($attrs->{changerows}) {
        # add add row button
        $buttons .= CGI::image_button({
            name => 'erp_addRow',
            value => $TWiki::Plugins::EditRowPlugin::ADD_ROW,
            title => $TWiki::Plugins::EditRowPlugin::ADD_ROW,
            src => '%PUBURLPATH%/TWiki/TWikiDocGraphics/plus.gif'
        }, '');
        if ($attrs->{changerows} eq 'on') {
            # add delete row button
            $buttons .= CGI::image_button({
                name => 'erp_deleteRow',
                value => $TWiki::Plugins::EditRowPlugin::DELETE_ROW,
                title => $TWiki::Plugins::EditRowPlugin::DELETE_ROW,
                src => '%PUBURLPATH%/TWiki/TWikiDocGraphics/minus.gif'
            }, '');
        }
    }
    $buttons .= CGI::image_button({
        name => 'erp_cancelRow',
        value => $TWiki::Plugins::EditRowPlugin::CANCEL_ROW,
        title => $TWiki::Plugins::EditRowPlugin::CANCEL_ROW,
        src => '%PUBURLPATH%/TWiki/TWikiDocGraphics/stop.gif',
    }, '');
    unshift(@out, $buttons);

    return '| ' . join(' | ', @out) . '|';
}

sub renderForDisplay {
    my ($this, $colDefs) = @_;
    my @out;
    my $attrs = $this->{table}->{attrs};
    if ($this->{number} == 1 &&
          (!defined($attrs->{headerislabel}) ||
             TWiki::isTrue($attrs->{headerislabel}))) {
        @out = map { $_->{text} } @{$this->{cols}};
        unshift(@out, '');
    } else {
        my $col = 0;
        foreach (@{$this->{cols}}) {
            push(@out, $_->renderForDisplay($colDefs->[$col++]));
        }
        my $id = "$this->{table}->{number}_$this->{number}";
        my $url;
        if ($TWiki::Plugins::VERSION < 1.11) {
            $url = TWiki::Func::getScriptUrl(
                $this->{table}->{web}, $this->{table}->{topic}, 'view').
                "?erp_active_table=$this->{table}->{number}".
                ";erp_active_row=$this->{number}#erp_$id";
        } else {
            $url = TWiki::Func::getScriptUrl(
                $this->{table}->{web}, $this->{table}->{topic}, 'view',
                erp_active_table => $this->{table}->{number},
                erp_active_row => $this->{number},
                '#' => "erp_$id");
        }
        my $button =
          CGI::img({
              -name => "erp_edit_$id",
              -border => 0,
              -src => '%PUBURLPATH%/TWiki/TWikiDocGraphics/edittopic.gif'
             });
        unshift(
            @out,
            "<a name='erp_$this->{table}->{number}_$this->{number}'></a>".
              "<a href='$url'>" . $button . "</a>");
    }
    return '| '.join(' | ', @out). ' |';
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

This is an object that represents a single row in a table.

=pod

---++ new(\$table, $rno)
Constructor
   * \$table - pointer to the table
   * $rno - what row number this is (start at 1)

---++ finish()
Must be called to dispose of the object. This method disconnects internal pointers that would
otherwise make a Table and its rows and cells self-referential.

---++ stringify()
Generate a TML representation of the row

---++ renderForEdit() -> $text
Render the row for editing. Standard TML is used to construct the table.

---++ renderForDisplay() -> $text
Render the row for display. Standard TML is used to construct the table.

=cut
