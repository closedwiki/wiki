# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2003 TWiki:Main.RahulMundke
# Copyright (C) 2003-2010 TWiki:TWiki.TWikiContributor
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

# =========================
package TWiki::Plugins::CounterPlugin;

# =========================
#This is plugin specific variable
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $debug 
    );

$VERSION = '$Rev$';
$RELEASE = '2010-09-05';

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between CounterPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "COUNTERPLUGIN_DEBUG" );

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins:CounterPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
    $_[0] =~ s/%COUNTER_PLUGIN%/_handleTag( )/geo;	
}

#-------------------------------------------------------------------------------------------------

sub _handleTag
{
    # increment the counter and throw up the page with this count
    my $FileLocation = &TWiki::Func::getWorkArea( 'CounterPlugin' );
    my $DataFile = 'visitor_count.txt';
    my $CounterFile = "$FileLocation/$DataFile";
    TWiki::Func::writeDebug( "- TWiki::Plugins:CounterPlugin::_handleTag - FileLocation is $FileLocation" ) if $debug;

    if ( open(FILE , '<', $CounterFile) ) {
        TWiki::Func::writeDebug("   Opened $DataFile file successfully") if $debug;
        $Count = <FILE>;
        close FILE;
    } else {
        # File doesn't exist
        $Count = 0;
    }

    open(FILE, '>', $CounterFile) || die "Can't open $DataFile file";
    ++$Count;
    print FILE $Count;
    close FILE;

    return $Count;
}

1;
