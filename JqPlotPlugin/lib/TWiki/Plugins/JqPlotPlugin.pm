# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2012 TWiki:Main.MahiroAndo 
# Copyright (C) 2012 TWiki Contributors
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

=pod

---+ package TWiki::Plugins::JqPlotPlugin

jqPlot JavaScript library for TWiki

=cut

# Always use strict to enforce variable scoping
use strict;

package TWiki::Plugins::JqPlotPlugin;

# Name of this Plugin, only used in this module
our $pluginName = 'JqPlotPlugin';

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version

our $VERSION = '$Rev$';
our $JQPLOT_RELEASE = 'jquery.jqplot.1.0.4r1121';
our $RELEASE = "2012-11-14 $JQPLOT_RELEASE";

# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION = 'Add line, bar and pie charts to TWiki topics using jqPlot !JavaScript library';
our $NO_PREFS_IN_TOPIC = 1;

# Define other global package variables
our $debug;

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    unless( $TWiki::cfg{Plugins}{JQueryPlugin}{Enabled} ) {
        TWiki::Func::writeWarning( "JQueryPlugin must be installed to use JqPlotPlugin" );
        return 0;
    }

    TWiki::Func::registerTagHandler( 'JQPLOT', \&_JQPLOT );
    return 1;
}

my $jqPlotPath = "%PUBURLPATH%/%SYSTEMWEB%/JqPlotPlugin/$JQPLOT_RELEASE";

my $jqPlotCommon = <<END;
<script type="text/javascript" src="$jqPlotPath/excanvas.min.js"></script><!--only for IE8 or older-->
<script type="text/javascript" src="$jqPlotPath/jquery.jqplot.min.js"></script>
<link rel="stylesheet" type="text/css" href="$jqPlotPath/jquery.jqplot.css" />
END

my $jqPlotCommonAdded = 0;

sub _JQPLOT {
    my($session, $params, $theTopic, $theWeb, $meta, $textRef) = @_;

    unless ($jqPlotCommonAdded) {
        $jqPlotCommonAdded = 1;
        TWiki::Func::addToHEAD('JQPLOTPLUGIN_COMMON', $jqPlotCommon);
    }

    if (my $names = $params->{_DEFAULT}) {
        for my $name (split /[\s,]+/, $names) {
            next if $name eq '';

            $name =~ s!^(/?plugins/)?jqplot\.!!;
            $name =~ s!(\.min)?(\.js)?$!!;

            my $path = "$jqPlotPath/plugins/jqplot.$name.min.js";
            my $script = qq(<script type="text/javascript" src="$path"></script>\n);
            TWiki::Func::addToHEAD('JQPLOTPLUGIN_'.uc($name), $script, 'JQPLOTPLUGIN_COMMON');
        }
    }

    return '';
}

1;
