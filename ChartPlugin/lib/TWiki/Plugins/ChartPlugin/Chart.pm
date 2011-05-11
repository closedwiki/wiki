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
# This file contains routines for creating charts for the ChartPlugin
#
# Access is via object oriented Perl and is as follows.
#
# Constructor:
#    new()		- Create a 'chart' object an initial various default values.
# Getters/Setters
#    setType($type)	- Set the type of chart (line, area, or combo)
#    getType		- Return the chart type
#
#    setTitle($title)	- Set the chart title (top of chart) - default is none
#    getTitle		- Get the chart title
#
#    setXlabel(@labels)	- Set the label under the X axis - default is none
#    getXlabel		- Get the X label
#
#    setYlabel($flag)	- Set the label for Y axis #1- default is none
#    getYlabel		- Get Y label #1
#
#    setYlabel1($flag)	- Set the label for Y axis #1 - default is none
#    getYlabel1		- Get the Y label #1
#
#    setYlabel2($flag)	- Set the label for Y axis #2 - default is none
#    getYlabel2		- Get the Y label #2
#
#    setData(@data)	- Set the the data (array) for $LEFT yaxis
#    setData1(@data)	- Set the the data (array) for $LEFT yaxis
#    setData2(@data)	- Set the the data (array) for $RIGHT yaxis
#    getData		- Get the data (array) for $LEFT yaxis
#    getData1		- Get the data (array) for $LEFT yaxis
#    getData2		- Get the data (array) for $RIGHT yaxis
#
#    getNumDataSets	- Get the number of data sets found in data for $LEFT yaxis
#    getNumDataSets1	- Get the number of data sets found in data for $LEFT yaxis
#    getNumDataSets2	- Get the number of data sets found in data for $RIGHT yaxis
#
#    getNumDataPoints	- Get the number of data points in data set=1.
#    getNumDataPoints1	- Get the number of data points in data set=1.
#    getNumDataPoints2	- Get the number of data points in data set=2.
#
#    setYmin($min)	- Set the minimum Y value to use for $LEFT yaxis
#    setYmin1($min)	- Set the minimum Y value to use for $LEFT yaxis
#    setYmin2($min)	- Set the minimum Y value to use for $RIGHT yaxis
#    getYmin		- Get the minimum Y value for $LEFT yaxis.  If no user specified
#    			  value via setYmin(), then return the minimum
#    			  value actually seen in the data sets
#    getYmin1		- Get the minimum Y value for $LEFT yaxis.  If no user specified
#    			  value via setYmin(), then return the minimum
#    			  value actually seen in the data sets
#    getYmin2		- Get the minimum Y value for $RIGHT yaxis.  If no user specified
#    			  value via setYmin(), then return the minimum
#    			  value actually seen in the data sets
#
#    setYmax($max)	- Set the maximum Y value to use for $LEFT yaxis
#    setYmax1($max)	- Set the maximum Y value to use for $LEFT yaxis
#    setYmax2($max)	- Set the maximum Y value to use for $RIGHT yaxis
#    getYmax		- Get the maximum Y value for $LEFT yaxis.  If no user specified
#    			  value via setYmax(), then return the maximum
#    			  value actually seen in the data sets
#    getYmax1		- Get the maximum Y value for $LEFT yaxis.  If no user specified
#    			  value via setYmax(), then return the maximum
#    			  value actually seen in the data sets
#    getYmax2		- Get the maximum Y value for $RIGHT yaxis.  If no user specified
#    			  value via setYmax(), then return the maximum
#    			  value actually seen in the data sets
#
#    setXmin($min)	- Set the minimum X value to display on the chart
#			  (only applicable for scatter charts)
#    getXmin		- Get the minimum X value.  If no user specified
#    			  value via setXmin(), then return the minimum
#    			  value actually seen in the data sets
#
#    setXmax($max)	- Set the maximum X value to display on the chart
#			  (only applicable for scatter charts)
#    getXmax		- Get the maximum X value.  If no user specified
#    			  value via setXmax(), then return the maximum
#    			  value actually seen in the data sets
#
#    setSubTypes(@types)- Set array describing the subtypes for each data set.
#    			  Values can be area or line and corresponds to the
#    			  associated data set.
#    getSubTypes	- Get the array of subtypes
#
#    setXaxis(@xaxis)	- Set the array of X axis values
#    getXaxis		- Get the array of X axis values
#
#    setXaxisAngle($angle)
#                       - Set the angle of the X axis labels
#    getXaxisAngle 	- Get the angle of the X axis labels
#
#    setYaxis(@yaxis)	- Set Y axis draw flag ("on" or "off") for $LEFT yaxis
#    getYaxis		- Get the value of the Y axis draw flag for $LEFT yaxis
#
#    setYaxis1(@yaxis)	- Set Y axis draw flag ("on" or "off") for $LEFT yaxis
#    getYaxis1		- Get the value of the Y axis draw flag for $LEFT yaxis
#
#    setYaxis2(@yaxis)	- Set Y axis draw flag ("on" or "off") for $RIGHT yaxis
#    getYaxis2		- Get the value of the Y axis draw flag for $RIGHT yaxis
#
#    setDefNumYGrids($num)- Set the defaultnumber of Y axes to draw
#    getDefNumYGrids	- Get the defaultnumber of Y axes to draw
#
#    setNumYGrids($num)	- Set the number of Y axes to draw for $LEFT yaxis
#    setNumYGrids1($num)- Set the number of Y axes to draw for $LEFT yaxis
#    setNumYGrids2($num)- Set the number of Y axes to draw for $RIGHT yaxis
#    getNumYGrids	- Get the number of Y axes to draw for $LEFT yaxis
#    getNumYGrids1	- Get the number of Y axes to draw for $LEFT yaxis
#    getNumYGrids2	- Get the number of Y axes to draw for $RIGHT yaxis
#
#    setNumYTics($num)	- Set the number of tic marks to draw between Y grids for $LEFT yaxis
#    setNumYTics1($num)	- Set the number of tic marks to draw between Y grids for $LEFT yaxis
#    setNumYTics2($num)	- Set the number of tic marks to draw between Y grids for $RIGHT yaxis
#    getNumYTics	- Get the number of tic marks to draw between Y grids for $LEFT yaxis
#    getNumYTics1	- Get the number of tic marks to draw between Y grids for $LEFT yaxis
#    getNumYTics2	- Get the number of tic marks to draw between Y grids for $RIGHT yaxis
#
#    setNumXGrids($num) - Set the number of X axis to draw
#    getNumXGrids	- Get the number of X axis to draw
#
#    setXgrid($type)	- Set the type of X grid to draw (off, on, or dot)
#    getXgrid		- Get the type of X grid to draw
#
#    setYgrid($type)	- Set the type of Y grid to draw (off, on, or dot)
#    getYgrid		- Get the type of Y grid to draw
#
#    setScale($scale)	- Set the type of Y scale to use (linear or log)
#    getScale		- Get the type of Y scale to use
#
#    setDataLabels(@lbls)- Set array describing whether to draw data labels
#    			  for each data point or not.  Each element
#    			  corresponds to the associated data set.
#    getDataLabels	- Get array of data label specifications per data set
#
#    setLegend(@legend)	- Set array of legends (descriptions) for each data set
#    getLegend		- Get array of data set legends (descriptions)
#
#    setImageWidth($w)	- Set width (in pixels) of the resulting chart image
#    getImageWidth	- Get width (in pixels) of the chart image
#
#    setImageHeight($h)	- Set height (in pixels) of the resulting chart image
#    getImageHeight	- Get height (in pixels) of the chart image
#
#    setAreaColors(@c)	- Set array of colors to be used when drawing areas
#    getAreaColors	- Get array of area colors
#    getAreaColorByIndex- Get the next area color by indexing into color array
#
#    setLineColors(@c)	- Set array of colors to be used when drawing lines
#    getLineColors	- Get array of line colors
#    getLineColorByIndex- Get the next line color by indexing into color array
#
#    setColors(@c)	- Set array of colors to be used by each data set.
#    getColors		- Get array of colors
#
#    setFileDir($dir)	- Set the directory in which the created chart will be placed.
#    getFileDir		- Get directory in which the chart is to be placed.
#
#    setFileName($name)	- Set the name of the chart file
#    getFileName	- Get the name oft he chart file
#
#    setMargin($margin)	- Set the margin (in pixels) allocated around the
#    			  entire chart.
#    getMargin		- Get the margin size
#
#    setImage($im)	- Set the GD image info
#    getImage		- Get the GD image info
#
#    setFont($type,$font)- Set the font for 'type' types of data
#    getFont($type)	- Get the font for 'type' of data
#    getFontWidth($type)- Get the font width for 'type' of data
#    getFontHeight($type)- Get the font height for 'type' of data
#    setBGcolor(@color)	- Set the background color of the chart
#    getBGcolor()	- Get the background color of the chart
#    setGridColor($color)- Set the color of the grid
#    getGridColor()	- Get the color of the grid
#    setBorderColor($color)- Set the color of the chart border
#    getBorderColor()	- Get the color of the gridchart border
#
#    computeFinalColors	- Computes the final colors to be used by each data
#    			  set taking colors from either the user specified
#    			  colors or from the 'area' and 'line' color
#    			  defaults based on the type of each data set
#    computeSubTypes	- Compute the subtype for each data set based on
#    			  'type' and 'subType' specified.
#    setDefaultDataValue($value)
#                       - Set a default value if there is no data seen in
#                         the table.
#    getDefaultDataValue()
#                       - Get the default value to use if there is no data
#                         seen in the table
#    setPointSize($size)- Set the size in pixels of a drawn data point
#    getPointSize()	- Get the size in pixels of drawn data points
#    setLineWidth($width)- Set the width, in pixels, lines are drawn with
#    getLineWidth()	- Get the width of drawn lines
#
#    setBarLeadingSpaceUnits($units)
#    			- Set the leading space (in units) before the first drawn bar graph
#    getBarLeadingSpaceUnits()
#    			- Get the space before the first drawn bar graph
#    setBarTrailingSpaceUnits($units)
#    			- Set the trailing space (in units) after the last drawn bar graph
#    getBarTrailingSpaceUnits()
#    			- Get the space before the last drawn bar graph
#    setBarSpaceUnits($units)
#    			- Set the space (in units) between bar graphs
#    getBarSpaceUnits()
#    			- Get the space between bar graphs
#    setBarWidthUnits($units)
#    			- Set the width (in units) of bars
#    getBarWidthUnits()
#    			- Get the width of bars
#    setShowBarBorder($flag)
#                       - Set whether a black line is drawn around bars
#    getShowBarBorder()
#                       - Get the bar border flag

# =========================
package TWiki::Plugins::ChartPlugin::Chart;

use Exporter;
use GD;
gdBrushed;
gdDashSize;
gdMaxColors;
gdStyled;
gdStyledBrushed;
gdTiled;
gdTransparent;
gdTinyFont;
gdSmallFont;
gdMediumBoldFont;
gdLargeFont;
gdGiantFont;
use POSIX;
@ISA    = ();
@EXPORT = qw(
    setType getType
    setTitle getTitle
    setXlabel getXlabel
    setYlabel getYlabel
    setYlabel1 getYlabel1
    setYlabel2 getYlabel2
    setData getData
    setData1 getData1
    setData2 getData2
    getNumDataSets
    getNumDataSets1
    getNumDataSets2
    setYmin getYmin
    setYmin1 getYmin1
    setYmin2 getYmin2
    setYmax getYmax
    setYmax1 getYmax1
    setYmax2 getYmax2
    setXmin getXmin
    setXmax getXmax
    setSubTypes getSubTypes
    setXaxis getXaxis
    setXaxisAngle getXaxisAngle
    setNumXGrids getNumXGrids
    setYaxis getYaxis
    setYaxis1 getYaxis1
    setYaxis2 getYaxis2
    setNumYGrids getNumYGrids
    setNumYGrids1 getNumYGrids1
    setNumYGrids2 getNumYGrids2
    setDefNumYGrids getDefNumYGrids
    setNumYTics getNumYTics
    setNumYTics1 getNumYTics1
    setNumYTics2 getNumYTics2
    setXgrid getXgrid
    setYgrid getYgrid
    setScale getScale
    setDataLabels getDataLabels
    setLegend getLegend
    setImageWidth getImageWidth
    setImageHeight getImageHeight
    setAreaColors getAreaColors
    setLineColors getLineColors
    setColors getColors
    setGridColor getGridColor
    setBorderColor getBorderColor
    setFileDir getFileDir
    setFileName getFileName
    setMargin getMargin
    setPointSize getPointSize
    setLineWidth getLineWidth
    setBarLeadingSpaceUnits getBarLeadingSpaceUnits
    setBarTrailingSpaceUnits getBarTrailingSpaceUnits
    setBarSpaceUnits getBarSpaceUnits
    setBarWidthUnits getBarWidthUnits
    setShowBarBorder getShowBarBorder
    );

use strict;

# Define values for left and right Y axises.  Ideally we would use
# 'use constant', but this requires a newer version of Perl which all
# people might not have.
my $LEFT  = 1;
my $RIGHT = 2;

sub new {
    my ($class) = @_;
    my $this = {};
    bless $this, $class;
    $this->setMargin(10);
    $this->setColors();
    $this->setGridColor("#FFFFFF");
    $this->setBorderColor("#FFFFFF");
    $this->setLegend();
    $this->setYaxis("off");
    $this->setYaxis2("off");
    $this->setNumYTics1(0);
    $this->setNumYTics2(0);
    $this->setXaxis();
    $this->setXaxisAngle(0);
    $this->setNumXGrids(10);
    $this->setSubTypes();
    $this->setFont("title",  GD::gdGiantFont());    # Set title font
    $this->setFont("xaxis",  GD::gdSmallFont());    # Set X axis font
    $this->setFont("yaxis",  GD::gdSmallFont());    # Set Y axis font
    $this->setFont("xlabel", GD::gdSmallFont());    # Set X label font
    $this->setFont("ylabel", GD::gdSmallFont());    # Set Y label font
    $this->setFont("legend", GD::gdSmallFont());    # Set legend font
    $this->setFont("data",   GD::gdSmallFont());    # Set data values font
    $this->setScale("linear");
    $this->_setData($LEFT, ([]));
    $this->_setData($RIGHT, ([]));
    $this->setNumDataSets($LEFT, 0);
    $this->setNumDataSets($RIGHT, 0);
    $this->setNumYDigits(0);
    $this->setNumXDigits(0);
    return $this;
} ## end sub new

sub setType {my ($this, $type) = @_; $$this{TYPE} = $type}
sub getType {my ($this) = @_; return $$this{TYPE}}

sub setTitle {my ($this, $title) = @_; $$this{TITLE} = $title}
sub getTitle {my ($this) = @_; return $$this{TITLE}}

sub setXlabel {my ($this, $Xlabel) = @_; $$this{X_LABEL} = $Xlabel}
sub getXlabel {my ($this) = @_; return $$this{X_LABEL}}

sub _setYlabel {my ($this, $yAxisLoc, $Ylabel) = @_; $$this{"Y_LABEL$yAxisLoc"} = $Ylabel}
sub setYlabel  {my ($this, $Ylabel) = @_; _setYlabel($this, $LEFT, $Ylabel)}
sub setYlabel1 {my ($this, $Ylabel) = @_; _setYlabel($this, $LEFT, $Ylabel)}
sub setYlabel2 {my ($this, $Ylabel) = @_; _setYlabel($this, $RIGHT, $Ylabel)}

sub _getYlabel {my ($this, $yAxisLoc) = @_; return $$this{"Y_LABEL$yAxisLoc"}}
sub getYlabel  {my ($this) = @_; return _getYlabel($this, $LEFT)}
sub getYlabel1 {my ($this) = @_; return _getYlabel($this, $LEFT)}
sub getYlabel2 {my ($this) = @_; return _getYlabel($this, $RIGHT)}

sub setDefaultDataValue {my ($this, $defaultValue) = @_; $$this{DEFAULT_VALUE} = $defaultValue}
sub getDefaultDataValue {my ($this) = @_; return $$this{DEFAULT_VALUE}}

# Return the minimum data value seen so the caller can decide if special
# action is needed (as would be the case if scale=semilog and yMin <= 0
sub _setData {
    my ($this, $yAxisLoc, @data) = @_;

    # Create clean data values and calculate the min/max values to be charted.
    my $yMinData         = 9e+40;                          # Initialize with some very large value.
    my $yMaxData         = -9e+40;                         # Initialize with some very small value.
    my $value            = 0;
    my $maxRow           = @data - 1;
    my $maxCol           = 0;
    my $defaultDataValue = $this->getDefaultDataValue();
    for my $r (0 .. $maxRow) {
        $maxCol = @{$data[$r]} - 1;
        for my $c (0 .. $maxCol) {
            $value = $data[$r][$c];
            # Check to see if the value is non-empty.
            if ($value !~ /^\s*$/) {
                # If there is a non-empty value, then look for the number part
                if ($value =~ m/([\-]?[0-9.]+[eE]?[+-]?\d*)/) {
                    $value = $1;
                } else {
                    # If a non-number value in a column (like text for a
                    # column header) assume the user defined default data
                    # value
                    $value = $defaultDataValue;
                }
            } else {
                # Value is empty to use the user defined default value
                $value = $defaultDataValue;
            }
            $data[$r][$c] = $value;
            # Since we allow a default value which can be empty, we only
            # want to calculate min/max if the current value is a number.
            if ($value =~ m/([\-]?[0-9.]+[eE]?[+-]?\d*)/) {
                $yMinData = $1 if ($1 < $yMinData);
                $yMaxData = $1 if ($1 > $yMaxData);
            }
        } ## end for my $c (0 .. $maxCol)
    } ## end for my $r (0 .. $maxRow)

    # Save the min/max data set values.
    $this->_setYminOfData($yAxisLoc, $yMinData);
    $this->_setYmaxOfData($yAxisLoc, $yMaxData);

    $$this{"DATA$yAxisLoc"} = \@data;
    $this->setNumDataSets($yAxisLoc, scalar @data);
    $this->setNumDataPoints($yAxisLoc, scalar @{$data[0]});
    return $yMinData;
} ## end sub _setData

sub setData  {my ($this, @data) = @_; return _setData($this, $LEFT, @data)}
sub setData1 {my ($this, @data) = @_; return _setData($this, $LEFT, @data)}
sub setData2 {my ($this, @data) = @_; return _setData($this, $RIGHT, @data)}

sub _getData {
    my ($this, $yAxisLoc) = @_; 
    if (defined($$this{"DATA$yAxisLoc"})) {
	return @{$$this{"DATA$yAxisLoc"}};
    } else {
	return ();
    }
}
sub getData  {my ($this) = @_; return _getData($this, $LEFT)}
sub getData1 {my ($this) = @_; return _getData($this, $LEFT)}
sub getData2 {my ($this) = @_; return _getData($this, $RIGHT)}

sub setNumDataSets  {my ($this, $yAxisLoc, $num) = @_; $$this{"NUM_DATA_SETS$yAxisLoc"}   = $num};

sub _getNumDataSets {my ($this, $yAxisLoc) = @_; return $$this{"NUM_DATA_SETS$yAxisLoc"}}
sub getNumDataSets  {my ($this) = @_; return _getNumDataSets($this, $LEFT)}
sub getNumDataSets1 {my ($this) = @_; return _getNumDataSets($this, $LEFT)}
sub getNumDataSets2 {my ($this) = @_; return _getNumDataSets($this, $RIGHT)}

sub setNumDataPoints  {my ($this, $yAxisLoc, $num) = @_; $$this{"NUM_DATA_POINTS$yAxisLoc"}   = $num};

sub _getNumDataPoints {my ($this, $yAxisLoc) = @_; return $$this{"NUM_DATA_POINTS$yAxisLoc"}}
sub getNumDataPoints  {my ($this) = @_; return _getNumDataPoints($this, $LEFT)}
sub getNumDataPoints1 {my ($this) = @_; return _getNumDataPoints($this, $LEFT)}
sub getNumDataPoints2 {my ($this) = @_; return _getNumDataPoints($this, $RIGHT)}

sub setXmin {my ($this, $xMin) = @_; $$this{X_MIN} = $xMin}
sub getXmin {my ($this) = @_; return $$this{X_MIN}}

sub getXminOfData {my ($this) = @_; return $$this{X_DATA_MIN}}
sub setXminOfData {my ($this, $xmin) = @_; $$this{X_DATA_MIN} = $xmin}

sub setXmax {my ($this, $xMax) = @_; $$this{X_MAX} = $xMax}
sub getXmax {my ($this) = @_; return $$this{X_MAX}}

sub setXmaxOfData {my ($this, $xmax) = @_; $$this{X_DATA_MAX} = $xmax}
sub getXmaxOfData {my ($this) = @_; return $$this{X_DATA_MAX}}

sub _setYmin {my ($this, $yAxisLoc, $yMin) = @_; $$this{"Y_MIN$yAxisLoc"} = $yMin}
sub setYmin  {my ($this, $yMin) = @_; _setYmin($this, $LEFT, $yMin)}
sub setYmin1 {my ($this, $yMin) = @_; _setYmin($this, $LEFT, $yMin)}
sub setYmin2 {my ($this, $yMin) = @_; _setYmin($this, $RIGHT, $yMin)}

sub _getYmin {my ($this, $yAxisLoc) = @_; return $$this{"Y_MIN$yAxisLoc"}}
sub getYmin  {my ($this) = @_; return _getYmin($this, $LEFT)}
sub getYmin1 {my ($this) = @_; return _getYmin($this, $LEFT)}
sub getYmin2 {my ($this) = @_; return _getYmin($this, $RIGHT)}

sub _setYminOfData {my ($this, $yAxisLoc, $ymin) = @_; $$this{"Y_DATA_MIN$yAxisLoc"} = $ymin}
sub setYminOfData  {my ($this, $ymin) = @_; _setYminOfData($this, $LEFT, $ymin)}
sub setYminOfData1 {my ($this, $ymin) = @_; _setYminOfData($this, $LEFT, $ymin)}
sub setYminOfData2 {my ($this, $ymin) = @_; _setYminOfData($this, $RIGHT, $ymin)}

sub _getYminOfData {my ($this, $yAxisLoc) = @_; return $$this{"Y_DATA_MIN$yAxisLoc"}}
sub getYminOfData  {my ($this) = @_; return _getYminOfData($this, $LEFT)}
sub getYminOfData1 {my ($this) = @_; return _getYminOfData($this, $LEFT)}
sub getYminOfData2 {my ($this) = @_; return _getYminOfData($this, $RIGHT)}

sub _setYmax {my ($this, $yAxisLoc, $yMax) = @_; $$this{"Y_MAX$yAxisLoc"} = $yMax}
sub setYmax  {my ($this, $yMax) = @_; _setYmax($this, $LEFT, $yMax)}
sub setYmax1 {my ($this, $yMax) = @_; _setYmax($this, $LEFT, $yMax)}
sub setYmax2 {my ($this, $yMax) = @_; _setYmax($this, $RIGHT, $yMax)}

sub _getYmax {my ($this, $yAxisLoc) = @_; return $$this{"Y_MAX$yAxisLoc"}}
sub getYmax  {my ($this) = @_; return _getYmax($this, $LEFT)}
sub getYmax1 {my ($this) = @_; return _getYmax($this, $LEFT)}
sub getYmax2 {my ($this) = @_; return _getYmax($this, $RIGHT)}

sub _setYmaxOfData {my ($this, $yAxisLoc, $ymax) = @_; $$this{"Y_DATA_MAX$yAxisLoc"} = $ymax}
sub setYmaxOfData  {my ($this, $ymax) = @_; _setYmaxOfData($this, $LEFT, $ymax)}
sub setYmaxOfData1 {my ($this, $ymax) = @_; _setYmaxOfData($this, $LEFT, $ymax)}
sub setYmaxOfData2 {my ($this, $ymax) = @_; _setYmaxOfData($this, $RIGHT, $ymax)}

sub _getYmaxOfData {my ($this, $yAxisLoc) = @_; return $$this{"Y_DATA_MAX$yAxisLoc"}}
sub getYmaxOfData  {my ($this) = @_; return _getYmaxOfData($this, $LEFT)}
sub getYmaxOfData1 {my ($this) = @_; return _getYmaxOfData($this, $LEFT)}
sub getYmaxOfData2 {my ($this) = @_; return _getYmaxOfData($this, $RIGHT)}

sub setSubTypes {my ($this, @subTypes) = @_; $$this{SUB_TYPES} = \@subTypes}
sub getSubTypes {my ($this) = @_; return @{$$this{SUB_TYPES}}}

sub setXaxis {my ($this, @xAxis) = @_; $$this{X_AXIS} = \@xAxis}
sub getXaxis {my ($this) = @_; return @{$$this{X_AXIS}}}

sub setXaxisAngle {my ($this, $angle) = @_; $$this{X_AXIS_ANGLE} = $angle}
sub getXaxisAngle {my ($this) = @_; return $$this{X_AXIS_ANGLE}}

sub _setYaxis {my ($this, $yAxisLoc, $yAxis) = @_; $$this{"Y_AXIS$yAxisLoc"} = $yAxis}
sub setYaxis  {my ($this, $yAxis)   = @_; _setYaxis($this, $LEFT, $yAxis)}
sub setYaxis1 {my ($this, $yAxis)   = @_; _setYaxis($this, $LEFT, $yAxis)}
sub setYaxis2 {my ($this, $yAxis)   = @_; _setYaxis($this, $RIGHT, $yAxis)}

sub _getYaxis {my ($this, $yAxisLoc) = @_; return $$this{"Y_AXIS$yAxisLoc"}}
sub getYaxis  {my ($this) = @_; return _getYaxis($this, $LEFT)}
sub getYaxis1 {my ($this) = @_; return _getYaxis($this, $LEFT)}
sub getYaxis2 {my ($this) = @_; return _getYaxis($this, $RIGHT)}

sub setDefNumYGrids {my ($this, $numYGrids) = @_; $$this{DEFAULT_NUM_Y_GRIDS} = $numYGrids}
sub getDefNumYGrids {my ($this) = @_; return $$this{DEFAULT_NUM_Y_GRIDS}}

sub _setNumYGrids {my ($this, $yAxisLoc, $numYGrids) = @_; $$this{"NUM_Y_GRIDS$yAxisLoc"} = $numYGrids}
sub setNumYGrids  {my ($this, $numYGrids) = @_; _setNumYGrids($this, $LEFT, $numYGrids)}
sub setNumYGrids1 {my ($this, $numYGrids) = @_; _setNumYGrids($this, $LEFT, $numYGrids)}
sub setNumYGrids2 {my ($this, $numYGrids) = @_; _setNumYGrids($this, $RIGHT, $numYGrids)}

sub _getNumYGrids {my ($this, $yAxisLoc) = @_; return $$this{"NUM_Y_GRIDS$yAxisLoc"}}
sub getNumYGrids  {my ($this) = @_; return _getNumYGrids($this, $LEFT)}
sub getNumYGrids1 {my ($this) = @_; return _getNumYGrids($this, $LEFT)}
sub getNumYGrids2 {my ($this) = @_; return _getNumYGrids($this, $RIGHT)}

sub _setNumYTics {my ($this, $yAxisLoc, $numYTics) = @_; $$this{"NUM_Y_TICS$yAxisLoc"} = $numYTics}
sub setNumYTics  {my ($this, $numYTics) = @_; _setNumYTics($this, $LEFT, $numYTics)}
sub setNumYTics1 {my ($this, $numYTics) = @_; _setNumYTics($this, $LEFT, $numYTics)}
sub setNumYTics2 {my ($this, $numYTics) = @_; _setNumYTics($this, $RIGHT, $numYTics)}

sub _getNumYTics {my ($this, $yAxisLoc)  = @_; return $$this{"NUM_Y_TICS$yAxisLoc"}}
sub getNumYTics  {my ($this) = @_; return _getNumYTics($this, $LEFT)}
sub getNumYTics1 {my ($this) = @_; return _getNumYTics($this, $LEFT)}
sub getNumYTics2 {my ($this) = @_; return _getNumYTics($this, $RIGHT)}

sub setNumXGrids {my ($this, $numXGrids) = @_; $$this{NUM_X_GRIDS} = $numXGrids}
sub getNumXGrids {my ($this) = @_; return $$this{NUM_X_GRIDS}}

sub setXgrid {my ($this, $xGrid) = @_; $$this{X_GRID} = $xGrid}
sub getXgrid {my ($this) = @_; return $$this{X_GRID}}

sub setYgrid {my ($this, $yGrid) = @_; $$this{Y_GRID} = $yGrid}
sub getYgrid {my ($this) = @_; return $$this{Y_GRID}}

sub setScale {my ($this, $scale) = @_; $$this{SCALE} = $scale}
sub getScale {my ($this) = @_; return $$this{SCALE}}

sub setDataLabels {my ($this, @dataLabels) = @_; $$this{DATA_LABELS} = \@dataLabels}
sub getDataLabels {my ($this) = @_; return @{$$this{DATA_LABELS}}}

sub setLegend {my ($this, @legend) = @_; $$this{LEGEND} = \@legend}
sub getLegend {my ($this) = @_; return @{$$this{LEGEND}}}

sub setImageWidth {my ($this, $imageWidth) = @_; $$this{IMAGE_WIDTH} = _getInt($imageWidth)}
sub getImageWidth {my ($this) = @_; return $$this{IMAGE_WIDTH}}

sub setImageHeight {my ($this, $imageHeight) = @_; $$this{IMAGE_HEIGHT} = _getInt($imageHeight)}
sub getImageHeight {my ($this) = @_; return $$this{IMAGE_HEIGHT}}

sub setAreaColors {
    my ($this, @AreaColors) = @_;
    $$this{AREA_COLORS}     = \@AreaColors;
    $$this{NEXT_AREA_COLOR} = 0;
}
sub getAreaColors {my ($this) = @_; return @{$$this{AREA_COLORS}}}

sub getAreaColorByIndex {
    my ($this, $index) = @_;
    my @colors    = $this->getAreaColors();
    my $nextColor = $colors[$index % @colors];
    return $nextColor;
}

sub setLineColors {
    my ($this, @LineColors) = @_;
    $$this{LINE_COLORS}     = \@LineColors;
    $$this{NEXT_LINE_COLOR} = 0;
}
sub getLineColors {my ($this) = @_; return @{$$this{LINE_COLORS}}}

sub getLineColorByIndex {
    my ($this, $index) = @_;
    my @colors    = $this->getLineColors();
    my $nextColor = $colors[$index % @colors];
    return $nextColor;
}

sub setColors {my ($this, @Colors) = @_; $$this{COLORS} = \@Colors}
sub getColors {my ($this) = @_; return @{$$this{COLORS}}}

sub setGridColor {my ($this, @gridColor) = @_; $$this{GRID_COLOR} = \@gridColor}
sub getGridColor {my ($this) = @_; return @{$$this{GRID_COLOR}}}

sub setBorderColor {my ($this, $borderColor) = @_; $$this{BORDER_COLOR} = $borderColor}
sub getBorderColor {my ($this) = @_; return $$this{BORDER_COLOR}}

sub setFileDir {my ($this, $dir) = @_; $$this{FILE_DIR} = $dir}
sub getFileDir {my ($this) = @_; return $$this{FILE_DIR}}

sub setFileName {my ($this, $name) = @_; $$this{FILE_NAME} = $name}
sub getFileName {my ($this) = @_; return $$this{FILE_NAME}}

sub setMargin {my ($this, $margin) = @_; $$this{MARGIN} = $margin}
sub getMargin {my ($this) = @_; return $$this{MARGIN}}

sub setImage {my ($this, $image) = @_; $$this{IMAGE} = $image}
sub getImage {my ($this) = @_; return $$this{IMAGE}}

sub setFont {
    my ($this, $type, $font) = @_;
    $$this{"FONT_$type"}        = $font;
    $$this{"FONT_WIDTH_$type"}  = $font->width;
    $$this{"FONT_HEIGHT_$type"} = $font->height;
}
sub getFont       {my ($this, $type) = @_; return $$this{"FONT_$type"}}
sub getFontWidth  {my ($this, $type) = @_; return $$this{"FONT_WIDTH_$type"}}
sub getFontHeight {my ($this, $type) = @_; return $$this{"FONT_HEIGHT_$type"}}

sub setBGcolor {my ($this, @bgcolor) = @_; $$this{BGCOLOR} = \@bgcolor}
sub getBGcolor {my ($this) = @_; return @{$$this{BGCOLOR}}}

sub _setNumYDigits {my ($this, $yAxisLoc, $numDigits) = @_; $$this{"NUM_Y_DIGITS$yAxisLoc"} = $numDigits}
sub setNumYDigits  {my ($this, $numDigits) = @_; _setNumYDigits($this, $LEFT, $numDigits)}
sub setNumYDigits1 {my ($this, $numDigits) = @_; _setNumYDigits($this, $LEFT, $numDigits)}
sub setNumYDigits2 {my ($this, $numDigits) = @_; _setNumYDigits($this, $RIGHT, $numDigits)}

sub _getNumYDigits {my ($this, $yAxisLoc) = @_; return $$this{"NUM_Y_DIGITS$yAxisLoc"}}
sub getNumYDigits  {my ($this) = @_; return _getNumYDigits($this, $LEFT)}
sub getNumYDigits1 {my ($this) = @_; return _getNumYDigits($this, $LEFT)}
sub getNumYDigits2 {my ($this) = @_; return _getNumYDigits($this, $RIGHT)}

sub setNumXDigits {my ($this, $numDigits) = @_; $$this{NUM_X_DIGITS} = $numDigits}
sub getNumXDigits {my ($this) = @_; return $$this{NUM_X_DIGITS}}

sub setPointSize {my ($this, $pixels) = @_; $$this{POINT_SIZE} = $pixels}
sub getPointSize {my ($this) = @_; return $$this{POINT_SIZE}}
sub setLineWidth {my ($this, $pixels) = @_; $$this{LINE_WIDTH} = $pixels}
sub getLineWidth {my ($this) = @_; return $$this{LINE_WIDTH}}

sub setBarLeadingSpaceUnits {my ($this, $units) = @_; $$this{BAR_LEADING_SPACE_UNITS} = $units}
sub getBarLeadingSpaceUnits {my ($this) = @_; return $$this{BAR_LEADING_SPACE_UNITS}}
sub setBarTrailingSpaceUnits {my ($this, $units) = @_; $$this{BAR_TRAILING_SPACE_UNITS} = $units}
sub getBarTrailingSpaceUnits {my ($this) = @_; return $$this{BAR_TRAILING_SPACE_UNITS}}
sub setBarSpaceUnits {my ($this, $units) = @_; $$this{BAR_SPACE_UNITS} = $units}
sub getBarSpaceUnits {my ($this) = @_; return $$this{BAR_SPACE_UNITS}}
sub setBarWidthUnits {my ($this, $units) = @_; $$this{BAR_WIDTH_UNITS} = $units}
sub getBarWidthUnits {my ($this) = @_; return $$this{BAR_WIDTH_UNITS}}
sub setShowBarBorder {my ($this, $flag) = @_; $$this{BAR_BORDER_FLAG} = $flag}
sub getShowBarBorder {my ($this) = @_; return $$this{BAR_BORDER_FLAG}}

# Make sure colors are defined for each data set on each Y axis
sub computeFinalColors {
    my ($this)      = @_;

    my $numDataSets = $this->getNumDataSets1();
    $numDataSets += $this->getNumDataSets2();
    my @subTypes    = $this->getSubTypes();
    my $im          = $this->getImage();

    # Calculate the colors that will be needed.
    # If 'type' = line or area then call getColors().  If no colors
    # defined, then default to getLineColors() for lines and
    # getAreaColors() for areas.
    # If 'type' = combo, then get colors via getColors().  If no colors
    # defined, then call getDataType() to determine if the data sets are
    # specified as lines or areas and get the next available color from
    # getLineColors() and/or getAreaColors().
    my @colors      = $this->getColors();
    my @lineColors  = $this->getLineColors();
    my @areaColors  = $this->getAreaColors();
    my @chartColors = ();                       # Actual colors used for each line/area
    if (@colors) {
        # User defined colors.  Reuse colors if there are more data sets
        # than colors.
        my $numColors = @colors;
        for (1 .. POSIX::ceil($numDataSets / $numColors)) {
            push(@chartColors, @colors);
        }
    } else {
        # No user defined colors so use the defaults.  This can be a bit
        # tricky since depending on what 'type' the data is will determine
        # where we get the next color.
        my $index = 0;
        for my $subType (@subTypes) {
            my $color;
            if ($subType =~ /(area|bar)/) {
                $color = $this->getAreaColorByIndex($index);
            } else {
                $color = $this->getLineColorByIndex($index);
            }
            push(@chartColors, $color);
            $index++;
        }
    } ## end else [ if (@colors) ]

    # Walk through each color and allocate it in the GD.
    my @allocatedColors;
    for my $color (@chartColors) {
        push(@allocatedColors, $im->colorAllocate(_convert_color($color)));
    }
    return @allocatedColors;
} ## end sub computeFinalColors

# Calculate the 'types' for each of the data sets on each Y axis.  If
# getType() is 'area', then artificially fill in subTypes for each data set
# to match that type.  If type is 'combo', then subTypes should have been
# specified by the user.  If not, then assume that all but the last data
# set are 'area' and the last is 'line'.
sub computeSubTypes {
    my ($this)      = @_;
    my $numDataSets = $this->getNumDataSets1();
    $numDataSets += $this->getNumDataSets2();
    my $type        = $this->getType();
    my @subTypes;
    # Deal with types that don't allow subtypes.  In this case force all
    # subtypes to be the same as the type.
    if (($type eq "area") || ($type eq "bar")) {
        for (1 .. $numDataSets) {
            push(@subTypes, $type);
        }
        $this->setSubTypes(@subTypes);
    } else {
        # If a user specified subtype, then reuse user's info over and
        # over again if there are more data sets than subtypes specified.
        # If no subtype, then assume all but the last data set are 'area'
        # and the last 'line'.
        my @userSubTypes = $this->getSubTypes();
        if (@userSubTypes) {
            my $numUserSubTypes = @userSubTypes;
            for (1 .. POSIX::ceil($numDataSets / $numUserSubTypes)) {
                push(@subTypes, @userSubTypes);
            }
        } else {
            # If no 'subtype' specified and type is 'combo' or 'scatter',
            # assume all 'area' except the last which is 'line', otherwise
            # assume a subtype of 'line' for type 'line'.
            if ($type eq "line") {
                for my $y (1 .. $numDataSets) {
                    push(@subTypes, "line");
                }
            } elsif ($type eq "scatter") {
                for my $y (1 .. $numDataSets) {
                    push(@subTypes, "point");
                }
            } else {
                for my $y (1 .. $numDataSets - 1) {
                    push(@subTypes, "area");
                }
                push(@subTypes, "line");
            }
        } ## end else [ if (@userSubTypes) ]
    } ## end else [ if (($type eq "area") ...)]
        # Set the subTypes since they will have changed and other calculations
        # need this information.
    $this->setSubTypes(@subTypes);
    return @subTypes;
} ## end sub computeSubTypes

# This places and error inside of an image.
sub makeError {
    my ($this, $msg)      = @_;
    my $imageWidth  = $this->getImageWidth();
    my $imageHeight = $this->getImageHeight();
    my $im = new GD::Image($imageWidth, $imageHeight);
    $this->setImage($im);

    my $initialBGcolorText = "#FFFFFF"; # White
    my $initialBGcolor     = $im->colorAllocate(_convert_color($initialBGcolorText));
    my $red                = $im->colorAllocate(_convert_color("#FF0000"));
    my $font		   = $this->getFont("title");
    my $lineSpacing	   = 2;

    # Start with a totally white background
    $im->filledRectangle(0, 0, $imageWidth - 1, $imageHeight - 1, $initialBGcolor);
    $im->rectangle(0, 0, $imageWidth - 1, $imageHeight - 1, $red);
    my $maxChars = int($imageWidth / $this->getFontWidth("title")) - 1;
    $Text::Wrap::columns = $maxChars;
    my $numLines = my @lines = split(/\n/, Text::Wrap::wrap("", "", $msg));

    my $maxLines = $imageHeight / ($this->getFontHeight("title") + $lineSpacing);
    my $y = int(($imageHeight / 2) - ($numLines / 2 * ($this->getFontHeight("title") + $lineSpacing)));
    foreach my $line (@lines) {
	$im->string($font, 10, $y, $line, $red);
	$y += $this->getFontHeight("title") + $lineSpacing;
    }
    #$xLL += $this->getFontHeight("ylabel") + 10;
    #$xUR -= $this->getFontWidth("yaxis") * $maxLength;
    my $dir      = $this->getFileDir();
    my $filename = $this->getFileName();
    umask(002);
    open(IMAGE, ">$dir/$filename") or return "Can't create file '$dir/$filename: $!";
    binmode IMAGE;
    if ($GD::VERSION > 1.19) {
        print IMAGE $im->png;
    } else {
        print IMAGE $im->gif;
    }
    close IMAGE;
    return undef;
}

# The main guts of this file.  This routine takes all the information
# specified in the Chart object and constructs a chart based on all of the
# information contained in the object.
sub makeChart {
    my ($this)      = @_;
    my $imageWidth  = $this->getImageWidth();
    my $imageHeight = $this->getImageHeight();

    # Create empty image to get filled in later.
    my $im = new GD::Image($imageWidth, $imageHeight);
    $this->setImage($im);

    # Create the background color.  If not defined, default to white, else
    # use the user specified value.

    # Define some commonly used colors
    my ($outsideBGColor, $insideBGColor, $boxBGColor) = $this->getBGcolor();
    my $initialBGcolorText = "#FFFFFF"; # White
    my $initialBGcolor     = $im->colorAllocate(_convert_color($initialBGcolorText));
    my $black              = $im->colorAllocate(0, 0, 0);
    my $borderColorText    = $this->getBorderColor();
    my $borderColor;
    if ($borderColorText eq "transparent") {
	$borderColor = undef;
    } else {
	$borderColor = $im->colorAllocate(_convert_color($borderColorText));
    }

    # Start with a totally white background
    $im->filledRectangle(0, 0, $imageWidth - 1, $imageHeight - 1, $initialBGcolor);

    # Calculate the 'types' for each of the data sets.
    my @subTypes = $this->computeSubTypes();

    # Count how many of the data sets are 'bar'
    my $numBarDataSets = grep(/bar/, @subTypes);

    my $type = $this->getType;
    # If a scatter chart, then set the following flag
    my $scatterChart;
    $scatterChart = 1 if ($type eq "scatter");

    # Get the number of pixels width/height of drawn data points.
    my $pointSize     = $this->getPointSize;
    my $pointSizeHalf = $pointSize / 2;

    # Get the number of pixels width lines are to be drawn with
    my $lineWidth = $this->getLineWidth;

    # Get the Y axis scale to use
    my $scale = $this->getScale();

    my @yAxisLocs = ($LEFT);
    # Get the data and info about the data.
    my @data1 = $this->getData1();
    my @data2 = $this->getData2();
    my $numDataSets1   = $this->getNumDataSets1();
    my $numDataSets2   = $this->getNumDataSets2();
    my $isData2Data = $numDataSets2;
    push (@yAxisLocs, $RIGHT) if ($isData2Data);
    my @numDataPoints;
    $numDataPoints[$LEFT] = $this->getNumDataPoints1();
    $numDataPoints[$RIGHT] = $this->getNumDataPoints2();
    return "Error: Number of data points needs to be > 1" if ($numDataPoints[$LEFT] <= 1);
    return "Error: Number of data points for data2 needs to be > 1" if ($isData2Data && $numDataPoints[$RIGHT] <= 1);

    # Calculate the colors that will be needed for the various lines and
    # areas figuring out which color is needed when and also dealing with
    # color reuse (more data sets than colors specified).
    my @allocatedColors = $this->computeFinalColors();

    # Allocate the grid color(s) and define a line style for the grid for
    # grids defined as 'dot'.  For grids defined as 'on', then just use the
    # first color defined
    my $firstColor = undef;
    my %gridColors;
    # Get unique list of colors.
    foreach my $color ($this->getGridColor()) {
        $firstColor = $color if (! defined $firstColor);
        $gridColors{$color} = 1;
    }
    # Allocate color for each unique grid color
    for my $color (keys %gridColors) {
        next if ($color eq "transparent");
        $gridColors{$color} = $im->colorAllocate(_convert_color($color));
    }
    my @gridColors;
    # Now define array of colors for grid
    foreach my $color ($this->getGridColor()) {
        if ($color eq "transparent") {
            push(@gridColors, gdTransparent);
        } else {
            push(@gridColors, $gridColors{$color});
        }
    }
    $im->setStyle(@gridColors);
    # Get the first color for solid grid lines
    my $gridColor = $gridColors{$firstColor};

    # Calculate the initial pixel locations of lower left side (xLL/yLL)
    # and upper right side (xUR/yUR) of the chart with respect to the
    # graphic image.  Depending on X/Y labels, titles, legends, etc. this
    # will change in the code below.
    my $margin = $this->getMargin();
    my $xLL    = $margin;
    my $yLL    = $imageHeight - 1 - $margin;
    my $xUR    = $imageWidth - 1 - $margin;
    my $yUR    = $margin;

    # Calculate how much space will be needed for the Y label1 (if specified).
    my $yLabel1 = $this->getYlabel1();
    if (defined $yLabel1) {
        # Allocate space for label1 as well as some space between the label
        # and the Y Axis labels or the left side of the chart.
        $xLL += $this->getFontHeight("ylabel") + 10;
    }
    # Calculate how much space will be needed for the Y label2 (if specified).
    my $yLabel2 = $this->getYlabel2();
    if (defined $yLabel2) {
        # Allocate space for label2 as well as some space between the label
        # and the Y Axis labels or the side of the chart.
        $xUR -= $this->getFontHeight("ylabel");
    }

    my @yAxisMin;
    my @yAxisMax;
    my @numYGrids;
    # Foreach data set, see if we need to compute ymin and ymax.
    foreach my $yAxisLoc (@yAxisLocs) {
	# Get the users specified ymin, ymax, and numygrids
	$yAxisMin[$yAxisLoc]  = $this->_getYmin($yAxisLoc);
	$yAxisMax[$yAxisLoc]  = $this->_getYmax($yAxisLoc);
	$numYGrids[$yAxisLoc] = $this->_getNumYGrids($yAxisLoc);
	# If ymin not set, either as a CHART default or a per CHART value,
	# compute a good default.
	if (! defined($yAxisMin[$yAxisLoc])) {
	    my $yMinData = $this->_getYminOfData($yAxisLoc);
	    if ($scale eq "semilog") {
		my $yMinLog10 = log10($yMinData);
		$yAxisMin[$yAxisLoc] = pow(10.0, floor($yMinLog10));
	    } else {
		$yAxisMin[$yAxisLoc] = computeFloor($yMinData);
	    }
	}
	# If ymax not set, either as a CHART default or a per CHART value,
	# compute a good default.
	if (! defined($yAxisMax[$yAxisLoc])) {
	    my $yMaxData = $this->_getYmaxOfData($yAxisLoc);
	    if ($scale eq "semilog") {
		my $yMaxLog10 = log10($yMaxData);
		$yAxisMax[$yAxisLoc] = pow(10.0, ceil($yMaxLog10));
	    } else {
		$yAxisMax[$yAxisLoc] = computeCeil($yMaxData);
	    }
	}
	# If indications are that there is no chart height and the user hasn't
	# set ymin or ymax, then adjust things to make the chart height
	# non-zero.
	if ($yAxisMin[$yAxisLoc] == $yAxisMax[$yAxisLoc]) {
	    # First see if we can tweak ymax
	    if (! defined($this->_getYmax($yAxisLoc))) {
		$yAxisMax[$yAxisLoc] = computeCeil($yAxisMax[$yAxisLoc] + 0.1);
	    } elsif (! defined($this->_getYmin($yAxisLoc))) {
		$yAxisMin[$yAxisLoc] = computeFloor($yAxisMin[$yAxisLoc] - 0.1);
	    }
	}
	$this->_setYminOfData($yAxisLoc, $yAxisMin[$yAxisLoc]);
	$this->_setYmaxOfData($yAxisLoc, $yAxisMax[$yAxisLoc]);
	# Check for valid user specified min/max
	if (defined($this->_getYmin($yAxisLoc)) && defined($this->_getYmax($yAxisLoc)) && $yAxisMin[$yAxisLoc] == $yAxisMax[$yAxisLoc]) {
	    return "No Chart height with ymin$yAxisLoc($yAxisMin[$yAxisLoc]) == ymax($yAxisMax[$yAxisLoc])";
	}
    }
    # If numygrids not defined, then no user specified value so attempt to
    # compute a reasonable value from data1 data.
    if (! defined($numYGrids[$LEFT]) || $numYGrids[$LEFT] eq "") {
        if ($scale eq "semilog") {
            $numYGrids[$LEFT] = log10($yAxisMax[$LEFT]) - log10($yAxisMin[$LEFT]) - 1;
        } else {
	    if ($this->getDefNumYGrids() eq "") {
		# So no user defined numxgrids and no system default, so
		# calculate one using at most 9 grid lines.
		$numYGrids[$LEFT] = $this->computeLinearNumGrids($yAxisMin[$LEFT], $yAxisMax[$LEFT], 9);
	    } else {
		$numYGrids[$LEFT] = $this->getDefNumYGrids();
	    }
        }
        $this->setNumYGrids1($numYGrids[$LEFT]);
    }
    # If there is data2, then we force the numYGrids for data set=RIGHT to be
    # the same as numYGrids on data1.
    if ($isData2Data) {
        $this->setNumYGrids2($numYGrids[$RIGHT] = $numYGrids[$LEFT]);
    }

    foreach my $yAxisLoc (@yAxisLocs) {
	if ($scale eq "semilog") {
	    $this->_setNumYDigits($yAxisLoc, 0);
	    my $tics = $this->_getNumYTics($yAxisLoc);
	    $this->_setNumYTics($yAxisLoc, 8) if (! defined($tics) || $tics > 8);
	} else {
	    # Calculate how many digits we need to display on the yaxis
	    my $maxYDigits = $this->computeNumDigits($yAxisMin[$yAxisLoc], $yAxisMax[$yAxisLoc], $numYGrids[$yAxisLoc]);
	    $this->_setNumYDigits($yAxisLoc, $maxYDigits);
	}
    }

    my @scaledYAxisMin;
    my @scaledYAxisMax;
    my @chartHeight;
    foreach my $yAxisLoc (@yAxisLocs) {
	$scaledYAxisMin[$yAxisLoc] = $this->_scale($yAxisMin[$yAxisLoc]);
	$scaledYAxisMax[$yAxisLoc] = $this->_scale($yAxisMax[$yAxisLoc]);
	$chartHeight[$yAxisLoc]    = $scaledYAxisMax[$yAxisLoc] - $scaledYAxisMin[$yAxisLoc];
	# Check to see if either the user specified ymin/ymax values, or the
	# data itself was such that ymin > ymax.
	return "Y max$yAxisLoc ($yAxisMax[$yAxisLoc]) < Y Min$yAxisLoc ($yAxisMin[$yAxisLoc])" if ($chartHeight[$yAxisLoc] < 0);
    }

    # To support scatter graphs (where the X data is probably not sorted)
    # we get the X axis labels and sort them (numerically) producing an
    # array of indexes which will then be used when plotting the actual
    # data.  For example, if @xAxis is (1 3 5 2 4), then the indexes of the
    # values to plot would be 0 3 1 4 2
    my @xAxis        = $this->getXaxis();
    my $xGrid        = $this->getXgrid();
    my $xAxisNumeric = 1;                   # Flag whether the X axis values are numeric or not.
    my %xAxisIndex;
    # Check to see if the X axis values are numeric or not.  If not, then
    # we fake X axis data to be the indexes in the array.
    if (@xAxis) {
        foreach my $index (0 .. $#xAxis) {
            if ($xAxis[$index] =~ m/^([\-]?[0-9.]+[eE]?[+-]?\d*)$/) {
                $xAxisIndex{$index} = $1;
            } else {
                $xAxisIndex{$index} = $xAxis[$index];
                $xAxisNumeric = 0;
            }
        }
    } else {
        if ($scatterChart) {    # No xaxis specified and scatter graph
            return "xaxis needs to be specified for a scatter graph";
        } else {
            foreach my $index (0 .. $numDataPoints[$LEFT]) {
                $xAxisIndex{$index} = $index;
            }
        }
    }
    return "non-numeric X axis values not allowed for a scatter graph" if ($scatterChart && ! $xAxisNumeric);

    # Get the number of user specified X axis lines/labels to draw.
    my $numXGrids = $this->getNumXGrids();

    # Create an array that will represent the drawn X axis grid lines.  If
    # a chart type is 'scatter', then assume the X axis data is real
    # numbers (not simple text).
    my @xAxisLabels;
    my $xAxisMin;
    my $xAxisMax;
    if ($scatterChart) {
        $xAxisMin = 9e+40;     # Initialize with some very large value.
        $xAxisMax = -9e+40;    # Initialize with some very small value.
        foreach my $yAxisLoc (0 .. $#xAxis) {
            my $value = $xAxisIndex{$yAxisLoc};
            if ($value =~ m/([\-]?[0-9.]+[eE]?[+-]?\d*)/) {
                $xAxisMin = $1 if ($1 < $xAxisMin);
                $xAxisMax = $1 if ($1 > $xAxisMax);
            }
        }
        my ($newXmin, $newXmax, $newNumXGrids, $newNumXDecimalDigits);
        $newXmin      = $this->getXmin();
        $newXmax      = $this->getXmax();
        $newXmin      = computeFloor($xAxisMin) if (! defined($newXmin));
        $newXmax      = computeCeil($xAxisMax) if (! defined($newXmax));
        $newNumXGrids = $this->computeLinearNumGrids($newXmin, $newXmax, $numDataPoints[$LEFT]);
        $this->setXminOfData($xAxisMin = $newXmin);
        $this->setXmaxOfData($xAxisMax = $newXmax);
        $this->setNumXGrids($numXGrids = $newNumXGrids);
        $this->setNumXDigits($newNumXDecimalDigits);
    } else {
        # Set the minimum xIndex which is 0
        $this->setXminOfData($xAxisMin = 0);
        # Since not a scatter graph, then assume that the X axis labels are
        # simple text and are drawn in the exact order that they occur in
        # the table.  As an exception, if no X axis is specified, then
        # there are no X labels to draw so just compute the number of grid
        # lines.
        @xAxisLabels = @xAxis;
        if (@xAxis) {
            $this->setXmaxOfData($xAxisMax = $#xAxis);
            # Set the number of X grids be the smaller of: number of data
            # points to draw or the number of X grids the user specifies
            $this->setNumXGrids($numXGrids = ($numDataPoints[$LEFT] - 2)) if (($numDataPoints[$LEFT] - 2) < $numXGrids);
        } else {
            $this->setXmaxOfData($xAxisMax = $numDataPoints[$LEFT]);
        }
    } ## end else [ if ($scatterChart) ]

    # Compute the number of digits to use when displaying the Y axis
    # labels.
    if ($scatterChart) {
        # Check for error situation where there is no chart width as
        # xmin == xmax
        return "Chart width = 0 (xmin($xAxisMin) == xmax($xAxisMax))" if ($xAxisMin == $xAxisMax);
        my $maxXDigits = $this->computeNumDigits($xAxisMin, $xAxisMax, $numXGrids);
        $this->setNumXDigits($maxXDigits);
    }

    # Calculate how much space will be needed for the Y axis labels.
    # Although tedious, we need to walk through each number that will be
    # drawn and calculate it's width since the widths can vary from number
    # to number.
    my %yGridLabels;
    my $yAxis2LabelWidth = 0;
    my $isYaxis2Text   = 0;
    if (defined($yLabel2) || $this->getYaxis2() eq "on") {
	$isYaxis2Text = 1;
    }
    foreach my $yAxisLoc (@yAxisLocs) {
	if ($this->_getYaxis($yAxisLoc) eq "on") {
	    # Calculate the string width of both the min/max Y axis labels so
	    # we know how much room to allocate for them.  Save the values for
	    # later use.
	    my $labelInc  = ($yAxisMax[$yAxisLoc] - $yAxisMin[$yAxisLoc]) / ($numYGrids[$yAxisLoc] + 1);
	    my $yaxis     = $yAxisMin[$yAxisLoc];
	    my $maxLength = 0;
	    my $len;
	    my $yAxisDecimalDigits = $this->_getNumYDigits($yAxisLoc);
	    for my $yAxisIndex (0 .. ($numYGrids[$yAxisLoc] + 1)) {
		my $text = _printNumber($yaxis, $yAxisDecimalDigits);
		$yGridLabels{$yAxisLoc}[$yAxisIndex] = $text;
		$len = length($text);
		$maxLength = $len if ($len > $maxLength);
		if ($scale eq "semilog") {
		    $yaxis *= 10.0;
		} else {
		    $yaxis += $labelInc;
		}
	    }
	    if ($yAxisLoc == $LEFT) {
		$xLL += $this->getFontWidth("yaxis") * $maxLength;
	    }
	    if ($yAxisLoc == $RIGHT && $isYaxis2Text) {
		$xUR -= $this->getFontWidth("yaxis") * $maxLength;
		$yAxis2LabelWidth = $maxLength;
	    }
	} ## end if ($this->getYaxis() ...)
    }
    $xUR -= 10 if ($isYaxis2Text);

    # Calculate how much space will be needed for the X label (if specified).
    my $xLabel = $this->getXlabel();
    if (defined $xLabel) {
        $yLL -= $this->getFontHeight("xlabel");
    }

    # Calculate how much space will be needed for the X axis labels (if
    # specified).  Check the X axis angle to see what the orientation
    # of the labels needs to be.
    # A special case is scatter chart.
    my $xAxisAngle  = $this->getXaxisAngle();
    my $xAxisMaxLen = 0;
    my @xLabels;
    if (@xAxis) {
        if ($scatterChart) {
            my $xaxis              = $xAxisMin;
            my $labelInc           = ($xAxisMax - $xAxisMin) / ($numXGrids + 1);
            my $xAxisDecimalDigits = $this->getNumXDigits;
            for my $xAxisIndex (0 .. ($numXGrids + 1)) {
                my $text = _printNumber($xaxis, $xAxisDecimalDigits);
                $xLabels[$xAxisIndex] = $text;
                $xaxis += $labelInc;
            }
        }
        if ($xAxisAngle == 0) {
            # Horizontal labels so just add the height of the font
            $yLL -= $this->getFontHeight("xaxis");
        } else {
            # Note: if the angle is != 0, then assume 90 degrees (for now)
            # so the labels are vertical so use the max length.
            my $maxLen = 0;
            my $len    = 0;
            if ($scatterChart) {
                my $xaxis              = $xAxisMin;
                my $labelInc           = ($xAxisMax - $xAxisMin) / ($numXGrids + 1);
                my $xAxisDecimalDigits = $this->getNumXDigits;
                for my $xAxisIndex (0 .. ($numXGrids + 1)) {
                    my $text = _printNumber($xaxis, $xAxisDecimalDigits);
                    $len = length($text);
                    $maxLen = $len if ($len > $maxLen);
                    $xaxis += $labelInc;
                }
            } else {
                for my $x (values %xAxisIndex) {
                    $len = length($x);
                    $maxLen = $len if ($len > $maxLen);
                }
            }
            $yLL -= $this->getFontWidth("xaxis") * $maxLen;
            $xAxisMaxLen = $maxLen;
        } ## end else [ if ($xAxisAngle == 0) ]
    } ## end if (@xAxis)

    # Calculate how much space needed for the legend.
    my @legends = $this->getLegend();
    if (@legends) {
        my $legendWidth;
        my $maxLegendWidth = 0;
        for my $legend (@legends) {
            $legendWidth = length($legend);
            $maxLegendWidth = $legendWidth if ($legendWidth > $maxLegendWidth);
        }
        $xUR -= $this->getFontWidth("legend") * $maxLegendWidth;
    }
    # Calculate how much space will be needed for the chart title
    if (defined $this->getTitle()) {
        $yUR += $this->getFontHeight("title");
    }

    # OK, now that we've calculated the bounding box for the chart, we
    # calculate other various values.

    # Calculate the width/height of the chart portion.
    my $chartWidthInPixels  = $xUR - $xLL + 1;
    my $chartHeightInPixels = $yLL - $yUR + 1;

    # If any of the subTypes are 'bar', then compute how wide the bars need
    # to be given how many bars are to be drawn and how much space is
    # available for them to be drawn in.
    my $xShowBarBorder	  = $this->getShowBarBorder();
    my $barLeadingSpacePixels = 0;
    my $barSpacePixels = 0;
    my $barWidthPixels = 0;
    my $barTrailingSpacePixels = 0;
    if ($numBarDataSets) {
        # Check to see if any of the types is 'area' as it doesn't make
        # sense to mix 'area' and 'bar' on the same chart.
        return "Error: Can't mix 'area' and 'bar' subtypes on the same chart" if (grep(/area/, @subTypes));
	my $numDataPoints  = $numDataPoints[$LEFT];

	# Calculate N such that 2N = width of a single bar and the space
	# between bars is N and the space before the first bar and after
	# the last bar is 2N.
	my $dataPointPixelsWide = $chartWidthInPixels / $numDataPoints;
	my $barLeadingSpaceUnits = $this->getBarLeadingSpaceUnits();
	my $barSpaceUnits = $this->getBarSpaceUnits();
	my $barWidthsUnits = $this->getBarWidthUnits();
	my $barTrailingSpaceUnits = $this->getBarTrailingSpaceUnits();
	my $numBarUnits = $barLeadingSpaceUnits + ($numBarDataSets * $barWidthsUnits) + (($numBarDataSets - 1) * $barSpaceUnits) + $barTrailingSpaceUnits;
	my $barPixelsPerUnit = $dataPointPixelsWide / $numBarUnits;
	$barLeadingSpacePixels = $barLeadingSpaceUnits * $barPixelsPerUnit;
	$barSpacePixels = $barSpaceUnits * $barPixelsPerUnit;
	$barWidthPixels = $barWidthsUnits * $barPixelsPerUnit;
	$barTrailingSpacePixels = $barTrailingSpaceUnits * $barPixelsPerUnit;
    }

    # Calculate the width of the chart (in terms of graphed data) and the
    # number of pixels per X value (used for scatter graphs).
    my $chartWidth = $xAxisMax - $xAxisMin;
    $chartWidth = 1 if (! $scatterChart);
    my $xPixelsPerValue = $chartWidthInPixels / $chartWidth;
    # Calculate the number of pixels per X element (non-scatter)
    my $xDrawInc;
    if ($scatterChart) {
        $xDrawInc = $chartWidthInPixels / ($numXGrids + 1);
    } else {
        if ($numBarDataSets) {
            # If bars are drawn, then we need to artificially make more room
            # for the bars by assuming 1 extra (undrawn) data set.
            $xDrawInc = $chartWidthInPixels / $numDataPoints[$LEFT];
        } else {
            $xDrawInc = $chartWidthInPixels / ($numDataPoints[$LEFT] - 1);
        }
    }
    my @yPixelsPerValue;
    $yPixelsPerValue[$LEFT] = $chartHeightInPixels / $chartHeight[$LEFT];
    if ($numDataSets2) {
	$yPixelsPerValue[$RIGHT] = $chartHeightInPixels / $chartHeight[$RIGHT];
    }

    # Draw box around entire chart so area filling won't get outside of the
    # box
    $im->rectangle($xLL, $yLL, $xUR, $yUR, $borderColor) if (defined($borderColor));
    # If a user specified bgcolor (and it isn't the same as the default
    # background color), then set this color to surround the chart.
    if (defined $outsideBGColor && $outsideBGColor !~ /$initialBGcolorText/i) {
        my $bgcolorOutside = $im->colorAllocate(_convert_color($outsideBGColor));
        $im->fill(1, 1, $bgcolorOutside);
    }
    # If a user also specified bgcolor with a 2nd value (and it isn't the
    # same as the default background color), then set this color to fill
    # the inside of the chart.
    if (defined $insideBGColor && $insideBGColor !~ /$initialBGcolorText/i) {
        my $bgcolorInside = $im->colorAllocate(_convert_color($insideBGColor));
        $im->fill($xLL + 1, $yUR + 1, $bgcolorInside);
    }

    ########################################################################
    # OK, we are about to actually start drawing things.  The order we draw
    # things is:
    #     1) draw areas
    #     2) draw grid lines and X/Y axis labels
    #     3) draw bars
    #     4) draw lines, points, plines
    #     5) draw rectangle around chart
    #     6) draw data point labels
    #     7) draw chart title, X and Y label
    #     8) draw legends

    # 1111111111111111111111111111111111111111111111111111111111111111111111
    # Start drawing each data set.  The only exception is if there is no
    # data, then don't draw anything.
    # Note: the data sets are drawn back to front so that areas are drawn
    # correctly.
    # Note: all areas are drawn first so they appear behind the lines and
    # won't hide other data sets.
    my $lineNum = $this->getNumDataSets1() + $this->getNumDataSets2() - 1;
    foreach my $yAxisLoc (reverse(@yAxisLocs)) {
	my $numDataSets = $this->_getNumDataSets($yAxisLoc);
	my @data = $this->_getData($yAxisLoc);
	foreach (my $dataSet = $numDataSets - 1; $dataSet >= 0; $dataSet--) {
	    my $row = $data[$dataSet];
	    my @row = @{$data[$dataSet]};

	    my $color = $allocatedColors[$lineNum];
	    if ($subTypes[$lineNum] eq "area") {
		# Data set is an area.  Create a polygon representing the area
		# and then fill in that polygon.  Note: As a special case, if
		# the area to be drawn is lower on the chart than a previously
		# drawn area then just draw a line.
		my $poly = new GD::Polygon;
		my $xIndex;
		my $x;
		# Create the top of the polygon
		for $xIndex (0 .. ($numDataPoints[$yAxisLoc] - 1)) {
		    my $topYValue = $this->_scale($row[$xIndex]);
		    # If there is no current value, then there is no default
		    # value so assume a value the same as the minimum of the
		    # chart.
		    if ($topYValue eq "") {
			$topYValue = $scaledYAxisMin[$yAxisLoc];
		    }
		    my $y = $yLL - ($topYValue - $scaledYAxisMin[$yAxisLoc]) * $yPixelsPerValue[$yAxisLoc];
		    if ($scatterChart) {
			$x = $xLL + (($xAxisIndex{$xIndex} - $xAxisMin) * $xPixelsPerValue);
		    } else {
			$x = $xLL + ($xDrawInc * $xIndex);
		    }
		    $poly->addPt($x, $y);
		} ## end for $xIndex (0 .. ($numDataPoints[$LEFT]...))

		# Complete the polygon by adding a point at the bottom right of
		# the graph and then one at the bottom left of the graph.
		$poly->addPt($x,   $yLL);
		$poly->addPt($xLL, $yLL);
		$im->filledPolygon($poly, $color);
	    } ## end if ($subTypes[$dataSet...])
	    $lineNum--
	} ## end foreach (my $dataSet = $numDataSets...)
    }

    # 2222222222222222222222222222222222222222222222222222222222222222222222
    # Draw the Y axis labels and optional grid lines so the grid lines
    # fall behind the areas/lines.
    foreach my $yAxisLoc (@yAxisLocs) {
	my $yAxis = $this->_getYaxis($yAxisLoc);
	my $yGrid = $this->getYgrid();
	my $numYGrids = $this->_getNumYGrids($yAxisLoc);
	my $xBase = $xLL;
	$xBase = $xUR if ($yAxisLoc == $RIGHT);
	if (($yAxis eq "on") || ($yGrid ne "off")) {
	    my $yDrawInc = $chartHeightInPixels / ($numYGrids + 1);
	    for my $yAxisIndex (0 .. ($numYGrids + 1)) {
		my $Y = $yLL - ($yDrawInc * $yAxisIndex);
		if ($yAxis eq "on") {
		    my $text = $yGridLabels{$yAxisLoc}[$yAxisIndex];
		    my $X = $xBase - (length($text) + 1) * $this->getFontWidth("yaxis");
		    if ($yAxisLoc == $RIGHT) {
			$X = $xBase + 1 * $this->getFontWidth("yaxis");
		    }
		    $im->string(
			$this->getFont("yaxis"),
			$X,
			$Y - ($this->getFontHeight("yaxis") / 2),
			$text,
			$black
		    );
		}
		# Draw the ygrid lines for the left yaxis only. The right
		# yaxis will reuse these grid lines
		if ($yAxisLoc == $LEFT) {
		    if (($yAxisIndex != 0) && ($yAxisIndex <= $numYGrids)) {
			if ($yGrid eq "on") {
			    $im->line($xLL - 2, $Y, $xUR + 2, $Y, $gridColor);
			} elsif ($yGrid eq "dot") {
			    $im->line($xLL - 2, $Y, $xUR + 2, $Y, gdStyled);
			}
		    }
		}
		# Draw tic marks between Y grid lines (if requested -- might be
		# the case if the style of graph is 'semilog')
		my $numYTics = $this->_getNumYTics($yAxisLoc) + 1;
		# Draw tics skipping the tics above last value
		if ($yAxisIndex < ($numYGrids + 1)) {
		    for (my $tic = 1; $tic <= $numYTics; $tic++) {
			my $ticY;
			if ($scale eq "semilog") {
			    $ticY = $Y - $this->_scale($tic) * $yDrawInc;
			} else {
			    $ticY = $Y - $tic * $yDrawInc / $numYTics;
			}
			$im->line($xBase - 2, $ticY, $xBase + 2, $ticY, $gridColor);
		    }
		}
	    } ## end for my $yAxisIndex (0 .....)
	} ## end if (($yAxis eq "on") ||...)
    }

    # Draw the X axis labels and grid lines (if asked for).  To do this we
    # calculate the interval between X axis values to draw based on the
    # user specified number of X axis values to draw.
    my @xGridIndexes;
    $xGridIndexes[0] = 0;
    my $barNum = 0;
    if (@xAxis) {
        my $xIndexInc;
        my $xIndexMax;
        if ($scatterChart) {
            $xIndexInc = 1;
            # If bars are drawn, then there is 1 fewer X axis label to draw
            # than normal.
            if ($numBarDataSets) {
                $xIndexMax = $numXGrids;
            } else {
                $xIndexMax = $numXGrids + 1;
            }
        } else {
            if ($numXGrids == 0) {
                $xIndexInc = 1;
            } else {
                $xIndexInc = int($numDataPoints[$LEFT] / ($numXGrids + 1));
            }
            $xIndexMax = $numDataPoints[$LEFT] - 1;
        }
        my $xAxisFontWidth     = $this->getFontWidth("xaxis");
        my $xaxis              = $xAxisMin;
        my $xAxisDecimalDigits = $this->getNumXDigits;
        for (my $xAxisIndex = 0; $xAxisIndex <= $xIndexMax; $xAxisIndex += $xIndexInc) {
	    # Keep track of the xAxis indexes that are drawn so if
	    # datalabel="auto*" then we know where to drawn data labels.
	    $xGridIndexes[$xAxisIndex] = $xAxisIndex;
            # Calculate what the X axis label will be.  If scatter then
            # compute the value, if not scatter then use the user specified
            # value.
            my $label;
            if ($scatterChart) {
                $label = $xLabels[$xAxisIndex];
            } else {
                $label = $xAxis[$xAxisIndex];
            }
            $label = "" if (! defined $label);
            my $xLoc = $xLL + ($xDrawInc * $xAxisIndex);
            # If a horizontal xaxis, then attempt to center the label
            # around the X axis.  A special case is when there are 'bar's
            # being drawn so the label then needs to be centered under the
            # are the bars are drawn in.
            if ($xAxisAngle == 0) {
                # Calculate the centered X position of the axis label.
                my $len            = length($label);
                my $halfLabelWidth = $len / 2 * $xAxisFontWidth;
                my $xLabelLoc      = $xLoc - $halfLabelWidth;
                # Compute the X position of each X axis label.  In general we want
                # each label centered on the X axis line, but the first and last
                # labels need some extra care.  The first label might not have
                # enough room to be centered about the (0,0) point so needs to
                # positioned so the left part of the label lines up with (0,0).
                # The last label has a similar problem in that there might not be
                # enough room on the right side of the chart to center the label so
                # the right side of the label may need to be aligned with the right
                # side of the chart.
                # Note: if a bar data set, then just center under the bar
                # area
                my $xPos;
                if ($numBarDataSets) {
                    $xPos = $xLabelLoc + $chartWidthInPixels / $numDataPoints[$LEFT] / 2;
                } elsif ($xLabelLoc > 0) {
                    if (($xLabelLoc + $halfLabelWidth * 2) >= $imageWidth) {
                        $xPos = $xUR - $len * $xAxisFontWidth;
                    } else {
                        $xPos = $xLabelLoc;
                    }
                } else {
                    $xPos = $xLL;
                }
                # If any bars are drawn, then center the X axis label under
                # the bar area.
                $im->string($this->getFont("xaxis"), $xPos, $yLL + 3, $label, $black);
            } else {
                # Assuming a vertical label
                my $len             = length($label);
                my $halfLabelHeight = $this->getFontHeight("xaxis") / 2;
                my $yLabelLoc       = $yLL + $len * $xAxisFontWidth;
                my $xPos            = $xLoc - $halfLabelHeight;
                if ($numBarDataSets) {
                    $xPos += $chartWidthInPixels / $numDataPoints[$LEFT] / 2;
                }
                $im->stringUp($this->getFont("xaxis"), $xPos, $yLabelLoc + 3, $label, $black);
            }
            if (($xAxisIndex != 0) && ($xAxisIndex <= $xIndexMax) && $xGrid eq "on") {
                $im->line($xLoc, $yLL + 2, $xLoc, $yUR - 2, $gridColor);
            }
            if (($xAxisIndex != 0) && ($xAxisIndex <= $xIndexMax) && $xGrid eq "dot") {
                $im->line($xLoc, $yLL + 2, $xLoc, $yUR - 2, gdStyled);
            }
        } ## end for (my $xAxisIndex = 0...)
    } ## end if (@xAxis)
    # Make sure that the max xaxis value is included in the list of
    # drawn xAxises.
    $xGridIndexes[$numDataPoints[$LEFT]] = $numDataPoints[$LEFT];

    # 3333333333333333333333333333333333333333333333333333333333333333333333
    # Now draw any bars.
    $barNum = 0;
    $lineNum = 0;
    foreach my $yAxisLoc (@yAxisLocs) {
	my $numDataSets = $this->_getNumDataSets($yAxisLoc);
	my @data = $this->_getData($yAxisLoc);
	for my $dataSet (0 .. $numDataSets - 1) {
	    my $row = $data[$dataSet];
	    my @row = @{$data[$dataSet]};

	    my $color = $allocatedColors[$lineNum];
	    if ($subTypes[$lineNum] eq "bar") {
		for my $xIndex (0 .. ($numDataPoints[$yAxisLoc] - 1)) {
		    my $currentYValue = $row[$xIndex];
		    # If there is no current value, then there is no default
		    # value so assume a value the same as the minimum of the
		    # chart.
		    if ($currentYValue eq "") {
			$currentYValue = $scaledYAxisMin[$yAxisLoc];
		    }
		    my $y;
		    if ($scale eq "semilog") {
			$y = $yLL - ($this->_scale($currentYValue) - $scaledYAxisMin[$yAxisLoc]) * $yPixelsPerValue[$yAxisLoc];
		    } else {
			$y = $yLL - ($currentYValue - $scaledYAxisMin[$yAxisLoc]) * $yPixelsPerValue[$yAxisLoc];
		    }
		    # Calculate the X position of the start of this data point.
		    my $x;
		    if ($scatterChart) {
			$x = $xLL + (($xAxisIndex{$xIndex} - $xAxisMin) * $xPixelsPerValue);
		    } else {
			$x = $xLL + ($xDrawInc * $xIndex);
		    }
		    # Now ajust the X position for this given bar with in
		    # this data point.
		    $x += $barLeadingSpacePixels + ($barNum * ($barWidthPixels + $barSpacePixels));
		    $im->filledRectangle($x, $y, $x + $barWidthPixels - 1, $yLL, $color);
		    $im->rectangle($x, $y, $x + $barWidthPixels - 1, $yLL, $black) if ($xShowBarBorder);
		} ## end for my $xIndex (0 .. ($numDataPoints[$yAxisLoc]...))
		$barNum++;
	    } ## end if ($subTypes[$dataSet...])
	    $lineNum++;
	} ## end for my $dataSet (0 .. $numDataSets1...)
    }

    # 4444444444444444444444444444444444444444444444444444444444444444444444
    # Now that the areas and bars are drawn, draw the lines and even redraw
    # lines outlining the already drawn areas (since some areas might have
    # been overwritten).
    $lineNum = 0;
    foreach my $yAxisLoc (@yAxisLocs) {
	my $numDataSets = $this->_getNumDataSets($yAxisLoc);
	my $numDataPoints = $this->_getNumDataPoints($yAxisLoc);
	my @data = $this->_getData($yAxisLoc);
	for my $dataSet (0 .. $numDataSets - 1) {
	    my $row = $data[$dataSet];
	    my @row = @{$data[$dataSet]};

	    my $color = $allocatedColors[$lineNum];
	    my ($x1, $x2);
	    # Draw the data set (if an area, it gets filled in by code below).
	    for my $xIndex (0 .. ($numDataPoints - 2)) {
		my $currentYValue = $row[$xIndex];
		my $nextYValue    = $row[$xIndex + 1];
		$currentYValue = $this->_scale($currentYValue) if ($currentYValue ne "");
		$nextYValue    = $this->_scale($nextYValue)    if ($nextYValue    ne "");

		# Deal with sparse data.  If there is:
		#    - current but no next value, draw a point at current
		#    - no current but a next value, draw a point at next
		#    - if both, draw a line between them if asked to
		if ($currentYValue ne "" && $nextYValue eq "") {
		    if ($scatterChart) {
			$x1 = $xLL + (($xAxisIndex{$xIndex} - $xAxisMin) * $xPixelsPerValue);
		    } else {
			$x1 = $xLL + ($xDrawInc * $xIndex);
		    }
		    # If any bars were drawn, then place all lines, plines,
		    # points in the middle of the area in which the bars were
		    # drawn.
		    if ($numBarDataSets) {
			$x1 += $xDrawInc / 2;
		    }
		    my $y1 = $yLL - ($currentYValue - $scaledYAxisMin[$yAxisLoc]) * $yPixelsPerValue[$yAxisLoc];
		    if ($subTypes[$lineNum] ne "bar") {
			$im->filledRectangle($x1 - $pointSizeHalf, $y1 - $pointSizeHalf, $x1 + $pointSizeHalf, $y1 + $pointSizeHalf, $color);
		    }
		} elsif ($currentYValue eq "" && $nextYValue ne "") {
		    if ($scatterChart) {
			$x2 = $xLL + (($xAxisIndex{($xIndex + 1)} - $xAxisMin) * $xPixelsPerValue);
		    } else {
			$x2 = $xLL + ($xDrawInc * ($xIndex + 1));
		    }
		    # If any bars were drawn, then place all lines, plines,
		    # points in the middle of the area in which the bars were
		    # drawn.
		    if ($numBarDataSets) {
			$x2 += $xDrawInc / 2;
		    }
		    my $y2 = $yLL - ($nextYValue - $scaledYAxisMin[$yAxisLoc]) * $yPixelsPerValue[$yAxisLoc];
		    if ($subTypes[$lineNum] ne "bar") {
			$im->filledRectangle($x2 - $pointSizeHalf, $y2 - $pointSizeHalf, $x2 + $pointSizeHalf, $y2 + $pointSizeHalf, $color);
		    }
		} elsif ($currentYValue ne "" && $nextYValue ne "") {
		    if ($scatterChart) {
			$x1 = $xLL + (($xAxisIndex{$xIndex} - $xAxisMin) * $xPixelsPerValue);
			$x2 = $xLL + (($xAxisIndex{($xIndex + 1)} - $xAxisMin) * $xPixelsPerValue);
		    } else {
			$x1 = $xLL + ($xDrawInc * $xIndex);
			$x2 = $xLL + ($xDrawInc * ($xIndex + 1));
		    }
		    # If any bars were drawn, then place all lines, plines,
		    # points in the middle of the area in which the bars were
		    # drawn.
		    if ($numBarDataSets) {
			$x1 += $xDrawInc / 2;
			$x2 += $xDrawInc / 2;
		    }
		    my $y1 = $yLL - ($currentYValue - $scaledYAxisMin[$yAxisLoc]) * $yPixelsPerValue[$yAxisLoc];
		    my $y2 = $yLL - ($nextYValue - $scaledYAxisMin[$yAxisLoc]) * $yPixelsPerValue[$yAxisLoc];
		    # If just a line, then draw a second and 3rd line slightly
		    # below the line to make it appear thicker.
		    if ($subTypes[$lineNum] eq "line" || $subTypes[$lineNum] eq "pline" || $subTypes[$lineNum] eq "area") {
			if ($GD::VERSION >= 2.15) {
			    $im->setThickness($lineWidth);
			    $im->line($x1, $y1, $x2, $y2, $color);
			    $im->setThickness(1);
			} elsif ($lineWidth > 1) {
			    $im->line($x1, $y1, $x2, $y2, $color);
			    for my $yDiff (1 .. (($lineWidth - 1) / 2)) {
				$im->line($x1, $y1 + $yDiff, $x2, $y2 + $yDiff, $color);
			    }
			    for my $yDiff (1 .. (($lineWidth) / 2)) {
				$im->line($x1, $y1 - $yDiff, $x2, $y2 - $yDiff, $color);
			    }
			} else {
			    $im->line($x1, $y1, $x2, $y2, $color);
			}
		    } ## end if ($subTypes[$lineNum...])
			# Draw points.
		    if ($subTypes[$lineNum] eq "point" || $subTypes[$lineNum] eq "pline") {
			$im->filledRectangle($x1 - $pointSizeHalf, $y1 - $pointSizeHalf, $x1 + $pointSizeHalf, $y1 + $pointSizeHalf, $color);
			$im->filledRectangle($x2 - $pointSizeHalf, $y2 - $pointSizeHalf, $x2 + $pointSizeHalf, $y2 + $pointSizeHalf, $color);
		    }
		} ## end elsif ($currentYValue ne ...)
	    } ## end for my $xIndex (0 .. ($numDataPoints...))
	    $lineNum++;
	} ## end for my $dataSet (0 .. $numDataSets...)
    }

    # 5555555555555555555555555555555555555555555555555555555555555555555555
    # Redraw box around entire chart in case it got overwritten by
    # anything.
    $im->rectangle($xLL, $yLL, $xUR, $yUR, $borderColor) if (defined($borderColor));

    # 6666666666666666666666666666666666666666666666666666666666666666666666
    # If requested, draw in labels for the charted values.  This is done
    # last so the labels appear on top of everything else that has been
    # placed on the chart.
    my $numDataLabels = my @dataLabels = $this->getDataLabels();
    # If fewer dataLabel values specified than data sets, then repeat the
    # user specified values.
    if (@dataLabels) {
        my $font       = $this->getFont("data");
        my $fontWidth  = $this->getFontWidth("data");
        my $fontHeight = $this->getFontHeight("data");
	my $boxBG = $im->colorAllocate(_convert_color($boxBGColor));
	$barNum = 0;
	$lineNum = 0;
	foreach my $yAxisLoc (@yAxisLocs) {
	    my $numDataSets = $this->_getNumDataSets($yAxisLoc);
	    my @data = $this->_getData($yAxisLoc);
	    for my $dataSet (0 .. $numDataSets - 1) {
		my $dataLabel = $dataLabels[$dataSet % $numDataLabels];
		$dataLabel =~ s/\s//g;
		my $row       = $data[$dataSet];
		my @row       = @{$data[$dataSet]};
		my $auto      = 0;
		my $mod       = 0;
		if ($dataLabel =~ m/auto/) {
		    $auto = 1;
		    $dataLabel = "box" if ($dataLabel =~ m/box/);
		} elsif ($dataLabel =~ m/(\d+)/) {
		    my $num = $1;
		    $num = 2 if ($num < 2);
		    if ($num < $numDataPoints[$yAxisLoc]) {
			$mod = int($numDataPoints[$yAxisLoc] / ($num - 1));
		    }
		    $dataLabel = "box" if ($dataLabel =~ m/box/);
		}

		my $color = $allocatedColors[$lineNum];
		for my $xIndex (0 .. ($numDataPoints[$yAxisLoc] - 1)) {
		    # If the user specified "auto" or "autobox" for datalabel
		    # for this dataset, then only draw a label if the current
		    # xIndex is one where an xAxis was drawn.
		    next if ($auto && ! defined($xGridIndexes[$xIndex]));
		    # If a datalabel="#" or datalabel="#box" then only show
		    # the specified number of data labels.
		    next if ($mod && (($xIndex % $mod) != 0 && $xIndex != ($numDataPoints[$yAxisLoc] - 1)));

		    my $currentYValue = $row[$xIndex];
		    my $drawText      = $currentYValue;
		    if ($scatterChart) {
			$drawText = $xAxisIndex{$xIndex} . "/" . $currentYValue;
		    }
		    my $len = length $drawText;

		    # If the drawText is non empty, place string/box such
		    # that the lower right corner is located at the data value.
		    # The only exception is if the box would fall off of the
		    # chart either to the left or at the top.
		    if ($currentYValue ne "") {
			my $currentValueY = $this->_scale($currentYValue);
			my $x1;
			if ($scatterChart) {
			    $x1 = $xLL + (($xAxisIndex{$xIndex} - $xAxisMin) * $xPixelsPerValue) - ($len * $fontWidth) - 4;
			} else {
			    $x1 = $xLL + ($xDrawInc * $xIndex) - ($len * $fontWidth) - 4;
			}
			# If any bars were drawn, then all lines, plines,
			# points were drawn in the middle of the area in which
			# the bars were drawn so we need to adjust the data
			# labels accordingly.  If the data label is for a bar
			# itself, then perform a slightly different adjustment.
			if ($numBarDataSets) {
			    if ($subTypes[$dataSet] eq "bar") {
				$x1 += $barLeadingSpacePixels + ($barNum * ($barWidthPixels + $barSpacePixels));
			    } else {
				$x1 += $xDrawInc / 2;
			    }
			}
			my $y1 = $yLL - ($currentValueY - $scaledYAxisMin[$yAxisLoc]) * $yPixelsPerValue[$yAxisLoc] - $fontHeight - 4;
			$x1 += $len * $fontWidth + 4 if ($x1 < 0);    # Push back onto left side
			$y1 += $fontHeight if ($y1 < 0);              # Push down into chart
			if ($dataLabel eq "box") {
			    # In order to put the value into a box, we draw a box,
			    # fill it with white, then draw a black line around the
			    # white box and then draw the value inside the box.
			    $im->filledRectangle($x1, $y1, $x1 + $len * $fontWidth + 4, $y1 + $fontHeight + 4, $boxBG);
			    $im->rectangle($x1, $y1, $x1 + $len * $fontWidth + 4, $y1 + $fontHeight + 4, $black);
			}
			if ($dataLabel ne "off") {
			    $im->string($font, $x1 + 3, $y1 + 2, $drawText, $color);
			}
		    } ## end if ($currentYValue ne ...)
		} ## end for my $xIndex (0 .. ($numDataPoints[$yAxisLoc]...))
		$barNum++ if ($subTypes[$dataSet] eq "bar");
		$lineNum++;
	    } ## end for my $dataSet (0 .. $numDataSets1...)
	}
    } ## end if (@dataLabels)

    # 7777777777777777777777777777777777777777777777777777777777777777777777
    # Draw the title (if requested)
    if (defined $this->getTitle()) {
        my $title = $this->getTitle();
        my $x     = $xLL + $chartWidthInPixels / 2 - (length($title) / 2 * $this->getFontWidth("title"));
        my $y     = 0;
        $im->string($this->getFont("title"), $x, $y, $this->getTitle(), $black);
    }

    # Draw the Y label (if specified)
    if (defined $yLabel1) {
        $im->stringUp(
            $this->getFont("ylabel"),
            $margin,
	    $yUR + ($chartHeightInPixels / 2) + (length($yLabel1) * $this->getFontWidth("ylabel") / 2),
            $yLabel1,
	    $black
        );
    }
    # Draw the Y label (if specified)
    if (defined $yLabel2) {
	my $yOffsetMax = $margin;
	foreach my $yGridLabel (@{$yGridLabels{$RIGHT}}) {
	    my $size = (length($yGridLabel) + 1) * $this->getFontWidth("yaxis");
	    $yOffsetMax = $size if ($size > $yOffsetMax);
	}
        $im->stringUp(
            $this->getFont("ylabel"),
            $xUR + $yOffsetMax,
	    $yUR + ($chartHeightInPixels / 2) + (length($yLabel2) * $this->getFontWidth("ylabel") / 2),
            $yLabel2,
	    $black
        );
    }
    # Draw the X label (if specified)
    if (defined $xLabel) {
        my $yPos = $yLL + 5;
        # Adjust depending on if X axis labels are drawn or not and the
        # orientation of the X axis labels.
        if (@xAxis) {
            if ($xAxisAngle == 0) {
                $yPos += $this->getFontHeight("xaxis");
            } else {
                $yPos += $xAxisMaxLen * $this->getFontWidth("xaxis");
            }
        }
        $im->string(
            $this->getFont("xlabel"),
            $xLL + ($chartWidthInPixels / 2) - (length($xLabel) * $this->getFontWidth("xlabel") / 2),
            $yPos, $xLabel, $black
        );
    } ## end if (defined $xLabel)

    # 8888888888888888888888888888888888888888888888888888888888888888888888
    # Draw the legends (if requested).  This requires some extra work since
    # we may need to 'bubble' up/down the legends if they would overlap
    # each other.
    if (@legends) {
        my $legendFont     = $this->getFont("legend");
        my $fontHeight     = $this->getFontHeight("legend");
        my $halfFontHeight = $fontHeight / 2;
        my $fontWidth      = $this->getFontWidth("legend");
        my $x1             = $xUR + 5;
	if (defined $yLabel2) {
	    $x1 += $this->getFontHeight("ylabel");
	}
	if ($this->getYaxis2() eq "on") {
	    $x1 += $this->getFontWidth("ylabel") * $yAxis2LabelWidth;
	}
	$x1 += 10 if ($isYaxis2Text);
        # 1. determine the ideal Y location of each label
	my @lastValues;
	my $lastValuesIndex = 0;
	foreach my $yAxisLoc (@yAxisLocs) {
	    my $numDataSets = $this->_getNumDataSets($yAxisLoc);
	    my $numDataPoints = $this->_getNumDataPoints($yAxisLoc);
	    my @data = $this->_getData($yAxisLoc);
	    for my $dataSet (0 .. $numDataSets - 1) {
		my $row = $data[$dataSet];
		my @row = @{$data[$dataSet]};
		# Since this @row might contain sparse data, we walk
		# backwards through the data looking for the 1st non-empty
		# value.
                my $lastValue = 0;
		for (my $xIndex = $numDataPoints - 1; $xIndex >= 0; $xIndex--) {
		    if ($row[$xIndex] ne "") {
			$lastValue = $row[$xIndex];
			last;
		    }
		}
		my $y = $yLL - (($lastValue - $scaledYAxisMin[$yAxisLoc]) * $yPixelsPerValue[$yAxisLoc]) - $halfFontHeight;
		# If the y location falls off of the bottom of the chart, then
		# pull up to the bottom of the chart.
		$y = $yLL - $halfFontHeight if ($y > $yLL);
		$lastValues[$lastValuesIndex++] = $y;
	    }
	}
        # 2. Now adjust the Y locations so no labels overlap.  If any two
        # labels have the same Y location, then the first data set gets that
        # location and all subsequent data sets labels get moved.
        @lastValues = $this->adjustLegendYLocations($yUR, @lastValues);

        # 3. Now draw the legends at the (possibly) newly computed Y
        # locations.
        for my $dataSet (0 .. $#lastValues) {
            my $y1 = $lastValues[$dataSet];
            $im->string($legendFont, $x1, $y1, $legends[$dataSet], $black);
            $im->line($x1, $y1 + $fontHeight,     $x1 + length($legends[$dataSet]) * $fontWidth, $y1 + $fontHeight,     $allocatedColors[$dataSet]);
            $im->line($x1, $y1 + $fontHeight - 1, $x1 + length($legends[$dataSet]) * $fontWidth, $y1 + $fontHeight - 1, $allocatedColors[$dataSet]);
        }
    } ## end if (@legends)

    ########################################################################
    # OK, the chart is all drawn so all we need to do is write it out to
    # the specified file.
    my $dir      = $this->getFileDir();
    my $filename = $this->getFileName();
    umask(002);
    open(IMAGE, ">$dir/$filename") or return "Can't create file '$dir/$filename: $!";
    binmode IMAGE;
    if ($GD::VERSION > 1.19) {
        print IMAGE $im->png;
    } else {
        print IMAGE $im->gif;
    }
    close IMAGE;
    return undef;
} ## end sub makeChart

# Given an array of Y locations for legends, walk through the array and
# adjust the values such that no legends will overlap.  This is done in two
# passes.  The first pass is to shift locations up if they overlap with
# other labels.  The second pass is to shift down the locations if any were
# shifted off the top of the chart.
sub adjustLegendYLocations {
    my ($this, $yUR, @yValues) = @_;
    my $fontHeight     = $this->getFontHeight("legend");
    my $halfFontHeight = $fontHeight / 2;
    my $overLap;
    my $overLappedWith;
    my $yValue;
    my $dataSet;
    my @retYvalues;

    my %newYvalues1;
    my %yValues;
    my $needToShiftBackDown = 0;
    # Put the Y values into a hash since it is easier to deal with a hash.
    for $dataSet (0 .. @yValues - 1) {
        $yValues{$dataSet} = $yValues[$dataSet];
    }
    # Now sort the Y values from highest value (lowest point on the chart)
    # to lowest value (highest point on the chart) to make it easier to
    # adjust the Y values such that no two values are on top of each other.
    # The process is to start with the lowest (on the chart) legend and
    # then adjust all subsequent legends up if they happen to overlap
    # previously placed legends.

    for $dataSet (sort {$yValues{$b} <=> $yValues{$a}} keys %yValues) {
        $yValue  = $yValues{$dataSet};
        $overLap = 0;
        # Check to see if the currently looked at Y value overlaps with any
        # (possibly adjusted) previous Y values.  If so, then adjust it up.
        for my $newDataSet (sort {$newYvalues1{$b} <=> $newYvalues1{$a}} keys %newYvalues1) {
            my $new = $newYvalues1{$newDataSet};
            # Check to see if the labels actually overlap.
            if (($yValue + $halfFontHeight) >= ($new - $halfFontHeight)) {
                # Remember the value of the already placed legend so when
                # we adjust the current value, we adjust based on what we
                # overlapped with.  We keep a flag instead of just using
                # $overLappedWith since $overLappedWith might equal 0 in an
                # overlap condition which would break the logic.
                $overLap        = 1;
                $overLappedWith = $new;
            }
        }
        if ($overLap != 0) {
            # Adjust the current Y value up on the chart by an amount of
            # 1/2 the height of the legend font.  The starting point is the
            # previously placed Y value that the current value overlapped
            # with.
            $yValue = $overLappedWith - $fontHeight;
        }
        # Save the possibly adjusted value into a new hash;
        $newYvalues1{$dataSet} = $yValue;
        # Check to see if the shifting up of labels moved it above the
        # top of the graph.  If so, we will need to then shift things
        # back down (see below).
        $needToShiftBackDown = 1 if ($yValue < $yUR);
    } ## end for $dataSet (sort {$yValues...})

    # If any values got adjusted off of the top of the chart, then we need
    # to re-adjust the legends back down so they are all on the chart.
    if ($needToShiftBackDown == 1) {
        my %newYvalues2;
        my $firstValue = 1;
        my $adjustedTo;
        # Now adjust back down on the graph any legends that got adjusted
        # off the top of the graph.
        for $dataSet (sort {$newYvalues1{$a} <=> $newYvalues1{$b}} keys %newYvalues1) {
            $yValue  = $newYvalues1{$dataSet};
            $overLap = 0;
            # If the first value, we don't need to do a lot of work since
            # there are no previous values to compare against.
            if ($firstValue) {
                # Check to see if the 1st value falls off of the top of the
                # chart.  If so, force its value to be at the top of the
                # chart.  This will force all other values to be shifted
                # down as well.
                if ($yValue < $yUR) {
                    $overLap    = -1;
                    $adjustedTo = $yUR - $halfFontHeight;
                    $firstValue = 0;
                }
            } else {
                # Check to see if the current value overlaps any of the previously looked at
                # legends.  If so, adjust down.
                for my $newDataSet2 (sort {$newYvalues2{$a} <=> $newYvalues2{$b}} keys %newYvalues2) {
                    my $new = $newYvalues2{$newDataSet2};
                    if (($yValue - $halfFontHeight) <= ($new + $halfFontHeight)) {
                        $overLap    = 1;
                        $adjustedTo = $new + $fontHeight;
                    } else {
                        # If already in an overlap mode, then take the last legend
                        # value we adjusted as the starting point for adjusting the
                        # current value
                        $adjustedTo = $new + $fontHeight if ($overLap);
                    }
                }
            } ## end else [ if ($firstValue) ]
            if ($overLap == 0) {
                $newYvalues2{$dataSet} = $yValue;
            } else {
                $newYvalues2{$dataSet} = $adjustedTo;
            }
        } ## end for $dataSet (sort {$newYvalues1...})
            # Move the adjusted values into an array that gets returned
        for $dataSet (keys %newYvalues2) {
            $retYvalues[$dataSet] = $newYvalues2{$dataSet};
        }
    } else {
        # Move the adjusted values into an array that gets returned
        for $dataSet (keys %newYvalues1) {
            $retYvalues[$dataSet] = $newYvalues1{$dataSet};
        }
    }
    return @retYvalues;
} ## end sub adjustLegendYLocations

# This routine attempts to compute the number of grid lines to use such
# that the resulting grid values are human readable.  The largest number
# of grid lines is passed in.
sub computeLinearNumGrids {
    my ($this, $min, $max, $numGrids) = @_;
    $numGrids++;
    # Compute the difference between the max and min values.
    my $diff = $max - $min;

    # Deal with the special case where the difference is 0 or the number of
    # grids is 0.  If this is the case, then there is nothing we can do
    # here so we just return.
    return $numGrids if ($diff == 0);
    return 0 if ($numGrids == 0);

    # We "normalize" the difference to make processing easier.  So convert:
    # 123	=> 1.23
    # 0.123	=> 1.23
    # 1.23e10	=> 1.23
    # So $baseDiff will always be in the range of 1-9
    my $decimalDigits = log10($diff);
    if ($decimalDigits) {
        $decimalDigits = int(floor($decimalDigits));
    }
    my $baseDiff = $diff / pow(10.0, $decimalDigits);
    # Deail with some odd math issues with rounding.
    $baseDiff = int($baseDiff * 1000 + 0.1) / 1000;

    # Walk through all possible number of grids looking for a range
    # between grids that is human readable.  We do this by computing all
    # ranges and taking the first shortest.  This gives preference to a
    # larger number of grid lines.
    my $minLen         = 99999;
    my $minLenNumGrids = 0;
    for (my $g = $numGrids; $g > 1; $g--) {
        my $range = $baseDiff / $g * 1;
        my $len   = length($range);
        if ($len < $minLen) {
            $minLen         = $len;
            $minLenNumGrids = $g;
        }
    }
    return $minLenNumGrids - 1;
} ## end sub computeLinearNumGrids

# This routine takes a number and returns the "floor" for that number
# adjusting to the nearest 1*, 2*, or 5*
sub computeFloor {
    my ($num) = @_;
    return 0 if ($num == 0);
    my $decimalDigits = log10($num < 0 ? -$num : $num);
    if ($decimalDigits) {
        $decimalDigits = int(floor($decimalDigits));
    }
    my $base = $num / pow(10.0, $decimalDigits);
    my $newBase;
    if ($base < -5) {
        $newBase = -10;
    } elsif ($base < -2) {
        $newBase = -5;
    } elsif ($base < -1) {
        $newBase = -2;
    } elsif ($base < 0) {
        $newBase = -1;
    } elsif ($base < 1) {
        $newBase = 0;
    } elsif ($base < 2) {
        $newBase = 1;
    } elsif ($base < 5) {
        $newBase = 2;
    } else {
        $newBase = 5;
    }
    my $newNum = $newBase * pow(10.0, $decimalDigits);
    return $newBase * pow(10.0, $decimalDigits);
} ## end sub computeFloor

# This routine takes a number and returns the "ceil" for that number
# adjusting to the nearest 1*, 2*, or 5*
sub computeCeil {
    my ($num) = @_;
    return 1 if ($num == 0);
    my $decimalDigits = log10($num < 0 ? -$num : $num);
    if ($decimalDigits) {
        $decimalDigits = int(floor($decimalDigits));
    }
    my $base = $num / pow(10.0, $decimalDigits);
    my $newBase;
    if ($base <= -5) {
        $newBase = -5;
    } elsif ($base <= -2) {
        $newBase = -2;
    } elsif ($base <= -1) {
        $newBase = -1;
    } elsif ($base <= 0) {
        $newBase = 0;
    } elsif ($base <= 1) {
        $newBase = 1;
    } elsif ($base <= 2) {
        $newBase = 2;
    } elsif ($base <= 5) {
        $newBase = 5;
    } else {
        $newBase = 10;
    }
    return $newBase * pow(10.0, $decimalDigits);
} ## end sub computeCeil

# Attempt to compute the number of significant digits in the numbers
# generated based on the user specified min, max and number of grids.
sub computeNumDigits {
    my ($this, $min, $max, $numGrids) = @_;
    # Compute the difference between the max and min values.
    my $diff = $max - $min;
    # Compute the increment between grid lines.
    my $inc = sprintf("%.12f", $diff / ($numGrids + 1));
    # If the increment is >= 1000, then it doesn't make any sense to show
    # any decimal digits.
    return 0 if ($inc >= 1000);
    $inc =~ s/0*$//;    # Strip off all trailing 0's

    # Get the integer part and fractional part from $inc
    my $integerDigits    = undef;
    my $fractionalDigits = undef;
    if ($inc =~ m/(\d+)\.(\d+)/) {
        $integerDigits    = $1;
        $fractionalDigits = $2;
    } else {
        $inc =~ m/(\d+)/;
        $integerDigits    = $1;
        $fractionalDigits = "";
    }
    my $numIntegerDigits    = length($integerDigits);
    my $numFractionalDigits = length($fractionalDigits);

    if (6 - $numIntegerDigits >= 0) {
        return $numFractionalDigits if ($numFractionalDigits < 6 - $numIntegerDigits);
        return 6 - $numIntegerDigits;
    } else {
        return 0;
    }
} ## end sub computeNumDigits

# Convert a color in the form of either #RRGGBB or just RRGGBB (both in hex
# format) to a 3 element array of decimal numbers in the form
# (RED GREEN BLUE).
sub _convert_color {
    my ($hexcolor) = @_;
    my ($red, $green, $blue);
    $hexcolor =~ /#?(..)(..)(..)/;
    $red   = hex($1);
    $green = hex($2);
    $blue  = hex($3);
    return ($red, $green, $blue);
}

# This routine takes a floating point number and returns a string in a
# consistent format suitable for printing out and showing the user.  If the
# number is > 999,999 or less than 0.001, then engineering notation is
# used.
sub _printNumber {
    my ($num, $numDigits) = @_;
    my $text;
    if (abs($num) > 999999) {
        $text = sprintf("%2.1e", $num);
    } elsif (abs($num) < 0.001 && $num != 0) {
        $text = sprintf("%2.1e", $num);
    } else {
        $text = sprintf("%.${numDigits}f", $num);
    }
    return $text;
}

# Given a number, return an adjusted version of that number depending on
# the scale the user has specified.  If scale=semilog, then return the
# log10 of the value else just return the original value (assuming linear).
sub _scale {
    my ($this, $value) = @_;
    my $scale = $this->getScale();
    return log10($value) if ($scale eq "semilog");
    # Assume linear
    return $value;
}

# Return first integer number found in a string
sub _getInt {
    my ($str) = @_;
    $str = '0' unless ($str);
    if ($str =~ s/^.*?(\-?)0*([0-9]+).*$/$1$2/o) {
        return int($str);
    }
    return 0;
}

1;
