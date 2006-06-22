# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (c) 2006 by Meredith Lesly
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::AttachContentPlugin;

# Always use strict to enforce variable scoping
use strict;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package
use vars qw( $VERSION $RELEASE $debug $pluginName );
use vars qw( $savedAlready $keepPars ); 

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# Name of this Plugin, only used in this module
$pluginName = 'AttachContentPlugin';

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    $debug = TWiki::Func::getPreferencesFlag("DEBUG");
    $keepPars = TWiki::Func::getPreferencesValue("KEEPPARS");

    # Plugin correctly initialized
    return 1;
}

=pod

---++ afterSaveHandler($text, $topic, $web, $error, $meta )
   * =$text= - the text of the topic _excluding meta-data tags_
     (see beforeSaveHandler)
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$error= - any error string returned by the save.
   * =$meta= - the metadata of the saved topic, represented by a TWiki::Meta object 

This handler is called each time a topic is saved.

__NOTE:__ meta-data is embedded in $text (using %META: tags)

__Since:__ TWiki::Plugins::VERSION = '1.020'

=cut

sub afterSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web, $error, $meta ) = @_;

    return if $savedAlready;
    $savedAlready = 1;

    TWiki::Func::writeDebug( "- ${pluginName}::afterSaveHandler( $_[2].$_[1] )" ) if $debug;

    $_[0] =~ s/%ATTACH{"(.*?)"}%(.*?)%ENDATTACH%/&handleAttach($1, $2, $_[2], $_[1])/ges;
    $savedAlready = 0;
}

sub handleAttach {
    my ($fileName, $content, $web, $topic) = @_;
    my $workArea = TWiki::Func::getWorkArea($pluginName);
    my $fullName = $workArea . '/' . $fileName;

    $content = TWiki::Func::expandCommonVariables($content, $topic, $web);
    unless ($keepPars) {
	$content =~ s/<p\s*\/>/\r/;
    }

    TWiki::Func::writeDebug("fullName: $fullName") if $debug;

    TWiki::Func::saveFile($fullName, $content);

    TWiki::Func::saveAttachment($web, $topic, $fileName, { file => $fullName });
    return "";
}

1;
