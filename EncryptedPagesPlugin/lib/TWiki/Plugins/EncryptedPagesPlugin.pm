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
# EncryptedPages Link Plugin:
#
# MRJC: RJE! edit this.
# Here we handle an inter-site links, i.e. links going outside TWiki
# The recognized syntax is:
#       InterSiteName:TopicName
# and inserts <a href="URL/TopicName">InterSiteName:TopicName</a>
# link, where URL is obtained by a topic that lists all
# InterSiteName/URL pairs.
# Inter-site name convention: Sites must start with upper case
# and must be preceeded by white space, '-', '*' or '('
#
# =========================
package TWiki::Plugins::EncryptedPagesPlugin;
# =========================

use vars qw(
        $web $topic $user $installWeb  $VERSION $debug
        $prefixPattern $postfixPattern
        $replacementText
    );


$VERSION = '1.000';



# 'Use locale' for internationalisation of Perl sorting and searching - 
# main locale settings are done in TWiki::setupLocale
BEGIN {
    # Do a dynamic 'use locale' for this module
    if( $TWiki::useLocale ) {
        require locale;
	import locale ();
    }
}

# =========================
# Plugin startup - read preferences and get all EncryptedPages Site->URL mappings
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between EncryptedPagesPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin preferences from EncryptedPagesPlugin topic

    $debug = &TWiki::Func::getPreferencesFlag( "ENCRYPTEDPAGESPLUGIN_DEBUG" );

    $prefixPattern  = '%ENCRYPTEDPAGE{';
    $postfixPattern = '}%';
    $replacementText = &TWiki::Func::getPreferencesValue( "ENCRYPTEDPAGESPLUGIN_APPLET_INVOCATION");

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::EncryptedPagesPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub DISABLE_commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
    &TWiki::Func::writeDebug( "- EncryptedPagesPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;
}

# =========================
sub DISABLE_startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead
    &TWiki::Func::writeDebug( "- EncryptedPagesPlugin::startRenderingHandler( $_[1] )" ) if $debug;
}

# =========================
# Expand the Site:page references, called once per line of text
sub outsidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    $replacementText = &TWiki::Func::expandCommonVariables( $replacementText, $topic, $web);
    $_[0] =~ s/$prefixPattern(.*)$postfixPattern/$replacementText/geo;
    my $key= $1;
    $_[0] =~ s/--!!--/$key/geo;
}

# =========================
sub DISABLE_insidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead
}


1;
