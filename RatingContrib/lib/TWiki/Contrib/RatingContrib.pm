# Contrib for TWiki Collaboration Platform, http://TWiki.org/
#
# Author: Crawford Currie http://c-dot.co.uk
# Copyright (C) 2007 C-Dot Consultants
# Copyright (C) 2006-2010 TWiki Contributors. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution.
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
package TWiki::Contrib::RatingContrib;

use strict;

require TWiki::Func;    # The plugins API

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION );

$VERSION = '$Rev$';
$RELEASE = '2010-11-27';
$SHORTDESCRIPTION = 'Rating widget for TWiki forms using "line of stars" style input field';

require CGI;

sub renderRating {
    my ($name, $size, $small, $value, $input_attrs) = @_;

    my $pubUrlPath = TWiki::Func::getPubUrlPath().'/'.
      TWiki::Func::getTwikiWebname().'/RatingContrib';

    TWiki::Func::addToHEAD( 'RATINGS_HEAD', <<HEAD );
<link href="$pubUrlPath/rating.css" rel="stylesheet" type="text/css" media="screen" />
<script type='text/javascript' src='$pubUrlPath/rating.js'></script>
HEAD

    my $style = $small ? ' small-star' : '';
    my $blockWidth = $small ? 10 : 25;

    my $hidden = '';
    if ($input_attrs) {
        $input_attrs->{type} = 'hidden';
        $input_attrs->{name} = $name;
        $input_attrs->{id} = 'rate_value_'.$name;
        $input_attrs->{value} = $value;
        $hidden = CGI::input($input_attrs);
    }

    my $result = CGI::div(
        {
            class=>'current-rating',
            id => 'rate_display_'.$name,
            style=>'width:'.($value * $blockWidth).'px',
        }, $hidden);

    if ($input_attrs) {
        foreach my $i (1..$size) {
            my $attrs = {
                style => 'width:'.($i * $blockWidth).
                  'px;z-index:'.($size - $i + 2) };
            $attrs->{href} = "javascript:RatingClicked('rate_value_$name',".
              "'rate_display_$name', $i, $blockWidth)";
            $result .= CGI::a($attrs, $i);
        }
    }

    return CGI::div(
        {
            class=>'star-rating'.$style,
            style=>'width:'.($size * $blockWidth).'px',
        }, $result);
}

1;
