# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001-2003 John Talintyre, jet@cheerful.com
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2005-2006 TWiki Contributors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# As per the GPL, removal of this notice is prohibited.

use strict;

package TWiki::Plugins::TablePlugin::Core;

use Time::Local;

use vars qw( $translationToken
  $insideTABLE $tableCount @curTable $sortCol $maxSortCols $requestedTable $up
  $sortTablesInText $sortAttachments $currTablePre $sortColFromUrl
  $tableWidth @columnWidths
  $tableBorder $tableFrame $tableRules $cellPadding $cellSpacing $cellBorder
  @headerAlign @dataAlign $vAlign $headerVAlign $dataVAlign
  $headerBg $headerBgSorted $headerColor $sortAllTables $twoCol @dataBg @dataBgSorted @dataColor
  @isoMonth
  $headerRows $footerRows
  $upchar $downchar $diamondchar $url
  @isoMonth %mon2num $initSort $initDirection $currentSortDirection
  @rowspan $pluginAttrs $prefsAttrs $tableId $tableSummary $tableCaption
  $iconUrl $unsortEnabled
  %sortDirection %columnType
  %cssAttrs $didWriteDefaultStyle
);

BEGIN {
    $translationToken = "\0";
    $currTablePre     = '';
    $upchar           = '';
    $downchar         = '';
    $diamondchar      = '';
    @isoMonth         = (
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    );
    {
        my $count = 0;
        %mon2num = map { $_ => $count++ } @isoMonth;
    }
    %sortDirection = ( 'ASCENDING', 0, 'DESCENDING', 1, 'NONE', 2 );
    %columnType = (
        'TEXT',   'text',   'DATE',      'date',
        'NUMBER', 'number', 'UNDEFINED', 'undefined'
    );

    # the maximum number of columns we will handle
    $maxSortCols = 10000;
    $iconUrl =
        TWiki::Func::getPubUrlPath() . '/'
      . TWiki::Func::getTwikiWebname()
      . '/TWikiDocGraphics/';
    $unsortEnabled        = 1;    # if true, table columns can be unsorted
    $didWriteDefaultStyle = 0;
}

sub _setDefaults {
    $sortAllTables  = $sortTablesInText;
    $tableBorder    = 1;
    $tableFrame     = '';
    $tableRules     = '';
    $cellSpacing    = 0;
    $cellPadding    = 0;
    $cellBorder     = '';
    $tableWidth     = '';
    @columnWidths   = ();
    $headerRows     = 1;
    $footerRows     = 0;
    @headerAlign    = ();
    @dataAlign      = ();
    $vAlign         = '';
    $headerVAlign   = '';
    $dataVAlign     = '';
    $headerBg       = '#6b7f93';
    $headerBgSorted = '';
    $headerColor    = '#ffffff';
    @dataBg         = ( '#ecf2f8', '#ffffff' );
    @dataBgSorted   = ();
    @dataColor      = ();
    $tableId        = '';
    $tableSummary   = '';
    $tableCaption   = '';
    undef $initSort;
    %cssAttrs       = ();
    _parseParameters( $pluginAttrs, 0 );
    _parseParameters( $prefsAttrs,  0 );    # Preferences setting
}

# Table attributes defined as a Plugin setting, a preferences setting
# e.g. in WebPreferences or as a %TABLE{...}% setting
sub _parseParameters {
    my ( $args, $useCss ) = @_;

    return '' unless ( defined($args) );
    return '' unless ( $args =~ /\S/ );

    my %params = TWiki::Func::extractParameters($args);
    
    # Defines which column to initially sort : ShawnBradford 20020221
    my $tmp = $params{initsort};
    $initSort = $tmp if ($tmp);

    # Defines which direction to sort the column set by initsort :
    # ShawnBradford 20020221
    $tmp           = $params{initdirection};
    $initDirection = $sortDirection{'ASCENDING'}
      if ( defined $tmp && $tmp =~ /^down$/i );
    $initDirection = $sortDirection{'DESCENDING'}
      if ( defined $tmp && $tmp =~ /^up$/i );

    $tmp           = $params{sort};
    $tmp           = '0' if ( defined $tmp && $tmp =~ /^off$/oi );
    $sortAllTables = $tmp if ( defined $tmp && $tmp ne '' );

    $tmp = $params{tableborder};
    if ( defined $tmp && $tmp ne '' ) {
        $tableBorder = $tmp;
        $cssAttrs{tableBorder} = $tableBorder if $useCss;
    }

    $tmp = $params{tableframe};
    if ( defined $tmp && $tmp ne '' ) {
        $tableFrame = $tmp;
        $cssAttrs{tableFrame} = $tableFrame if $useCss;
    }

    $tmp = $params{tablerules};
    if ( defined $tmp && $tmp ne '' ) {
        $tableRules = $tmp;
        $cssAttrs{tableRules} = $tableRules if $useCss;
    }

    $tmp = $params{cellpadding};
    if ( defined $tmp && $tmp ne '' ) {
        $cellPadding = $tmp;
        $cssAttrs{cellPadding} = $cellPadding if $useCss;
    }

    $tmp = $params{cellspacing};
    if ( defined $tmp && $tmp ne '' ) {
        $cellSpacing = $tmp;
    }

    $tmp = $params{cellborder};
    if ( defined $tmp && $tmp ne '' ) {
        $cellBorder = $tmp;
        $cssAttrs{cellBorder} = $cellBorder if $useCss;
    }

    $tmp = $params{headeralign};
    if ( defined $tmp && $tmp ne '' ) {
        @headerAlign = split( /,\s*/, $tmp );
        $cssAttrs{headerAlign} = @headerAlign if $useCss;
    }

    $tmp = $params{dataalign};
    if ( defined $tmp && $tmp ne '' ) {
        @dataAlign = split( /,\s*/, $tmp );
        $cssAttrs{dataAlign} = @dataAlign if $useCss;
    }

    $tmp = $params{tablewidth};
    if ( defined $tmp && $tmp ne '' ) {
        $tableWidth = $tmp;
        $cssAttrs{tableWidth} = $tableWidth if $useCss;
    }

    $tmp = $params{columnwidths};
    if ( defined $tmp && $tmp ne '' ) {
        @columnWidths = split( /, */, $tmp );
        $cssAttrs{columnWidths} = @columnWidths if $useCss;
    }

    $tmp = $params{headerrows};
    if ( defined $tmp && $tmp ne '' ) {
        $headerRows = $tmp;
        $headerRows = 1 if ( $headerRows < 1 );
    }

    $tmp = $params{footerrows};
    if ( defined $tmp && $tmp ne '' ) {
        $footerRows = $tmp;
    }

    $tmp = $params{valign};
    if ( defined $tmp && $tmp ne '' ) {
        $vAlign = $tmp if ( defined $tmp );
        $cssAttrs{vAlign} = $vAlign if $useCss;
    }

    $tmp = $params{datavalign};
    if ( defined $tmp && $tmp ne '' ) {
        $dataVAlign = $tmp if ( defined $tmp );
        $cssAttrs{dataVAlign} = $dataVAlign if $useCss;
    }

    $tmp = $params{headervalign};
    if ( defined $tmp && $tmp ne '' ) {
        $headerVAlign = $tmp if ( defined $tmp );
        $cssAttrs{headerVAlign} = $headerVAlign if $useCss;
    }

    my $tmpheaderbg = $params{headerbg};
    if ( defined $tmpheaderbg && $tmpheaderbg ne '' ) {
        $headerBg = $tmpheaderbg;
        $cssAttrs{headerBg} = $headerBg if $useCss;
    }

    # only set headerbgsorted color if it is defined in %TABLE{}% attributes
    # otherwise use headerbg
    $tmp = $params{headerbgsorted};
    if ( defined $tmp && $tmp ne '' ) {
        $headerBgSorted = $tmp;
        $cssAttrs{headerBgSorted} = $headerBgSorted if $useCss;
    }
    elsif ( defined $tmpheaderbg ) {
        $headerBgSorted = $tmpheaderbg;
        $cssAttrs{headerBgSorted} = $headerBgSorted if $useCss;
    }

    $tmp = $params{headercolor};
    if ( defined $tmp && $tmp ne '' ) {
        $headerColor = $tmp if ( defined $tmp );
        $cssAttrs{headerColor} = $headerColor if $useCss;
    }

    my $tmpdatabg = $params{databg};
    if ( defined $tmpdatabg && $tmpdatabg ne '' ) {
        @dataBg = split( /,\s*/, $tmpdatabg );
        $cssAttrs{dataBg} = @dataBg if $useCss;
    }

    # only set databgsorted color if it is defined in %TABLE{}% attributes
    # otherwise use databg
    $tmp = $params{databgsorted};
    if ( defined $tmp && $tmp ne '' ) {
        @dataBgSorted = split( /,\s*/, $tmp );
        $cssAttrs{dataBgSorted} = @dataBgSorted if $useCss;
    }
    elsif ( defined $tmpdatabg ) {
        @dataBgSorted = split( /,\s*/, $tmpdatabg );
        $cssAttrs{dataBgSorted} = @dataBgSorted if $useCss;
    }

    $tmp = $params{datacolor};
    if ( defined $tmp && $tmp ne '' ) {
        @dataColor = split( /,\s*/, $tmp ) if ( defined $tmp );
        $cssAttrs{dataColor} = @dataColor if $useCss;
    }

    $tmp = $params{id};
    if ( defined $tmp && $tmp ne '' ) {
        $tableId = 'table' . $tmp;
    }
    else {
        $tableId = 'table' . ( $tableCount + 1 );
    }
    $cssAttrs{tableId} = $tableId;

    $tmp = $params{summary};
    if ( defined $tmp && $tmp ne '' ) {
        $tableSummary = $tmp;
    }

    $tmp = $params{caption};
    if ( defined $tmp && $tmp ne '' ) {
        $tableCaption = $tmp;
    }

    my $isCustomAttributes = $useCss;
    _addStylesToHead( $isCustomAttributes, %cssAttrs );

    return $currTablePre . '<nop>';
}

# Convert text to number and date if syntactically possible
sub _convertToNumberAndDate {
    my ($text) = @_;

    $text =~ s/&nbsp;/ /go;
    $text =~ s/<\/?nobr>/ /go;

    my $num  = undef;
    my $date = undef;
    if ( $text =~ /^\s*$/ ) {
        $num  = 0;
        $date = 0;
    }

    if ( $text =~
m|^\s*([0-9]{1,2})[-\s/]*([A-Z][a-z][a-z])[-\s/]*([0-9]{4})\s*-\s*([0-9][0-9]):([0-9][0-9])|
      )
    {

        # "31 Dec 2003 - 23:59", "31-Dec-2003 - 23:59",
        # "31 Dec 2003 - 23:59 - any suffix"
        $date = timegm( 0, $5, $4, $1, $mon2num{$2}, $3 - 1900 );
    }
    elsif ( $text =~
        m|^\s*([0-9]{1,2})[-\s/]([A-Z][a-z][a-z])[-\s/]([0-9]{2,4})\s*$| )
    {

        # "31 Dec 2003", "31 Dec 03", "31-Dec-2003", "31/Dec/2003"
        my $year = $3;
        $year += 1900 if ( length($year) == 2 && $year > 80 );
        $year += 2000 if ( length($year) == 2 );
        $date = timegm( 0, 0, 0, $1, $mon2num{$2}, $year - 1900 );
    }
    elsif ( $text =~ /^\s*[0-9]+(\.[0-9]+)?\s*$/ ) {
        $num = $text;
    }

    return ( $num, $date );
}

sub _processTableRow {
    my ( $thePre, $theRow ) = @_;

    $currTablePre = $thePre || '';
    my $span = 0;
    my $l1   = 0;
    my $l2   = 0;

    if ( !$insideTABLE ) {
        @curTable = ();
        @rowspan  = ();

        $tableCount++;
        $currentSortDirection = $sortDirection{'NONE'};

        if (   defined $requestedTable
            && $requestedTable == $tableCount
            && defined $sortColFromUrl )
        {
            $sortCol              = $sortColFromUrl;
            $sortCol              = $maxSortCols if ( $sortCol > $maxSortCols );
            $currentSortDirection = _getCurrentSortDirection($up);
        }
        elsif ( defined $initSort ) {
            $sortCol              = $initSort - 1;
            $sortCol              = $maxSortCols if ( $sortCol > $maxSortCols );
            $currentSortDirection = _getCurrentSortDirection($initDirection);
        }

    }

    $theRow =~ s/\t/   /go;    # change tabs to space
    $theRow =~ s/\s*$//o;      # remove trailing spaces
    $theRow =~ s/(\|\|+)/$translationToken.length($1)."\|"/geo;   # calc COLSPAN
    my $colCount = 0;
    my @row      = ();
    $span = 0;
    my $value = '';

    foreach ( split( /\|/, $theRow ) ) {
        my $attr = {};
        $span = 1;

        #AS 25-5-01 Fix to avoid matching also single columns
        if (s/$translationToken([0-9]+)//) {
            $span = $1;
            $attr->{colspan} = $span;
        }
        s/^\s+$/ &nbsp; /o;
        ( $l1, $l2 ) = ( 0, 0 );
        if (/^(\s*).*?(\s*)$/) {
            $l1 = length($1);
            $l2 = length($2);
        }
        if ( $l1 >= 2 ) {
            if ( $l2 <= 1 ) {
                $attr->{align} = 'right';
            }
            else {
                $attr->{align} = 'center';
            }
        }
        if ( $span <= 2 ) {
            $attr->{class} =
              _appendColNumberCssClass( $attr->{class}, $colCount );
        }
        if (   defined $columnWidths[$colCount]
            && $columnWidths[$colCount]
            && $span <= 2 )
        {

            # html attribute
            $attr->{width} = $columnWidths[$colCount];
        }

        if (/^\s*\^\s*$/) {    # row span above
            $rowspan[$colCount]++;
            push @row, { text => $value, type => 'Y' };
        }
        else {
            for ( my $col = $colCount ; $col < ( $colCount + $span ) ; $col++ )
            {
                if ( defined( $rowspan[$col] ) && $rowspan[$col] ) {
                    my $nRows = scalar(@curTable);
                    my $rspan = $rowspan[$col] + 1;
                    if ( $rspan > 1 ) {
                        $curTable[ $nRows - $rspan ][$col]->{attrs}->{rowspan} =
                          $rspan;
                    }
                    undef( $rowspan[$col] );
                }
            }

            if (
                (
                    (
                        defined $requestedTable
                        && $requestedTable == $tableCount
                    )
                    || defined $initSort
                )
                && defined $sortCol
                && $colCount == $sortCol
              )
            {

                # CSS class name
                if ( $currentSortDirection == $sortDirection{'ASCENDING'} ) {
                    $attr->{class} =
                      _appendSortedAscendingCssClass( $attr->{class} );
                }
                if ( $currentSortDirection == $sortDirection{'DESCENDING'} ) {
                    $attr->{class} =
                      _appendSortedDescendingCssClass( $attr->{class} );
                }
            }

            my $type = '';
            if (/^\s*\*(.*)\*\s*$/) {
                $value = $1;
                if (@headerAlign) {
                    my $align =
                      @headerAlign[ $colCount % ( $#headerAlign + 1 ) ];

                    # html attribute
                    $attr->{align} = $align;
                }
                if ($headerVAlign) {

                    # html attribute
                    $attr->{valign} = $headerVAlign if $headerVAlign;
                }
                elsif ($vAlign) {

                    # html attribute
                    $attr->{valign} = $vAlign;
                }
                $type = 'th';
            }
            else {
                if (/^\s*(.*?)\s*$/) {    # strip white spaces
                    $_ = $1;
                }
                $value = $_;
                if (@dataAlign) {
                    my $align = @dataAlign[ $colCount % ( $#dataAlign + 1 ) ];

                    # html attribute
                    $attr->{align} = $align;
                }
                if ($dataVAlign) {

                    # html attribute
                    $attr->{valign} = $dataVAlign if $dataVAlign;
                }
                elsif ($vAlign) {

                    # html attribute
                    $attr->{valign} = $vAlign;
                }
                $type = 'td';
            }

            push @row, { text => $value, attrs => $attr, type => $type };
        }
        while ( $span > 1 ) {
            push @row, { text => $value, type => 'X' };
            $colCount++;
            $span--;
        }
        $colCount++;
    }
    push @curTable, \@row;
    return $currTablePre
      . '<nop>';    # Avoid TWiki converting empty lines to new paras
}

# Determine whether to generate sorting headers for this table. The header
# indicates the context of the table (body or file attachment)
sub _shouldISortThisTable {
    my ($header) = @_;

    return 0 unless $sortAllTables;

    # All cells in header are headings?
    foreach my $cell (@$header) {
        return 0 if ( $cell->{type} ne 'th' );
    }

    return 1;
}

# Guess if column is a date, number or plain text
sub _guessColumnType {
    my ($col)         = @_;
    my $isDate        = 1;
    my $isNum         = 1;
    my $num           = '';
    my $date          = '';
    my $columnIsValid = 0;
    foreach my $row (@curTable) {
        next if ( !$row->[$col]->{text} );

        # else
        $columnIsValid = 1;
        ( $num, $date ) = _convertToNumberAndDate( $row->[$col]->{text} );
        $isDate = 0 if ( !defined($date) );
        $isNum  = 0 if ( !defined($num) );
        last if ( !$isDate && !$isNum );
        $row->[$col]->{date}   = $date;
        $row->[$col]->{number} = $num;
    }
    return $columnType{'UNDEFINED'} if ( !$columnIsValid );
    my $type = $columnType{'TEXT'};
    if ($isDate) {
        $type = $columnType{'DATE'};
    }
    elsif ($isNum) {
        $type = $columnType{'NUMBER'};
    }
    return $type;
}

# Remove HTML from text so it can be sorted
sub _stripHtml {
    my ($text) = @_;
    $text ||= '';
    $text =~ s/\&nbsp;/ /go;    # convert space
    $text =~
      s/\[\[[^\]]+\]\[([^\]]+)\]\]/$1/go; # extract label from [[...][...]] link
    $text =~ s/<[^>]+>//go;               # strip HTML
    $text =~ s/^ *//go;                   # strip leading space space
    $text = lc($text);                    # convert to lower case
    return $text;
}

=pod

Appends $className to $classList, separated by a space.  

=cut

sub _appendToClassList {
    my ( $classList, $className ) = @_;
    $classList = $classList ? $classList .= ' ' : '';
    $classList .= $className;
    return $classList;
}

sub _appendSortedCssClass {
    my ($classList) = @_;

    return _appendToClassList( $classList, 'twikiSortedCol' );
}

sub _appendRowNumberCssClass {
    my ( $classList, $colListName, $rowNum ) = @_;

    my $rowClassName = 'twikiTableRow' . $colListName . $rowNum;
    return _appendToClassList( $classList, $rowClassName );
}

sub _appendColNumberCssClass {
    my ( $classList, $colNum ) = @_;

    my $colClassName = 'twikiTableCol' . $colNum;
    return _appendToClassList( $classList, $colClassName );
}

sub _appendFirstColumnCssClass {
    my ($classList) = @_;

    return _appendToClassList( $classList, 'twikiFirstCol' );
}

sub _appendLastRowCssClass {
    my ($classList) = @_;

    return _appendToClassList( $classList, 'twikiLast' );
}

sub _appendSortedAscendingCssClass {
    my ($classList) = @_;

    return _appendToClassList( $classList, 'twikiSortedAscendingCol' );
}

sub _appendSortedDescendingCssClass {
    my ($classList) = @_;

    return _appendToClassList( $classList, 'twikiSortedDescendingCol' );
}

# The default sort direction.
sub _getDefaultSortDirection {
    return $sortDirection{'ASCENDING'};
}

# Gets the current sort direction.
sub _getCurrentSortDirection {
    my ($currentDirection) = @_;
    $currentDirection ||= _getDefaultSortDirection();
    return $currentDirection;
}

# Gets the new sort direction (needed for sort button) based on the current sort
# direction.
sub _getNewSortDirection {
    my ($currentDirection) = @_;
    if ( !defined $currentDirection ) {
        return _getDefaultSortDirection();
    }
    my $newDirection;
    if ( $currentDirection == $sortDirection{'ASCENDING'} ) {
        $newDirection = $sortDirection{'DESCENDING'};
    }
    if ( $currentDirection == $sortDirection{'DESCENDING'} ) {
        if ($unsortEnabled) {
            $newDirection = $sortDirection{'NONE'};
        }
        else {
            $newDirection = $sortDirection{'ASCENDING'};
        }
    }
    if ( $currentDirection == $sortDirection{'NONE'} ) {
        $newDirection = $sortDirection{'ASCENDING'};
    }
    return $newDirection;
}

=pod

Writes css styles to the head if $useCss is true (when custom attributes have been passed to
the TABLE{} variable.

Explicitly set styles override html styling (in this file marked with comment '# html attribute').

=cut

sub _addStylesToHead {
    my ( $useCss, %cssAttrs ) = @_;

    my @styles = ();

    if ( !$didWriteDefaultStyle ) {
        my $id       = 'default';
        my $selector = '.twikiTable';
        my $attr     = 'padding-left:.3em; vertical-align:text-bottom;';
        push( @styles, ".tableSortIcon img {$attr}" );

        if ($cellPadding) {
            my $attr = 'padding:' . $cellPadding . 'px;';
            push( @styles, "$selector td {$attr}" );
            push( @styles, "$selector th {$attr}" );
        }
        _writeStyleToHead( $id, @styles );
        $didWriteDefaultStyle = 1;
    }

    # only write default style
    return if !$useCss;

    my $id       = $cssAttrs{tableId};
    my $selector = '.twikiTable' . '#' . $id;

    # tablerules
    if ( defined $cssAttrs{tableRules} ) {
        if ( $cssAttrs{tableRules} eq 'all' ) {
            my $attr = 'border-style:solid;';
            push( @styles, "$selector td {$attr}" );
            push( @styles, "$selector th {$attr}" );
        }
        if ( $cssAttrs{tableRules} eq 'none' ) {
            my $attr = 'border-style:none;';
            push( @styles, "$selector td {$attr}" );
            push( @styles, "$selector th {$attr}" );
        }
        if ( $cssAttrs{tableRules} eq 'cols' ) {
            my $attr = 'border-style:none solid;';
            push( @styles, "$selector td {$attr}" );
            push( @styles, "$selector th {$attr}" );
        }
        if ( $cssAttrs{tableRules} eq 'rows' ) {
            my $attr = 'border-style:solid none;';
            push( @styles, "$selector td {$attr}" );
            push( @styles, "$selector th {$attr}" );
        }
        if ( $cssAttrs{tableRules} eq 'groups' ) {
            my $attr = 'border-style:solid none;';
            push( @styles, "$selector th {$attr}" );
            $attr = 'border-style:none;';
            push( @styles, "$selector td {$attr}" );
        }
    }
    
    # tableframe 
    if ( defined $cssAttrs{tableFrame} ) {
        my $attr = '';
        if ( $cssAttrs{tableFrame} eq 'void' ) {
            $attr = 'border-style:none;';
        }
        if ( $cssAttrs{tableFrame} eq 'above' ) {
            $attr = 'border-style:solid none none none;';
        }
        if ( $cssAttrs{tableFrame} eq 'below' ) {
            $attr = 'border-style:none none solid none;';
        }
        if ( $cssAttrs{tableFrame} eq 'lhs' ) {
            $attr = 'border-style:none none none solid;';
        }
        if ( $cssAttrs{tableFrame} eq 'rhs' ) {
            $attr = 'border-style:none solid none none;';
        }
        if ( $cssAttrs{tableFrame} eq 'hsides' ) {
            $attr = 'border-style:solid none solid none;';
        }
        if ( $cssAttrs{tableFrame} eq 'vsides' ) {
            $attr = 'border-style:none solid none solid;';
        }
        if ( $cssAttrs{tableFrame} eq 'box' ) {
            $attr = 'border-style:solid;';
        }
        if ( $cssAttrs{tableFrame} eq 'border' ) {
            $attr = 'border-style:solid;';
        }
        push( @styles, "$selector {$attr}" );
    }

    # tableborder
    if ( defined $cssAttrs{tableBorder} ) {
        my $tableBorderWidth = $cssAttrs{tableBorder} || 0;
        my $attr = 'border-width:' . $tableBorderWidth . 'px;';
        push( @styles, "$selector {$attr}" );
    }

    # cellborder
    if ( defined $cssAttrs{cellBorder} ) {
        my $cellBorderWidth = $cssAttrs{cellBorder} || 0;
        my $attr = 'border-width:' . $cellBorderWidth . 'px;';
        push( @styles, "$selector td {$attr}" );
        push( @styles, "$selector th {$attr}" );
    }

    # tablewidth
    if ( defined $cssAttrs{tableWidth} ) {
        my $attr = 'width:' . $cssAttrs{tableWidth} . ';';
        push( @styles, "$selector {$attr}" );
    }

    # valign
    if ( defined $cssAttrs{vAlign} ) {
        my $attr = 'vertical-align:' . $cssAttrs{vAlign} . ';';
        push( @styles, "$selector td {$attr}" );
        push( @styles, "$selector th {$attr}" );
    }

    # headerVAlign
    if ( defined $cssAttrs{headerVAlign} ) {
        my $attr = 'vertical-align:' . $cssAttrs{headerVAlign} . ';';
        push( @styles, "$selector th {$attr}" );
    }

    # dataVAlign
    if ( defined $cssAttrs{dataVAlign} ) {
        my $attr = 'vertical-align:' . $cssAttrs{dataVAlign} . ';';
        push( @styles, "$selector td {$attr}" );
    }

    # headerbg
    if ( defined $cssAttrs{headerBg} ) {
        unless ( $cssAttrs{headerBg} =~ /none/i ) {
            my $attr = 'background-color:' . $cssAttrs{headerBg} . ';';
            push( @styles, "$selector th {$attr}" );
        }
    }

    # headerbgsorted
    if ( defined $cssAttrs{headerBgSorted} ) {
        unless ( $cssAttrs{headerBgSorted} =~ /none/i ) {
            my $attr = 'background-color:' . $cssAttrs{headerBgSorted} . ';';
            push( @styles, "$selector th.twikiSortedAscendingCol {$attr}" );
            push( @styles, "$selector th.twikiSortedDescendingCol {$attr}" );
        }
    }

    # headercolor
    if ( defined $cssAttrs{headerColor} ) {
        my $attr = 'color:' . $cssAttrs{headerColor} . ';';
        push( @styles, "$selector th {$attr}" );
        push( @styles, "$selector th a:link {$attr}" );
        push( @styles, "$selector th a:visited {$attr}" );
        push( @styles, "$selector th a:link font {$attr}" );
        push( @styles, "$selector th a:visited font {$attr}" );
        my $hoverLinkColor = $cssAttrs{headerBg} || '#fff';
        my $hoverBackgroundColor = $cssAttrs{headerColor};
        $attr = 'color:'
          . $hoverLinkColor
          . ';background-color:'
          . $hoverBackgroundColor . ';';
        push( @styles, "$selector th a:hover {$attr}" );
        push( @styles, "$selector th a:hover font {$attr}" );
    }

    # databg (array)
    if ( defined $cssAttrs{dataBg} ) {
        unless ( $cssAttrs{dataBg} =~ /none/i ) {
            my $count = 0;
            foreach (@dataBg) {
                my $rowSelector = 'twikiTableRow' . 'dataBg' . $count;
                my $color       = $_;
                my $attr        = 'background-color:' . $_ . ';';
                push( @styles, "$selector tr.$rowSelector td {$attr}" );
                $count++;
            }
        }
    }

    # databgsorted (array)
    if ( defined $cssAttrs{dataBgSorted} ) {
        unless ( $cssAttrs{dataBgSorted} =~ /none/i ) {
            my $count = 0;
            foreach (@dataBgSorted) {
                my $rowSelector = 'twikiTableRow' . 'dataBgSorted' . $count;
                my $color       = $_;
                my $attr        = 'background-color:' . $_ . ';';
                push( @styles,
                    "$selector tr.$rowSelector td.twikiSortedCol {$attr}" );
                $count++;
            }
        }
    }

    # datacolor (array)
    if ( defined $cssAttrs{dataColor} ) {
        unless ( $cssAttrs{dataColor} =~ /none/i ) {
            my $count = 0;
            foreach (@dataColor) {
                my $rowSelector = 'twikiTableRow' . 'dataColor' . $count;
                my $color       = $_;
                my $attr        = 'color:' . $_ . ';';
                push( @styles, "$selector tr.$rowSelector td {$attr}" );
                push( @styles, "$selector tr.$rowSelector td font {$attr}" );
                $count++;
            }
        }
    }

    # columnwidths
    if ( defined $cssAttrs{columnWidths} ) {
        my $count = 0;
        foreach (@columnWidths) {
            my $colSelector = 'twikiTableCol' . $count;
            my $width       = $_;
            my $attr        = 'width:' . $_ . ';';
            push( @styles, "$selector td.$colSelector {$attr}" );
            push( @styles, "$selector th.$colSelector {$attr}" );
            $count++;
        }
    }

    # headeralign
    if ( defined $cssAttrs{headerAlign} ) {
        if ( scalar @headerAlign == 1 ) {
            my $align = $headerAlign[0];
            my $attr  = 'text-align:' . $align . ';';
            push( @styles, "$selector th {$attr}" );
        }
        else {
            my $count = 0;
            foreach (@headerAlign) {
                my $colSelector = 'twikiTableCol' . $count;
                my $width       = $_;
                my $attr        = 'text-align:' . $_ . ';';
                push( @styles, "$selector th.$colSelector {$attr}" );
                $count++;
            }
        }
    }

    # dataAlign
    if ( defined $cssAttrs{dataAlign} ) {
        if ( scalar @dataAlign == 1 ) {
            my $align = $dataAlign[0];
            my $attr  = 'text-align:' . $align . ';';
            push( @styles, "$selector td {$attr}" );
        }
        else {
            my $count = 0;
            foreach (@dataAlign) {
                my $colSelector = 'twikiTableCol' . $count;
                my $width       = $_;
                my $attr        = 'text-align:' . $_ . ';';
                push( @styles, "$selector td.$colSelector {$attr}" );
                $count++;
            }
        }
    }

    # cellspacing : no good css equivalent; use table tag attribute

    # cellpadding
    if ( defined $cssAttrs{cellPadding} ) {
        my $attr = 'padding:' . $cssAttrs{cellPadding} . 'px;';
        push( @styles, "$selector td {$attr}" );
        push( @styles, "$selector th {$attr}" );
    }

    return if !scalar @styles;
    _writeStyleToHead( $id, @styles );
}

sub _writeStyleToHead {
    my ( $id, @styles ) = @_;

    my $style = join( "\n", @styles );
    my $header =
      '<style type="text/css" media="all">' . "\n" . $style . "\n" . '</style>';
    TWiki::Func::addToHEAD( 'TABLEPLUGIN_' . $id, $header );
}

sub emitTable {

    #Validate headerrows/footerrows and modify if out of range
    if ( $headerRows > @curTable ) {
        $headerRows = @curTable;    # limit header to size of table!
    }
    if ( $headerRows + $footerRows > @curTable ) {
        $footerRows = @curTable - $headerRows;  # and footer to whatever is left
    }

    my $sortThisTable = _shouldISortThisTable( $curTable[ $headerRows - 1 ] );
    my $tattrs        = {
        class       => 'twikiTable',
        border      => $tableBorder,
        cellspacing => $cellSpacing,
        cellpadding => $cellPadding,
    };
    $tattrs->{id}      = $tableId      if ($tableId);
    $tattrs->{summary} = $tableSummary if ($tableSummary);
    $tattrs->{frame}   = $tableFrame   if ($tableFrame);
    $tattrs->{rules}   = $tableRules   if ($tableRules);
    $tattrs->{width}   = $tableWidth   if ($tableWidth);

    my $text = $currTablePre . CGI::start_table($tattrs);
    $text .= $currTablePre . CGI::caption($tableCaption) if ($tableCaption);
    my $stype = '';

    # count the number of cols to prevent looping over non-existing columns
    my $maxCols = 0;

    #Flush out any remaining rowspans
    for ( my $i = 0 ; $i < @rowspan ; $i++ ) {
        if ( defined( $rowspan[$i] ) && $rowspan[$i] ) {
            my $nRows = scalar(@curTable);
            my $rspan = $rowspan[$i] + 1;
            my $r     = $nRows - $rspan;
            $curTable[$r][$i]->{attrs} ||= {};
            if ( $rspan > 1 ) {
                $curTable[$r][$i]->{attrs}->{rowspan} = $rspan;
            }
        }
    }

    if (
        (
               defined $sortCol
            && defined $requestedTable
            && $requestedTable == $tableCount
        )
        || defined $initSort
      )
    {

        # DG 08 Aug 2002: Allow multi-line headers
        my @header = splice( @curTable, 0, $headerRows );

        # DG 08 Aug 2002: Skip sorting any trailers as well
        my @trailer = ();
        if ( $footerRows && scalar(@curTable) > $footerRows ) {
            @trailer = splice( @curTable, -$footerRows );
        }

        # Count the maximum number of columns of this table
        for my $row ( 0 .. $#curTable ) {
            my $thisRowMaxColCount = 0;
            for my $col ( 0 .. $#{ $curTable[$row] } ) {
                $thisRowMaxColCount++;
            }
            $maxCols = $thisRowMaxColCount
              if ( $thisRowMaxColCount > $maxCols );
        }

        # Handle multi-row labels by killing rowspans in sorted tables
        for my $row ( 0 .. $#curTable ) {
            for my $col ( 0 .. $#{ $curTable[$row] } ) {
                $curTable[$row][$col]->{attrs}->{rowspan} = 1;
                if ( $curTable[$row][$col]->{type} eq 'Y' ) {
                    $curTable[$row][$col]->{text} =
                      $curTable[ $row - 1 ][$col]->{text};
                    $curTable[$row][$col]->{type} = 'td';
                }
            }
        }

        $stype = $columnType{'UNDEFINED'};

        # only get the column type if within bounds
        if ( $sortCol < $maxCols ) {
            $stype = _guessColumnType($sortCol);
        }

        # invalidate sorting if no valid column
        if ( $stype eq $columnType{'UNDEFINED'} ) {
            undef $initSort;
            undef $sortCol;
        }
        elsif ( $stype eq $columnType{'TEXT'} ) {
            if ( $currentSortDirection == $sortDirection{'DESCENDING'} ) {

                # efficient way of sorting stripped HTML text
                # SMELL: efficient? That's not efficient!
                @curTable = map { $_->[0] }
                  sort { $b->[1] cmp $a->[1] }
                  map { [ $_, _stripHtml( $_->[$sortCol]->{text} ) ] }
                  @curTable;
            }
            if ( $currentSortDirection == $sortDirection{'ASCENDING'} ) {
                @curTable = map { $_->[0] }
                  sort { $a->[1] cmp $b->[1] }
                  map { [ $_, _stripHtml( $_->[$sortCol]->{text} ) ] }
                  @curTable;
            }
        }
        else {
            if ( $currentSortDirection == $sortDirection{'DESCENDING'} ) {
                @curTable =
                  sort { $b->[$sortCol]->{$stype} <=> $a->[$sortCol]->{$stype} }
                  @curTable;
            }
            if ( $currentSortDirection == $sortDirection{'ASCENDING'} ) {
                @curTable =
                  sort { $a->[$sortCol]->{$stype} <=> $b->[$sortCol]->{$stype} }
                  @curTable;
            }

        }

        # DG 08 Aug 2002: Cleanup after the header/trailer splicing
        # this is probably awfully inefficient - but how big is a table?
        @curTable = ( @header, @curTable, @trailer );
    }    # if defined $sortCol ...

    my $rowCount       = 0;
    my $numberOfRows   = scalar(@curTable);
    my $dataColorCount = 0;

    foreach my $row (@curTable) {
        my $rowtext  = '';
        my $colCount = 0;

        # keep track of header cells: if all cells are header cells, do not
        # update the data color count
        my $headerCellCount = 0;
        my $isHeaderRow     = 0;

        foreach my $fcell (@$row) {

            # check if cell exists
            next if ( !$fcell || !$fcell->{type} );

            my $tableAnchor = '';
            next
              if ( $fcell->{type} eq 'X' )
              ;    # data was there so sort could work with col spanning
            my $type = $fcell->{type};
            my $cell = $fcell->{text};
            my $attr = $fcell->{attrs} || {};

            my $newDirection;
            my $isSorted = 0;

            if (
                   $currentSortDirection != $sortDirection{'NONE'}
                && defined $sortCol
                && $colCount == $sortCol

                # Removing the line below hides the marking of sorted columns
                # until the user clicks on a header (KJL)
                # && defined $requestedTable && $requestedTable == $tableCount
                && $stype ne ''
              )
            {
                $isSorted     = 1;
                $newDirection = _getNewSortDirection($currentSortDirection);
            }
            else {
                $newDirection = _getDefaultSortDirection();
            }

            if ( $type eq 'th' ) {
                $headerCellCount++;
                unless ($upchar) {
                    $upchar = CGI::span(
                        { class => 'tableSortIcon tableSortUp' },
                        CGI::img(
                            {
                                src    => $iconUrl . 'tablesortup.gif',
                                border => 0,
                                width  => 11,
                                height => 13,
                                alt    => 'Sorted ascending',
                                title  => 'Sorted ascending'
                            }
                        )
                    );
                    $downchar = CGI::span(
                        { class => 'tableSortIcon tableSortDown' },
                        CGI::img(
                            {
                                src    => $iconUrl . 'tablesortdown.gif',
                                border => 0,
                                width  => 11,
                                height => 13,
                                alt    => 'Sorted descending',
                                title  => 'Sorted descending'
                            }
                        )
                    );
                    $diamondchar = CGI::span(
                        { class => 'tableSortIcon tableSortUp' },
                        CGI::img(
                            {
                                src    => $iconUrl . 'tablesortdiamond.gif',
                                border => 0,
                                width  => 11,
                                height => 13,
                                alt    => 'Sort',
                                title  => 'Sort'
                            }
                        )
                    );
                }

                # DG: allow headers without b.g too (consistent and yes,
                # I use this)
                # html attribute
                $attr->{bgcolor} = $headerBg unless ( $headerBg =~ /none/i );
                $attr->{maxCols} = $maxCols;

                if ($isSorted) {
                    if ( $currentSortDirection == $sortDirection{'ASCENDING'} )
                    {
                        $tableAnchor = $upchar;
                    }
                    if ( $currentSortDirection == $sortDirection{'DESCENDING'} )
                    {
                        $tableAnchor = $downchar;
                    }
                }

                if (   defined $sortCol
                    && $colCount == $sortCol
                    && defined $requestedTable
                    && $requestedTable == $tableCount )
                {

                    $tableAnchor =
                      CGI::a( { name => 'sorted_table' }, '<!-- -->' )
                      . $tableAnchor;
                }

                if ($headerColor) {

                    my $cellAttrs = { color => $headerColor };

                    # html attribute
                    $cell = CGI::font( $cellAttrs, $cell );
                }

                if ( $sortThisTable && $rowCount == $headerRows - 1 ) {
                    if ($isSorted) {
                        unless ( $headerBgSorted =~ /none/i ) {

                            # html attribute
                            $attr->{bgcolor} = $headerBgSorted;
                        }
                    }

                    my $debugText      = '';
                    my $linkAttributes = {
                        href => $url
                          . 'sortcol='
                          . $colCount
                          . ';table='
                          . $tableCount . ';up='
                          . $newDirection
                          . '#sorted_table',
                        rel   => 'nofollow',
                        title => 'Sort by this column'
                    };
                    if ( $cell =~ /\[\[|href/o ) {
                        $cell .=
                            $debugText . ' '
                          . CGI::a( $linkAttributes, $diamondchar )
                          . $tableAnchor;
                    }
                    else {
                        $cell = $debugText
                          . CGI::a( $linkAttributes, $cell )
                          . $tableAnchor;
                    }
                }

            }
            else {

                # $type is not 'th'
                if (@dataBg) {
                    my $bgcolor;
                    if ($isSorted) {
                        $bgcolor =
                          $dataBgSorted[ $dataColorCount %
                          ( $#dataBgSorted + 1 ) ];
                    }
                    else {
                        $bgcolor =
                          $dataBg[ $dataColorCount % ( $#dataBg + 1 ) ];
                    }
                    unless ( $bgcolor =~ /none/i ) {

                        # html attribute
                        $attr->{bgcolor} = $bgcolor;
                    }
                }
                if (@dataColor) {
                    my $color =
                      $dataColor[ $dataColorCount % ( $#dataColor + 1 ) ];

                    unless ( $color =~ /^(none)$/i ) {
                        my $cellAttrs = { color => $color };

                        # html attribute
                        $cell = CGI::font( $cellAttrs, ' ' . $cell . ' ' );
                    }
                }
                $type = 'td' unless $type eq 'Y';
            }    ###if( $type eq 'th' )

            if ($isSorted) {
                $attr->{class} = _appendSortedCssClass( $attr->{class} );
            }

            my $isLastRow = ( $rowCount == $numberOfRows - 1 );
            if ( $attr->{rowspan} ) {
                $isLastRow =
                  ( ( $rowCount + ( $attr->{rowspan} - 1 ) ) ==
                      $numberOfRows - 1 );
            }

            # CSS class name
            $attr->{class} = _appendFirstColumnCssClass( $attr->{class} )
              if $colCount == 0;
            $attr->{class} = _appendLastRowCssClass( $attr->{class} )
              if $isLastRow;

            $colCount++;
            next if ( $type eq 'Y' );
            my $fn = 'CGI::' . $type;
            no strict 'refs';
            $rowtext .= "\n\t\t" . &$fn( $attr, " $cell " );
            use strict 'refs';
        }    # foreach my $fcell ( @$row )

        # assign css class names to tr
        # based on settings: dataBg, dataBgSorted
        my $trClassName = '';

        # just 2 css names is too limited, but we will keep it for compatibility
        # with existing style sheets
        my $rowTypeName =
          ( $rowCount % 2 ) ? 'twikiTableOdd' : 'twikiTableEven';
        $trClassName = _appendToClassList( $trClassName, $rowTypeName );

        if ( scalar @dataBgSorted ) {
            my $modRowNum = $dataColorCount % ( $#dataBgSorted + 1 );
            $trClassName =
              _appendRowNumberCssClass( $trClassName, 'dataBgSorted',
                $modRowNum );
        }
        if ( scalar @dataBg ) {
            my $modRowNum = $dataColorCount % ( $#dataBg + 1 );
            $trClassName =
              _appendRowNumberCssClass( $trClassName, 'dataBg', $modRowNum );
        }
        if ( scalar @dataColor ) {
            my $modRowNum = $dataColorCount % ( $#dataColor + 1 );
            $trClassName =
              _appendRowNumberCssClass( $trClassName, 'dataColor', $modRowNum );
        }
        $rowtext .= "\n\t";
        my $rowHTML = "\n\t" . CGI::Tr( { class => $trClassName }, $rowtext );
        
        $isHeaderRow = ( $headerCellCount == $colCount );
        my $isFooterRow = ( ( $numberOfRows - $rowCount ) <= $footerRows );

        if ($isFooterRow) {

           # this makes one tfoot element per header row due to the line by line
           # nature of this parser - which might be a good thing..
            $rowHTML = "\n\t" . CGI::tfoot($rowHTML . "\n\t");
        }
        elsif ($isHeaderRow) {

           # this makes one thead element per header row due to the line by line
           # nature of this parser - which might be a good thing..
            $rowHTML = "\n\t" . CGI::thead($rowHTML . "\n\t");

            # reset data color count to start with first color after
            # each table heading
            $dataColorCount = 0;
        }
        else {
            $dataColorCount++;
        }
        $text .= $currTablePre . $rowHTML;
        $rowCount++;
    }    # foreach my $row ( @curTable )

    $text .= $currTablePre . CGI::end_table() . "\n";
    _setDefaults();
    return $text;
}

sub handler {
    ### my ( $text, $removed ) = @_;

    unless ($TWiki::Plugins::TablePlugin::initialised) {
        $insideTABLE = 0;
        $tableCount  = 0;

        $twoCol = 1;

        my $cgi = TWiki::Func::getCgiQuery();
        return unless $cgi;

        # Extract and attach existing parameters
        my $plist = $cgi->query_string();
        $plist =~ s/\;/\&/go;
        $plist =~ s/\&?sortcol.*up=[0-9]+\&?//go;
        $plist .= '&' if $plist;
        $url = $cgi->url . $cgi->path_info() . '?' . $plist;
        $url =~ s/\&/\&amp;/go;

        $sortColFromUrl =
          $cgi->param('sortcol');    # zero based: 0 is first column
        $requestedTable = $cgi->param('table');
        $up             = $cgi->param('up');

        $sortTablesInText = 0;
        $sortAttachments  = 0;
        my $tmp = TWiki::Func::getPreferencesValue('TABLEPLUGIN_SORT');
        if ( !$tmp || $tmp =~ /^all$/oi ) {
            $sortTablesInText = 1;
            $sortAttachments  = 1;
        }
        elsif ( $tmp =~ /^attachments$/oi ) {
            $sortAttachments = 1;
        }

        $pluginAttrs =
          TWiki::Func::getPreferencesValue('TABLEPLUGIN_TABLEATTRIBUTES');
        $prefsAttrs = TWiki::Func::getPreferencesValue('TABLEATTRIBUTES');
        _setDefaults();

        $TWiki::Plugins::TablePlugin::initialised = 1;
    }

    undef $initSort;
    $insideTABLE = 0;

    my $defaultSort = $sortAllTables;

    my $acceptable = $sortAllTables;
    my @lines = split( /\r?\n/, $_[0] );
    for (@lines) {
        if (s/%TABLE(?:{(.*?)})?%/_parseParameters($1, 1)/se) {
            $acceptable = 1;
        }
        elsif ( $acceptable
            && s/^(\s*)\|(.*\|\s*)$/_processTableRow($1,$2)/eo )
        {
            $insideTABLE = 1;
        }
        elsif ($insideTABLE) {
            $_           = emitTable() . $_;
            $insideTABLE = 0;
            undef $initSort;
            $sortAllTables = $defaultSort;
            $acceptable    = $defaultSort;
        }
    }
    $_[0] = join( "\n", @lines );

    if ($insideTABLE) {
        $_[0] .= emitTable();
    }
}

1;
