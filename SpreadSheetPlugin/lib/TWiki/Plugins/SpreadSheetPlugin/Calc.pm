# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2001-2012 Peter Thoeny, peter[at]thoeny.org and
# TWiki Contributors.
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
#
# =========================
#
# This is part of TWiki's Spreadsheet Plugin.
#
# The code below is kept out of the main plugin module for
# performance reasons, so it doesn't get compiled until it
# is actually used.

package TWiki::Plugins::SpreadSheetPlugin::Calc;

use strict;
use Time::Local;
use Time::Local qw( timegm_nocheck timelocal_nocheck );  # Necessary for DOY

# =========================
my $web;
my $topic;
my $debug;
my $renderingWeb;
my @tableMatrix;
my $cPos = -1;
my $rPos = -1;
my $escToken = "\0";
my %varStore = ();
my $dontSpaceRE = "";
my @monArr = ( "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" );
my @wdayArr = ( "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" );
my %mon2num;
{
  my $count = 0;
  %mon2num = map { $_ => $count++ } @monArr;
}

# =========================
sub init
{
    ( $web, $topic, $debug ) = @_;

    # initialize variables, once per page view
    %varStore = ();
    $dontSpaceRE = "";

    # Module initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::SpreadSheetPlugin::Calc::init( $web.$topic )" ) if $debug;
    return 1;
}

# =========================
sub CALC
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- SpreadSheetPlugin::Calc::CALC( $_[2].$_[1] )" ) if $debug;

    @tableMatrix = ();
    $cPos = -1;
    $rPos = -1;
    $web = $_[2];

    my @result = ();
    my $insidePRE = 0;
    my $insideTABLE = 0;
    my $line = "";
    my $before = "";
    my $cell = "";
    my @row = ();

    $_[0] =~ s/\r//go;
    $_[0] =~ s/\\\n//go;  # Join lines ending in "\"
    foreach( split( /\n/, $_[0] ) ) {

        # change state:
        m|<pre>|i       && ( $insidePRE = 1 );
        m|<verbatim>|i  && ( $insidePRE = 1 );
        m|</pre>|i      && ( $insidePRE = 0 );
        m|</verbatim>|i && ( $insidePRE = 0 );

        if( ! ( $insidePRE ) ) {

            if( /^\s*\|.*\|\s*$/ ) {
                # inside | table |
                if( ! $insideTABLE ) {
                    $insideTABLE = 1;
                    @tableMatrix = ();  # reset table matrix
                    $cPos = -1;
                    $rPos = -1;
                }
                $line = $_;
                $line =~ s/^(\s*\|)(.*)\|\s*$/$2/o;
                $before = $1;
                @row  = split( /\|/o, $line, -1 );
                $row[0] = '' unless( @row );
                push( @tableMatrix, [ @row ] );
                $rPos++;
                $line = "$before";
                for( $cPos = 0; $cPos < @row; $cPos++ ) {
                    $cell = $row[$cPos];
                    $cell =~ s/%CALC\{(.*?)\}%/doCalc($1)/geo;
                    $line .= "$cell|";
                }
                s/.*/$line/o;

            } else {
                # outside | table |
                if( $insideTABLE ) {
                    $insideTABLE = 0;
                }
                s/%CALC\{(.*?)\}%/doCalc($1)/geo;
            }
        }
        push( @result, $_ );
    }
    $_[0] = join( "\n", @result );
}

# =========================
sub doCalc
{
    my( $theAttributes ) = @_;
    my $text = &TWiki::Func::extractNameValuePair( $theAttributes );

    # Add nesting level to parenthesis,
    # e.g. "A(B())" gets "A-esc-1(B-esc-2(-esc-2)-esc-1)"
    my $level = 0;
    $text =~ s/([\(\)])/_addNestingLevel($1, \$level)/geo;
    $text = _doFunc( "MAIN", $text );

    if( ( $rPos >= 0 ) && ( $cPos >= 0 ) ) {
        # update cell in table matrix
        $tableMatrix[$rPos][$cPos] = $text;
    }

    return $text;
}

# =========================
sub _addNestingLevel
{
  my( $theParen, $theLevelRef ) = @_;

  my $result = "";
  if( $theParen eq "(" ) {
    $$theLevelRef++;
    $result = "$escToken$$theLevelRef$theParen";
  } else {
    $result = "$escToken$$theLevelRef$theParen";
    $$theLevelRef--;
  }
  return $result;
}

# =========================
sub _recurseFunc
{
    # Handle functions recursively
    $_[0] =~ s/\$([A-Z]+)$escToken([0-9]+)\((.*?)$escToken\2\)/_doFunc($1,$3)/geo;
    # Clean up unbalanced mess
    $_[0] =~ s/$escToken\-*[0-9]+([\(\)])/$1/go;
}

# =========================
sub _doFunc
{
    my( $theFunc, $theAttr ) = @_;

    $theAttr = "" unless( defined $theAttr );
    TWiki::Func::writeDebug( "- SpreadSheetPlugin::Calc::_doFunc: $theFunc( $theAttr ) start" ) if $debug;

    unless( $theFunc =~ /^(IF|LISTIF|LISTMAP|NOEXEC|WHILE)$/ ) {
        _recurseFunc( $theAttr );
    }
    # else: delay the function handler to after parsing the parameters,
    # in which case handling functions and cleaning up needs to be done later

    my $result = "";
    my $i = 0;
    if( $theFunc eq "MAIN" ) {
        $result = $theAttr;

    } elsif( $theFunc eq "EXEC" ) {
        # add nesting level escapes
        my $level = 0;
        $result = $theAttr;
        $result =~ s/([\(\)])/_addNestingLevel($1, \$level)/geo;
        # execute functions in attribute recursively and clean up unbalanced parenthesis
        _recurseFunc( $result );

    } elsif( $theFunc eq "NOEXEC" ) {
        $result = $theAttr;

    } elsif( $theFunc eq "T" ) {
        $result = "";
        my @arr = _getTableRange( "$theAttr..$theAttr" );
        if( @arr ) {
            $result = $arr[0];
        }

    } elsif( $theFunc eq "TRIM" ) {
        $result = $theAttr || "";
        $result =~ s/^\s*//o;
        $result =~ s/\s*$//o;
        $result =~ s/\s+/ /go;

    } elsif( $theFunc eq "FORMAT" ) {
        # Format FORMAT(TYPE, precision, value) returns formatted value -- JimStraus - 05 Jan 2003
        my( $format, $res, $value )  = split( /,\s*/, $theAttr );
        $format =~ s/^\s*(.*?)\s*$/$1/; #Strip leading and trailing spaces
        $res =~ s/^\s*(.*?)\s*$/$1/;
        $value =~ s/^\s*(.*?)\s*$/$1/;
        if( $format eq "DOLLAR" ) {
            my $neg = 1 if $value < 0;
            $value = abs($value);
            $result = sprintf("%0.${res}f", $value);
            my $temp = reverse $result;
            $temp =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
            $result = "\$" . (scalar reverse $temp);
            $result = "(".$result.")" if $neg;
        } elsif( $format eq "COMMA" ) {
            $result = sprintf("%0.${res}f", $value);
            my $temp = reverse $result;
            $temp =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
            $result = scalar reverse $temp;
        } elsif( $format eq "PERCENT" ) {
            $result = sprintf("%0.${res}f%%", $value * 100);
        } elsif( $format eq "NUMBER" ) {
            $result = sprintf("%0.${res}f", $value);
        } elsif( $format eq "K" ) {
            $result = sprintf("%0.${res}f K", $value / 1024);
        } elsif( $format eq "KB" ) {
            $result = sprintf("%0.${res}f KB", $value / 1024);
        } elsif ($format eq "MB") {
            $result = sprintf("%0.${res}f MB", $value / (1024 * 1024));
        } elsif( $format =~ /^KBMB/ ) {
            $value /= 1024;
            my @lbls = ( "MB", "GB", "TB", "PB", "EB", "ZB" );
            my $lbl = "KB";
            while( $value >= 1024 && @lbls ) {
                $value /= 1024;
                $lbl = shift @lbls;
            }
            $result = sprintf("%0.${res}f", $value) . " $lbl";
        } else {
            # FORMAT not recognized, just return value
            $result = $value;
        }

    } elsif( $theFunc eq "EMPTY" ) {
        $result = 1;
        $result = 0 if( length( $theAttr ) > 0 );

    } elsif( $theFunc eq "EXACT" ) {
        $result = 0;
        my( $str1, $str2 ) = split( /,\s*/, $theAttr, 2 );
        $str1 = "" unless( $str1 );
        $str2 = "" unless( $str2 );
        $str1 =~ s/^\s*(.*?)\s*$/$1/o; # cut leading and trailing spaces
        $str2 =~ s/^\s*(.*?)\s*$/$1/o;
        $result = 1 if( $str1 eq $str2 );

    } elsif( $theFunc eq "RAND" ) {
        my $max = _getNumber( $theAttr );
        $max = 1 if( $max <= 0 );
        $result = rand( $max );

    } elsif( $theFunc eq "VALUE" ) {
        $result = _getNumber( $theAttr );

    } elsif( $theFunc =~ /^(EVAL|INT)$/ ) {
        $result = _safeEvalPerl( $theAttr );
        unless( $result =~ /^ERROR/ ) {
            $result = int( _getNumber( $result ) ) if( $theFunc eq "INT" );
        }

    } elsif( $theFunc eq "FLOOR" ) {
        $i = _getNumber( $theAttr );
        $result = int( $i );
        if( $i < 0 && $i != $result ) {
            $result -= 1;
        }

    } elsif( $theFunc eq "CEILING" ) {
        $i = _getNumber( $theAttr );
        $result = int( $i );
        if( $i > 0 && $i != $result ) {
            $result += 1;
        }

    } elsif( $theFunc eq "ROUND" ) {
        # ROUND(num, digits)
        my( $num, $digits ) = split( /,\s*/, $theAttr, 2 );
        $result = _safeEvalPerl( $num );
        unless( $result =~ /^ERROR/ ) {
            $result = _getNumber( $result );
            if( ( $digits ) && ( $digits =~ s/^.*?(\-?[0-9]+).*$/$1/o ) && ( $digits ) ) {
                my $factor = 10**$digits;
                $result *= $factor;
                ( $result >= 0 ) ? ( $result += 0.5 ) : ( $result -= 0.5 );
                $result = int( $result );
                $result /= $factor;
            } else {
                ( $result >= 0 ) ? ( $result += 0.5 ) : ( $result -= 0.5 );
                $result = int( $result );
            }
        }

    } elsif( $theFunc eq "MOD" ) {
        $result = 0;
        my( $num1, $num2 ) = split( /,\s*/, $theAttr, 2 );
        $num1 = _getNumber( $num1 );
        $num2 = _getNumber( $num2 );
        if( $num1 && $num2 ) {
            $result = $num1 % $num2;
        }

    } elsif( $theFunc eq "ODD" ) {
        $result = _getNumber( $theAttr ) % 2;

    } elsif( $theFunc eq "EVEN" ) {
        $result = ( _getNumber( $theAttr ) + 1 ) % 2;

    } elsif( $theFunc eq "AND" ) {
        $result = 0;
        my @arr = _getListAsInteger( $theAttr );
        foreach $i( @arr ) {
            unless( $i ) {
                $result = 0;
                last;
            }
            $result = 1;
        }

    } elsif( $theFunc eq "OR" ) {
        $result = 0;
        my @arr = _getListAsInteger( $theAttr );
        foreach $i( @arr ) {
            if( $i ) {
                $result = 1;
                last;
            }
        }

    } elsif( $theFunc eq "XOR" ) {
        my @arr = _getListAsInteger( $theAttr );
        $result = shift( @arr );
        if( scalar( @arr ) > 0 ) {
            foreach $i ( @arr ) {
                $result = ( $result xor $i );
            }
        } else {
            $result = 0;
        }
        $result = $result ? 1 : 0;

    } elsif( $theFunc eq "BITXOR" ) {
        my $ff = chr(255) x length( $theAttr );
        $result = $theAttr ^ $ff;

    } elsif( $theFunc eq "NOT" ) {
        $result = 1;
        $result = 0 if( _getNumber( $theAttr ) );

    } elsif( $theFunc eq "ABS" ) {
        $result = abs( _getNumber( $theAttr ) );

    } elsif( $theFunc eq "SIGN" ) {
        $i = _getNumber( $theAttr );
        $result =  0;
        $result =  1 if( $i > 0 );
        $result = -1 if( $i < 0 );

    } elsif( $theFunc eq "LN" ) {
        $result = log(_getNumber( $theAttr ) );

    } elsif( $theFunc eq "LOG" ) {
        my( $num, $base ) = split( /,\s*/, $theAttr, 2 );
        $num = _getNumber( $num );
        $base = _getNumber( $base );
        $base = 10 if( $base <= 0 );
        $result = log( $num ) / log( $base );

    } elsif( $theFunc eq "EXP" ) {
        $result = exp( _getNumber( $theAttr ) );

    } elsif( $theFunc eq "PI" ) {
        $result = 3.1415926535897932384;

    } elsif( $theFunc eq "SQRT" ) {
        $result = sqrt( _getNumber( $theAttr ) );

    } elsif( $theFunc eq "IF" ) {
        # IF(condition, value if true, value if false)
        my( $condition, $str1, $str2 ) = _properSplit( $theAttr, 3 );
        # with delay, handle functions in condition recursively and clean up unbalanced parenthesis
        _recurseFunc( $condition );
        $condition =~ s/^\s*(.*?)\s*$/$1/o;
        $result = _safeEvalPerl( $condition );
        unless( $result =~ /^ERROR/ ) {
            if( $result ) {
                $result = $str1;
            } else {
                $result = $str2;
            }
            $result = "" unless( defined( $result ) );
            # with delay, handle functions in result recursively and clean up unbalanced parenthesis
            _recurseFunc( $result );

        } # else return error message

    } elsif( $theFunc eq "WHILE" ) {
        # WHILE(condition, do something)
        my( $condition, $str ) = _properSplit( $theAttr, 2 );
        my $i = 0;
        while( 1 ) {
            if( $i++ >= 32767 ) {
                $result .= 'ERROR: Infinite loop (32767 cycles)';
                last; # prevent infinite loop
            }
            # with delay, handle functions in condition recursively and clean up unbalanced parenthesis
            my $cond = $condition;
            $cond =~ s/\$counter/$i/go;
            _recurseFunc( $cond );
            $cond =~ s/^\s*(.*?)\s*$/$1/o;
            my $res = _safeEvalPerl( $cond );
            if( $res =~ /^ERROR/ ) {
                $result .= $res;
                last; # exit loop and return error
            }
            last unless( $res ); # proper loop exit
            $res = $str;
            $res = "" unless( defined( $res ) );
            # with delay, handle functions in result recursively and clean up unbalanced parenthesis
            $res =~ s/\$counter/$i/go;
            _recurseFunc( $res );
            $result .= $res;
        }

    } elsif( $theFunc eq "ISUPPER" ) {
        my $regex = ($TWiki::regex{upperAlpha}) ? qr/[$TWiki::regex{upperAlpha}]+/o : '[[:upper:]]+';
        $result = ( $theAttr =~ m/^$regex$/o ) ? 1 : 0;

    } elsif( $theFunc eq "ISLOWER" ) {
        my $regex = ($TWiki::regex{lowerAlpha}) ? qr/[$TWiki::regex{lowerAlpha}]+/o : '[[:lower:]]+';
        $result = ( $theAttr =~ m/^$regex$/o ) ? 1 : 0;

    } elsif( $theFunc eq "ISDIGIT" ) {
        my $regex = ($TWiki::regex{numeric}) ? qr/[$TWiki::regex{numeric}]+/o : '[[:digit:]]+';
        $result = ( $theAttr =~ m/^$regex$/o ) ? 1 : 0;

    } elsif( $theFunc eq "ISWIKIWORD" ) {
        my $regex = ($TWiki::regex{wikiWordRegex}) ? $TWiki::regex{wikiWordRegex} :
                    '[[:upper:]]+[[:lower:][:digit:]]+[[:upper:]]+[[:alpha:][:digit:]]*';
        $result = ( $theAttr =~ m/^$regex$/o ) ? 1 : 0;

    } elsif( $theFunc eq "UPPER" ) {
        $result = uc( $theAttr );

    } elsif( $theFunc eq "LOWER" ) {
        $result = lc( $theAttr );

    } elsif( $theFunc eq "PROPER" ) {
        # FIXME: I18N
        $result = lc( $theAttr );
        $result =~ s/(^|[^a-z])([a-z])/$1 . uc($2)/geo;

    } elsif( $theFunc eq "PROPERSPACE" ) {
        $result = _properSpace( $theAttr );

    } elsif( $theFunc eq "CHAR" ) {
        if( $theAttr =~ /([0-9]+)/ ) {
            $i = $1;
        } else {
            $i = 0;
        }
        $i = 255 if $i > 255;
        $i = 0 if $i < 0;
        $result = chr( $i );

    } elsif( $theFunc eq "REPEAT" ) {
        my( $str, $num ) = split( /,\s*/, $theAttr, 2 );
        $str = "" unless( defined( $str ) );
        $num = _getNumber( $num );
        $result = "$str" x $num;

    } elsif( $theFunc eq "CODE" ) {
        $result = ord( $theAttr );

    } elsif( $theFunc eq "LENGTH" ) {
        $result = length( $theAttr );

    } elsif( $theFunc eq "ROW" ) {
        $i = $theAttr || 0;
        $result = $rPos + $i + 1;

    } elsif( $theFunc eq "COLUMN" ) {
        $i = $theAttr || 0;
        $result = $cPos + $i + 1;

    } elsif( $theFunc eq "LEFT" ) {
        $i = $rPos + 1;
        $result = "R$i:C0..R$i:C$cPos";

    } elsif( $theFunc eq "ABOVE" ) {
        $i = $cPos + 1;
        $result = "R0:C$i..R$rPos:C$i";

    } elsif( $theFunc eq "RIGHT" ) {
        $i = $rPos + 1;
        my $cStart = $cPos + 2;
        $result = "R$i:C$cStart..R$i:C32000";

    } elsif( $theFunc eq "DEF" ) {
        # Format DEF(list) returns first defined cell
        # Added by MF 26/3/2002, fixed by PeterThoeny
        my @arr = _getList( $theAttr );
        foreach my $cell ( @arr ) {
            if( $cell ) {
                $cell =~ s/^\s*(.*?)\s*$/$1/o;
                if( $cell ) {
                    $result = $cell;
                    last;
                }
            }
        }

    } elsif( $theFunc eq "MAX" ) {
        my @arr = sort { $a <=> $b }
                  grep { /./ }
                  grep { defined $_ }
                  _getListAsFloat( $theAttr );
        $result = $arr[$#arr];

    } elsif( $theFunc eq "MIN" ) {
        my @arr = sort { $a <=> $b }
                  grep { /./ }
                  grep { defined $_ }
                  _getListAsFloat( $theAttr );
        $result = $arr[0];

    } elsif( $theFunc eq "SUM" ) {
        $result = 0;
        my @arr = _getListAsFloat( $theAttr );
        foreach $i ( @arr ) {
            $result += $i  if defined $i;
        }

    } elsif( $theFunc eq "SUMPRODUCT" ) {
        $result = 0;
        my @arr;
        my @lol = split( /,\s*/, $theAttr );
        my $size = 32000;
        for $i (0 .. $#lol ) {
            @arr = _getListAsFloat( $lol[$i] );
            $lol[$i] = [ @arr ];                # store reference to array
            $size = @arr if( @arr < $size );    # remember smallest array
        }
        if( ( $size > 0 ) && ( $size < 32000 ) ) {
            my $y; my $prod; my $val;
            $size--;
            for $y (0 .. $size ) {
                $prod = 1;
                for $i (0 .. $#lol ) {
                    $val = $lol[$i][$y];
                    if( defined $val ) {
                        $prod *= $val;
                    } else {
                        $prod = 0;   # don't count empty cells
                    }
                }
                $result += $prod;
            }
        }

    } elsif( $theFunc =~ /^(SUMDAYS|DURATION)$/ ) {
        # DURATION is undocumented, is for SvenDowideit
        # contributed by SvenDowideit - 07 Mar 2003; modified by PTh
        $result = 0;
        my @arr = _getListAsDays( $theAttr );
        foreach $i ( @arr ) {
            $result += $i  if defined $i;
        }

    } elsif( $theFunc eq "WORKINGDAYS" ) {
        my( $num1, $num2 ) = split( /,\s*/, $theAttr, 2 );
        $result = _workingDays( _getNumber( $num1 ), _getNumber( $num2 ) );

    } elsif( $theFunc =~ /^(MULT|PRODUCT)$/ ) {   # MULT is deprecated (no not remove)
        my @arr = _getListAsFloat( $theAttr );
        $result = 1;
        foreach $i ( @arr ) {
            $result *= $i  if defined $i;
        }

    } elsif( $theFunc =~ /^(AVERAGE|MEAN)$/ ) {
        $result = 0;
        my $items = 0;
        my @arr = _getListAsFloat( $theAttr );
        foreach $i ( @arr ) {
            if( defined $i ) {
                $result += $i;
                $items++;
            }
        }
        if( $items > 0 ) {
            $result = $result / $items;
        }

    } elsif( $theFunc eq "MEDIAN" ) {
        my @arr = sort { $a <=> $b } grep { defined $_ } _getListAsFloat( $theAttr );
        $i = @arr;
        if( ( $i % 2 ) > 0 ) {
            $result = $arr[$i/2];
        } elsif( $i ) {
            $i /= 2;
            $result = ( $arr[$i] + $arr[$i-1] ) / 2;
        }

    } elsif( $theFunc eq "PERCENTILE" ) {
        my( $percentile, $set ) = split( /,\s*/, $theAttr, 2 );
        my @arr = sort { $a <=> $b } grep { defined $_ } _getListAsFloat( $set );
        $result = 0;

        my $size = scalar( @arr );
        if( $size > 0 ) {
            $i = $percentile / 100 * ( $size + 1 );
            my $iInt = int( $i );
            if( $i <= 1 ) {
                $result = $arr[0];
            } elsif( $i >= $size ) {
                $result = $arr[$size-1];
            } elsif( $i == $iInt ) {
                $result = $arr[$i-1];
            } else {
                # interpolate beween neighbors # Example: $i = 7.25
                my $r1 = $iInt + 1 - $i;       # 0.75 = 7 + 1 - 7.25
                my $r2 = 1 - $r1;              # 0.25 = 1 - 0.75
                my $x1 = $arr[$iInt-1];
                my $x2 = $arr[$iInt];
                $result = ($r1 * $x1) + ($r2 * $x2);
            }
        }

    } elsif( $theFunc eq "COUNTSTR" ) {
        $result = 0;  # count any string
        $i = 0;       # count string equal second attr
        my $list = $theAttr;
        my $str = "";
        if( $theAttr =~ /^(.*),\s*(.*?)$/ ) {  # greedy match for last comma
            $list = $1;
            $str = $2;
        }
        $str =~ s/\s*$//o;
        my @arr = _getList( $list );
        foreach my $cell ( @arr ) {
            if( defined $cell ) {
                $cell =~ s/^\s*(.*?)\s*$/$1/o;
                $result++ if( $cell );
                $i++ if( $cell eq $str );
            }
        }
        $result = $i if( $str );

    } elsif( $theFunc eq "COUNTITEMS" ) {
        $result = "";
        my @arr = _getList( $theAttr );
        my %items = ();
        my $key = "";
        foreach $key ( @arr ) {
            $key =~ s/^\s*(.*?)\s*$/$1/o if( $key );
            if( $key ) {
                if( exists( $items{ $key } ) ) {
                    $items{ $key }++;
                } else {
                    $items{ $key } = 1;
                }
            }
        }
        foreach $key ( sort keys %items ) {
            $result .= "$key: $items{ $key }<br /> ";
        }
        $result =~ s|<br /> $||o;

    } elsif( $theFunc =~ /^(FIND|SEARCH)$/ ) {
        my( $searchString, $string, $pos ) = split( /,\s*/, $theAttr, 3 );
        $result = 0;
        $pos--;
        $pos = 0 if( $pos < 0 );
        pos( $string ) = $pos if( $pos );
        $searchString = quotemeta( $searchString ) if( $theFunc eq "FIND" );
        # using zero width lookahead '(?=...)' to keep pos at the beginning of match
        if( eval '$string =~ m/(?=$searchString)/g' && $string ) {
            $result = pos( $string ) + 1;
        }

    } elsif( $theFunc eq "REPLACE" ) {
        my( $string, $start, $num, $replace ) = split ( /,\s*/, $theAttr, 4 );
        $result = $string;
        $start-- unless ($start < 1);
        $num = 0 unless( $num );
        $replace = "" unless( defined $replace );
        eval 'substr( $string, $start, $num, $replace )';
        $result = $string;

    } elsif( $theFunc eq "SUBSTITUTE" ) {
        my( $string, $from, $to, $inst, $options ) = split( /,\s*/, $theAttr );
        $result = $string;
        $to = "" unless( defined $to );
        $from = quotemeta( $from ) unless( $options && $options =~ /r/i);
        if( $inst ) {
            # replace Nth instance
            my $count = 0;
            if( eval '$string =~ s/($from)/if( ++$count == $inst ) { $to; } else { $1; }/gex;' && $string ) {
                $result = $string;
            }
        } else {
            # global replace
            if( eval '$string =~ s/$from/$to/g' ) {
                $result = $string;
            }
        }

    } elsif( $theFunc =~ /^(MIDSTRING|SUBSTRING)$/ ) {
        my( $string, $start, $num ) = split ( /,\s*/, $theAttr, 3 );
        $result = '';
        if( $start && $num ) {
            $start-- unless ($start < 1);
            eval '$result = substr( $string, $start, $num )';
        }

    } elsif( $theFunc =~ /^(LEFTSTRING|RIGHTSTRING)$/ ) {
        my( $string, $num ) = split ( /,\s*/, $theAttr, 2 );
        $num = 1 unless( $num );
        my $start = 0;
        $start = length( $string ) - $num if( $theFunc eq "RIGHTSTRING" );
        eval '$result = substr( $string, $start, $num )';

    } elsif( $theFunc eq "INSERTSTRING" ) {
        my( $string, $start, $new ) = split ( /,\s*/, $theAttr, 3 );
        $start = _getNumber( $start );
        eval 'substr( $string, $start, 0, $new )';
        $result = $string;

    } elsif( $theFunc eq "TRANSLATE" ) {
        $result = $theAttr;
        # greedy match for comma separated parameters (in case first parameter has embedded commas)
        if( $theAttr =~ /^(.*)\,\s*(.+)\,\s*(.+)$/ ) {
            my $string = $1;
            my $from = $2;
            my $to   = $3;
            $from =~ s/\$comma/,/g;      $to =~ s/\$comma/,/g;
            $from =~ s/\$sp/ /g;         $to =~ s/\$sp/ /g;
            $from =~ s/\$n/\n/g;         $to =~ s/\$n/\n/g; # the $from is silly, CALC can't be multi-line, yet
            $from = quotemeta( $from );  $to = quotemeta( $to );
            $from =~ s/([a-zA-Z0-9])\\\-([a-zA-Z0-9])/$1\-$2/g; # fix quotemeta (allow only ranges)
            $to   =~ s/([a-zA-Z0-9])\\\-([a-zA-Z0-9])/$1\-$2/g;
            $result = $string;
            if( $string && eval "\$string =~ tr/$from/$to/" ) {
                $result = $string;
            }
        }

    } elsif ( $theFunc eq "TIME" ) {
        $result = $theAttr;
        $result =~ s/^\s+//o;
        $result =~ s/\s+$//o;
        if( $result ) {
            $result = _date2serial( $result );
        } else {
            $result = time();
        }

    } elsif ( $theFunc eq "TODAY" ) {
        $result = _date2serial( _serial2date( time(), '$year/$month/$day GMT', 1 ) );

    } elsif( $theFunc =~ /^(FORMATTIME|FORMATGMTIME)$/ ) {
        my( $time, $str ) = split( /,\s*/, $theAttr, 2 );
        if( $time =~ /([0-9]+)/ ) {
            $time = $1;
        } else {
            $time = time();
        }
        my $isGmt = 0;
        $isGmt = 1 if( ( $str =~ m/ gmt/i ) || ( $theFunc eq "FORMATGMTIME" ) );
        $result = _serial2date( $time, $str, $isGmt );

    } elsif( $theFunc eq "FORMATTIMEDIFF" ) {
        my( $scale, $prec, $time ) = split( /,\s*/, $theAttr, 3 );
        $scale = "" unless( $scale );
        $prec = int( _getNumber( $prec ) - 1 );
        $prec = 0 if( $prec < 0 );
        $time = _getNumber( $time );
        $time = 0 if( $time < 0 );
        my @unit  = ( 0, 0, 0, 0, 0, 0 ); # sec, min, hours, days, month, years
        my @factor = ( 1, 60, 60, 24, 30.4166, 12 ); # sec, min, hours, days, month, years
        my @singular = ( 'second',  'minute',  'hour',  'day',  'month', 'year' );
        my @plural =   ( 'seconds', 'minutes', 'hours', 'days', 'month', 'years' );
        my $min = 0;
        my $max = $prec;
        if( $scale =~ /^min/i ) {
            $min = 1;
            $unit[1] = $time;
        } elsif( $scale =~ /^hou/i ) {
            $min = 2;
            $unit[2] = $time;
        } elsif( $scale =~ /^day/i ) {
            $min = 3;
            $unit[3] = $time;
        } elsif( $scale =~ /^mon/i ) {
            $min = 4;
            $unit[4] = $time;
        } elsif( $scale =~ /^yea/i ) {
            $min = 5;
            $unit[5] = $time;
        } else {
            $unit[0] = $time;
        }
        my @arr = ();
        my $i = 0;
        my $val1 = 0;
        my $val2 = 0;
        for( $i = $min; $i < 5; $i++ ) {
            $val1 = $unit[$i];
            $val2 = $unit[$i+1] = int($val1 / $factor[$i+1]);
            $val1 = $unit[$i] = $val1 - int($val2 * $factor[$i+1]);

            push( @arr, "$val1 $singular[$i]" ) if( $val1 == 1 );
            push( @arr, "$val1 $plural[$i]" )   if( $val1 > 1 );
        }
        push( @arr, "$val2 $singular[$i]" ) if( $val2 == 1 );
        push( @arr, "$val2 $plural[$i]" )   if( $val2 > 1 );
        push( @arr, "0 $plural[$min]" )   unless( @arr );
        my @reverse = reverse( @arr );
        $#reverse = $prec if( @reverse > $prec );
        $result = join( ', ', @reverse );
        $result =~ s/(.+)\, /$1 and /;

    } elsif( $theFunc eq "TIMEADD" ) {
       my( $time, $value, $scale ) = split( /,\s*/, $theAttr, 3 );
       $time = 0 unless( $time );
       $value = 0 unless( $value );
       $scale = "" unless( $scale );
       $time =~ s/.*?([0-9]+).*/$1/o || 0;
       $value =~ s/.*?(\-?[0-9\.]+).*/$1/o || 0;
       $value *= 60            if( $scale =~ /^min/i );
       $value *= 3600          if( $scale =~ /^hou/i );
       $value *= 3600*24       if( $scale =~ /^day/i );
       $value *= 3600*24*7     if( $scale =~ /^week/i );
       $value *= 3600*24*30.42 if( $scale =~ /^mon/i );  # FIXME: exact calc
       $value *= 3600*24*365   if( $scale =~ /^year/i ); # FIXME: exact calc
       $result = int( $time + $value );

    } elsif( $theFunc eq "TIMEDIFF" ) {
       my( $time1, $time2, $scale ) = split( /,\s*/, $theAttr, 3 );
       $scale ||= '';
       $time1 = 0 unless( $time1 );
       $time2 = 0 unless( $time2 );
       $time1 =~ s/.*?([0-9]+).*/$1/o || 0;
       $time2 =~ s/.*?([0-9]+).*/$1/o || 0;
       $result = $time2 - $time1;
       $result /= 60            if( $scale =~ /^min/i );
       $result /= 3600          if( $scale =~ /^hou/i );
       $result /= 3600*24       if( $scale =~ /^day/i );
       $result /= 3600*24*7     if( $scale =~ /^week/i );
       $result /= 3600*24*30.42 if( $scale =~ /^mon/i );  # FIXME: exact calc
       $result /= 3600*24*365   if( $scale =~ /^year/i ); # FIXME: exact calc

    } elsif( $theFunc eq "SET" ) {
       my( $name, $value ) = split( /,\s*/, $theAttr, 2 );
       $name =~ s/[^a-zA-Z0-9\_]//go;
       if( $name && defined( $value ) ) {
           $value =~ s/\s*$//o;
           $varStore{ $name } = $value;
       }

    } elsif( $theFunc eq "SETIFEMPTY" ) {
       my( $name, $value ) = split( /,\s*/, $theAttr, 2 );
       $name =~ s/[^a-zA-Z0-9\_]//go;
       if( $name && defined( $value ) && ! $varStore{ $name } ) {
           $value =~ s/\s*$//o;
           $varStore{ $name } = $value;
       }

    } elsif( $theFunc eq "SETM" ) {
       my( $name, $value ) = split( /,\s*/, $theAttr, 2 );
       $name =~ s/[^a-zA-Z0-9\_]//go;
       if( $name ) {
           my $old = $varStore{ $name };
           $old = "" unless( defined( $old ) );
           $value = _safeEvalPerl( "$old $value" );
           $varStore{ $name } = $value;
       }

    } elsif( $theFunc eq "GET" ) {
       my $name = $theAttr;
       $name =~ s/[^a-zA-Z0-9\_]//go;
       $result = $varStore{ $name } if( $name );
       $result = "" unless( defined( $result ) );

    } elsif( $theFunc eq "SPLIT" ) {
        my( $sep, $str ) = _properSplit( $theAttr, 2 );
        $sep = "  *" if( !defined $sep || $sep eq '' );
        $sep =~ s/\$comma/,/go;
        $sep =~ s/\$sp/ /go;
        $sep =~ s/\$(nop|empty)//go;
        $result = _listToDelimitedString( split( $sep, $str ) );

    } elsif( $theFunc eq "LIST" ) {
        my @arr = _getList( $theAttr );
        $result = _listToDelimitedString( @arr );

    } elsif( $theFunc eq "LISTITEM" ) {
        my( $index, $str ) = _properSplit( $theAttr, 2 );
        $index = _getNumber( $index );
        $str = "" unless( defined( $str ) );
        my @arr = _getList( $str );
        my $size = scalar @arr;
        if( $index && $size ) {
            $index-- if( $index > 0 );                 # documented index starts at 1
            $index = $size + $index if( $index < 0 );  # start from back if negative
            $result = $arr[$index] if( ( $index >= 0 ) && ( $index < $size ) );
        }

    } elsif( $theFunc eq "LISTJOIN" ) {
        my( $sep, $str ) = _properSplit( $theAttr, 2 );
        $str = "" unless( defined( $str ) );
        $result = _listToDelimitedString( _getList( $str ) );
        $sep = ", " if( !defined $sep || $sep eq '' );
        $sep =~ s/\$comma/,/go;
        $sep =~ s/\$sp/ /go;
        $sep =~ s/\$(nop|empty)//go;
        $sep =~ s/\$n/\n/go;
        $result =~ s/, */$sep/go;

    } elsif( $theFunc eq "LISTSIZE" ) {
        my @arr = _getList( $theAttr );
        $result = scalar @arr;

    } elsif( $theFunc eq "LISTSORT" ) {
        my $isNumeric = 1;
        my @arr = map {
            s/^\s*//o;
            s/\s*$//o;
            $isNumeric = 0 unless( $_ =~ /^[\+\-]?[0-9\.]+$/ );
            $_
        } _getList( $theAttr );
        if( $isNumeric ) {
            @arr = sort { $a <=> $b } @arr;
        } else {
            @arr = sort @arr;
        }
        $result = _listToDelimitedString( @arr );

    } elsif( $theFunc eq "LISTSHUFFLE" ) {
        my @arr = _getList( $theAttr );
        my $size = scalar @arr;
        if( $size > 1 ) {
            for( $i = $size; $i--; ) {
                my $j = int( rand( $i + 1 ) );
                next if( $i == $j );
                @arr[$i, $j] = @arr[$j, $i];
            }
        }
        $result = _listToDelimitedString( @arr );

    } elsif( $theFunc eq "LISTRAND" ) {
        my @arr = _getList( $theAttr );
        my $size = scalar @arr;
        if( $size > 0 ) {
            $i = int( rand( $size ) );
            $result = $arr[$i];
        }

    } elsif( $theFunc eq "LISTREVERSE" ) {
        my @arr = reverse _getList( $theAttr );
        $result = _listToDelimitedString( @arr );

    } elsif( $theFunc eq "LISTTRUNCATE" ) {
        my( $index, $str ) = _properSplit( $theAttr, 2 );
        $index = int( _getNumber( $index ) );
        $str = "" unless( defined( $str ) );
        my @arr = _getList( $str );
        my $size = scalar @arr;
        if( $index > 0 ) {
            $index = $size if( $index > $size );
            $#arr = $index - 1;
            $result = _listToDelimitedString( @arr );
        } elsif( $index < 0 ) {
            $index = - $size if( $index < - $size );
            splice( @arr, 0, $size + $index );
            $result = _listToDelimitedString( @arr );
        } #else result = '';

    } elsif( $theFunc eq "LISTUNIQUE" ) {
        my %seen = ();
        my @arr = grep { ! $seen{$_} ++ } _getList( $theAttr );
        $result = _listToDelimitedString( @arr );

    } elsif( $theFunc eq "LISTMAP" ) {
        # LISTMAP(action, item 1, item 2, ...)
        my( $action, $str ) = _properSplit( $theAttr, 2 );
        $action = "" unless( defined( $action ) );
        $str = "" unless( defined( $str ) );
        # with delay, handle functions in result recursively and clean up unbalanced parenthesis
        _recurseFunc( $str );
        my $item = "";
        $i = 0;
        my @arr =
            map {
               $item = $_;
               $_ = $action;
               $i++;
               s/\$index/$i/go;
               $_ .= $item unless( s/\$item/$item/go );
               _recurseFunc( $_ );
               $_
            } _getList( $str );
        $result = _listToDelimitedString( @arr );

    } elsif( $theFunc eq "LISTNONEMPTY" ) {
        my @arr = grep { /./ } _getList( $theAttr );
        $result = _listToDelimitedString( @arr );

    } elsif( $theFunc eq "LISTIF" ) {
        # LISTIF(cmd, item 1, item 2, ...)
        my( $cmd, $str ) = _properSplit( $theAttr, 2 );
        $cmd = "" unless( defined( $cmd ) );
        $cmd =~ s/^\s*(.*?)\s*$/$1/o;
        $str = "" unless( defined( $str ) );
        # with delay, handle functions in result recursively and clean up unbalanced parenthesis
        _recurseFunc( $str );
        my $item = "";
        my $eval = "";
        $i = 0;
        my @arr =
            grep { ! /^TWIKI_GREP_REMOVE$/ }
            map {
                $item = $_;
                $_ = $cmd;
                $i++;
                s/\$index/$i/go;
                s/\$item/$item/go;
                _recurseFunc( $_ );
                $eval = _safeEvalPerl( $_ );
                if( $eval =~ /^ERROR/ ) {
                    $_ = $eval;
                } elsif( $eval ) {
                    $_ = $item;
                } else {
                    $_ = "TWIKI_GREP_REMOVE";
                }
            } _getList( $str );
        $result = _listToDelimitedString( @arr );

    } elsif ( $theFunc eq "NOP" ) {
        # pass everything through, this will allow plugins to defy plugin order
        # for example the %SEARCH{}% variable
        $theAttr =~ s/\$per(cnt)?/%/g;
        $theAttr =~ s/\$quot/"/g;
        $result = $theAttr;

    } elsif ( $theFunc eq "EXISTS" ) {
        $result = TWiki::Func::topicExists( $web, $theAttr );
        $result = 0 unless( $result );

    } elsif ( $theFunc eq "HEXENCODE" ) {
        $result = uc( unpack( "H*", $theAttr ) );

    } elsif ( $theFunc eq "HEXDECODE" ) {
        $theAttr =~ s/[^0-9A-Fa-f]//g; # only hex numbers
        $theAttr =~ s/.$// if( length( $theAttr ) % 2 ); # must be set of two
        $result = pack( "H*", $theAttr ); 
    }

    TWiki::Func::writeDebug( "- SpreadSheetPlugin::Calc::_doFunc: $theFunc( $theAttr ) returns: $result" ) if $debug;
    return $result;
}

# =========================
sub _listToDelimitedString
{
    my @arr = map { s/^\s*//o; s/\s*$//o; $_ } @_;
    my $text = join( ", ", @arr );
    return $text;
}

# =========================
sub _properSplit
{
    my( $theAttr, $theLevel ) = @_;

    # escape commas inside functions
    $theAttr =~ s/(\$[A-Z]+$escToken([0-9]+)\(.*?$escToken\2\))/_escapeCommas($1)/geo;
    # split at commas and restore commas inside functions
    my @arr = map{ s/<$escToken>/\,/go; $_ } split( /,\s*/, $theAttr, $theLevel );
    return @arr;
}

# =========================
sub _escapeCommas
{
    my( $theText ) = @_;
    $theText =~ s/\,/<$escToken>/go;
    return $theText;
}

# =========================
sub _getNumber
{
    my( $theText ) = @_;
    return 0 unless( $theText );
    $theText =~ s/([0-9])\,(?=[0-9]{3})/$1/go;          # "1,234,567" ==> "1234567"
    if( $theText =~ /[0-9]e/i ) {                       # "1.5e-3"    ==> "0.0015"
        $theText = sprintf "%.20f", $theText;
        $theText =~ s/0+$//;
    }
    unless( $theText =~ s/^.*?(\-?[0-9\.]+).*$/$1/o ) { # "xy-1.23zz" ==> "-1.23"
        $theText = 0;
    }
    $theText =~ s/^(\-?)0+([0-9])/$1$2/o;               # "-0009.12"  ==> "-9.12"
    $theText =~ s/^(\-?)\./${1}0\./o;                   # "-.25"      ==> "-0.25"
    $theText =~ s/^\-0$/0/o;                            # "-0"        ==> "0"
    $theText =~ s/\.$//o;                               # "123."      ==> "123"
    return $theText;
}

# =========================
sub _safeEvalPerl
{
    my( $theText ) = @_;
    # Allow only simple math with operators - + * / % ( )
    $theText =~ s/\%\s*[^\-\+\*\/0-9\.\(\)]+//go; # defuse %hash but keep modulus
    # keep only numbers and operators (shh... don't tell anyone, we support comparison operators)
    $theText =~ s/[^\!\<\=\>\-\+\*\/\%0-9e\.\(\)]*//go;
    $theText =~ s/(^|[^\.])\b0+(?=[0-9])/$1/go;  # remove leading 0s to defuse interpretation of numbers as octals
    $theText =~ s/(^|[^0-9])e/$1/go;  # remove "e"-s unless in expression such as "123e-4"
    $theText =~ /(.*)/;
    $theText = $1;  # untainted variable
    return "" unless( $theText );
    local $SIG{__DIE__} = sub { TWiki::Func::writeDebug($_[0]); warn $_[0] };
    my $result = eval $theText;
    if( $@ ) {
        $result = $@;
        $result =~ s/[\n\r]//go;
        $result =~ s/\[[^\]]+.*view.*?\:\s?//o;                   # Cut "[Mon Mar 15 23:31:39 2004] view: "
        $result =~ s/\s?at \(eval.*?\)\sline\s?[0-9]*\.?\s?//go;  # Cut "at (eval 51) line 2."
        $result =~ s/at end of line\.?//go;                       # Cut "at end of line"
        $result =~ s/,?\s*$//o;
        $result = "ERROR: $result";

    } else {
        $result = 0 unless( $result );  # logical false is "0"
    }
    return $result;
}

# =========================
sub _getListAsInteger
{
    my( $theAttr ) = @_;

    my $val = 0;
    my @list = _getList( $theAttr );
    (my $baz = "foo") =~ s/foo//;  # reset search vars. defensive coding
    for my $i (0 .. $#list ) {
        $val = $list[$i];
        # search first integer pattern, skip over HTML tags
        if( $val =~ /^\s*(?:<[^>]*>)*([\-\+]*[0-9]+).*/o ) {
            $list[$i] = $1;  # untainted variable, possibly undef
        } else {
            $list[$i] = undef;
        }
    }
    return @list;
}

# =========================
sub _getListAsFloat
{
    my( $theAttr ) = @_;

    my $val = 0;
    my @list = _getList( $theAttr );
    (my $baz = "foo") =~ s/foo//;  # reset search vars. defensive coding
    for my $i (0 .. $#list ) {
        $val = $list[$i];
        # search first float pattern, skip over HTML tags
        if( $val =~ /^\s*(?:<[^>]*>)*\$?([\-\+]*[0-9\.]+).*/o ) {
            $list[$i] = $1;  # untainted variable, possibly undef
        } else {
            $list[$i] = undef;
        }
    }
    return @list;
}

# =========================
sub _getListAsDays
{
    my( $theAttr ) = @_;

    # contributed by by SvenDowideit - 07 Mar 2003; modified by PTh
    my $val = 0;
    my @arr = _getList( $theAttr );
    (my $baz = "foo") =~ s/foo//;  # reset search vars. defensive coding
    for my $i (0 .. $#arr ) {
        $val = $arr[$i];
        # search first float pattern
        if( $val =~ /^\s*([\-\+]*[0-9\.]+)\s*d/oi ) {
            $arr[$i] = $1;      # untainted variable, possibly undef
        } elsif( $val =~ /^\s*([\-\+]*[0-9\.]+)\s*w/oi ) {
            $arr[$i] = 5 * $1;  # untainted variable, possibly undef
        } elsif( $val =~ /^\s*([\-\+]*[0-9\.]+)\s*h/oi ) {
            $arr[$i] = $1 / 8;  # untainted variable, possibly undef
        } elsif( $val =~ /^\s*([\-\+]*[0-9\.]+)/o ) {
            $arr[$i] = $1;      # untainted variable, possibly undef
        } else {
            $arr[$i] = undef;
        }
    }
    return @arr;
}

# =========================
sub _getList
{
    my( $theAttr ) = @_;

    my @list = ();
    foreach( split( /,\s*/, $theAttr ) ) {
        if( m/\s*R([0-9]+)\:C([0-9]+)\s*\.\.+\s*R([0-9]+)\:C([0-9]+)/ ) {
            # table range
            push( @list, _getTableRange( $_ ) );
        } else {
            # list item
            push( @list, split( /\s*,\s*/, $_ ) ); 
        }
    }
    return @list;
}

# =========================
sub _getTableRange
{
    my( $theAttr ) = @_;

    my @arr = ();
    if( $rPos < 0 ) {
        return @arr;
    }

    TWiki::Func::writeDebug( "- SpreadSheetPlugin::Calc::_getTableRange( $theAttr )" ) if $debug;
    unless( $theAttr =~ /\s*R([0-9]+)\:C([0-9]+)\s*\.\.+\s*R([0-9]+)\:C([0-9]+)/ ) {
        return @arr;
    }
    my $r1 = $1 - 1;
    my $c1 = $2 - 1;
    my $r2 = $3 - 1;
    my $c2 = $4 - 1;
    my $r = 0;
    my $c = 0;
    if( $c1 < 0     ) { $c1 = 0; }
    if( $c2 < 0     ) { $c2 = 0; }
    if( $c2 < $c1   ) { $c = $c1; $c1 = $c2; $c2 = $c; }
    if( $r1 > $rPos ) { $r1 = $rPos; }
    if( $r1 < 0     ) { $r1 = 0; }
    if( $r2 > $rPos ) { $r2 = $rPos; }
    if( $r2 < 0     ) { $r2 = 0; }
    if( $r2 < $r1   ) { $r = $r1; $r1 = $r2; $r2 = $r; }

    my $pRow = ();
    for $r ( $r1 .. $r2 ) {
        $pRow = $tableMatrix[$r];
        for $c ( $c1 .. $c2 ) {
            if( $c < @$pRow ) {
                push( @arr, $$pRow[$c] );
            }
        }
    }
    TWiki::Func::writeDebug( "- SpreadSheetPlugin::Calc::_getTableRange() returns @arr" ) if $debug;
    return @arr;
}

# =========================
sub _date2serial
{
    my ( $theText ) = @_;

    my $sec = 0; my $min = 0; my $hour = 0; my $day = 1; my $mon = 0; my $year = 0;

    # Handle DOY (Day of Year)
    if( $theText =~ m|([Dd][Oo][Yy])\s*([0-9]{4})[\.]([0-9]{1,3})[\.]([0-9]{1,2})[\.]([0-9]{1,2})[\.]([0-9]{1,2})| ) {
        # "DOY2003.122.23.15.59", "DOY2003.2.9.3.5.9" i.e. year.ddd.hh.mm.ss
        $year = $2 - 1900; $day = $3; $hour = $4; $min = $5; $sec = $6;	 # Note: $day is in fact doy
    } elsif( $theText =~ m|([Dd][Oo][Yy])\s*([0-9]{4})[\.]([0-9]{1,3})[\.]([0-9]{1,2})[\.]([0-9]{1,2})| ) {
        # "DOY2003.122.23.15", "DOY2003.2.9.3" i.e. year.ddd.hh.mm
        $year = $2 - 1900; $day = $3; $hour = $4; $min = $5;
    } elsif( $theText =~ m|([Dd][Oo][Yy])\s*([0-9]{4})[\.]([0-9]{1,3})[\.]([0-9]{1,2})| ) {
        # "DOY2003.122.23", "DOY2003.2.9" i.e. year.ddd.hh
        $year = $2 - 1900; $day = $3; $hour = $4;
    } elsif( $theText =~ m|([Dd][Oo][Yy])\s*([0-9]{4})[\.]([0-9]{1,3})| ) {
        # "DOY2003.122", "DOY2003.2" i.e. year.ddd
        $year = $2 - 1900; $day = $3;
    } elsif ($theText =~ m|([0-9]{1,2})[-\s/]+([A-Z][a-z][a-z])[-\s/]+([0-9]{4})[-\s/]+([0-9]{1,2}):([0-9]{1,2}):([0-9]{1,2})| ) {
        # "31 Dec 2003 - 23:59:59", "31-Dec-2003 - 23:59:59", "31 Dec 2003 - 23:59:59 - any suffix"
        $day = $1; $mon = $mon2num{$2} || 0; $year = $3 - 1900; $hour = $4; $min = $5; $sec = $6;
    } elsif ($theText =~ m|([0-9]{1,2})[-\s/]+([A-Z][a-z][a-z])[-\s/]+([0-9]{4})[-\s/]+([0-9]{1,2}):([0-9]{1,2})| ) {
        # "31 Dec 2003 - 23:59", "31-Dec-2003 - 23:59", "31 Dec 2003 - 23:59 - any suffix"
        $day = $1; $mon = $mon2num{$2} || 0; $year = $3 - 1900; $hour = $4; $min = $5;
    } elsif( $theText =~ m|([0-9]{1,2})[-\s/]+([A-Z][a-z][a-z])[-\s/]+([0-9]{2,4})| ) {
        # "31 Dec 2003", "31 Dec 03", "31-Dec-2003", "31/Dec/2003"
        $day = $1; $mon = $mon2num{$2} || 0; $year = $3;
        $year += 100 if( $year < 80 );      # "05"   --> "105" (leave "99" as is)
        $year -= 1900 if( $year >= 1900 );  # "2005" --> "105"
    } elsif( $theText =~ m|([0-9]{4})[-/\.]([0-9]{1,2})[-/\.]([0-9]{1,2})[-/\.\,\s]+([0-9]{1,2})[-\:/\.]([0-9]{1,2})[-\:/\.]([0-9]{1,2})| ) {
        # "2003/12/31 23:59:59", "2003-12-31-23-59-59", "2003.12.31.23.59.59"
        $year = $1 - 1900; $mon = $2 - 1; $day = $3; $hour = $4; $min = $5; $sec = $6;
    } elsif( $theText =~ m|([0-9]{4})[-/\.]([0-9]{1,2})[-/\.]([0-9]{1,2})[-/\.\,\s]+([0-9]{1,2})[-\:/\.]([0-9]{1,2})| ) {
        # "2003/12/31 23:59", "2003-12-31-23-59", "2003.12.31.23.59"
        $year = $1 - 1900; $mon = $2 - 1; $day = $3; $hour = $4; $min = $5;
    } elsif( $theText =~ m|([0-9]{4})[-/]([0-9]{1,2})[-/]([0-9]{1,2})| ) {
        # "2003/12/31", "2003-12-31"
        $year = $1 - 1900; $mon = $2 - 1; $day = $3;
    } elsif( $theText =~ m|([0-9]{1,2})[-/]([0-9]{1,2})[-/]([0-9]{2,4})| ) {
        # "12/31/2003", "12/31/03", "12-31-2003"
        # (shh, don't tell anyone that we support ambiguous American dates, my boss asked me to)
        $year = $3; $mon = $1 - 1; $day = $2;
        $year += 100 if( $year < 80 );      # "05"   --> "105" (leave "99" as is)
        $year -= 1900 if( $year >= 1900 );  # "2005" --> "105"
    } else {
        # unsupported format
        return 0;
    }
    if( ( $sec > 60 ) || ( $min > 59 ) || ( $hour > 23 ) || ( $day < 1 ) || ( $day > 365 ) || ( $mon > 11 )) {
        # unsupported, out of range
        return 0;
    }

    # To handle DOY, use timegm_nocheck or timelocal_nocheck that won't check input data range.
    # This is necessary because with DOY, $day must be able to be greater than 31 and timegm
    # and timelocal won't allow it. Keep using timegm or timelocal for non-DOY stuff.
    if( $theText =~ /gmt/i ) {
        if( $theText =~ /DOY/i ) {
            return timegm_nocheck( $sec, $min, $hour, $day, $mon, $year);
        } else {
            return timegm( $sec, $min, $hour, $day, $mon, $year );
        }
    } else {
        if( $theText =~ /DOY/i ) {
            return timelocal_nocheck( $sec, $min, $hour, $day, $mon, $year);
        } else {
            return timelocal( $sec, $min, $hour, $day, $mon, $year );
        }
    }
}

# =========================
sub _serial2date
{
    my ( $theTime, $theStr, $isGmt ) = @_;

    my( $sec, $min, $hour, $day, $mon, $year, $wday, $yday ) = ( $isGmt ? gmtime( $theTime ) : localtime( $theTime ) );

    $theStr =~ s/\$isoweek\(([^\)]*)\)/_isoWeek( $1, $day, $mon, $year, $wday, $theTime )/geoi;
    $theStr =~ s/\$isoweek/_isoWeek( '$week', $day, $mon, $year, $wday, $theTime )/geoi;
    $theStr =~ s/\$sec[o]?[n]?[d]?[s]?/sprintf("%.2u",$sec)/geoi;
    $theStr =~ s/\$min[u]?[t]?[e]?[s]?/sprintf("%.2u",$min)/geoi;
    $theStr =~ s/\$hou[r]?[s]?/sprintf("%.2u",$hour)/geoi;
    $theStr =~ s/\$day/sprintf("%.2u",$day)/geoi;
    $theStr =~ s/\$mon(?!t)/$monArr[$mon]/goi;
    $theStr =~ s/\$mo[n]?[t]?[h]?/sprintf("%.2u",$mon+1)/geoi;
    $theStr =~ s/\$yearday/$yday+1/geoi;
    $theStr =~ s/\$yea[r]?/sprintf("%.4u",$year+1900)/geoi;
    $theStr =~ s/\$ye/sprintf("%.2u",$year%100)/geoi;
    $theStr =~ s/\$wday/substr($wdayArr[$wday],0,3)/geoi;
    $theStr =~ s/\$wd/$wday+1/geoi;
    $theStr =~ s/\$weekday/$wdayArr[$wday]/goi;

    return $theStr;
}

# =========================
sub _isoWeek
{
    my ( $format, $day, $mon, $year, $wday, $serial ) = @_;

    # Contributed by PeterPayne - 22 Oct 2007
    # Enhanced by PeterThoeny 2010-08-27
    # Calculate the ISO8601 week number from the serial.

    my $isoyear = $year + 1900;
    my $yearserial = _year2isoweek1serial( $year + 1900, 1 );
    if ( $mon >= 11 ) { # check if date is in next year's first week
        my $yearnextserial = _year2isoweek1serial( $year + 1900 + 1, 1 );
        if ( $serial >= $yearnextserial ) {
            $yearserial = $yearnextserial;
            $isoyear += 1;
        }
    } elsif ( $serial < $yearserial ) {
        $yearserial = _year2isoweek1serial( $year + 1900 - 1, 1 );
        $isoyear -= 1;
    }

    # calculate GMT of just past midnight today
    my $today_gmt = timegm( 0, 0, 0, $day, $mon, $year );
    my $isoweek = int( ( $today_gmt - $yearserial ) / ( 7 * 24 * 3600 ) ) + 1 ;
    my $isowk = sprintf("%.2u", $isoweek );
    my $isoday = $wday;
    $isoday = 7 unless( $isoday );

    $format =~ s/\$iso/$isoyear-W$isoweek/go;
    $format =~ s/\$year/$isoyear/go;
    $format =~ s/\$week/$isoweek/go;
    $format =~ s/\$wk/$isowk/go;
    $format =~ s/\$day/$isoday/go;

    return $format;
}

# =========================
sub _year2isoweek1serial
{
    my ( $year, $isGmt ) = @_;

    # Contributed by PeterPayne - 22 Oct 2007
    # Calculate the serial of the beginning of week 1 for specified year.
    # Year is 4 digit year (e.g. "2000")

    $year -= 1900;

    # get Jan 4
    my @param = ( 0, 0, 0, 4, 0, $year );
    my $jan4epoch = ( $isGmt ? timegm( @param ) : timelocal( @param ) );

    # what day does Jan 4 fall on?
    my $jan4day = ( $isGmt ? (gmtime($jan4epoch))[6] : (localtime($jan4epoch))[6] );

    $jan4day += 7 if ( $jan4day < 1 );

    return( $jan4epoch - ( 24 * 3600 * ( $jan4day - 1 ) ) );
}

# =========================
sub _properSpace
{
    my ( $theStr ) = @_;

    # FIXME: I18N

    unless( $dontSpaceRE ) {
        $dontSpaceRE = &TWiki::Func::getPreferencesValue( "DONTSPACE" ) ||
                       &TWiki::Func::getPreferencesValue( "SPREADSHEETPLUGIN_DONTSPACE" ) ||
                       "UnlikelyGibberishWikiWord";
        $dontSpaceRE =~ s/[^a-zA-Z0-9\,\s]//go;
        $dontSpaceRE = "(" . join( "|", split( /[\,\s]+/, $dontSpaceRE ) ) . ")";
        # Example: "(RedHat|McIntosh)"
    }
    $theStr =~ s/$dontSpaceRE/_spaceWikiWord( $1, "<DONT_SPACE>" )/geo;  # e.g. "Mc<DONT_SPACE>Intosh"
    $theStr =~ s/(^|[\s\(]|\]\[)([a-zA-Z0-9]+)/$1 . _spaceWikiWord( $2, " " )/geo;
    $theStr =~ s/<DONT_SPACE>//go;  # remove "<DONT_SPACE>" marker

    return $theStr;
}

# =========================
sub _spaceWikiWord
{
    my ( $theStr, $theSpacer ) = @_;

    $theStr =~ s/([a-z])([A-Z0-9])/$1$theSpacer$2/go;
    $theStr =~ s/([0-9])([a-zA-Z])/$1$theSpacer$2/go;

    return $theStr;
}

# =========================
sub _workingDays
{
    my ( $start, $end ) = @_;

    # Rewritten by PeterThoeny - 2009-05-03 (previous implementation was buggy)
    # Calculate working days between two times. Times are standard system times (secs since 1970).
    # Working days are Monday through Friday (sorry, Israel!)
    # A day has 60 * 60 * 24 sec
    # Adding 3601 sec to account for daylight saving change in March in Northern Hemisphere
    my $days = int( ( abs( $end - $start ) + 3601 ) / 86400 );
    my $weeks = int( $days / 7 );
    my $fullWeekWorkingDays = 5 * $weeks;
    my $extra = $days % 7;
    if( $extra > 0 ) {
      $start = $end if( $start > $end );
      my @tm = gmtime( $start );
      my $wday = $tm[6]; # 0 is Sun, 6 is Sat
      if( $wday == 0 ) {
        $extra--;
      } else {
        my $sum = $wday + $extra;
        $extra-- if( $sum > 6 );
        $extra-- if( $sum > 7 );
      }
    }
    return $fullWeekWorkingDays + $extra;
}

# =========================
1;
