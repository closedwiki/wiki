# EmailObfuscationPlugin
# 
# Copyright (C) 2006 Stephen Gordon, sgordon@esscc.uq.edu.au

# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
# Copyright (C) 2006 TWiki:Main.StephenGordon
# Copyright (C) 2006-2010 TWiki Contributors. All Rights Reserved. 
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution.
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

=pod

---+ package EmailObfuscationPlugin

This plugin replaces that @ symbol in an email address with a proper
HTML character entity which causes many email harvesters to fail
to recognise an address while appearing as normal to all valid browsers.

=cut

use HTML::Entities qw(encode_entities_numeric);

package TWiki::Plugins::EmailObfuscationPlugin;

use strict;

use vars qw( $VERSION $RELEASE $debug $pluginName );

$VERSION = '$Rev: 9598$';
$RELEASE = '2010-10-30';

$pluginName = 'EmailObfuscationPlugin';

my $ESCAPELIST;

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

=cut

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::$pluginName::initPlugin( $web.$topic ) is OK" ) if $debug;

    $ESCAPELIST = TWiki::Func::getPreferencesValue( "\U$pluginName\E_ESCAPELIST" ) || "\000-\056\072-\100\133-\140\173-\177";

    # Plugin correctly initialized
    return 1;
}

=pod

---++ postRenderingHandler( $text )
   * =$text= - the text that has just been rendered. May be modified in place.
=cut
sub postRenderingHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    #my $text = shift;
    TWiki::Func::writeDebug( " TWiki::Plugins::$pluginName::postRenderingHandler( $_[2].$_[1] )" ) if $debug;

    $_[0] =~ s/((mailto:)?[a-zA-Z0-9-_.+]+\@[a-zA-Z0-9-_.]+\.[a-zA-Z0-9-_]+)/HTML::Entities::encode_entities_numeric( $1, $ESCAPELIST )/gem;

}

1;
