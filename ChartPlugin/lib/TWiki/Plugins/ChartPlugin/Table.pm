# ChartPlugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004-2012 Peter Thoeny, Peter@Thoeny.org
# Copyright (C) 2008-2012 TWiki Contributors
# Plugin written by http://TWiki.org/cgi-bin/view/Main/TaitCyrus
#
# For licensing info read LICENSE file in the TWiki root.
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
# As per the GPL, removal of this notice is prohibited.
#
# =========================
#
# This file contains routines for dealing with TWiki tables.
#
# Access is via object oriented Perl and is as follows.
#
# Constructor
#    new($topicContents)	- Create a 'Table' object from topic contents
# Getters/Setters
#    checkTableExists($name)	- Check if the specified table name exists
#    getTable($num)		- Return the specified table
#    getTableInfo		- DEBUG purposes only.  Print out contents
#    				  of tables in table object
#    getRow($row,$c1,$c2)	- Return the data at the specified row
#    				  starting at column 1 and ending at column 2
#    getData($tblnum,$range,$dataOrientedVertically, $replicateConstants)
#                               - Return the data at the specified range.
#    				  If a single row or single column, then
#    				  return the data.  If multiple
#    				  rows/columns, then return the data in row
#    				  format.  $dataOrientedVertically indicates whether to
#    				  get data by column or data by row.  $replicateConstants
#    				  indicates whether to replicate constants or not.
#    getRowColumnCount($range)	- Return the number of rows/columns
#    				  specified in the range

# =========================
package TWiki::Plugins::ChartPlugin::Table;

use strict;

sub new {
    my ($class, $topicContents) = @_;
    my $this = {};
    bless $this, $class;
    $this->_parseOutTables($topicContents);
    return $this;
}

sub getNumberOfTables {my ($this) = @_; return $$this{NUM_TABLES};}

# Check to make sure that the specified table (either by name or number)
# exists.
sub checkTableExists {
    my ($this, $tableName) = @_;
    return 1 if defined($$this{"TABLE_$tableName"});
    return 0;
}

sub getTable {
    my ($this, $tableName) = @_;
    my $table = $$this{"TABLE_$tableName"};
    return @$table if defined($table);
    return ();
}

sub getNumRowsInTable {
    my ($this, $tableName) = @_;
    my $table = $$this{"TABLE_$tableName"};
    my $nRows = 0;
    $nRows = @$table if defined($table);
    return $nRows;
}

sub getNumColsInTable {
    my ($this, $tableName) = @_;
    my $nCols = $$this{"NCOLS_$tableName"} || 0;
    return $nCols;
}

# Parse a spreadsheet-style range specification to get an array
# of normalised data ranges
sub getTableRanges {
    my ($this, $tableName, $str, $dataOrientedVertically) = @_;

    my $maxRowNum = $this->getNumRowsInTable($tableName);
    my $maxColNum = $this->getNumColsInTable($tableName);
    my @sets = ();
    foreach my $dataSet (split(/\s*,\s*/, $str)) {
        my @set = ();
        foreach my $range (split(/\s*\+\s*/, $dataSet)) {
            if ($range =~ /^R(\d+)\:C(\d+)\s*(\.\.+\s*R(\d+)\:C(\d+))?$/) {
                my $r1 = $1;
                my $c1 = $2;
                my $r2 = $4 ? ($4) : $r1;
                my $c2 = $5 ? ($5) : $c1;
                # trim range to actual table size
		if ($dataOrientedVertically) {
		    $r1 = $maxRowNum if ($r1 > $maxRowNum);
		    $r2 = $maxRowNum if ($r2 > $maxRowNum);
		} else {
		    $c1 = $maxColNum if ($c1 > $maxColNum);
		    $c2 = $maxColNum if ($c2 > $maxColNum);
		}
		#<<<
                push(@set, {
		    startRow	=> $r1,
		    startCol	=> $c1,
		    endRow	=> $r2,
		    endCol	=> $c2}
		);
		#>>>
            } else {
                push(@set, {text => $range}
		);
	    }
        } ## end foreach my $range (split(/\s*\+\s*/...))
        push(@sets, \@set) if scalar(@set);
    } ## end foreach my $dataSet (split(...))
    return @sets;
} ## end sub getTableRanges

# This routine is only intended for debug purposes.  All it does is to
# output the contents of the table object to the TWiki debug.txt file.
sub getTableInfo {
    my ($this) = @_;

    foreach my $table (1 .. $this->getNumberOfTables()) {
        my @t = $this->getTable($table);
        &TWiki::Func::writeDebug("- TWiki::Plugins::ChartPlugin::TABLE[$table][@t]");
        foreach my $row (@t) {
            my @col = @$row;
            &TWiki::Func::writeDebug("- TWiki::Plugins::ChartPlugin::ROW[$row][@col]");
        }
    }
}

# The guts of this routine was initially copied from SpreadSheetPlugin.pm,
# but has been modified to support the functionality needed by the
# ChartPlugin.  A major change is supporting the notion of multiple tables
# in a topic page and allowing the user to reference the specific table
# they want.
#
# This routine basically returns an array of hashes where each hash
# contains the information for a single table.  Thus the first hash in the
# array represents the first table found on the topic page, the second hash
# in the array represents the second table found on the topic page, etc.
sub _parseOutTables {
    my ($this, $topic) = @_;
    my $tableNum  = 1;     # Index in the same way users will ref tables
    my $tableName = "";    # If a named table.
    my @tableMatrix;       # Currently parsed table.
    my $nCols = 0;         # Number of columns in current table

    my $result      = "";
    my $insidePRE   = 0;
    my $insideTABLE = 0;
    my $line        = "";
    my @row         = ();

    $topic =~ s/\r//go;
    $topic =~ s/\\\n//go;    # Join lines ending in "\"
    $topic .= "\n-\n";       # Item6355: Add newline at end to support table at very end of topic
    foreach (split(/\n/, $topic)) {

        # change state:
        m|<pre>|i       && ($insidePRE = 1);
        m|<verbatim>|i  && ($insidePRE = 1);
        m|</pre>|i      && ($insidePRE = 0);
        m|</verbatim>|i && ($insidePRE = 0);

        if (! ($insidePRE)) {

            if (/%TABLE{.*name="(.*?)".*}%/) {
                $tableName = $1;
            }
            if (/^\s*\|.*\|\s*$/) {
                # inside | table |
                $insideTABLE = 1;
                $line        = $_;
                $line =~ s/^(\s*\|)(.*)\|\s*$/$2/o;    # Remove starting '|'
                @row = split(/\|/o, $line, -1);
                _trim(\@row);
                push(@tableMatrix, [@row]);
                $nCols = @row if (@row > $nCols);

            } else {
                # outside | table |
                if ($insideTABLE) {
                    # We were inside a table and are now outside of it so
                    # save the table info into the Table object.
                    $insideTABLE = 0;
                    if (@tableMatrix != 0) {
                        # Save the table via its table number
                        $$this{"TABLE_$tableNum"} = [@tableMatrix];
                        $$this{"NCOLS_$tableNum"} = $nCols;
                        # Deal with a 'named' table also.
                        if ($tableName) {
                            $$this{"TABLE_$tableName"} = [@tableMatrix];
                            $$this{"NCOLS_$tableName"} = $nCols;
                        }
                        $tableNum++;
                        $tableName = "";
                    }
                    undef @tableMatrix;    # reset table matrix
                    $nCols = 0;
                } ## end if ($insideTABLE)
            } ## end else [ if (/^\s*\|.*\|\s*$/) ]
        } ## end if (! ($insidePRE))
        $result .= "$_\n";
    } ## end foreach (split(/\n/, $topic...))
    $$this{NUM_TABLES} = $tableNum;
} ## end sub _parseOutTables

# Trim any leading and trailing white space, any '*' header markers, 
# HTML tags, and TWiki links.
sub _trim {
    my ($totrim) = @_;
    for my $element (@$totrim) {
        $element =~ s/\[\[.*?\]\[(.*?)\]\]/$1/g;      # Strip out TWiki links
        $element =~ s/^[\s\*]+//;    # Strip of leading white/*
        $element =~ s/[\s\*]+$//;    # Strip of trailing white/*
        $element =~ s/<.*?>//g;      # Strip out all HTML tags
    }
}

# Given a table name and a range of TWiki table data (in
# SpreadSheetPlugin format), return the specified data.  Assume that the
# data is row oriented unless only a single column is specified.
# NOTE: All data is returned as a 2 dimensional array even in the case of a
# single row/column of data. Discontinuous ranges are collapsed into
# contiguous rows, left aligned and zero-padded i.e.
# R1:C1..R2:C2,R6:C3..R7:C4 gets returned as:
# R1C1 R1C2 0
# R2C1 R2C2 0
# R6C3 R6C4 R6C5
# R7C3 R7C5 R7C5
# As a special case, handle the situation where ALL data is explicitly
# specified inline with no SpreadSheetPlugin cell specifiers.
sub getData {
    my ($this, $tableName, $spreadSheetSyntax, $dataOrientedVertically, $replicateConstants) = @_;
    # Deal with the situation where all data is explicitly specified with
    # no SpreadSheetPlugin cell specifiers.
    if ($spreadSheetSyntax !~ m/R\d/) {
	$spreadSheetSyntax =~ s/ //g;
	my @result = split(/,/, $spreadSheetSyntax);
	return [@result];
    }

    my @selectedTable = $this->getTable($tableName);
    my @ranges = $this->getTableRanges($tableName, $spreadSheetSyntax, $dataOrientedVertically);

    # Compute the max length of the requested data.  This is needed so if
    # a constant is specified instead of a spreadsheet range, we know how
    # many copies of the constant to make.
    my $maxDataLen = 1;
    if ($replicateConstants) {
	foreach my $set (@ranges) {
	    foreach my $range (@$set) {
		if ($dataOrientedVertically) {
		    if (defined($range->{endRow})) {
			my $len = abs($range->{endRow} - $range->{startRow}) + 1;
			$maxDataLen = $len if ($len > $maxDataLen);
		    }
		} else {
		    if (defined($range->{endCol})) {
			my $len = abs($range->{endCol} - $range->{startCol}) + 1;
			$maxDataLen = $len if ($len > $maxDataLen);
		    }
		}
	    }
	}
    }

    my @rows    = ();
    my $rowbase = 0;
    # For each dataset
    foreach my $set (@ranges) {
        my $rh = 0;    # Height of this dataset, in rows

        # For each range within the dataset
        foreach my $range (@$set) {
            if ($dataOrientedVertically) {
		if (defined($range->{text})) {
		    foreach my $i (1..$maxDataLen) {
			push(@{$rows[$rowbase]}, $range->{text});
		    }
		    $rh = 1;
		} else {
		    my $rs = abs($range->{endCol} - $range->{startCol}) + 1;
		    $rh = $rs if ($rs > $rh);
		    my $startCol   = $range->{startCol} - 1;
		    my $endCol     = $range->{endCol} - 1;
		    my $nextColInc = ($startCol <= $endCol) ? 1 : -1;
		    my $newColIndex = 0;
		    for (my $c = $startCol; $c != $endCol + $nextColInc; $c = $c + $nextColInc) {
			my $startRow   = $range->{startRow} - 1;
			my $endRow     = $range->{endRow} - 1;
			my $nextRowInc = ($startRow <= $endRow) ? 1 : -1;
			for (my $r = $startRow; $r != $endRow + $nextRowInc; $r = $r + $nextRowInc) {
			    my $value = $selectedTable[$r][$c];
			    if (defined $value) {
				push(@{$rows[$rowbase + $newColIndex]}, $value);
			    }
			}
			$newColIndex++;
		    }
		}
            } else {
		if (defined($range->{text})) {
		    foreach my $i (1..$maxDataLen) {
			push(@{$rows[$rowbase]}, $range->{text});
		    }
		    $rh = 1;
		} else {
		    my $rs = abs($range->{endRow} - $range->{startRow}) + 1;
		    $rh = $rs if ($rs > $rh);
		    my $startRow   = $range->{startRow} - 1;
		    my $endRow     = $range->{endRow} - 1;
		    my $nextRowInc = ($startRow <= $endRow) ? 1 : -1;
		    my $newRowIndex = 0;
		    for (my $r = $startRow; $r != $endRow + $nextRowInc; $r = $r + $nextRowInc) {
			my $startCol   = $range->{startCol} - 1;
			my $endCol     = $range->{endCol} - 1;
			my $nextColInc = ($startCol <= $endCol) ? 1 : -1;
			for (my $c = $startCol; $c != $endCol + $nextColInc; $c = $c + $nextColInc) {
			    my $value = $selectedTable[$r][$c];
			    if (defined $value) {
				push(@{$rows[$rowbase + $newRowIndex]}, $value);
			    }
			}
		    $newRowIndex++;
		    }
		}
            }
        } ## end foreach my $range (@$set)

	# Start the next dataset on a new row
        $rowbase += $rh;
    } ## end foreach my $set (@ranges)

    # Remove empty rows
    my @result;
    foreach my $row (@rows) {
        push(@result, $row) if $row && scalar(@$row);
    }

    return @result;
} ## end sub getData

# Transpose an array
sub transpose {
    my @a = @_;
    my @b;
    foreach my $row (@a) {
        my $r = 0;
        foreach my $col (@$row) {
            push(@{$b[$r++]}, $col);
        }
    }
    return @b;
}

sub max {$_[0] > $_[1] ? $_[0] : $_[1]}

# Given a range of TWiki table data (in SpreadSheetPlugin format), return
# an array containing the number of rows/columns specified by the range.
sub getRowColumnCount {
    my ($this, $tableName, $spreadSheetSyntax, $dataOrientedVertically) = @_;
    my @ranges = $this->getTableRanges($tableName, $spreadSheetSyntax, $dataOrientedVertically);
    my $rows   = 0;
    my $cols   = 0;
    foreach my $set (@ranges) {
        my $r = 0;
        my $c = 0;
        foreach my $range (@$set) {
	    if (defined($range->{text})) {
		$r = max($r, 1);
		$c += 1;
	    } else {
		$r = max($r, abs($range->{endRow} - $range->{startRow}) + 1);
		$c += abs($range->{endCol} - $range->{startCol}) + 1;
	    }
        }
        $rows += $r;
        $cols = $c if $c > $cols;
    }
    return ($rows, $cols);
} ## end sub getRowColumnCount

1;
