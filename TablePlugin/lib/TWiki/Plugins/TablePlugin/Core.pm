# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001-2003 John Talintyre, jet@cheerful.com
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2005 TWiki Contributors
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
             $insideTABLE $tableCount @curTable $sortCol $requestedTable $up
             $sortTablesInText $sortAttachments $currTablePre
             $tableWidth @columnWidths
             $tableBorder $tableFrame $tableRules $cellPadding $cellSpacing 
             @headerAlign @dataAlign $vAlign
             $headerBg $headerColor $sortAllTables $twoCol @dataBg @dataColor
             @isoMonth
             $headerRows $footerRows
             $upchar $downchar $diamondchar $url
             @isoMonth %mon2num $initSort $initDirection
             @rowspan $pluginAttrs $prefsAttrs $tableId $tableSummary $tableCaption );

BEGIN {
    $translationToken = "\0";
    $currTablePre = '';
    $upchar = '';
    $downchar = '';
    $diamondchar = '';
    @isoMonth = (
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' );
    {
        my $count = 0;
        %mon2num = map { $_ => $count++ } @isoMonth;
    }
};

sub _setDefaults {
    $sortAllTables = $sortTablesInText;
    $tableBorder  = 1;
    $tableFrame   = '';
    $tableRules   = '';
    $cellSpacing  = 1;
    $cellPadding  = 0;
    $tableWidth   = '';
    @columnWidths = ( );
    $headerRows   = 1;
    $footerRows   = 0;
    @headerAlign  = ( );
    @dataAlign    = ( );
    $vAlign       = '';
    $headerBg     = "#99CCCC";
    $headerColor  = '';
    @dataBg       = ( "#FFFFCC", "#FFFFFF" );
    @dataColor    = ( );
    $tableId      = '';
    $tableSummary      = '';
    $tableCaption      = '';
    undef $initSort;

    _parseParameters( $pluginAttrs );
    _parseParameters( $prefsAttrs );   # Preferences setting
}

# Table attributes defined as a Plugin setting, a preferences setting
# e.g. in WebPreferences or as a %TABLE{...}% setting
sub _parseParameters {
    my( $args ) = @_;

    return '' unless( defined( $args ));
    return '' unless( $args =~ /\S/ );

    my %params = TWiki::Func::extractParameters( $args );

    # Defines which column to initially sort : ShawnBradford 20020221
    my $tmp = $params{initsort};
    $initSort = $tmp if ( $tmp );

    # Defines which direction to sort the column set by initsort :
    # ShawnBradford 20020221
    $tmp = $params{initdirection};
    $initDirection = 0 if( defined $tmp && $tmp =~/^down$/i );
    $initDirection = 1 if( defined $tmp && $tmp =~/^up$/i );

    $tmp = $params{sort};
    $tmp = '0' if( defined $tmp && $tmp =~ /^off$/oi );
    $sortAllTables = $tmp if( defined $tmp && $tmp ne '' );

    $tmp = $params{tableborder};
    $tableBorder = $tmp if( defined $tmp && $tmp ne '' );

    $tmp = $params{tableframe};
    $tableFrame = $tmp if( defined $tmp && $tmp ne '' );

    $tmp = $params{tablerules};
    $tableRules = $tmp if( defined $tmp && $tmp ne '' );

    $tmp = $params{cellpadding};
    $cellPadding = $tmp if( defined $tmp && $tmp ne '' );

    $tmp = $params{cellspacing};
    $cellSpacing = $tmp if( defined $tmp && $tmp ne '' );

    $tmp = $params{headeralign};
    @headerAlign = split( /,\s*/, $tmp ) if( defined $tmp );

    $tmp = $params{dataalign};
    @dataAlign = split( /,\s*/, $tmp ) if( defined $tmp );

    $tmp = $params{tablewidth};
    $tableWidth = $tmp if( defined $tmp );

    $tmp = $params{columnwidths};
    @columnWidths = split ( /, */, $tmp ) if( defined $tmp );

    $tmp = $params{headerrows};
    $headerRows = $tmp if( defined $tmp && $tmp ne '' );
    $headerRows = 1 if( $headerRows < 1 );

    $tmp = $params{footerrows};
    $footerRows = $tmp if( defined $tmp && $tmp ne '' );

    $tmp = $params{valign};
    $vAlign = $tmp if( defined $tmp );

    $tmp = $params{headerbg};
    $headerBg = $tmp if( defined $tmp );

    $tmp = $params{headercolor};
    $headerColor = $tmp if( defined $tmp );

    $tmp = $params{databg};
    @dataBg = split( /,\s*/, $tmp ) if( defined $tmp );

    $tmp = $params{datacolor};
    @dataColor = split( /,\s*/, $tmp ) if( defined $tmp );
    
    $tmp = $params{id};
    $tableId = $tmp if( defined $tmp );

    $tmp = $params{summary};
    $tableSummary = $tmp if( defined $tmp );
    
    $tmp = $params{caption};
    $tableCaption = $tmp if( defined $tmp );
    
    return $currTablePre.'<nop>';
}

# Convert text to number and date if syntactically possible
sub _convertToNumberAndDate {
    my( $text ) = @_;

    $text =~ s/&nbsp;/ /go;

    my $num = undef;
    my $date = undef;
    if( $text =~ /^\s*$/ ) {
        $num = 0;
        $date = 0;
    }

    if( $text =~ m|^\s*([0-9]{1,2})[-\s/]*([A-Z][a-z][a-z])[-\s/]*([0-9]{4})\s*-\s*([0-9][0-9]):([0-9][0-9])| ) {
        # "31 Dec 2003 - 23:59", "31-Dec-2003 - 23:59",
        # "31 Dec 2003 - 23:59 - any suffix"
        $date = timegm(0, $5, $4, $1, $mon2num{$2}, $3 - 1900);
    } elsif( $text =~ m|^\s*([0-9]{1,2})[-\s/]([A-Z][a-z][a-z])[-\s/]([0-9]{2,4})\s*$| ) {
        # "31 Dec 2003", "31 Dec 03", "31-Dec-2003", "31/Dec/2003"
        my $year = $3;
        $year += 1900 if( length( $year ) == 2 && $year > 80 );
        $year += 2000 if( length( $year ) == 2 );
        $date = timegm( 0, 0, 0, $1, $mon2num{$2}, $year - 1900 );
    } elsif ( $text =~ /^\s*[0-9]+(\.[0-9]+)?\s*$/ ) {
        $num = $text;
    }

    return( $num, $date );
}

sub _processTableRow {
    my( $thePre, $theRow ) = @_;

    $currTablePre = $thePre || '';
    my $span = 0;
    my $l1 = 0;
    my $l2 = 0;
    if( ! $insideTABLE ) {
        @curTable = ();
        @rowspan = ();
        $tableCount++;
    }
    $theRow =~ s/\t/   /go;  # change tabs to space
    $theRow =~ s/\s*$//o;    # remove trailing spaces
    $theRow =~ s/(\|\|+)/$translationToken.length($1)."\|"/geo;# calc COLSPAN
    my $colCount = 0;
    my @row = ();
    $span = 0;
    my $value = '';
    foreach( split( /\|/, $theRow ) ) {
        my $attr = {};
        $span = 1;
        #AS 25-5-01 Fix to avoid matching also single columns
        if ( s/$translationToken([0-9]+)// ) {
            $span = $1;
            $attr->{colspan} = $span;
        }
        s/^\s+$/ &nbsp; /o;
        ( $l1, $l2 ) = ( 0, 0 );
        if( /^(\s*).*?(\s*)$/ ) {
            $l1 = length( $1 );
            $l2 = length( $2 );
        }
        if( $l1 >= 2 ) {
            if( $l2 <= 1 ) {
                $attr->{align} = 'right';
            } else {
                $attr->{align} = 'center';
            }
        }
        if( defined $columnWidths[$colCount] &&
              $columnWidths[$colCount] && $span <= 2 ) {
            $attr->{width} = $columnWidths[$colCount];
        }
        if( /^\s*\^\s*$/ ) { # row span above
            $rowspan[$colCount]++;
            push @row, { text => $value, type => 'Y' };
        } else {
            for (my $col = $colCount; $col < ($colCount+$span); $col++) {
                if( defined($rowspan[$col]) && $rowspan[$col] ) {
                    my $nRows = scalar(@curTable);
                    my $rspan = $rowspan[$col]+1;
                    $curTable[$nRows - $rspan][$col]->{attrs}->{rowspan} =
                      $rspan;
                    undef($rowspan[$col]);
                }
            }

			my $direction = $up ? 0 : 1;
			my $dir = 0;
			$dir = $direction if( defined( $sortCol ) &&
                                        $colCount == $sortCol );
			if( defined( $requestedTable ) &&
					defined( $sortCol ) && 
						( $requestedTable eq $tableCount ) &&
							( $colCount == $sortCol )) {
				if( $dir == 0 ) {
					$attr->{class} .= 'twikiSortedAscendingCol';
				} else {
					$attr->{class} .= 'twikiSortedDescendingCol';
				}
			}
			
			if( /^\s*\*(.*)\*\s*$/ ) {
                $value = $1;
                if( @headerAlign ) {
                    my $align = @headerAlign[$colCount % ($#headerAlign + 1) ];
                    $attr->{align} = $align;
                }

                $attr->{valign} = $vAlign if $vAlign;
                $attr->{class} = _appendFirstRowCssClass( $attr->{class} ) if $colCount == 0;
                push @row, { text => $value, attrs => $attr, type => 'th' };
            } else {
                if( /^\s*(.*?)\s*$/ ) {   # strip white spaces
                    $_ = $1;
                }
                $value = $_;
                if( @dataAlign ) {
                    my $align = @dataAlign[$colCount % ($#dataAlign + 1) ];
                    $attr->{align} = $align;
                }
                $attr->{valign} = $vAlign if $vAlign;
                $attr->{class} = _appendFirstRowCssClass( $attr->{class} ) if $colCount == 0;
                push @row, { text => $value, attrs => $attr, type => 'td' };
            }
        }
        while( $span > 1 ) {
            push @row, { text => $value, type => 'X' };
            $colCount++;
            $span--;
        }
        $colCount++;
    }
    push @curTable, \@row;
    return $currTablePre.'<nop>'; # Avoid TWiki converting empty lines to new paras
}

# Determine whether to generate sorting headers for this table. The header
# indicates the context of the table (body or file attachment)
sub _shouldISortThisTable {
    my( $header ) = @_;

    return 0 unless $sortAllTables;

    # All cells in header are headings?
    foreach my $cell ( @$header ) {
        return 0 if( $cell->{type} ne 'th' );
    }

    return 1;
}

# Guess if column is a date, number or plain text
sub _guessColumnType {
    my( $col ) = @_;
    my $isDate = 1;
    my $isNum  = 1;
    my $num = '';
    my $date = '';
    foreach my $row ( @curTable ) {
        ( $num, $date ) = _convertToNumberAndDate( $row->[$col]->{text} );
        $isDate = 0 if( ! defined( $date ) );
        $isNum  = 0 if( ! defined( $num ) );
        last if( !$isDate && !$isNum );
        $row->[$col]->{date} = $date;
        $row->[$col]->{number} = $num;
    }
    my $type = 'text';
    if( $isDate ) {
        $type = 'date';
    } elsif( $isNum ) {
        $type = 'number';
    }
    return $type;
}

# Remove HTML from text so it can be sorted
sub _stripHtml {
    my( $text ) = @_;
    $text ||= '';
    $text =~ s/\&nbsp;/ /go;                     # convert space
    $text =~ s/\[\[[^\]]+\]\[([^\]]+)\]\]/$1/go; # extract label from [[...][...]] link
    $text =~ s/<[^>]+>//go;                      # strip HTML
    $text =~ s/^ *//go;                          # strip leading space space
    $text = lc( $text );                         # convert to lower case
    return $text;
}

# Append CSS class name for "first column" to (possibly) already defined class names
sub _appendFirstRowCssClass {
	my ( $className ) = @_;
	$className .= ' ' if length( $className ) > 0;
	$className .= 'twikiFirstCol';
	return $className;
}

sub emitTable {
    #Validate headerrows/footerrows and modify if out of range
    if ( $headerRows > @curTable ) {
        $headerRows = @curTable; # limit header to size of table!
    }
    if ( $headerRows + $footerRows > @curTable ) {
        $footerRows = @curTable - $headerRows; # and footer to whatever is left
    }
    my $direction = $up ? 0 : 1;
    my $sortThisTable = _shouldISortThisTable( $curTable[$headerRows-1] );
    my $tattrs = { class => 'twikiTable',
                   border => $tableBorder,
                   cellspacing => $cellSpacing,
                   cellpadding => $cellPadding };
    $tattrs->{id} = $tableId if( $tableId );
    $tattrs->{summary} = $tableSummary if( $tableSummary );
    $tattrs->{frame} = $tableFrame if( $tableFrame );
    $tattrs->{rules} = $tableRules if( $tableRules );
    $tattrs->{width} = $tableWidth if( $tableWidth );
    my $text = $currTablePre.CGI::start_table( $tattrs );
    $text .= $currTablePre.CGI::caption( $tableCaption ) if( $tableCaption );
    my $stype = '';

    #Flush out any remaining rowspans
    for (my $i = 0; $i < @rowspan; $i++) {
        if( defined($rowspan[$i]) && $rowspan[$i] ) {
            my $nRows = scalar(@curTable);
            my $rspan = $rowspan[$i]+1;
            my $r = $nRows - $rspan;
            $curTable[$r][$i]->{attrs} ||= {};
            $curTable[$r][$i]->{attrs}->{rowspan} = $rspan;
        }
    }

    #Added to aid initial sorting direction and column : ShawnBradford 20020221
    if ( defined( $sortCol ) ) {
        undef $initSort;
    } elsif( defined( $initSort ) ) {
        $sortCol = $initSort - 1;
        $up = $initDirection;
        $direction = $up ? 0 : 1;
        $requestedTable = $tableCount;
    }

    if(( defined( $sortCol ) &&
           defined( $requestedTable ) &&
             $requestedTable eq $tableCount )
         || defined( $initSort ) ) {

        # DG 08 Aug 2002: Allow multi-line headers
        my @header = splice( @curTable, 0, $headerRows );
        # DG 08 Aug 2002: Skip sorting any trailers as well
        my @trailer = ();
        if ( $footerRows && scalar( @curTable ) > $footerRows ) {
            @trailer = splice( @curTable, -$footerRows );
        }

        # Handle multi-row labels by killing rowspans in sorted tables
        for my $row (0..$#curTable) {
            for my $col (0..$#{$curTable[$row]}) {
                $curTable[$row][$col]->{attrs}->{rowspan} = 1;
                if( $curTable[$row][$col]->{type} eq 'Y' ) {
                    $curTable[$row][$col]->{text} =
                      $curTable[$row-1][$col]->{text};
                    $curTable[$row][$col]->{type} = 'td';
                }
            }
        }

        $stype = _guessColumnType( $sortCol );
        if( $stype eq 'text' ) {
            if( $up ) {
                # efficient way of sorting stripped HTML text
                # SMELL: efficient? That's not efficient!
                @curTable = map { $_->[0] }
                  sort { $b->[1] cmp $a->[1] }
                    map { [ $_, _stripHtml( $_->[$sortCol]->{text} ) ] }
                      @curTable;
            } else {
                @curTable = map { $_->[0] }
                  sort { $a->[1] cmp $b->[1] }
                    map { [ $_, _stripHtml( $_->[$sortCol]->{text} ) ] }
                      @curTable;
            }
        } else {
            if( $up ) {
                @curTable = sort {
                    $b->[$sortCol]->{$stype} <=> $a->[$sortCol]->{$stype} }
                  @curTable;
            } else {
                @curTable = sort {
                    $a->[$sortCol]->{$stype} <=> $b->[$sortCol]->{$stype} }
                  @curTable;
            }

        }

        # DG 08 Aug 2002: Cleanup after the header/trailer splicing
        # this is probably awfully inefficient - but how big is a table?
        @curTable = ( @header, @curTable, @trailer );
    }
    my $rowCount = 0;
    my $dataColorCount = 0;
    my $resetCountNeeded = 0;
    my $arrow = '';
    foreach my $row ( @curTable ) {
        my $rowtext = '';
        my $colCount = 0;
        foreach my $fcell ( @$row ) {
            $arrow = '';
            next if( $fcell->{type} eq 'X' ); # data was there so sort could work with col spanning
            my $type = $fcell->{type};
            my $cell = $fcell->{text};
            my $attr = $fcell->{attrs} || {};

            if( $type eq 'th' ) {
                # reset data color count to start with first color after
                # each table heading
                $dataColorCount = 0 if( $resetCountNeeded );
                $resetCountNeeded = 0;
                unless( $upchar ) {
                    my $gfx = TWiki::Func::getPubUrlPath().'/'.
                      $TWiki::Plugins::TablePlugin::installWeb.
                        '/TablePlugin/';

                    $upchar = CGI::img({ src=> $gfx.'up.gif',
                                         alt => 'up' });
                    $downchar = CGI::img({ src =>$gfx.'down.gif',
                                           alt => 'down'});
                    $diamondchar = CGI::img({ src => $gfx.'diamond.gif',
                                              border => 0, alt => 'sort'});
                }

                # DG: allow headers without b.g too (consistent and yes,
                # I use this)
                $attr->{bgcolor} = $headerBg unless( $headerBg =~ /none/i );
                my $dir = 0;
                $dir = $direction if( defined( $sortCol ) &&
                                        $colCount == $sortCol );
                if( defined( $sortCol ) && $colCount == $sortCol &&
                      $stype ne '' ) {
                    if( $dir == 0 ) {
                        $arrow = CGI::a({ name=>'sorted_table' },
                                        CGI::span({ title=>$stype.
                                                      ' sorted ascending'},
                                                  $upchar));
                        $attr->{class} = 'twikiSortedAscendingCol';
                    } else {
                        $arrow = CGI::a(
                            { name=>'sorted_table' },
                            CGI::span({ title=>$stype.
                                          ' sorted descending'},
                                      $downchar));
                        $attr->{class} = 'twikiSortedDescendingCol';
                    }
                    $attr->{class} = _appendFirstRowCssClass( $attr->{class} ) if $colCount == 0;
                }
                if( $headerColor ) {
                    $cell = CGI::font( { color => $headerColor }, $cell );
                }
                if( $sortThisTable && $rowCount == $headerRows - 1 ) {
                    if( $cell =~ /\[\[|href/o ) {
                        $cell .= ' '.CGI::a({ href => $url.
                                                'sortcol='.$colCount.
                                                  ';table='.$tableCount.
                                                    ';up='.$dir.
                                                      '#sorted_table',
                                              rel => 'nofollow',
                                              title => 'Sort by this column'},
                                            $diamondchar).$arrow;
                    } else {
                        $cell = CGI::a({ href => $url.
                                           'sortcol='.$colCount.
                                             ';table='.$tableCount.
                                               ';up='.$dir.
                                                 '#sorted_table',
                                         rel=>'nofollow',
                                         title=>'Sort by this column'},
                                       $cell ).$arrow;
                    }
                } else {
                    $cell = ' *'.$cell.'* ';
                }

            } else {
                $resetCountNeeded = 1 if( $colCount == 0 );
                if( @dataBg ) {
                    my $color = $dataBg[$dataColorCount % ($#dataBg+1) ];
                    $attr->{bgcolor} = $color
                      unless( $color =~ /none/i );
                }
                if( @dataColor ) {
                    my $color = $dataColor[$dataColorCount % ($#dataColor+1) ];
                    $cell = CGI::font({ color=>$color }, $cell)
                      unless $color =~ /^(|none)$/i;
                }
                $type = 'td' unless $type eq 'Y';
            }
            $colCount++;
            next if( $type eq 'Y' );
            my $fn = 'CGI::'.$type;
            no strict 'refs';
            $rowtext .= &$fn($attr, " $cell ");
            use strict 'refs';
        }
        $text .= $currTablePre.CGI::Tr( { class=> ($rowCount % 2)?'twikiTableOdd':'twikiTableEven'}, $rowtext )."\n";
        $rowCount++;
        $dataColorCount++;
    }
    $text .= $currTablePre.CGI::end_table()."\n";
    _setDefaults();
    return $text;
}

sub handler {
    ### my ( $text, $removed ) = @_;

    unless( $TWiki::Plugins::TablePlugin::initialised ) {
        $insideTABLE = 0;
        $tableCount = 0;

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

        $sortCol = $cgi->param( 'sortcol' );
        $requestedTable = $cgi->param( 'table' );
        $up = $cgi->param( 'up' );

        $sortTablesInText = 0;
        $sortAttachments = 0;
        my $tmp = TWiki::Func::getPreferencesValue( 'TABLEPLUGIN_SORT' );
        if( ! $tmp || $tmp =~ /^all$/oi ) {
            $sortTablesInText = 1;
            $sortAttachments = 1;
        } elsif( $tmp =~ /^attachments$/oi ) {
            $sortAttachments =1;
        }

        $pluginAttrs =
          TWiki::Func::getPreferencesValue( 'TABLEPLUGIN_TABLEATTRIBUTES' );
        $prefsAttrs =
          TWiki::Func::getPreferencesValue( 'TABLEATTRIBUTES' );
        _setDefaults();

        $TWiki::Plugins::TablePlugin::initialised = 1;
    }

    undef $initSort;
    $insideTABLE = 0;

    my $defaultSort = $sortAllTables;

    my $acceptable = $sortAllTables;
    my @lines = split( /\r?\n/, $_[0] );
    for ( @lines ) {
        if( s/%TABLE(?:{(.*?)})?%/_parseParameters($1)/se ) {
            $acceptable = 1;
        }
        elsif( $acceptable &&
                 s/^(\s*)\|(.*\|\s*)$/_processTableRow($1,$2)/eo ) {
            $insideTABLE = 1;
        }
        elsif( $insideTABLE ) {
            $_ = emitTable() . $_;
            $insideTABLE = 0;
            undef $initSort;
            $sortAllTables = $defaultSort;
            $acceptable = $defaultSort;
        }
    }
    $_[0] = join( "\n", @lines );

    if( $insideTABLE ) {
        $_[0] .= emitTable();
    }
}

1;
