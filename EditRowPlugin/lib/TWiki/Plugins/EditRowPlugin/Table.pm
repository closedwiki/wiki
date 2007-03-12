package TWiki::Plugins::EditRowPlugin::Table;

use strict;

use TWiki::Func;
use TWiki::Plugins::EditRowPlugin::TableRow;
use TWiki::Plugins::EditRowPlugin::TableCell;

# Extract a topic into a list of lines and embedded table definitions.
# Each table definition is an object of type EditTable, and contains
# a set of attrs (read from the %EDITTABLE) and a list of rows.
sub parseTables {
    #my $text, $topic, $web = @_
    my $active_table = undef;
    my @tables;
    my $nTables = 0;

    foreach my $line (split(/\r?\n/, $_[0])) {
        if ($line =~ /%EDITTABLE{(.*?)}%/) {
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
                $attrs = new TWiki::Attrs($1);
            }
            $active_table =
              new TWiki::Plugins::EditRowPlugin::Table(
                  ++$nTables, $attrs, $_[2], $_[1]);
            push(@tables, $active_table);
            next;
        }

        if ($active_table && $line =~ s/^\s*\|//) {
            my $row = new TWiki::Plugins::EditRowPlugin::TableRow(
                $active_table, scalar(@{$active_table->{rows}}) + 1);
            my $n = 1;
            $line =~ s/\|\s*$//;
            push(@{$row->{cols}}, map {
                new TWiki::Plugins::EditRowPlugin::TableCell($row, $_, $n++); }
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
    my ($class, $tno, $attrs, $web, $topic) = @_;

    my $this = bless({}, $class);
    $this->{number} = $tno;
    $this->{rows} = [];
    $this->{attrs} = $attrs;
    if ($attrs->{format}) {
        $this->{colTypes} = _parseFormat($attrs->{format});
    } else {
        $this->{colTypes} = [];
    }
    $this->{topic} = $topic;
    $this->{web} = $web;

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
    my $s = '%EDITTABLE{'.$this->{attrs}->stringify()."}%\n";
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
            push(@out, $row->renderForEdit());
        } else {
            push(@out, $row->renderForDisplay($this));
        }
    }
    return join("\n", @out);
}

sub renderForDisplay {
    my $this = shift;
    my @out;
    foreach my $row (@{$this->{rows}}) {
        push(@out, $row->renderForDisplay());
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

# add a row after the active row containing the data just entered
# in the active row.
sub addRow {
    my ($this, $urps) = @_;
    my $arow = $this->{rows}->[$urps->{active_row} - 1];
    my $newRow = new TWiki::Plugins::EditRowPlugin::TableRow(
        $this, $urps->{active_row});
    splice(@{$this->{rows}}, $urps->{active_row}, 0, $newRow);
    foreach my $c (@{$arow->{cols}}) {
        my $cellName = "cell_$this->{number}_$arow->{number}_$c->{number}";
        my $cv = $urps->{$cellName} || '';
        push(@{$newRow->{cols}},
             new TWiki::Plugins::EditRowPlugin::TableCell(
                 $newRow, $cv, $c->{number}));
    }
    return $this->stringify();
}

# delete the current row
sub deleteRow {
    my ($this, $urps) = @_;
    splice(@{$this->{rows}}, $urps->{active_row} - 1, 1);
    return $this->stringify();
}

sub _parseFormat {
    my $format = shift;
    my @cols;

    $format =~ s/^\s*\|//;
    $format =~ s/\|\s*$//;

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
