# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2002-2012 Peter Thoeny, peter[at]thoeny.org
# Copyright (C) 2008-2012 TWiki:TWiki/TWikiContributor
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
# This file contains routines for producing PNG graphic files containing
# gauge information, useful for building dashboards.
#    NOTE: ONLY in the case where an old version of GD (1.19 or earlier) is
#    available will GIF's be created.  If the GD version is > 1.19, then
#    PNG's are created.

# =========================
package TWiki::Plugins::GaugePlugin;

use strict;
use MIME::Base64 qw(encode_base64);

# =========================
our $VERSION = '$Rev$';
our $RELEASE = '2012-11-13';

my $installWeb;
my $debug;
my $defaultType;
my $defaultColors;
my $defaultTambarScale;
my $defaultTambarWidth;
my $defaultTambarHeight;
my $defaultTrendWidth;
my $defaultTrendHeight;
my $defaultTambarScaleHeightPercentage;
my $defaultTambarAccess;
my %colorCache;

my $pluginInitialized = 0;
my $perlGDModuleFound = 0;
my $transparentColorValue = "#FFFFFF";
my $blackColor = "#000000";
my $redColor = "#FF0000";

# =========================
sub initPlugin {
    ( my $topic, my $web, my $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between GaugePlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "GAUGEPLUGIN_DEBUG" ) || 0;

    &TWiki::Func::writeDebug( "- TWiki::Plugins::GaugePlugin::initPlugin($web.$topic) is OK" ) if $debug;

    # Mark that we are not fully initialized yet.  Only get the default
    # values from the plugin topic page iff a GAUGE is found in a topic
    $pluginInitialized = 0;
    TWiki::Func::registerTagHandler('GAUGE', \&_make_gauge);
    TWiki::Func::registerTagHandler('GAUGETEST', \&testit);
    TWiki::Func::registerTagHandler('GAUGE_TIMER', \&_timeit);

    return 1;
}

# =========================

# Initialize all default values from the plugin topic page.
sub _init_defaults {
    $pluginInitialized = 1;
    eval {
        $perlGDModuleFound = require GD;
        require POSIX;
    };
    # Get default gauge type
    $defaultType = &TWiki::Func::getPreferencesValue( "GAUGEPLUGIN_TYPE" ) || 'tambar';
    # Get 'tambar' default values
    $defaultTambarScale = &TWiki::Func::getPreferencesValue( "GAUGEPLUGIN_TAMBAR_SCALE" ) || "0, 10, 20, 30";
    $defaultTambarWidth = &TWiki::Func::getPreferencesValue( "GAUGEPLUGIN_TAMBAR_WIDTH" ) || 60;
    $defaultTambarHeight = &TWiki::Func::getPreferencesValue( "GAUGEPLUGIN_TAMBAR_HEIGHT" ) || 16;
    $defaultColors = &TWiki::Func::getPreferencesValue( "GAUGEPLUGIN_TAMBAR_COLORS" )
                     || "#FF0000 #FFCCCC #FFFF00 #FFFFCC #00FF00 #CCFFCC";
    $defaultTambarScaleHeightPercentage = &TWiki::Func::getPreferencesValue( "GAUGEPLUGIN_TAMBAR_SCALE_HEIGHT_PERCENTAGE" ) || 20;
    $defaultTambarAccess = &TWiki::Func::getPreferencesValue( "GAUGEPLUGIN_TAMBAR_ACCESS" ) || "file";

    # Get 'trend' default values
    $defaultTrendWidth = &TWiki::Func::getPreferencesValue( "GAUGEPLUGIN_TREND_WIDTH" ) || 16;
    $defaultTrendHeight = &TWiki::Func::getPreferencesValue( "GAUGEPLUGIN_TREND_HEIGHT" ) || 16;
}

# Return the maximum value of the two specified numbers.
sub _max {
    my ( $v1, $v2 ) = @_;
    return $v1 if( $v1 > $v2 );
    return $v2;
}

# Return the minimum value of the two specified numbers.
sub _min {
    my ( $v1, $v2 ) = @_;
    return $v1 if( $v1 < $v2 );
    return $v2;
}

# Convert a color in the form of either #RRGGBB or just RRGGBB (both in hex
# format) to a 3 element array of decimal numbers in the form
# (RED GREEN BLUE).
sub _convert_color {
    my ($hexcolor) = @_;
    return _convert_color($transparentColorValue) if ($hexcolor eq "transparent");
    my ($red, $green, $blue);
    $hexcolor =~ /#?(..)(..)(..)/;
    $red   = hex($1);
    $green = hex($2);
    $blue  = hex($3);
    return ($red, $green, $blue);
}

# Return the value for the specified TWiki plugin parameter.  If the
# parameter does not exist, then return the specified default value.  The
# parameter is deleted from the list of specified parameters allowing the
# code to determine what parameters remain and were not requested.
sub _get_parameter {
    my ( $var_name, $type, $default, $parameters ) = @_;
    my $value = delete $$parameters{$var_name};         # Delete since already parsed.
    unless( defined($value) && $value ne "" ) {
        $value = $default;
    }
    my $filter = '';
    if( $type eq 'word' ) {
        $filter = '[^a-zA-Z0-9_\-]';
    } elsif( $type eq 'float') {
        $filter = '[^\-\+\.0-9e]';
    } elsif( $type eq 'pos' ) {
        $filter = '[^0-9\+]';
    } elsif( $type eq 'scale' ) {
        $filter = '[^\-\+\.0-9e, ]';
    } elsif( $type eq 'colors' ) {
        $filter = '[^\#a-zA-Z0-9\, ]';
    }
    if( $filter && $value ) {
       $value =~ s/<[^>]+//go;
       $value =~ s/$filter//g;
       return TWiki::Sandbox::untaintUnchecked( $value );
    }
    return $value;
}

# Generate the file name in which the graphic file will be placed.  Also
# make sure that the directory in which the graphic file will be placed
# exists.  If not, create it.
sub _make_filename {
    my ( $type, $name, $topic, $web ) = @_;
    # Generate the file name to be created
    my $fullname;
    # If GD version 1.19 or earlier, then create gif files else png files.
    if( $GD::VERSION > 1.19 ) {
        $fullname = "_GaugePlugin_${type}_${name}.png";
    } else {
        $fullname = "_GaugePlugin_${type}_${name}.gif";
    }

    # before save, create directories if they don't exist.
    # If the top level "pub/$web" directory doesn't exist, create it.
    my $dir = TWiki::Func::getPubDir() . "/$web";
    if( ! -e "$dir" ) {
        umask( 002 );
        mkdir( $dir, 0775 );
    }
    # If the top level "pub/$web/$topic" directory doesn't exist, create
    # it.
    my $tempPath = "$dir/$topic";
    if( ! -e "$tempPath" ) {
        umask( 002 );
        mkdir( $tempPath, 0775 );
    }
    # Return both the directory and the filename
    return ($tempPath, $fullname);
}

# This routine returns an red colored error message.
sub _make_error {
    my ( $msg ) = @_;
    return "<font color=red>GaugePlugin error: $msg</font>";
}

# This routine returns an error similar to _make_error_image() but using a
# simple <div> (making it look like an image).
sub _make_error_div {
    my ($msg, $width, $height) = @_;
    $height -= 2;
    $width -= 2;
    my $lineHeight = $height - 2;
    my $ret = "<div style='width:${width}px; height:${height}px; border:1px solid black;background-color:white; text-align:center;vertical-align:top;font-size:0.9em;padding:0px;overflow:hidden;'><span style='margin:0px;color:red;line-height:${lineHeight}px'>$msg</span></div>";
    return $ret;
}

# This routine creates and returns a PNG (optionally GIF) containing an
# error message.
sub _make_error_image {
    my ( $msg, $dir, $filename, $width, $height, $parameters ) = @_;
    my $msglen = length($msg);
    # Get info on the font used in the message so we know how much space
    # will be required to hold the message.
    my $font = GD::gdSmallFont();
    my $font_width = $font->width;
    my $font_height = $font->height;
    # Calculate the minimum size of graphic to hold the error message
    $width = _max($width, $font_width * ($msglen + 2));
    $height = _max($height, $font_height + 2);
    # Create the new image.
    my $im = new GD::Image($width, $height);
    undef %colorCache;
    # Allocate colors needed in the graphic.
    my $white = _allocateColor($im, $transparentColorValue);        # white background
    my $black = _allocateColor($im, $blackColor);              # black border
    my $red = _allocateColor($im, $redColor);              # Red letters
    # Make white background
    $im->filledRectangle(0, 0, $width - 1, $height - 1, $white);
    # Write text error message into graphic (centered)
    $im->string($font,
        ($width - ($font_width * length($msg))) / 2,
        ($height - $font_height) / 2,
        $msg, $red);
    # Make the black border
    $im->rectangle(0, 0, $width - 1, $height - 1, $black);

    # Write image file.
    my $prevUmask = umask( 002 );
    open(IMAGE, ">$dir/$filename") || return _make_error "Can't create '$dir/$filename': $!";
    binmode IMAGE;
    if( $GD::VERSION > 1.19 ) {
        print IMAGE $im->png;
    } else {
        print IMAGE $im->gif;
    }
    close IMAGE;
    umask($prevUmask);

    # Make a unique value to append to the image name that forces a web
    # browser to reload the image each time the image is viewed.  This is
    # done so value or scale changes are seen immediately and not ignored
    # because the browser has cached the image.  Eventually a hash value
    # should be used such that the user's browser CAN cache the image iff
    # none of the values used in creating the gauge have changed.
    my $timestamp = time();

    # Get remaining parameters and pass to <img ... />
    my $options = "";
    foreach my $k (keys %$parameters) {
        $options .= "$k=\"$$parameters{$k}\" ";
    }
    return "<img src=\"%ATTACHURL%/$filename?t=$timestamp\" alt=\"$msg\""
         . " width=\"$width\" height=\"$height\" $options />";
}

# Make a polygon that matches the gauge scale size.  Then scale the polygon
# to fit into the width/height of the actual image.
sub _make_poly_box {
    my ( $x1, $y1, $x2, $y2, $yoffset, $width, $left, $right ) = @_;
    # Clip the x values so they stay inside of gauge.
    $x1 = _max($x1, $left);
    $x2 = _min($x2, $right);
    my $xscale = ($width / ($right - $left));
    my $poly = new GD::Polygon;
    $poly->addPt($x1, $y1);
    $poly->addPt($x2, $y1);
    $poly->addPt($x2, $y2);
    $poly->addPt($x1, $y2);
    $poly->offset(- $left, $yoffset);
    $poly->scale($xscale, 1, 0, 0);
    my @b = $poly->bounds;
    return $poly;
}

# This is the poor mans gauge that uses simple HTML tables to build simple
# gauges.
sub _makeSimpleGauge {
    my ($topic, $web, $parameters) = @_;

    # Get the gauge colors (use defaults if not specified).
    my $colors = _get_parameter( 'colors', 'colors', $defaultColors, $parameters );
    my @colors = split(/[\s,]+/, $colors);

    # Get the tambar gauge scale values (use defaults of not specified).
    my $scale = _get_parameter( 'scale', 'scale', $defaultTambarScale, $parameters);
    my @scale = split(/[\s,]+/, $scale);
    # Get the left and right side values.  Needed to scale to the image
    # size.
    my $leftValue = $scale[0];
    my $rightValue = $scale[@scale - 1];
    # Check to see if this is a reverse gauge where the scale goes from
    # higher values down to lower values.  If so, then we need to do some
    # extra work to get this to display correctly.
    my $reverseGauge = 0;       # 0 = scale lower to higher, 1 = scale higher to lower
    if( $leftValue > $rightValue ) {
        $reverseGauge = 1;
        # Negate all scale values
        foreach my $s (@scale) {
            $s = -$s;
        }
        # Reset the left/right side of tambar
        $leftValue = -$leftValue;
        $rightValue = -$rightValue;
    }

    # Get the tambar gauge width and height (different from scale used)
    my $barWidth  = _get_parameter( 'width', 'pos', $defaultTambarWidth, $parameters);
    my $barHeight = _get_parameter( 'height', 'pos', $defaultTambarHeight, $parameters);
    my $scalesize = _get_parameter( 'scalesize', 'pos', $defaultTambarScaleHeightPercentage, $parameters);

    # Get the gauge value.
    my $barValue = _get_parameter( 'value', 'float', undef, $parameters );
    return _make_error_div("no data", $barWidth, $barHeight) if(! defined($barValue) );

    # If this is a reverse gauge, then negate the value
    $barValue = -$barValue if( $reverseGauge );

    # Compute the height of the scale portion of the gauge.  A minimum
    # value of 0.  Since we are using tables and 1px is used for the top
    # and bottom borders, we need to subtract 2 as we calculate the scale
    # height.
    my $scaleHeight = _max(0, ($barHeight - 2) * ($scalesize / 100.0));

    my $scaleRange = $rightValue - $leftValue;
    # Get the colors to use when drawing the bar.
    my $value_color_dark;
    my $value_color_light;
    my $color_fg;
    my $color_bg;
    my $scaleWidth = $barWidth - 2;
    my $scaleHTML = "<table style='width:${scaleWidth}px; height:${scaleHeight}px;' cellSpacing='0' cellPadding='0'><tr>";
    my $scaleColumns = 0;
    for my $i (1..@scale - 1) {
        # Obtain the colors for the dark and light versions of each color.
        $color_fg = $colors[($i - 1) * 2];
        $color_bg = $colors[($i - 1) * 2 + 1];
        # Determine the dark/light color to be used to represent the actual
        # value of the gauge.
        if( ($barValue <= $scale[$i]) && ! defined($value_color_dark)) {
            $value_color_dark = $color_fg;
            $value_color_light = $color_bg;
        }
	my $left = (($scale[$i - 1] - $leftValue) / $scaleRange) * $barWidth;
	my $right = (($scale[$i] - $leftValue) / $scaleRange) * $barWidth;
	my $w = $right - $left;
	$scaleHTML .= "<td style='background-color:$color_fg; width:${w}px;border:0;padding:0;'></td>";
	$scaleColumns++;
    }
    $scaleHTML .= "</tr></table>";
    # If not defined, then the value is greater than the max of the scale
    # so use the last colors seen
    if( ! defined $value_color_dark ) {
        $value_color_dark = $color_fg;
        $value_color_light = $color_bg;
    }

    # Force the value to be inside the bar. 
    $barValue = $leftValue if ($barValue < $leftValue);
    $barValue = $rightValue if ($barValue > $rightValue);

    # Adjust the barValue to have a min value such that it gets drawn with
    # a least a little color.
    my $minBarValue = $leftValue + $scaleRange * 0.03;
    $barValue = $minBarValue if ($barValue < $minBarValue);

    my $leftWidth = (($barValue - $leftValue) / $scaleRange) * $barWidth;
    my $rightWidth = $barWidth - $leftWidth;
    my $valueHeight = $barHeight - $scaleHeight - 2;

    my $ret = "<table style='display: inline-block; width:${barWidth}px; height:${barHeight}px; border-collapse:collapse; vertical-align:top;' cellSpacing='0' cellPadding='0'>";
    my $colSpan = 1;
    if ($scaleHeight < ($barHeight - 3)) {
	$ret .= "<tr><td style='background-color:$value_color_dark;width:${leftWidth}px;height:${valueHeight}px;border:1px solid black;padding:0px;'></td>";
	if ($rightWidth > 0) {
	    $ret .= "<td style='background-color:$value_color_light;width:${rightWidth}px;border:1px solid black;padding:0px;'></td></tr>";
	    $colSpan++;
	}
    }
    if ($scaleHeight) {
	$ret .= "<tr><td colspan=$colSpan valign=bottom style='height:${scaleHeight}px;border:1px solid black;padding:0px;'>$scaleHTML</td></tr>";
    }
    $ret .= "</table>";

    return $ret;
}

# Make a gauge.  Determine the type so we know what to do.
sub _make_gauge {
    my ($session, $params, $topic, $web) = @_;
    _init_defaults() if( !$pluginInitialized );
    my $parameters = new TWiki::Attrs($params->{_RAW}, 1);
    delete $parameters->{_RAW};
    my $type = _get_parameter( 'type', 'word', $defaultType, $parameters );
    return _makeSimpleGauge($topic, $web, $parameters) if($type eq "simple");
    return _make_trend_gauge($topic, $web, $parameters) if($type eq "trend");

    # If the GD module was found, then create an error image.
    if( $perlGDModuleFound ) {
        return _make_tambar_gauge( $topic, $web, $parameters ) if( $type eq "tambar" );
        return _make_error( "Unknown gauge type '$type'" );
    } else {
	# Since no GD library, if 'tambar', fail over to 'simple'
	return _makeSimpleGauge($topic, $web, $parameters) if( $type eq "tambar" );
        # It appears that the GD library wasn't found so we return a
        # different type of error that is just plain text.
        return _make_error("Required Perl module 'GD' not found");
    }
}

# Make a tambar gauge
sub _make_tambar_gauge {
    my ( $topic, $web, $parameters ) = @_;
    my ( $poly, $i, $scale );
    my ( $color_fg, $color_bg, $value_color_dark, $value_color_light );

    # Get the gauge colors (use defaults if not specified).
    my $tambar_colors = _get_parameter( 'colors', 'colors', $defaultColors, $parameters );
    my @tambar_colors = split(/[\s,]+/, $tambar_colors);

    # Get the tambar gauge scale values (use defaults of not specified).
    my $tambar_scale = _get_parameter( 'scale', 'scale', $defaultTambarScale, $parameters);
    my @tambar_scale = split(/[\s,]+/, $tambar_scale);
    # Get the left and right side values.  Needed to scale to the image
    # size.
    my $tambar_left = $tambar_scale[0];
    my $tambar_right = $tambar_scale[@tambar_scale - 1];
    # Check to see if this is a reverse gauge where the scale goes from
    # higher values down to lower values.  If so, then we need to do some
    # extra work to get this to display correctly.
    my $reverseGauge = 0;       # 0 = scale lower to higher, 1 = scale higher to lower
    if( $tambar_left > $tambar_right ) {
        $reverseGauge = 1;
        # Negate all scale values
        foreach my $s (@tambar_scale) {
            $s = -$s;
        }
        # Reset the left/right side of tambar
        $tambar_left = -$tambar_left;
        $tambar_right = -$tambar_right;
    }

    # Get the tambar gauge width and height (different from scale used)
    my $tambar_width  = _get_parameter( 'width', 'pos', $defaultTambarWidth, $parameters);
    my $tambar_height = _get_parameter( 'height', 'pos', $defaultTambarHeight, $parameters);
    my $tambar_scalesize = _get_parameter( 'scalesize', 'pos', $defaultTambarScaleHeightPercentage, $parameters);
    my $tambar_access = _get_parameter( 'access', 'word', $defaultTambarAccess, $parameters);
    if ($tambar_access ne "inline" && $tambar_access ne "file") {
	return _make_error("parameter *access* must be one of *inline* or *file*.");
    }

    # Compute the height of the scale portion of the gauge.  A minimum
    # value of 0, but is in general an 8th the size of the gauge value
    # part.
    my $tambar_scale_top;
    my $tambar_scale_bottom = $tambar_height;
    if ($tambar_scalesize == 0) {
	$tambar_scale_top = $tambar_height;
    } else {
	my $tambar_scale_height = _max(0, $tambar_height * ($tambar_scalesize / 100.0));
	$tambar_scale_top = $tambar_height - $tambar_scale_height;
    }

    # See if the parameter 'name' is available.  This is a required
    # parameter.  If it is missing, then generate an error message.
    my $name = _get_parameter( 'name', 'word', undef, $parameters);
    return _make_error("parameter *name* must be specified") unless( $name );

    # Generate the name of the graphic file that will be referenced
    my ( $dir, $filename ) = _make_filename("tambar", $name, $topic, $web);

    # Get the gauge value.
    my $value = _get_parameter( 'value', 'float', undef, $parameters );

    # Get the gauge IMG 'alt' text.  If there is no value, then use 'value' as the default
    my $alt = _get_parameter( 'alt', '', $value, $parameters ) || "";

    # clean up numerical value
    if( ( defined $value ) && ($value =~ m/([\-]?[0-9.]+[eE]?[+-]?\d*)/)) {
        $value = $1;
    } else {
        # If there is no numerical value, then create an error graphic noting the error
        return _make_error_image( "no data", $dir, $filename, $tambar_width, $tambar_height, $parameters );
    }

    # If this is a reverse gauge, then negate the value (leaving 'alt' alone)
    $value = -$value if( $reverseGauge );

    # OK, we are ready to generate the tambar gauge.
    # Create an image with a width = the last value specified in
    # tambar_scale.
    my $im = new GD::Image($tambar_width, $tambar_height);
    undef %colorCache; 

    # Allocate some colors used by the image.
    my $white = _allocateColor($im, $transparentColorValue);        # white background
    my $black = _allocateColor($im, $blackColor);              # black border

    # Make white the transparent color
    $im->transparent($white);

    undef $value_color_dark;
    undef $value_color_light;
    # Draw the scale for the bar gauge
    for $i (1..@tambar_scale - 1) {
        # Obtain the colors for the dark and light versions of each color.
        $color_fg = _allocateColor($im, $tambar_colors[($i - 1) * 2]);
        $color_bg = _allocateColor($im, $tambar_colors[($i - 1) * 2 + 1]);
        # Make a polygon that is initially in scale specified by the user
        # but then is remapped to fit inside the actual graphic size.
        $poly = _make_poly_box(
            $tambar_scale[$i - 1], $tambar_scale_top,
            $tambar_scale[$i], $tambar_scale_bottom,
            0,
            $tambar_width, $tambar_left, $tambar_right
            );
        $im->filledPolygon($poly, $color_fg);

        # Determine the dark/light color to be used to represent the actual
        # value of the gauge.
        if( ($value <= $tambar_scale[$i]) && ! defined $value_color_dark ) {
            $value_color_dark = $color_fg;
            $value_color_light = $color_bg;
        }
    }
    # If not defined, then the value is greater than the max of the scale
    # so use the last colors seen
    if( ! defined $value_color_dark ) {
        $value_color_dark = $color_fg;
        $value_color_light = $color_bg;
    }

    # Compute a 'value' to display forcing the display value to be within
    # the scale.  If the value is left of the left side of the scale, then
    # force a small bar (2 pixels) to be drawn.
    my $values_per_pixel = ($tambar_right - $tambar_left) / $tambar_width;
    my $valueInc = $values_per_pixel * 2;
    my $displayValue = _max($value, ($tambar_left + $valueInc));

    # Draw the gauge value
    $poly = _make_poly_box(
        $tambar_left, 0,
        $displayValue, $tambar_scale_top,
        0,
        $tambar_width, $tambar_left, $tambar_right );
    $im->filledPolygon($poly, $value_color_dark);

    # Fill out a lighter color from the gauge value to the end of the
    # gauge.
    $poly = _make_poly_box(
        $displayValue, 0,
        $tambar_right, $tambar_scale_top,
        0,
        $tambar_width, $tambar_left, $tambar_right );
    $im->filledPolygon($poly, $value_color_light);

    # Draw a black line at the gauge value.  Use the poly routine since it
    # does the scaling automatically for us.
    $poly = _make_poly_box(
        $displayValue, 0,
        $displayValue, $tambar_scale_top,
        0,
        $tambar_width, $tambar_left, $tambar_right );
    $im->filledPolygon($poly, $black);

    # Draw the black line separating the gauge value from the gauge scale.
    $im->line(0, $tambar_scale_top, $tambar_width, $tambar_scale_top, $black);

    # Draw a black border around the entire gauge.
    $im->rectangle(0, 0, $tambar_width - 1, $tambar_height - 1, $black);

    if ($tambar_access eq "inline") {
	my $ret;
	if( $GD::VERSION > 1.19 ) {
	    $ret = "<img src=\"data:image/png;base64," .  raw2URI($im->png) . "\" />";
	} else {
	    $ret = "<img src=\"data:image/gif;base64," .  raw2URI($im->gif) . "\" />";
	}
	return $ret;
    }

    # Create the file.
    my $prevUmask = umask( 002 );
    open(IMAGE, ">$dir/$filename") || return _make_error "Can't create '$dir/$filename': $!";
    binmode IMAGE;
    if( $GD::VERSION > 1.19 ) {
        print IMAGE $im->png;
    } else {
        print IMAGE $im->gif;
    }
    close IMAGE;
    umask($prevUmask);

    # Make a unique value to append to the image name that forces a web
    # browser to reload the image each time the image is viewed.  This is
    # done so value or scale changes are seen immediately and not ignored
    # because the browser has cached the image.  Eventually a hash value
    # should be used such that the user's browser CAN cache the image iff
    # none of the values used in creating the gauge have changed.
    my $timestamp = time();

    # Get remaining parameters and pass to <img ... />
    my $options = "";
    foreach my $k (keys %$parameters) {
        $options .= "$k=\"$$parameters{$k}\" ";
    }
    my $img = "<img src=\"%ATTACHURL%/$filename?t=$timestamp\" alt=\"$alt\""
         . " width=\"$tambar_width\" height=\"$tambar_height\" $options />";
    return $img;
}

# Make a trend gauge (an arrow)
sub _make_trend_gauge {
    my ( $topic, $web, $parameters ) = @_;
    my ( $poly, $i, $scale );
    my ( $color_fg, $color_bg, $value_color_dark, $value_color_light );

    # Get the trend gauge width and height (different from scale used)
    my $trend_width  = _get_parameter( 'width', 'pos', $defaultTrendWidth, $parameters);
    my $trend_height = _get_parameter( 'height', 'pos', $defaultTrendHeight, $parameters);

    # Get the trend value.  If there is no value, then create an error graphic noting the error
    my $filename;
    my $value = _get_parameter( 'value', 'float', undef, $parameters );

    # Get the gauge IMG 'alt' text.  If there is no value, then use 'value' as the default
    my $alt = _get_parameter( 'alt', '', $value, $parameters ) || "";

    # clean up numerical value
    if( ( defined $value ) && ( $value =~ /^.*?([\+\-]?[0-9\.]+).*$/ ) ) {
        $value = $1;

        # OK, we are ready to generate the trend gauge.  This is simple since
        # the graphics are assumed to already exist so we just figure out which
        # one to display and then display it.
        $filename = "trenddn.gif" if( $value < 0 );
        $filename = "trendeq.gif" if( $value == 0 );
        $filename = "trendup.gif" if( $value > 0 );

    } else {
        # show the "no data" gif
        $filename = "trendnd.gif";
        $alt = "no data" unless( $alt );
    }

    # Get remaining parameters and pass to <img ... />
    my $options = "";
    foreach my $k (keys %$parameters) {
        $options .= "$k=\"$$parameters{$k}\" ";
    }
    my $timestamp = time();
    return "<img src=\"%PUBURL%/$installWeb/GaugePlugin/$filename?t=$timestamp\""
         . " width=\"$trend_width\" height=\"$trend_height\" alt=\"$alt\" $options />";
}

# This routine converts a file into a data URI
sub file2URI {
    my ($file) = @_;
    my $base64 = "";
    open(FILE, $file);
    my $buf;
    while (read(FILE, $buf, 57)) {
	$base64 .= encode_base64($buf);
    }
    close(FILE);
    $base64 =~ s/\n//g;
    return $base64;
}

sub raw2URI {
    my ($data) = @_;
    my $base64 = encode_base64($data);
    $base64 =~ s/\n//g;
    return $base64;
}

# This routine is used to 'cache' colors so colors are reused instead of
# replicated.
sub _allocateColor {
    my ($im, $color) = @_;
    if (! defined($colorCache{$color})) {
	$colorCache{$color} = $im->colorAllocate(_convert_color($color));
    }
    return $colorCache{$color};
}

# The following is really for debugging and timing purposes and is not an
# advertised interface.  This routine basically creates a number of tambar
# gauges and (roughly) times how long it took to create them.
# Usage: %GAUGE_TIMER{###}%
# where ### is the number of gauges to create.
sub _timeit {
    my ($session, $params, $topic, $web) = @_;
    my $loops = $params->{_RAW};

    my $start_time = time();
    my $ret;
    for (my $i = 0; $i < $loops; $i++) {
        my $str = "name=\"timeit_$i\" value=\"8\"";
        $ret = _make_gauge( undef, {_RAW => $str}, $topic, $web );
    }
    my $finish_time = time();
    my $diff = $finish_time - $start_time;
    # Remove the just created test files.
    for (my $i = 0; $i < $loops; $i++) {
        my ($dir, $filename) = _make_filename("tambar", "timeit_$i", $topic, $web);
        unlink("$dir/$filename");
    }
    return "To make $loops gauges it (roughly) took $diff seconds.";
}

# This routine is for internal use only to make it easier to test various
# edge cases.
sub testit {
    my ($session, $params, $topic, $web) = @_;
    my $test = 0;
    my $minValue = 10;
    my $maxValue = 110;
    my $incValue = ($maxValue - $minValue) / 10;
    my $html = "<table style='border-collapse:collapse; border:0;'>";
    for (my $scaleSize = 0; $scaleSize <= 100; $scaleSize += 10) {
	$html .= "<tr>";
	for (my $value = $minValue; $value <= $maxValue; $value += $incValue) {
	    my $params = "name='test$test' value='$value' scalesize='$scaleSize' height='50'";
	    $html .= "<td valign=top style='border-left:3px solid blue;'>";
	    $html .= _make_gauge(0, {_RAW => $params}, $topic, $web);
	    $html .= "</td>";
	    $html .= "<td valign=top>";
	    $html .= _make_gauge(0, {_RAW => "$params, type='simple'"}, $topic, $web);
	    $html .= "</td>";
	    $test++;
	}
	$html .= "</tr>";
    }
#    $html .= "</table>";
#    $html .= "<table style='border-collapse:collapse; border:0;'>";
    for (my $value = $minValue; $value <= $maxValue; $value += $incValue) {
	$html .= "<tr>";
	for (my $scaleSize = 0; $scaleSize <= 100; $scaleSize += 10) {
	    my $params = "name='test$test' value='$value' scalesize='$scaleSize' height='50'";
	    $html .= "<td valign=top style='border-left:3px solid blue;'>";
	    $html .= _make_gauge(0, {_RAW => $params}, $topic, $web);
	    $html .= "</td>";
	    $html .= "<td valign=top>";
	    $html .= _make_gauge(0, {_RAW => "$params, type='simple'"}, $topic, $web);
	    $html .= "</td>";
	    $test++;
	}
	$html .= "</tr>";
    }
    $html .= "</table>";
    return $html;
}

1;
