# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
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

package TWiki::Plugins::HideInEditModePlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName
        $debug $exampleCfgVar
    );

$VERSION = '$REV$';
$pluginName = 'HideInEditModePlugin';  # Name of this Plugin

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    my $context = TWiki::Func::getContext();
    if ($context->{'view'}) {
	if (my $query = TWiki::Func::getCgiQuery()) {
	   if ($query->param('raw')) {
		TWiki::Func::writeDebug("In raw mode") if $debug;
	    }
	}
    }
    $_[0] =~ s/%STARTHIDDEN(\{"(.*?)"\})?%(.*?)%ENDHIDDEN%/$3/sg;
    # New feature: allowing top and bottom hidden areas. 
}

# =========================
sub beforeEditHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    my $topic = $_[1];
    my $web = $_[2];

    TWiki::Func::writeDebug( "- ${pluginName}::beforeEditHandler( $web.$topic )" ) if $debug;

    # This handler is called by the edit script just before presenting the edit text
    # in the edit box. Use it to process the text before editing.
    # New hook in TWiki::Plugins $VERSION = '1.010'

    # New feature: allowing top and bottom hidden areas. 
    if ($_[0] =~ /%STARTHIDDEN(\{"top"\})?%(.*?)%ENDHIDDEN%/s) {
	saveHiddenPortion($_[0], $topic, $web, "top");
    }
    if ($_[0] =~ /%STARTHIDDEN\{"bottom"\}%(.*?)%ENDHIDDEN%/s) {
	saveHiddenPortion($_[0], $topic, $web, "bottom");
    }
}

sub saveHiddenPortion {
    #my ($text, $topic, $web, $arg) = @_;
    $topic = $_[1];
    $web = $_[2];
    $arg = $_[3];

    my $wikiUser = TWiki::Func::getWikiUserName();	
    if (!TWiki::Func::checkAccessPermission("HIDDEN", $wikiUser, $_[0], $topic, $web)) {
	TWiki::Func::writeDebug("No access");
	$_[0] =~ s/%STARTHIDDEN(\{"(.*?)"\})?%(.*?)%ENDHIDDEN%//s;
	my $storage = $2;
	$storage =~ s/&amp\;/&/go;    
	$storage =~ s/&lt\;/</go;
	$storage =~ s/&gt\;/>/go;
	my $workArea = TWiki::Func::getWorkArea($pluginName);
	my $filename = "$workArea/tmp.$web.$topic";
	if ($arg) {
	    $fileName .= ".$arg";
	}
	TWiki::Func::saveFile($filename, $storage);
    }
}

# =========================
sub afterEditHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    my $topic = $_[1];
    my $web = $_[2];

    TWiki::Func::writeDebug( "- ${pluginName}::afterEditHandler( $web.$topic )" ) if $debug;

    # This handler is called by the preview script just before presenting the text.
    # New hook in TWiki::Plugins $VERSION = '1.010'

    my $workArea = TWiki::Func::getWorkArea($pluginName);
    my $prefix = "$workArea/tmp.$web.$topic";
    if ( -e "$prefix.top") {
	my $storage = TWiki::Func::readFile("$prefix.top");
	$_[0] = "$storage $_[0]";
    }
    if ( -e "$prefix.bottom") {
	my $storage = TWiki::Func::readFile("$prefix.bottom");
	$_[0] = "$_[0] $storage";
    }
    if ( -e $prefix ) {
	my $storage = TWiki::Func::readFile($prefix);
	$_[0] = "$storage $_[0]";
    }
}

1;
