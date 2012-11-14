# Plugin for TWiki Collaboration Platform, http://TWiki.org/
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

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package. It should always be Rev enclosed in dollar
# signs so that TWiki can determine the checked-in status of the plugin.
# It is used by the build automation tools, so you should leave it alone.
our $VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS. Add a release date in ISO
# format (preferred) or a release number such as '1.3'.
our $JQPLOT_RELEASE = 'jquery.jqplot.1.0.4r1121';
our $RELEASE = "2012-11-14 $JQPLOT_RELEASE";

# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION = 'jqPlot JavaScript library for TWiki';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use preferences
# stored in the plugin topic. This default is required for compatibility with
# older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, use $TWiki::cfg entries set in LocalSite.cfg, or
# if you want the users to be able to change settings, then use standard TWiki
# preferences that can be defined in your Main.TWikiPreferences and overridden
# at the web and topic level.
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
