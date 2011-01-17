# FluidPivotsPlugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004-2006 Peter Thoeny, Peter@Thoeny.org
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
#    getTableRange($range)	- Given a range of rows/columns in
#    				  SpreadSheetPlugin format, return an array
#    				  of staring row/column ending row/column
#    getRow($row,$c1,$c2)	- Return the data at the specified row
#    				  starting at column 1 and ending at column 2
#    getData($tblnum,$range)	- Return the data at the specified range.
#    				  If a single row or single column, then
#    				  return the data.  If multiple
#    				  rows/columns, then return the data in row
#    				  format.
#    getRowColumnCount($range)	- Return the number of rows/columns
#    				  specified in the range
#    getDataRows($tblnum,$range)- Return the data at the specified range
#    				  assuming that the data is in row format
#				  NOTE: In the case of multiple
#				  rows/columns, this is identical to
#				  getData().
#    getDataColumns($tblnum,$range)- Return the data at the specified range
#    				  assuming that the data is in column format

# =========================
package TWiki::Plugins::FluidPivotsPlugin::Table;

use Exporter;
@ISA = ();
@EXPORT = qw(
    getTable
    getNumRowsInTable
    getNumColsInTable
    getNumberOfTables
    getTableInfo
);

use strict;

sub new
{
    my ($class, $topicContents) = @_;
    my $this = {};
    bless $this, $class;
    $this->_parseOutTables($topicContents);
    return $this;
}

sub getNumberOfTables { my ($this) = @_; return $$this{NUM_TABLES}; }
# Check to make sure that the specified table (either by name or number)
# exists.
sub checkTableExists
{
    my ($this, $tableName) = @_;
    return 1 if defined( $$this{"TABLE_$tableName"} );
    return 0;
}

sub getTable
{
    my ($this, $tableName) = @_;
    my $table = $$this{"TABLE_$tableName"};
    return @$table if defined( $table );
    return ();
}

sub getNumRowsInTable
{
    my( $this, $tableName ) = @_;
    my $table = $$this{"TABLE_$tableName"};
    my $nRows = 0;
    $nRows = @$table if defined( $table );
    return $nRows;
}

sub getNumColsInTable
{
    my( $this, $tableName ) = @_;
    my $nCols = $$this{"NCOLS_$tableName"} || 0;
    return $nCols;
}

# This routine is only intended for debug purposes.  All it does is to
# output the contents of the table object to the TWiki debug.txt file.
sub getTableInfo {
    my ($this) = @_;

    foreach my $table (1..$this->getNumberOfTables()) {
	my @t = $this->getTable($table);
	&TWiki::Func::writeDebug( "- TWiki::Plugins::ChartPlugin::TABLE[$table][@t]");
	foreach my $row (@t) {
	    my @col = @$row;
	    &TWiki::Func::writeDebug( "- TWiki::Plugins::ChartPlugin::ROW[$row][@col]");
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
    my $tableNum = 1;		# Index in the same way users will ref tables
    my $tableName = "";		# If a named table.
    my @tableMatrix;            # Currently parsed table.
    my $nCols = 0;              # Number of columns in current table

    my $result = "";
    my $insidePRE = 0;
    my $insideTABLE = 0;
    my $line = "";
    my @row = ();

    $topic =~ s/\r//go;
    $topic =~ s/\\\n//go;  # Join lines ending in "\"
    $topic = "$topic\n "; # Add a last newline with a space, to detect the end of a table, if it ends at the end of the topic.

    foreach( split( /\n/, $topic ) ) {

        # change state:
        m|<pre>|i       && ( $insidePRE = 1 );
        m|<verbatim>|i  && ( $insidePRE = 1 );
        m|</pre>|i      && ( $insidePRE = 0 );
        m|</verbatim>|i && ( $insidePRE = 0 );

        if( ! ( $insidePRE ) ) {

	    if( /%TABLE{.*name="(.*?)".*}%/) {
		$tableName = $1;
	    }
            if( /^\s*\|.*\|\s*$/ ) {
                # inside | table |
		$insideTABLE = 1;
                $line = $_;
                $line =~ s/^(\s*\|)(.*)\|\s*$/$2/o;	# Remove starting '|'
                @row  = split( /\|/o, $line, -1 );
		_trim(\@row);
                push (@tableMatrix, [ @row ]);
                $nCols = @row if( @row > $nCols );

            } else {
                # outside | table |
                if( $insideTABLE ) {
		    # We were inside a table and are now outside of it so
		    # save the table info into the Table object.
                    $insideTABLE = 0;
		    if (@tableMatrix != 0) {
			# Save the table via its table number
			$$this{"TABLE_$tableNum"} = [@tableMatrix];
                        $$this{"NCOLS_$tableNum"} = $nCols;
                        # Deal with a 'named' table also.
                        if( $tableName ) {
                            $$this{"TABLE_$tableName"} = [@tableMatrix];
                            $$this{"NCOLS_$tableName"} = $nCols;
                        }
			$tableNum++;
			$tableName = "";
		    }
                    undef @tableMatrix;  # reset table matrix
                    $nCols = 0;
                }
            }
        }
        $result .= "$_\n";
    }
    $$this{NUM_TABLES} = $tableNum;
}

# Trim any leading and trailing white space and/or '*'.
sub _trim
{
    my ($totrim) = @_;
    for my $element (@$totrim) {
	$element =~ s/^[\s\*]+//;	# Strip of leading white/*
	$element =~ s/[\s\*]+$//;	# Strip of trailing white/*
    }
}

# Given a table name and a range of TWiki table data (in
# SpreadSheetPlugin format), return the specified data.  Assume that the
# data is row oriented unless only a single column is specified.
# NOTE: All data is returned as a 2 dimensional array even in the case of a
# single row/column of data.
sub getData
{
    my ($this, $tableName, $spreadSheetSyntax) = @_;
    my @selectedTable = $this->getTable($tableName);
    my ($r1, $c1, $r2, $c2) = $this->getTableRange($spreadSheetSyntax);
    # Make sure a valid range.
    return () if (! defined $r1);

    # trim range to actual table size
    my $maxRow = $this->getNumRowsInTable( $tableName ) - 1;
    my $maxCol = $this->getNumColsInTable( $tableName ) - 1;
    $r2 = $maxRow if( $r2 > $maxRow );
    $c2 = $maxCol if( $c2 > $maxCol );

    # OK, so the data range is valid, but it is still possible that the
    # range points to data that does not exist so limit the ranges to real
    # data.
    my @data = ();
    my @returnData = ();
    my $value;
    # Determine if this is a single column.  If not, then return data in
    # row format.
    if ($c1 == $c2) {
	if ($r1 > $r2) {
	    for (my $r = $r1; $r >= $r2; $r -= 1) {
		$value = $selectedTable[$r][$c1];
		push ( @data, $selectedTable[$r][$c1] ) if (defined $value);
	    }
	} else {
	    for (my $r = $r1; $r <= $r2; $r += 1) {
		$value = $selectedTable[$r][$c1];
		push ( @data, $selectedTable[$r][$c1] ) if (defined $value);
	    }
	}
	# If found data, then push onto array to be returned
	push (@returnData, [@data]) if (@data != 0);
    } else {
	if ($r1 == $r2) {
	    if ($c1 > $c2) {
		for (my $c = $c1; $c >= $c2; $c -= 1) {
		    $value = $selectedTable[$r1][$c];
		    push ( @data, $selectedTable[$r1][$c] ) if (defined $value);
		}
	    } else {
		for (my $c = $c1; $c <= $c2; $c += 1) {
		    $value = $selectedTable[$r1][$c];
		    push ( @data, $selectedTable[$r1][$c] ) if (defined $value);
		}
	    }
	    # If found data, then push onto array to be returned
	    push (@returnData, [@data]) if (@data != 0);
	} else {
	    # More than one column so get each row of data
	    if ($r1 > $r2) {
		for (my $r = $r1; $r >= $r2; $r -= 1) {
		    @data = ();
		    if ($c1 > $c2) {
			for (my $c = $c1; $c >= $c2; $c -= 1) {
			    $value = $selectedTable[$r][$c];
			    push ( @data, $selectedTable[$r][$c] ) if (defined $value);
			}
		    } else {
			for (my $c = $c1; $c <= $c2; $c += 1) {
			    $value = $selectedTable[$r][$c];
			    push ( @data, $selectedTable[$r][$c] ) if (defined $value);
			}
		    }
		    # If found data, then push onto array to be returned
		    push (@returnData, [@data]) if (@data != 0);
		}
	    } else {
		for (my $r = $r1; $r <= $r2; $r += 1) {
		    @data = ();
		    if ($c1 > $c2) {
			for (my $c = $c1; $c >= $c2; $c -= 1) {
			    $value = $selectedTable[$r][$c];
			    push ( @data, $selectedTable[$r][$c] ) if (defined $value);
			}
		    } else {
			for (my $c = $c1; $c <= $c2; $c += 1) {
			    $value = $selectedTable[$r][$c];
			    push ( @data, $selectedTable[$r][$c] ) if (defined $value);
			}
		    }
		    # If found data, then push onto array to be returned
		    push (@returnData, [@data]) if (@data != 0);
		}
	    }
	}
    }
    return @returnData;
}

# Given a range of TWiki table data (in SpreadSheetPlugin format), return
# an array containing the number of rows/columns specified by the range.
sub getRowColumnCount
{
    my ($this, $spreadSheetSyntax) = @_;
    my ($r1, $c1, $r2, $c2) = $this->getTableRange($spreadSheetSyntax);
    return (($r2 - $r1), ($c2 - $c1)) if (defined($r1));
    #&TWiki::Func::writeDebug( "- getRowColumnCount: bad data, returning undef");
    return (undef, undef);
}

# Given a table number and a range of TWiki table data (in
# SpreadSheetPlugin format), return the specified data assuming it is in
# rows.
sub getDataRows
{
    my ($this, $tableName, $spreadSheetSyntax) = @_;
    return $this->getData($tableName, $spreadSheetSyntax);
}

# Given a table number and a range of TWiki table data (in
# SpreadSheetPlugin format), return the specified data assuming it is in
# columns.
sub getDataColumns
{
    my ( $this, $tableName, $spreadSheetSyntax ) = @_;

    my @selectedTable = $this->getTable( $tableName );
    my ($r1, $c1, $r2, $c2) = $this->getTableRange( $spreadSheetSyntax );
    # Make sure a valid range.
    return () unless( defined $r1 );

    # trim range to actual table size
    my $maxRow = $this->getNumRowsInTable( $tableName ) - 1;
    my $maxCol = $this->getNumColsInTable( $tableName ) - 1;
    $r2 = $maxRow if( $r2 > $maxRow );
    $c2 = $maxCol if( $c2 > $maxCol );

    my @returnData = ();
    my $value = 0;
    if ($c1 > $c2) {
	for (my $c = $c1; $c >= $c2; $c -= 1) {
	    my @data = ();
	    if ($r1 > $r2) {
		for (my $r = $r1; $r >= $r2; $r -= 1) {
		    $value = $selectedTable[$r][$c];
		    push ( @data, $selectedTable[$r][$c] ) if( defined $value );
		}
	    } else {
		for (my $r = $r1; $r <= $r2; $r += 1) {
		    $value = $selectedTable[$r][$c];
		    push ( @data, $selectedTable[$r][$c] ) if( defined $value );
		}
	    }
	    # If found data, then push onto array to be returned
	    push (@returnData, [@data]) if (@data != 0);
	}
    } else {
	for (my $c = $c1; $c <= $c2; $c += 1) {
	    my @data = ();
	    if ($r1 > $r2) {
		for (my $r = $r1; $r >= $r2; $r -= 1) {
		    $value = $selectedTable[$r][$c];
		    push ( @data, $selectedTable[$r][$c] ) if( defined $value );
		}
	    } else {
		for (my $r = $r1; $r <= $r2; $r += 1) {
		    $value = $selectedTable[$r][$c];
		    push ( @data, $selectedTable[$r][$c] ) if( defined $value );
		}
	    }
	    # If found data, then push onto array to be returned
	    push (@returnData, [@data]) if (@data != 0);
	}
    }
    return @returnData;
}

# The following routine was grabbed from SpreadSheetPlugin.pm.  Only minor
# changes were made.
sub getTableRange
{
    my( $this, $theAttr ) = @_;

    my @arr = ();

    $theAttr =~ /\s*R([0-9]+)\:C([0-9]+)\s*\.\.+\s*R([0-9]+)\:C([0-9]+)/;
    if( ! $4 ) {
        return (undef, undef, undef, undef);
    }
    my $r1 = $1 - 1;
    my $c1 = $2 - 1;
    my $r2 = $3 - 1;
    my $c2 = $4 - 1;
    @arr = ($r1, $c1, $r2, $c2);
    #&TWiki::Func::writeDebug( "- SpreadSheetPlugin::getTableRange() returns @arr" ) if $debug;
    return @arr;
}

1;
