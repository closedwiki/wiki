# ChartPlugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2002-2010 Peter Thoeny, Peter@Thoeny.org
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
# This file contains routines for producing PNG graphic files containing
# chart information, useful for building dashboards.
#    NOTE: ONLY in the case where an old version of GD (1.19 or earlier) is
#    available will GIF's be created.  If the GD version is > 1.19, then
#    PNG's are created.
#
# This plugin uses Perl object oriented programming.  The ChartPlugin
# object contains several other Perl objects:
#     Table
#     Parameters
#     Chart
# In addition to having it's own getter/setters.

# =========================
package TWiki::Plugins::ChartPlugin;

use strict;

# =========================
use vars qw(
    $installWeb $VERSION $RELEASE $debug
    $pluginInitialized $initError
    $defaultType @defaultAreaColors @defaultLineColors
    $defaultWidth $defaultHeight $defaultBGcolor
    $defaultDataValue $defaultScale $defaultGridColor $defaultBorderColor $defaultPointSize
    $defaultLineWidth $defaultNumYGrids
    $defaultYMin $defaultYMax
    $defaultBarLeadingSpaceUnits $defaultBarTrailingSpaceUnits $defaultBarSpaceUnits $defaultBarWidthUnits
    $defaultSparkBarLeadingSpaceUnits $defaultSparkBarTrailingSpaceUnits $defaultSparkBarSpaceUnits $defaultSparkBarWidthUnits
    $defaultShowError
    %cachedTables $showParameters
    );

$VERSION = '$Rev$';
$RELEASE = '2011-05-11';

$pluginInitialized = 0;
$initError         = '';

# =========================
sub initPlugin {
    (my $topic, my $web, my $user, $installWeb) = @_;

    # check for Plugins.pm versions
    if ($TWiki::Plugins::VERSION < 1) {
        &TWiki::Func::writeWarning("Version mismatch between ChartPlugin and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag("CHARTPLUGIN_DEBUG") || 0;

    # Allow for debug output.  By default, we always just output an <img> tag.
    $showParameters = '%IMG%';

    &TWiki::Func::writeDebug("- TWiki::Plugins::ChartPlugin::initPlugin($web.$topic) is OK") if $debug;

    # Mark that we are not fully initialized yet.  Only get the default
    # values from the plugin topic page iff a CHART is found in a topic
    $pluginInitialized = 0;
    return 1;
} ## end sub initPlugin

# =========================

# Initialize all default values from the plugin topic page.
sub _init_defaults {
    return if $pluginInitialized;
    $pluginInitialized = 1;
    require Exporter;
    foreach my $module qw(
	GD
	POSIX
	Text::Wrap
        TWiki::Plugins::ChartPlugin::Chart
        TWiki::Plugins::ChartPlugin::Parameters
        TWiki::Plugins::ChartPlugin::Table
	) {
        eval "require $module";
	if ($@) {
	    $initError = "Required Perl module '$module' not found: $@";
	    return;
	}
    }

    # Get default chart type
    $defaultType = getChartPluginPreferencesValue("TYPE", 'line');
    $defaultYMin = getChartPluginPreferencesValue("YMIN", undef);
    $defaultYMax = getChartPluginPreferencesValue("YMAX", undef);
    # Get default chart values
    $defaultWidth  = getChartPluginPreferencesValue("WIDTH",  60);
    $defaultHeight = getChartPluginPreferencesValue("HEIGHT", 16);
    my $defaultAreaColors = getChartPluginPreferencesValue("AREA_COLORS", "#FF0000 #FFFF00 #00FF00");
    @defaultAreaColors = split(/[\s,]+/, $defaultAreaColors);
    my $defaultLineColors = getChartPluginPreferencesValue("LINE_COLORS", "#FFFF00 #FF00FF #00FFFF");
    @defaultLineColors = split(/[\s,]+/, $defaultLineColors);
    # Get default chart bgcolor
    $defaultBGcolor = getChartPluginPreferencesValue("BGCOLOR", '#FFFFFF #FFFFFF');
    # Get default number of Y axis grids
    $defaultNumYGrids = getChartPluginPreferencesValue("NUMYGRIDS", undef);
    # Get default value to use if there is no data seen in the table
    $defaultDataValue = getChartPluginPreferencesValue("DEFAULTDATA", "none");
    # Get default value for the scale (linear/semilog)
    $defaultScale = getChartPluginPreferencesValue("SCALE", "linear");
    # Get default grid color.
    $defaultGridColor = getChartPluginPreferencesValue("GRIDCOLOR", '#000000');
    # Get default chart border color.
    $defaultBorderColor = getChartPluginPreferencesValue("BORDERCOLOR", '#FFFFFF');
    # Get default value for the size, in pixels, of drawn data points
    $defaultPointSize = getChartPluginPreferencesValue("POINTSIZE", 2);
    # Get default value for the width, in pixels, of drawn lines
    $defaultLineWidth = getChartPluginPreferencesValue("LINEWIDTH", 3);
    # Get default value for the leading space before the first bar.
    $defaultBarLeadingSpaceUnits = getChartPluginPreferencesValue("BARLEADINGSPACEUNITS", 0);
    # Get default value for the trailing space after the last bar.
    $defaultBarTrailingSpaceUnits = getChartPluginPreferencesValue("BARTRAILINGSPACEUNITS", 0);
    # Get default value for the space between bars.
    $defaultBarSpaceUnits = getChartPluginPreferencesValue("BARSPACEUNITS", 1);
    # Get default value for the width of bars.
    $defaultBarWidthUnits = getChartPluginPreferencesValue("BARWIDTHUNITS", 2);
    # Get default value for the leading space before the first sparkbar.
    $defaultSparkBarLeadingSpaceUnits = getChartPluginPreferencesValue("SPARKBARLEADINGSPACEUNITS", 0);
    # Get default value for the trailing space after the last sparkbar.
    $defaultSparkBarTrailingSpaceUnits = getChartPluginPreferencesValue("SPARKBARTRAILINGSPACEUNITS", 0);
    # Get default value for the space between sparkbars.
    $defaultSparkBarSpaceUnits = getChartPluginPreferencesValue("SPARKBARSPACEUNITS", 1);
    # Get default value for the width of sparkbars.
    $defaultSparkBarWidthUnits = getChartPluginPreferencesValue("SPARKBARWIDTHUNITS", 2);
    # Get default value for showerror
    $defaultShowError = getChartPluginPreferencesValue("SHOWERROR", "text");
} ## end sub _init_defaults

sub getChartPluginPreferencesValue {
    my ($key, $default) = @_;
    my $value = &TWiki::Func::getPreferencesValue("CHARTPLUGIN_$key");
    return $default if (! defined($value));
    return $value;
}

# Object constructor for creating a ChartPlugin Perl object.  The object is
# initialized with the current web.topic.
sub ChartPlugin {
    my ($currentTopic, $currentWeb, $currentTopicContents) = @_;
    my $this = {};
    bless $this;
    $this->{CURRENT_TOPIC}        = $currentTopic;
    $this->{CURRENT_WEB}          = $currentWeb;
    $this->{CURRENT_TOPICONTENTS} = $currentTopicContents;
    return $this;
}

# Setter for storing the Table object
sub _setTables {my ($this, $table) = @_; $this->{TABLES} = $table;}
# Getter for Table object
sub _tables {my ($this) = @_; return $this->{TABLES};}

# Setter for storing the Parameters object
sub _setParameters {
    my ($this, $args) = @_;
    $this->{PARAMETERS} = TWiki::Plugins::ChartPlugin::Parameters->new($args);
}

# Getter for Parameters object
sub _Parameters {my ($this) = @_; return $this->{PARAMETERS};}

# This routine sets the specified web.topic as the location from where to
# get the table information.  If the specified web.topic happen to be the
# same as the web.topic from which the %CHART% was found, then the
# web.topic contents is already part of the ChartPlugin object so there is
# nothing to do.  Otherwise, this routine will read in the specified
# web.topic getting its contents and using that as the source to parse out
# table information.
sub _setTopicContents {
    my ($this, $inWeb, $inTopic) = @_;
    my $topicContents;
    # If $inWeb and $inTopic match the current web/topic, then we already
    # have the topic contents in the object so there is nothing to do.
    # Otherwise, we need to open the specified web/topic and read in its
    # contents.
    if (($inWeb eq $this->{CURRENT_WEB}) && ($inTopic eq $this->{CURRENT_TOPIC})) {
        $topicContents = $this->{CURRENT_TOPICONTENTS};
    } else {
        # A difference, so read in the topic.
        (my $meta, $topicContents) = TWiki::Func::readTopic($inWeb, $inTopic);
        # Check to make sure the web.topic actually exists.  If not, return
        # undef so the caller can catch the error.
        return undef if ($topicContents eq "");
        $topicContents = TWiki::Func::expandCommonVariables($topicContents, $inTopic, $inWeb);
    }

    # Lets parse the specified topic contents looking for tables.
    # Assuming that there might be multiple charts coming from the same
    # web/topic page, we want to cache the table parsing so we only do it
    # once per web/topic page.
    if (defined($cachedTables{$inWeb}) && defined($cachedTables{$inWeb}{$inTopic})) {
	$this->_setTables($cachedTables{$inWeb}{$inTopic});
    } else {
	my $table = TWiki::Plugins::ChartPlugin::Table->new($topicContents);
	$this->_setTables($table);
	$cachedTables{$inWeb}{$inTopic} = $table;
    }
    return 1;
} ## end sub _setTopicContents

# Return the maximum value of the two specified numbers.
sub _max {
    my ($v1, $v2) = @_;
    return $v1 if ($v1 > $v2);
    return $v2;
}

# Return the minimum value of the two specified numbers.
sub _min {
    my ($v1, $v2) = @_;
    return $v1 if ($v1 < $v2);
    return $v2;
}

# Generate the file name in which the graphic file will be placed.  Also
# make sure that the directory in which the graphic file will be placed
# exists.  If not, create it.
sub _make_filename {
    my ($type, $name, $topic, $web) = @_;
    # Generate the file name to be created
    my $fullname;
    # If GD version 1.19 or earlier, then create gif files else png files.
    if ($GD::VERSION > 1.19) {
        $fullname = "_ChartPlugin_${type}_${name}.png";
    } else {
        $fullname = "_ChartPlugin_${type}_${name}.gif";
    }

    # before save, create directories if they don't exist.
    # If the top level "pub/$web" directory doesn't exist, create it.
    my $dir = TWiki::Func::getPubDir() . "/$web";
    if (! -e "$dir") {
        umask(002);
        mkdir($dir, 0775);
    }
    # If the top level "pub/$web/$topic" directory doesn't exist, create
    # it.
    my $tempPath = "$dir/$topic";
    if (! -e "$tempPath") {
        umask(002);
        mkdir($tempPath, 0775);
    }
    # Return both the directory and the filename
    return ($tempPath, $fullname);
} ## end sub _make_filename

# This routine returns an red colored error message.
sub _make_error {
    my ($this, $msg) = @_;

    my $showError = $this->{showerror};
    if ($showError eq "image") {
	# Strip out any HTML or TWiki modifiers from the error msg;
	$msg =~ s/<.*?>//g;
	$msg =~ s/\*(\W+)/$1/g;
	$msg =~ s/(\W+)\*/$1/g;
	$msg =~ s/&lt;/</g;
	$msg =~ s/&gt;/>/g;

	my $chart = TWiki::Plugins::ChartPlugin::Chart->new();
	my $width = $this->{width};
	my $height = $this->{height};
	$chart->setImageWidth($width);
	$chart->setImageHeight($height);

	my $name = $this->{name};
	my ($dir, $filename) = _make_filename("error", $name, $this->{topic}, $this->{web});
	$chart->setFileDir($dir);
	$chart->setFileName($filename);
	$chart->setTitle($msg);
	$chart->makeError("ChartPlugin error: $msg");

	my $timestamp = time();
	my $img = "<img src=\"%ATTACHURL%/$filename?t=$timestamp\" alt=\"Error seen\" />";
	return $img;
    } elsif ($showError =~ /no/i) {
	return "&nbsp;";
    } else {
	$Text::Wrap::columns = 40;
	my $numLines = my @lines = split(/\n/, Text::Wrap::wrap("", "", $msg));
	my $ret = "<span width='300' style='color:red; white-space:nowrap;'>ChartPlugin error:<br/>";
	foreach my $line (@lines) {
	    $ret .= "$line<br/>";
	}
	$ret .= "</span>";
	return $ret;
	return "<font color=red>ChartPlugin error: $msg</font>";
    }
}

# Actually construct the chart by parsing out each of the %CHART%
# parameters, putting the parameters into the chart object, and then
# creating the chart.
sub _makeChart {
    my ($this, $args, $topic, $web) = @_;

    $this->{topic} = $topic;
    $this->{web} = $web;
    $this->{width} = $defaultWidth;
    $this->{height} = $defaultHeight;
    $this->{name} = "undefined";

    # Check to see if the GD module was found.  If not, then create an
    # error message to display back to the user.
    if ($initError) {
        # It appears that a library wasn't found so we return a
        # different type of error that is just plain text.
        return $this->_make_error($initError);
    }
    # Set/parse the %CHART% parameters putting into the ChartPlugin object
    $this->_setParameters($args);

    # Before we do anything, get the type of error msg to create if an
    # error is seen.
    $this->{showerror} = $this->_Parameters->getParameter("showerror", $defaultShowError);

    # Make a chart object in which we will place user specified parameters
    my $chart = TWiki::Plugins::ChartPlugin::Chart->new();

    # See if the parameter 'name' is available.  This is a required
    # parameter.  If it is missing, then generate an error message.
    my $name = $this->_Parameters->getParameter("name", undef);
    return $this->_make_error("parameter *name* must be specified") if (! defined $name);
    $this->{name} = $name;

    # Get the chart width and height
    $this->{width} = _max(1, int($this->_Parameters->getParameter("width", $defaultWidth)));
    $this->{height} = int($this->_Parameters->getParameter("height", $defaultHeight));
    $chart->setImageWidth($this->{width});
    $chart->setImageHeight($this->{height});

    # See if the parameter 'type' is available.  This is a required
    # parameter.  If it is missing, then generate an error message.
    my $type = $this->_Parameters->getParameter("type", $defaultType);
    return $this->_make_error("parameter *type* must be specified") if (! defined $type);
    my @unknownTypes = grep(! /area|line|bar|arealine|combo|scatter|sparkline|sparkbar/, ($type));
    # Check for a valid type
    return $this->_make_error("Invalid value of *$type* for parameter *type* ") if (@unknownTypes);
    $chart->setType($type);

    # See if the parameter 'subtype' (old name 'datatype') is available.
    my $dataType = $this->_Parameters->getParameter("datatype", undef);
    my $subType  = $this->_Parameters->getParameter("subtype",  undef);
    my $subType2  = $this->_Parameters->getParameter("subtype2",  undef);
    return $this->_make_error("paramters *datatype* and *subtype* can't both be specified") if (defined $dataType && defined $subType);

    $subType = $dataType if (defined $dataType);
    if (defined($subType2)) {
	$subType = "$subType,$subType2";
    }
    if (defined($subType)) {
        my @subTypes = split(/[\s,]+/, $subType);
        # Check for valid subtypes
        my @unknownSubTypes;
	foreach my $subType (@subTypes) {
	    my $ok = grep {$_ eq $subType} qw(area line point pline scatter bar);
	    push(@unknownSubTypes, $subType) if (! $ok);
	}
        return $this->_make_error("unknown subtypes: " . join(", ", @unknownSubTypes)) if (@unknownSubTypes);
        # Now check to make sure that the subtypes specified are valid for the
        # specified type.
        ### Check 'line' type
        if ($type eq "line") {
            @unknownSubTypes = grep(! /line|point|pline/, @subTypes);
            return $this->_make_error("unsupported subtypes: " . join(", ", @unknownSubTypes) . " for type line") if (@unknownSubTypes);
        }

        ### Check 'area' type
        if ($type eq "area") {
            @unknownSubTypes = grep(! /area/, @subTypes);
            return $this->_make_error("unsupported subtypes: " . join(", ", @unknownSubTypes) . " for type area") if (@unknownSubTypes);
        }

        ### Check 'scatter' type
        if ($type eq "scatter") {
            @unknownSubTypes = grep(! /area|line|point|pline|bar/, @subTypes);
            return $this->_make_error("unsupported subtypes: " . join(", ", @unknownSubTypes) . " for type scatter") if (@unknownSubTypes);
        }

        ### Check 'combo' type
        if ($type eq "combo") {
            @unknownSubTypes = grep(! /area|line|point|pline|bar/, @subTypes);
            return $this->_make_error("unsupported subtypes: " . join(", ", @unknownSubTypes) . " for type combo") if (@unknownSubTypes);
        }
        ### Check 'spark*' types
        if ($type =~ /^spark/) {
            return $this->_make_error("subtype can not be used when type = '$type'");
        }

        # All OK so set the subtype.
        $chart->setSubTypes(@subTypes);
    } ## end if (defined $subType)

    # See if the parameter 'scale' is available.
    my $scale = $this->_Parameters->getParameter("scale", $defaultScale);
    if ($scale ne "base10" and $scale ne "linear" and $scale ne "semilog") {
        return $this->_make_error("Invalid value of *$scale* for parameter *scale* ");
    }
    $chart->setScale($scale);

    # See if the parameter 'web' is available.  If not, then default to
    # looking for tables in the current web.
    my $inWeb = $this->_Parameters->getParameter("web", $web);

    # See if the parameter 'topic' is available.  If not, then default to
    # looking for tables in the current topic.
    my $inTopic = $this->_Parameters->getParameter("topic", $topic);

    # Before we parse any further parameters, lets get the contents of the
    # specified web/topic.
    if (! $this->_setTopicContents($inWeb, $inTopic)) {
        return $this->_make_error("Error retrieving TWiki topic $inWeb<nop>.$inTopic");
    }

    # Determine which table the user wants to chart
    my $tableName = $this->_Parameters->getParameter("table", 1);
    # Verify that the table name is valid.
    if (! $this->_tables->checkTableExists($tableName)) {
        return $this->_make_error("parameter *table* is not valid table; the specified table '$tableName' does not exist.");
    }

    # See if the parameter 'title' is available.
    $chart->setTitle($this->_Parameters->getParameter("title", undef));

    # See if the parameter 'xlabel' is available.
    $chart->setXlabel($this->_Parameters->getParameter("xlabel", undef));

    # See if the parameter 'ylabel' or 'ylabel2' is available.
    my $ylabel = $this->_Parameters->getParameter("ylabel", undef);
    $chart->setYlabel1($ylabel) if (defined($ylabel));
    $chart->setYlabel2($this->_Parameters->getParameter("ylabel2", undef));

    # See if the parameter 'data' is available.  This is a required
    # parameter.  If it is missing, then generate an error message.
    my $data = $this->_Parameters->getParameter("data", undef);
    my $data2 = $this->_Parameters->getParameter("data2", undef);
    if (! defined($data)) {
	return $this->_make_error("parameter *data* must be specified");
    }

    # See if the parameter 'xaxis' is available.
    my $xAxis = $this->_Parameters->getParameter("xaxis", undef);

    # See if the parameter 'yaxis' or 'yaxis2' is available.
    my $yAxis = $this->_Parameters->getParameter("yaxis", undef);
    my $yAxis2 = $this->_Parameters->getParameter("yaxis2", "off");
    $chart->setYaxis1($yAxis) if (defined($yAxis));
    $chart->setYaxis2($yAxis2);

    # See if the parameter 'ytics' is available.
    my $yTics = $this->_Parameters->getParameter("ytics", undef);
    my $yTics2 = $this->_Parameters->getParameter("ytics2", undef);
    $chart->setNumYTics1(int($yTics)) if (defined($yTics));
    $chart->setNumYTics2(int($yTics2)) if (defined($yTics2));

    # See if the parameter 'xaxisangle' is available.
    my $xaxisangle = _getNum($this->_Parameters->getParameter("xaxisangle", 0));
    $chart->setXaxisAngle($xaxisangle);

    # See if the parameter 'xmin' is available.
    my $xmin = $this->_Parameters->getParameter("xmin", undef);
    if (defined($xmin)) {
	if ($type ne "scatter") {
	    return $this->_make_error("user set xmin=$xmin is not valid when type not = scatter");
	}
	$xmin = _getNum($xmin);
    }
    $chart->setXmin($xmin);

    # See if the parameter 'xmax' is available.
    my $xmax = $this->_Parameters->getParameter("xmax", undef);
    if (defined($xmax)) {
	if ($type ne "scatter") {
	    return $this->_make_error("user set xmax=$xmax is not valid when type not = scatter");
	}
	$xmax = _getNum($xmax);
    }
    $chart->setXmax($xmax);

    # See if the parameter 'ymin*' is available.
    my $ymin  = $this->_Parameters->getParameter("ymin",  $defaultYMin);
    my $ymin2 = $this->_Parameters->getParameter("ymin2", $defaultYMin);
    if (defined($ymin)) {
	$ymin = _getNum($ymin);
	if ($scale eq "semilog" && $ymin <= 0) {
	    return $this->_make_error("user set ymin=$ymin is &lt;= 0 which is not valid when scale=semilog");
	}
    }
    $chart->setYmin1($ymin);
    if (defined($ymin2)) {
	$ymin2 = _getNum($ymin2);
	if ($scale eq "semilog" && $ymin2 <= 0) {
	    return $this->_make_error("user set ymin2=$ymin2 is &lt;= 0 which is not valid when scale=semilog");
	}
	$chart->setYmin2($ymin2);
    }

    # See if the parameter 'ymax' is available.
    my $ymax  = $this->_Parameters->getParameter("ymax", $defaultYMax);
    my $ymax2 = $this->_Parameters->getParameter("ymax2", $defaultYMax);
    if (defined($ymax)) {
	$ymax = _getNum($ymax);
	if ($scale eq "semilog" && $ymax <= 0) {
	    return $this->_make_error("user set ymax=$ymax is &lt;= 0 which is not valid when scale=semilog");
	}
    }
    $chart->setYmax1($ymax);
    if (defined($ymax2)) {
	$ymax2 = _getNum($ymax2);
	if ($scale eq "semilog" && $ymax2 <= 0) {
	    return $this->_make_error("user set ymax2=$ymax2 is &lt;= 0 which is not valid when scale=semilog");
	}
	$chart->setYmax2($ymax2);
    }

    # Set the default number of ygrids
    $chart->setDefNumYGrids($defaultNumYGrids);

    # See if the parameter 'numygrids' is available.
    my $numygrids = $this->_Parameters->getParameter("numygrids", undef);
    if (defined($numygrids)) {
	$chart->setNumYGrids(_max(1, int($numygrids)));
    }

    # See if the parameter 'numxgrids' is available.
    my $numxgrids = _min(10, int($this->_Parameters->getParameter("numxgrids", 10)));
    $chart->setNumXGrids($numxgrids);

    # See if the parameter 'xgrid' is available.
    my $xGrid = $this->_Parameters->getParameter("xgrid", "dot");
    $chart->setXgrid($xGrid);

    # See if the parameter 'ygrid' is available.
    my $yGrid = $this->_Parameters->getParameter("ygrid", "dot");
    $chart->setYgrid($yGrid);

    # See if the parameter 'datalabel' is available.
    my $dataLabel = $this->_Parameters->getParameter("datalabel", "off");
    my $dataLabel2 = $this->_Parameters->getParameter("datalabel2", "");
    $dataLabel = "$dataLabel,$dataLabel2" if ($dataLabel2 ne "");
    $chart->setDataLabels(split(/,\s*/, $dataLabel)) if (defined $dataLabel);

    # Get the chart IMG 'alt' text.
    my $alt = $this->_Parameters->getParameter("alt", "");

    # Get the chart 'bgcolor' color.
    my @defaultBGcolors = split(/[\s,]+/, $defaultBGcolor);
    my $bgcolor = $this->_Parameters->getParameter("bgcolor", undef);
    if (defined($bgcolor)) {
	my @userBGColors = split(/[\s,]+/, $bgcolor);
	foreach my $i (0 .. $#userBGColors) {
	    $defaultBGcolors[$i] = $userBGColors[$i];
	}
    }
    $chart->setBGcolor(@defaultBGcolors);

    # Set line/area colors.  If the parameter 'colors' is defined, then the
    # chart will be made with the user specified colors.  Otherwise the
    # chart will be made with the default colors, and then it will depend
    # on if an 'area' or 'line' is being drawn which will determine which
    # set of colors to use.
    $chart->setLineColors(@defaultLineColors);
    $chart->setAreaColors(@defaultAreaColors);
    # See if the parameter 'colors' is available.
    my $colors = $this->_Parameters->getParameter("colors", undef);
    my $colors2 = $this->_Parameters->getParameter("colors2", undef);
    $colors = "$colors,$colors2" if (defined($colors2));
    $chart->setColors(split(/[\s,]+/, $colors)) if (defined($colors));

    # Get the chart border  color.
    my $borderColor = $this->_Parameters->getParameter("bordercolor", $defaultBorderColor);
    $chart->setBorderColor($borderColor);

    # Get the chart grid  color.
    my $gridColor = $this->_Parameters->getParameter("gridcolor", $defaultGridColor);
    $chart->setGridColor(split(/[\s,]+/, $gridColor));

    # See if the parameter 'defaultdata' is available.
    my $DataValueDefault = $this->_Parameters->getParameter("defaultdata", $defaultDataValue);
    $DataValueDefault = '' if ($DataValueDefault eq "none");
    $chart->setDefaultDataValue($DataValueDefault);

    # Get the name of the directory and filename in which to create the
    # graphics file.
    my ($dir, $filename) = _make_filename($type, $name, $topic, $web);
    $chart->setFileDir($dir);
    $chart->setFileName($filename);

    # If the user specified an X axis range, then extract from the X axis
    # data the starting and ending row/columns.  This defines whether the
    # data is row ordered or column ordered.  If there is no X axis
    # information specified, then assume that the data is in column order.
    my $dataOrientedVertically = 0;
    if (defined($xAxis)) {
        my ($xAxisRows, $xAxisColumns) = $this->_tables->getRowColumnCount($tableName, $xAxis, $dataOrientedVertically);
	if (! defined($xAxisRows)) {
	    return $this->_make_error("parameter *xaxis* value of '$xAxis' is not valid");
	}
        if (abs($xAxisRows) > 1) {
            if ($xAxisColumns > 1) {
                return $this->_make_error("parameter *xaxis* specifies multiple (${xAxisRows}X$xAxisColumns) rows and columns.");
            }
            $dataOrientedVertically = 1;
        }
        my @d = $this->_tables->getData($tableName, $xAxis, $dataOrientedVertically, 0);
        return $this->_make_error("no X axis data found in specified area of table [$xAxis]") if (! @d);
        $chart->setXaxis(@{$d[0]});
    } else {
	# If no xaxis parameter, look at the data parameter to see if we can figure out
	# the orientation of the data.
        my ($dataRows, $dataColumns) = $this->_tables->getRowColumnCount($tableName, $data, 0);
        $dataOrientedVertically = 1 if ($dataRows > $dataColumns);
    }

    # Get the actual data for dataSet=1.
    my @data = $this->_tables->getData($tableName, $data, $dataOrientedVertically, 1);
    # Validate that there is real data returned.
    return $this->_make_error("data ($data) points to no data") if (! @data);
    my $yminData1 = $chart->setData(@data);

    # If scale=semilog and any data is <= 0, then error
    if ($scale eq "semilog" && $yminData1 <= 0) {
        return $this->_make_error("minimum data ($yminData1) &lt;= 0 not valid when scale=semilog");
    }

    my @data2;
    if (defined($data2)) {
	# Get the actual data for dataSet=2.
	@data2 = $this->_tables->getData($tableName, $data2, $dataOrientedVertically, 1);
	# Validate that there is real data returned.
	return $this->_make_error("data2 ($data2) points to no data") if (! @data2);
	my $yminData2 = $chart->setData2(@data2);

	# If scale=semilog and any data is <= 0, then error
	if ($scale eq "semilog" && $yminData2 <= 0) {
	    return $this->_make_error("minimum data2 ($yminData2) &lt;= 0 not valid when scale=semilog");
	}
    }

    # See if the parameter 'legend' is available.
    my $legend = $this->_Parameters->getParameter("legend", undef);

    # Validate the legend data
    my @legend;
    if ($legend) {
	# Assume that if the data is vertically oriented, then the legends
	# is horizontally oriented and vis-versa
	my $legendOrientedVertically = 0;
	$legendOrientedVertically = 1 if ($dataOrientedVertically == 0);
	my @d = $this->_tables->getData($tableName, $legend, $legendOrientedVertically, 0);
	# Since users can do things like specifying R1:C5..R1:C99,R1:C4
	# which gets returned as multiply arrays of arrays, we combine all
	# arrays into a single array where we will later validate whether
	# there is enough legends to match the data to chart.
	foreach my $d (@d) {
	    push(@legend, @$d);
	}
        my $cnt = @legend;
        if ($cnt == 0) {
            return $this->_make_error("parameter *legend* contains an invalid value '$legend'.");
        }
	# Make sure that there are enough legends to go with all specified
	# data sets (if legends were specified)
        my $numLegends  = @legend;
        my $numDataSets = @data;
        $numDataSets += @data2;
        if ($numDataSets != $numLegends) {
            return $this->_make_error(
                "parameter *legend* contains an invalid value '$legend' since it specifies $numLegends legends and there are $numDataSets data sets."
            );
        }

        $chart->setLegend(@legend);
    } ## end if ($legend)

    # Set the default point size
    $chart->setPointSize(_max(1, int($this->_Parameters->getParameter("pointsize", $defaultPointSize))));

    # Set the default line width
    $chart->setLineWidth(_max(1, int($this->_Parameters->getParameter("linewidth", $defaultLineWidth))));

    # Set default bar graph values
    if ($type =~ /spark(.*)/) {
	$type = $1;
	$chart->setType($type);
	$chart->setBarLeadingSpaceUnits(0);
	$chart->setBarTrailingSpaceUnits($defaultSparkBarSpaceUnits);
	$chart->setBarSpaceUnits(0);
	$chart->setBarWidthUnits($defaultSparkBarWidthUnits);
	$chart->setShowBarBorder(0);
	$chart->setBorderColor("transparent");
	$chart->setYgrid("off");
	$chart->setLineWidth(1);
	$chart->setMargin(0);
	if ($type eq "bar" && $this->{width} <= 1) {
	    # If 'sparkbar', check to see if we need to replace the user's
	    # 'width' with an auto-computed value so all bars are seen as
	    # expected (2 pixels wide with 1 pixel spacer).
	    my $numDataPoints  = $chart->getNumDataPoints1();
	    my $minWidth = $numDataPoints * ($defaultSparkBarWidthUnits + $defaultSparkBarSpaceUnits);
	    $chart->setImageWidth($this->{width} = $minWidth);
	}
    } else {
	$chart->setBarLeadingSpaceUnits($defaultBarLeadingSpaceUnits);
	$chart->setBarTrailingSpaceUnits($defaultBarTrailingSpaceUnits);
	$chart->setBarSpaceUnits($defaultBarSpaceUnits);
	$chart->setBarWidthUnits($defaultBarWidthUnits);
	$chart->setShowBarBorder(1);
    }

    # Create the actual chart.
    my $err = $chart->makeChart();
    return $this->_make_error("chart error: name=$name: $err") if ($err);

    # Get remaining parameters and pass to <img ... />
    my $options    = "";
    my %parameters = $this->_Parameters->getAllParameters();
    delete $parameters{_RAW};
    foreach my $k (keys %parameters) {
        $options .= "$k=\"$parameters{$k}\" ";
    }
    # Make a unique value to append to the image name that forces a web
    # browser to reload the image each time the image is viewed.  This is
    # done so changes to the values used to generate the chart, or the
    # chart layout specifications, are seen immediately and not ignored
    # because the browser has cached the image.  Eventually a hash value
    # should be used such that the user's browser CAN cache the image iff
    # none of the values/parameters used in creating the chart have changed.
    my $timestamp = time();
    my $img = "<img src=\"%ATTACHURL%/$filename?t=$timestamp\" alt=\"$alt\" $options />";
    if ($showParameters ne "") {
	my $ret = $showParameters;
	$ret =~ s/%IMG%/$img/;
	$ret =~ s/%PARAMS%/$args/;
	return $ret;
    } else {
	return $img;
    }
} ## end sub _makeChart

# The following is really for debugging and timing purposes and is not an
# advertised interface.  This routine basically creates a number of charts
# and (roughly) times how long it took to create them.
# Usage: %CHART_TIMER{### <parameters>}%
# where ### is the number of charts to create and <parameters> are valid
# %CHART% parameters ('name' is overridden by the timer so is ignored if
# specified in <parameters>
sub _timeit {
    my ($this, $loops, $params, $topic, $web) = @_;
    my $removeFiles = 0;        # Flag on whether to remove the test graphics or not
    my $start_time  = time();
    for (my $i = 0; $i < $loops; $i++) {
        my $str = "$params name=\"timeit_$i\"";
        $this->_makeChart($str, $topic, $web);
    }
    my $finish_time = time();
    my $diff        = $finish_time - $start_time;
    # Remove the just created test files.
    if ($removeFiles) {
        for (my $i = 0; $i < $loops; $i++) {
            my ($dir, $filename) = _make_filename("area", "timeit_$i", $topic, $web);
            unlink("$dir/$filename");
        }
    }
    return "To make $loops charts it (roughly) took $diff seconds.<BR>";
} ## end sub _timeit

# For somewhat debugging/diag purposes, allow users the ability to specify
# an output format used by %CHART%.  This is called from:
#     %CHART_PARAMOUTPUT{<outputFormat>}%
# where outputFormat can contain anything users want, but %IMG% is replaced
# with the generated CHART tag and %PARAMS% is replaced with the CHART
# parameters.
sub _parameterOutput {
    my ($this, $params, $topic, $web) = @_;
    $showParameters = $params;
    return "";
}

# =========================
sub _getNum {
    my ($theText) = @_;
    return 0 unless ($theText);
    $theText =~ s/([0-9])\,(?=[0-9]{3})/$1/go;    # "1,234,567" ==> "1234567"
    if ($theText =~ /[0-9]e/i) {                  # "1.5e-3"    ==> "0.0015"
        $theText = sprintf "%.20f", $theText;
        $theText =~ s/0+$//;
    }
    unless ($theText =~ s/^.*?(\-?[0-9\.]+).*$/$1/o) {    # "xy-1.23zz" ==> "-1.23"
        $theText = 0;
    }
    $theText =~ s/^(\-?)0+([0-9])/$1$2/o;                 # "-0009.12"  ==> "-9.12"
    $theText =~ s/^(\-?)\./${1}0\./o;                     # "-.25"      ==> "-0.25"
    $theText =~ s/^\-0$/0/o;                              # "-0"        ==> "0"
    $theText =~ s/\.$//o;                                 # "123."      ==> "123"
    return $theText;
} ## end sub _getNum

# =========================
sub commonTagsHandler {
    ### my ( $text ) = @_;   # do not uncomment, use $_[0] instead
    my $topic = $_[1];
    my $web   = $_[2];

    # If no %CHART%s on this page, then there is nothing to do so just
    # return.
    if ($_[0] !~ m/%CHART.*{.*}%/) {
        # nothing to do
        return;
    }
    _init_defaults();
    my $chart = ChartPlugin($topic, $web, $_[0]);
    $_[0] =~ s/%CHART_PARAMOUTPUT{(.*)}%/$chart->_parameterOutput($1, $topic, $web)/eog;
    $_[0] =~ s/%CHART{(.*?)}%/$chart->_makeChart($1, $topic, $web)/eog;
    $_[0] =~ s/%CHART_TIMER{(\d+) (.*)}%/$chart->_timeit($1, $2, $topic, $web)/eog;
} ## end sub commonTagsHandler

sub mylog {
    my ($msg) = @_;
    use POSIX;
    open(LOG, ">>/tmp/mylog.txt");
    print LOG strftime("%Y/%m/%d %H:%M:%S %Z: ", localtime(time()));
    print LOG "$msg\n";
    close(LOG);
}
1;
