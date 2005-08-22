# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001-2003 John Talintyre, jet@cheerful.com
# Copyright (C) 2001-2004 Peter Thoeny, peter@thoeny.com
#
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
use strict;

package TWiki::Plugins::TablePlugin::Core;

use Time::Local;

use vars qw( $translationToken
             $insideTABLE $tableCount @curTable $sortCol $requestedTable $up
             $doBody $doAttachments $currTablePre $tableWidth @columnWidths
             $tableBorder $tableFrame $tableRules $cellPadding $cellSpacing 
             @headerAlign @dataAlign $vAlign
             $headerBg $headerColor $doSort $twoCol @dataBg @dataColor
             @isoMonth
             $headerRows $footerRows
             @fields $upchar $downchar $diamondchar $url
             @isoMonth %mon2num $initSort $initDirection
             @rowspan );

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

    @fields = ( 'text', 'attributes', 'th td X', 'numbers', 'dates' );
    # X means a spanned cell
};

sub _setDefaults {
    $doSort       = $doBody;
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
    undef $initSort;
}

# Table attributes defined as a Plugin setting, a preferences setting
# e.g. in WebPreferences or as a %TABLE{...}% setting
sub _parseParameters {
    my( $args ) = @_;

    return '' if( $args =~/^\s*$/ );

    my %params = TWiki::Func::extractParameters( $args );

    # Defines which column to initially sort : ShawnBradford 20020221
    my $tmp = $params{initsort};
    $initSort = $tmp if ( $tmp );

    # Defines which direction to sort the column set by initsort :
    # ShawnBradford 20020221
    $tmp = $params{initdirection};
    $initDirection = 0 if( $tmp && $tmp =~/^down$/i );
    $initDirection = 1 if( $tmp && $tmp =~/^up$/i );

    $tmp = $params{sort};
    $tmp = '0' if( $tmp && $tmp =~ /^off$/oi );
    $doSort = $tmp if( $tmp && $tmp ne '' );

    $tmp = $params{tableborder};
    $tableBorder = $tmp if( $tmp && $tmp ne '' );

    $tmp = $params{tableframe};
    $tableFrame = $tmp if( $tmp && $tmp ne '' );

    $tmp = $params{tablerules};
    $tableRules = $tmp if( $tmp && $tmp ne '' );

    $tmp = $params{cellpadding};
    $cellPadding = $tmp if( $tmp && $tmp ne '' );

    $tmp = $params{cellspacing};
    $cellSpacing = $tmp if( $tmp && $tmp ne '' );

    $tmp = $params{headeralign};
    @headerAlign = split( /,\s*/, $tmp ) if( $tmp );

    $tmp = $params{dataalign};
    @dataAlign = split( /,\s*/, $tmp ) if( $tmp );

    $tmp = $params{tablewidth};
    $tableWidth = $tmp if( $tmp );

    $tmp = $params{columnwidths};
    @columnWidths = split ( /, */, $tmp ) if( $tmp );

    $tmp = $params{headerrows};
    $headerRows = $tmp if( $tmp && $tmp ne '' );
    $headerRows = 1 if( $headerRows < 1 );

    $tmp = $params{footerrows};
    $footerRows = $tmp if( $tmp && $tmp ne '' );

    $tmp = $params{valign};
    $vAlign = $tmp if( $tmp );

    $tmp = $params{headerbg};
    $headerBg = $tmp if( $tmp );

    $tmp = $params{headercolor};
    $headerColor = $tmp if( $tmp );

    $tmp = $params{databg};
    @dataBg = split( /,\s*/, $tmp ) if( $tmp );

    $tmp = $params{datacolor};
    @dataColor = split( /,\s*/, $tmp ) if( $tmp );

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
    $theRow =~ s/(\|\|+)/$translationToken . length($1) . "\|"/geo;  # calc COLSPAN
    my $colCount = 0;
    my @row = ();
    $span = 0;
    my $value = '';
    foreach( split( /\|/, $theRow ) ) {
        $colCount++;
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
        if( defined $columnWidths[$colCount-1] && $columnWidths[$colCount-1] && $span <= 2 ) {
            $attr->{width} = $columnWidths[$colCount-1];
        }
        if( /^\s*\^\s*$/ ) { # row span above
            $rowspan[$colCount-1]++;
            push @row, [ $value, '', 'X' ];
        } else {
            for (my $col = $colCount-1; $col < ($colCount+$span-1); $col++) {
                if( defined($rowspan[$col]) && $rowspan[$col] ) {
                    my $nRows = scalar(@curTable);
                    my $rspan = $rowspan[$col]+1;
                    $curTable[$nRows-$rspan][$col][1]->{rowspan} = $rspan;
                    undef($rowspan[$col]);
                }
            }
            if( /^\s*\*(.*)\*\s*$/ ) {
                $value = $1;
                if( @headerAlign ) {
                    my $align = @headerAlign[($colCount - 1) % ($#headerAlign + 1) ];
                    $attr->{align} = $align;
                }

                $attr->{valign} = $vAlign if $vAlign;
                $attr->{class} = 'twikiFirstCol' if $colCount == 1;
                push @row, [ $value, $attr, 'th' ];
            } else {
                if( /^\s*(.*?)\s*$/ ) {   # strip white spaces
                    $_ = $1;
                }
                $value = $_;
                if( @dataAlign ) {
                    my $align = @dataAlign[($colCount - 1) % ($#dataAlign + 1) ];
                    $attr->{align} = $align;
                }
                $attr->{valign} = $vAlign if $vAlign;
                $attr->{class} = 'twikiFirstCol' if $colCount == 1;
                push @row, [ $value, $attr, 'td' ];
            }
        }
        while( $span > 1 ) {
            push @row, [ $value, '', 'X' ];
            $colCount++;
            $span--;
        }
    }
    push @curTable, \@row;
    return $currTablePre.'<nop>'; # Avoid TWiki converting empty lines to new paras
}

# Do sort?
sub doIt {
    my( $header ) = @_;

    # Attachments table?
    if( $header->[0]->[0] =~ /FileAttachment/ ) {
        return $doAttachments;
    }

    my $doIt = $doSort;
    if( $doSort ) {
        # All cells in header are headings?
        foreach my $cell ( @$header ) {
            if( $cell->[2] ne 'th' ) {
                $doIt = 0;
                last;
            }
        }
    }

    return $doIt;
}

# Guess if a column is a date (4), number (3) or plain text (0)
sub _guessColumnType {
    my( $col ) = @_;
    my $isDate = 1;
    my $isNum  = 1;
    my $num = '';
    my $date = '';
    foreach my $row ( @curTable ) {
        ( $num, $date ) = _convertToNumberAndDate( $row->[$col]->[0] );
        $isDate = 0 if( ! defined( $date ) );
        $isNum  = 0 if( ! defined( $num ) );
        last if( !$isDate && !$isNum );
        $row->[$col]->[4] = $date;
        $row->[$col]->[3] = $num;
    }

    if( $isDate ) {
        return 4;
    } elsif( $isNum ) {
        return 3;
    } else {
        return 0;
    }
}

# Remove HTML from text so it can be sorted
sub _stripHtml {
    my( $text ) = @_;
    $text =~ s/\&nbsp;/ /go;                     # convert space
    $text =~ s/\[\[[^\]]+\]\[([^\]]+)\]\]/$1/go; # extract label from [[...][...]] link
    $text =~ s/<[^>]+>//go;                      # strip HTML
    $text =~ s/^ *//go;                          # strip leading space space
    $text = lc( $text );                         # convert to lower case
    return $text;
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
    my $doIt = doIt( $curTable[$headerRows-1] );
    my $tattrs = { border => $tableBorder,
                   cellspacing => $cellSpacing,
                   cellpadding => $cellPadding };
    $tattrs->{frame} = $tableFrame if( $tableFrame );
    $tattrs->{rules} = $tableRules if( $tableRules );
    $tattrs->{width} = $tableWidth if( $tableWidth );
    my $text = $currTablePre.CGI::start_table( $tattrs );
    my $stype = '';

    #Flush out any remaining rowspans
    for (my $i = 0; $i < @rowspan; $i++) {
        if( defined($rowspan[$i]) && $rowspan[$i] ) {
            my $nRows = scalar(@curTable);
            my $rspan = $rowspan[$i]+1;
            my $r = $nRows - $rspan;
            $curTable[$r][$i][1]->{rowspan} = $rspan;
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

        # Handle multi-row labels
        for my $row (0..$#curTable) {
            for my $col (0..$#{$curTable[$row]}) {
                delete $curTable[$row][$col][1]->{rowspan}
                  if $curTable[$row][$col][1];
                $curTable[$row][$col] =
                  [ $curTable[$row-1][$col][0],
                    $curTable[$row][$col][1],
                    'td',
                    $curTable[$row][$col][3],
                    $curTable[$row][$col][4] ]
                    if $curTable[$row][$col][2] eq 'X';
            }
        }

        $stype = _guessColumnType( $sortCol );
        if( $stype ) {
            if( $up ) {
                @curTable = sort { $b->[$sortCol]->[$stype] <=> $a->[$sortCol]->[$stype] } @curTable;
            } else {
                @curTable = sort { $a->[$sortCol]->[$stype] <=> $b->[$sortCol]->[$stype] } @curTable;
            }

        } else {
            if( $up ) {
                # efficient way of sorting stripped HTML text
                # SMELL: efficient? That's not efficient!
                @curTable = map { $_->[0] }
                  sort { $b->[1] cmp $a->[1] }
                    map { [ $_, _stripHtml( $_->[$sortCol]->[0] ) ] } @curTable;
            } else {
                @curTable = map { $_->[0] }
                  sort { $a->[1] cmp $b->[1] }
                    map { [ $_, _stripHtml( $_->[$sortCol]->[0] ) ] } @curTable;
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
            next if( $fcell->[2] eq 'X' ); # data was there so sort could work with col spanning
            my $type = $fcell->[2];
            my $cell = $fcell->[0];
            my $attr = $fcell->[1] || {};
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
                                        CGI::span({ title=>$fields[$stype].
                                                      ' sorted ascending'},
                                                  $upchar));
                        $attr->{class} = 'twikiSortedAscendingCol';
                    } else {
                        $arrow = CGI::a({ name=>'sorted_table' },
                                        CGI::span({ title=>$fields[$stype].
                                                      ' sorted descending'},
                                                  $downchar));
                        $attr->{class} = 'twikiSortedDescendingCol';
                    }
                }
                if( $headerColor ) {
                    $cell = CGI::font( { color => $headerColor }, $cell );
                }
                if( $doIt && $rowCount == $headerRows - 1 ) {
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
            }
            my $fn = 'CGI::'.$type;
            no strict 'refs';
            $rowtext .= &$fn($attr, $cell);
            use strict 'refs';
            $colCount++;
        }
        $text .= $currTablePre.CGI::Tr( {}, $rowtext )."\n";
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

        $doBody = 0;
        $doAttachments = 0;
        my $tmp = TWiki::Func::getPreferencesValue( 'TABLEPLUGIN_SORT' );
        if( ! $tmp || $tmp =~ /^all$/oi ) {
            $doBody = 1;
            $doAttachments = 1;
        } elsif( $tmp =~ /^attachments$/oi ) {
            $doAttachments =1;
        }

        _setDefaults();
        my $pluginAttrs =
          TWiki::Func::getPreferencesValue( 'TABLEPLUGIN_TABLEATTRIBUTES' );
        _parseParameters( $pluginAttrs );
        my $prefsAttrs =
          TWiki::Func::getPreferencesValue( 'TABLEATTRIBUTES' );
        _parseParameters( $prefsAttrs );   # Preferences setting

        $TWiki::Plugins::TablePlugin::initialised = 1;
    }

    undef $initSort;
    $insideTABLE = 0;

    my @lines = split( /\r?\n/, $_[0] );
    for ( @lines ) {
        $_ =~ s/%TABLE{(.*?)}%/_parseParameters($1)/seo;
        if( s/^(\s*)\|(.*\|\s*)$/_processTableRow($1,$2)/eo ) {
            $insideTABLE = 1;
        } elsif( $insideTABLE ) {
            $_ = emitTable() . $_;
            $insideTABLE = 0;
            undef $initSort;
        }
    }
    $_[0] = join( "\n", @lines );

    if( $insideTABLE ) {
        $_[0] .= emitTable();
    }
}

1;
