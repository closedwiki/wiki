# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2003 TWiki:Main.AbieSwanepoel
# Copyright (C) 2008-2011 TWiki Contributors. All Rights Reserved.
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
# For licensing info read LICENSE file in the TWiki root.

=pod

---+ package GnuPlotPlugin

=cut

package TWiki::Plugins::GnuPlotPlugin;

use strict;

use vars qw( $VERSION $RELEASE $debug $pluginName );

$VERSION = '$Rev$';
$RELEASE = '2011-03-12';

# Name of this Plugin, only used in this module
$pluginName = 'GnuPlotPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

=cut

sub initPlugin {
    #TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
    my( $topic, $web, $user, $installWeb ) = @_;
    $debug = TWiki::Func::getPreferencesValue( 'GNUPLOTPLUGIN_DEBUG' );
    TWiki::Func::writeDebug( "Initialising GnuPlotPlugin...." ) if $debug;
    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # register the handleGnuPlotTag function to handle %GNUPLOT{...}% tag
    TWiki::Func::registerTagHandler( 'GNUPLOT', \&handleGnuPlotTag );

    # Allow a sub to be called from the REST interface 
    # using the provided alias
    TWiki::Func::registerRESTHandler('gnuPlot', \&restGnuPlot);

    # Plugin correctly initialized
    return 1;
}

sub handleGnuPlotTag {
    my($session, $params, $topic, $web) = @_;
    # $session  - not used.
    # $params=  - _DEFAULT is the name of the plot
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: rendered text for the plugin

    TWiki::Func::writeDebug( "GnuPlotPlugin::handleGnuPlotTag for $web - $topic Name=$params->{_DEFAULT}" ) if $debug;
    my $plotName = $params->{_DEFAULT};
    unless ($plotName) { return showError('Plot must have a name.'); };
    my $query = TWiki::Func::getCgiQuery();
    my $action = $query->param( 'gnuPlotAction');
    unless ($action) { return showPlot($web, $topic, $plotName); };
    my $queryTarget = $query->param( 'gnuPlotName');
    if ($action eq 'edit' and $queryTarget eq $plotName) { return editPlotSettings($web, $topic, $plotName); };
    if ($action eq 'save' and $queryTarget eq $plotName) { return savePlotSettings($web, $topic, $plotName, $query->param( 'gnuPlotSettingsText')); };
    return showPlot($web, $topic, $plotName); 
}

sub showError{
    my $error = shift;
    TWiki::Func::writeDebug( "GnuPlotPlugin showError" ) if $debug;
    return "Error: $error\n";
}

sub showPlot{
    my ($web, $topic, $name) = @_;
    TWiki::Func::writeDebug( "GnuPlotPlugin::showPlot  - showPlot for $web, $topic, $name" ) if $debug;
    require TWiki::Plugins::GnuPlotPlugin::Plot;
    my $plot = TWiki::Plugins::GnuPlotPlugin::Plot->new($web, $topic, $name);
    return $plot->render();
}

sub editPlotSettings{
    my ($web, $topic, $name) = @_;
    TWiki::Func::writeDebug( "GnuPlotPlugin::editPlotSettings for $web, $topic, $name" ) if $debug;
    require TWiki::Plugins::GnuPlotPlugin::PlotSettings;
    my $settings = TWiki::Plugins::GnuPlotPlugin::PlotSettings->fromFile($web, $topic, $name);
    return $settings->render();
}

sub savePlotSettings{
    my ($web, $topic, $name, $text) = @_;
    TWiki::Func::writeDebug( "GnuPlotPlugin::savePlotSettings $web, $topic, $name, $text" ) if $debug;
    require TWiki::Plugins::GnuPlotPlugin::PlotSettings;
    TWiki::Func::writeDebug( "GnuPlotPlugin::savePlotSettings ----------------------------------------------------" ) if $debug;
    TWiki::Plugins::GnuPlotPlugin::PlotSettings::writeFile($web, $topic, $name, $text);
    TWiki::Func::writeDebug( "GnuPlotPlugin::savePlotSettings OOOOO----------------------------------------------------" ) if $debug;
    TWiki::Func::redirectCgiQuery( {}, TWiki::Func::getScriptUrl( $web, $topic, "view" ) . "\#gnuplot$name");
}

=pod


---++ restExample($session) -> $text

This is an example of a sub to be called by the =rest= script. The parameter is:
   * =$session= - The TWiki object associated to this session.

Additional parameters can be recovered via de query object in the $session.

For more information, check TWiki:TWiki.TWikiScripts#rest

=cut

sub restGnuPlot {
   #my ($session) = @_;
   return "This is an example of a REST invocation\n\n";
}

1;
