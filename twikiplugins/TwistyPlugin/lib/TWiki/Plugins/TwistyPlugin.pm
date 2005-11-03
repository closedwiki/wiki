# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
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

=pod

---+ package TwistyPlugin

Convenience plugin for TWiki:Plugins.TwistyContrib.
It has two major features:
   * When active, the Twisty javascript library is included in every topic.
   * Provides a convenience sintax to define twisty areas.


=cut

package TWiki::Plugins::TwistyPlugin;    # change the package name and $pluginName!!!

use strict;

use vars qw( $VERSION $RELEASE $pluginName $debug @modes);

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

$pluginName = 'TwistyPlugin';  # Name of this Plugin

#there is no need to document this.
sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin preferences, variables defined by:
    #   * Set EXAMPLE = ...
    $debug = TWiki::Func::getPluginPreferencesFlag( "DEBUG" );
    my $header=<<'EOF'; 
<style type="text/css" media="all">
@import url("%PUBURL%/TWiki/TwistyContrib/twist.css");
</style>

<script type="text/javascript" src="%PUBURL%/TWiki/TwistyContrib/twist.js"></script>
EOF

    TWiki::Func::addToHEAD('TWISTYPLUGIN_TWISTY',$header);
    TWiki::Func::registerTagHandler( 'EXAMPLETAG', \&_EXAMPLETAG );
    TWiki::Func::registerTagHandler('TWISTYSHOW',\&_TWISTYSHOW);
    TWiki::Func::registerTagHandler('TWISTYHIDE',\&_TWISTYHIDE);
    TWiki::Func::registerTagHandler('TWISTYTOGGLE',\&_TWISTYTOGGLE);
    TWiki::Func::registerTagHandler('ENDTWISTYTOGGLE',\&_ENDTWISTYTOGGLE);

    return 1;
}


sub _TWISTYSHOW {
     return _TWISTYBUTTON(@_, 'show');
}

sub _TWISTYHIDE {
     return _TWISTYBUTTON(@_, 'hide');
}

sub _TWISTYBUTTON {
	my($session, $params, $theTopic, $theWeb, $theState) = @_;
	my $id=$params->{'id'}||'';
    my $link=$params->{'link'}||'';
    my $mode=$params->{'mode'}||'span';
    my $img=$params->{'img'} || '';
    $img =~ s/['\"]//go;
    my $imgTag=($img ne '') ? '<img src="'.$img.'" border="0" alt="" />' : '';
    my $initialHidden=($theState eq 'hide') ? 'twistyHidden ' : '';
    return '<'.$mode.' id="'.$id.$theState.'" class="'.$initialHidden.'twistyMakeVisible"><a href="#" class="twistyTrigger"><span class="twikiLinkLabel">'.$link.'</span>'.$imgTag.'</a></'.$mode.'>';
}

sub _TWISTYTOGGLE {
    my($session, $params, $theTopic, $theWeb) = @_;
    my $id=$params->{'id'}||'';
    my $mode=$params->{'mode'}||'span';
    my $cookieEnabled=($params->{'remember'} eq 'on') ? ' twistyRememberSetting' : '';
    unshift @modes,$mode;
    return '<'.$mode.' id="'.$id.'toggle" class="twistyMakeHidden'.$cookieEnabled.'">';
}

sub _ENDTWISTYTOGGLE {
    my($session, $params, $theTopic, $theWeb) = @_;
    my $mode=shift @modes;
    return '</'.$mode.'>';
}


1;
