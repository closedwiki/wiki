#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
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
#
# This is an empty TWiki plugin. Use it as a template
# for your own plugins; see TWiki.TWikiPlugins for details.
#
# Each plugin is a package that contains the subs:
#
#   initPlugin           ( $topic, $web, $user, $installWeb )
#   commonTagsHandler    ( $text, $topic, $web )
#   startRenderingHandler( $text, $web )
#   outsidePREHandler    ( $text )
#   insidePREHandler     ( $text )
#   endRenderingHandler  ( $text )
#
# initPlugin is required, all other are optional. 
# For increased performance, all handlers except initPlugin are
# disabled. To enable a handler remove the leading DISABLE_ from
# the function name.
# 
# NOTE: To interact with TWiki use the official TWiki functions
# in the &TWiki::Func module. Do not reference any functions or
# variables elsewhere in TWiki!!


# =========================
package TWiki::Plugins::CategoryPlugin; 	# change the package name!!!

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $debug $categoryTemplate
        $globalCategoriesWeb $categoryImgUrl $categoryHeader $categorySearch 
    );

$VERSION = '0.900';

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    &TWiki::Func::writeDebug( "- TWiki::Plugins::CategoryPlugin::initPlugin is OK" ) if $debug;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        &TWiki::Func::writeWarning( "Version mismatch between CategoryPlugin and Plugins.pm" );
        return 0;
    }

    $categoryTemplate= &TWiki::Prefs::getPreferencesValue( "CATEGORY_TEMPLATE" ) || &TWiki::Prefs::getPreferencesValue( "CATEGORYPLUGIN_CATEGORY_TEMPLATE" ) || "%TWIKIWEB%.CategoryTemplate";

    # web where global categories topics are stored
    $globalCategoriesWeb = &TWiki::Prefs::getPreferencesValue( "GLOBAL_CATEGORIES_WEB" ) || &TWiki::Prefs::getPreferencesValue( "CATEGORYPLUGIN_GLOBAL_CATEGORIES_WEB" ) || "%TWIKIWEB%";

    # CATEGORY_SEARCH
    $categorySearch = &TWiki::Prefs::getPreferencesValue( "GLOBAL_CATEGORIES_WEB" ) || &TWiki::Prefs::getPreferencesValue( "CATEGORYPLUGIN_GLOBAL_CATEGORIES_WEB" ) || "%SEARCH{\".*Category$\" scope=\"topic\" regex=\"on\" order=\"topic\" web=\"%CATEGORY_WEBS%\" nosearch=\"on\" nosummary=\"on\" }%";

    $categoryImgUrl = &TWiki::Prefs::getPreferencesValue( "CATEGORYPLUGIN_CATEGORYIMGURL" )  || "%M%";
    $categoryHeader = &TWiki::Prefs::getPreferencesValue( "CATEGORYPLUGIN_HEADER" )  || "[[Categories]]: |";

    # Get plugin debug flag
    $debug = &TWiki::Func::getPreferencesFlag( "CATEGORYPLUGIN_DEBUG" );

    # Plugin correctly initialized
    &TWiki::Func::writeDebug( "- TWiki::Plugins::CategoryPlugin::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}


# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    &TWiki::Func::writeDebug( "- CategoryPlugin::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%
    $_[0] =~ s/%CATEGORY\{(.+)\}%/&CategoryShowLinks($1)/geo;
    $_[0] =~ s/%CATEGORY\{\}%/&CategoryShowLinks($1)/geo;
    $_[0] =~ s/%CATEGORY_TEMPLATE%/&CategoryTemplate/geo;
    $_[0] =~ s/%GLOBAL_CATEGORIES_WEB%/&GlobalCategoriesWeb/geo;
    $_[0] =~ s/%CATEGORY_SEARCH%/&CategorySearch/geo;

#    $_[0] =~ s/%PATENTAPP\{([0-9]+)\}%/&PatentApplicationShowLink($1)/geo;
#    $_[0] =~ s/%BUGLIST\{(.+)\}%/&BugzillaShowMilestoneBugList($1)/geo;
#    $_[0] =~ s/%MYBUGS\{(.+)\}%/&BugzillaShowMyBugList($1)/geo;
}

# =========================
sub DISABLE_startRenderingHandler
{
### my ( $text, $web ) = @_;   # do not uncomment, use $_[0], $_[1] instead

    &TWiki::Func::writeDebug( "- EmptyPlugin::startRenderingHandler( $_[1].$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just before the line loop

    # do custom extension rule, like for example:
    # $_[0] =~ s/old/new/go;
}

# =========================
sub DISABLE_outsidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

#   &TWiki::Func::writeDebug( "- EmptyPlugin::outsidePREHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, in loop outside of <PRE> tag.
    # This is the place to define customized rendering rules.
    # Note: This is an expensive function to comment out.
    # Consider startRenderingHandler instead
}

# =========================
sub DISABLE_insidePREHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

#   &TWiki::Func::writeDebug( "- EmptyPlugin::insidePREHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion, in loop inside of <PRE> tag.
    # This is the place to define customized rendering rules.
    # Note: This is an expensive function to comment out.
    # Consider startRenderingHandler instead
}

# =========================
sub DISABLE_endRenderingHandler
{
### my ( $text ) = @_;   # do not uncomment, use $_[0] instead

    &TWiki::Func::writeDebug( "- EmptyPlugin::endRenderingHandler( $web.$topic )" ) if $debug;

    # This handler is called by getRenderedVersion just after the line loop

}

# =========================


sub CategoryShowLinks {
    &TWiki::Func::writeDebug( "- CategoryPlugin::CategoryShowLinks(ENTERED)" ) if $debug;
    my ($cats) = @_;
    &TWiki::Func::writeDebug( "- CategoryPlugin::CategoryShowLinks( \@cats = $cats)" ) if $debug;

    if (!$cats) { return ""; }

    my (@categories) = split (/[ |,]/, $cats);
    &TWiki::Func::writeDebug( "- CategoryPlugin::CategoryShowLinks( \@categories = @categories)\nprinting:" ) if $debug;

    my ($categoryLinks) = "";

    foreach $cat (@categories) {
        if (!$cat) {
            next;
        }
        &TWiki::Func::writeDebug( "\t\$cat = $cat)\n" ) if $debug;
        $categoryLinks = "$categoryLinks [[$cat]] |";
    }

    $categoryLinks = "$categoryHeader$categoryLinks";

    &TWiki::Func::writeDebug( "- CategoryPlugin::CategoryShowLinks( \$categoryLinks = $categoryLinks)" ) if $debug;

    # return "$categoryImgUrl$categoryLinks\n---";
    return "$categoryLinks\n---";
}

sub CategoryTemplate {
    return $categoryTemplate;
}

sub GlobalCategoriesWeb {
    return $globalCategoriesWeb;
}

sub CategorySearch {
    return "$categorySearch";
}

1;
