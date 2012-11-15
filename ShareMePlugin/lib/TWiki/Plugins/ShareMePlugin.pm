# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2010-2012 Peter Thoeny, peter[at]thoeny.org
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

=pod

---+ package ShareMePlugin

=cut

package TWiki::Plugins::ShareMePlugin;

# Always use strict to enforce variable scoping
use strict;

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version

our $VERSION = '$Rev$';
our $RELEASE = '2012-11-15';
our $SHORTDESCRIPTION = 'Icon bar to share a TWiki page on popular social media sites such as Facebook, StumbleUpon, Twitter';
our $NO_PREFS_IN_TOPIC = 0;

my $installWeb;
my $debug;
my $defaultSites;
my $siteDefs;

# Name of this Plugin, only used in this module
my $pluginName = 'ShareMePlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

=cut

sub initPlugin {
    my( $topic, $web, $user, $instWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }
    $installWeb = $instWeb;

    # Get plugin settings
    $debug = TWiki::Func::getPreferencesFlag( "SHAREMEPLUGIN_DEBUG" );
    $defaultSites = TWiki::Func::getPreferencesValue( "SHAREMEPLUGIN_DEFAULTSITES" );

    undef $siteDefs;

    # register the _EXAMPLETAG function to handle %EXAMPLETAG{...}%
    # This will be called whenever %EXAMPLETAG% or %EXAMPLETAG{...}% is
    # seen in the topic text.
    TWiki::Func::registerTagHandler( 'SHAREME', \&_SHAREME );

    # Plugin correctly initialized
    return 1;
}

=pod

---++ _SHAREME()

This handles the %SHAREME{...}% variable

=cut

sub _SHAREME {
    my( $session, $params, $theTopic, $theWeb ) = @_;

    _initSitesDef() unless $siteDefs;
    $theWeb   = $session->{SESSION_TAGS}{BASEWEB}   || $theWeb;
    $theTopic = $session->{SESSION_TAGS}{BASETOPIC} || $theTopic;

    my @sites = _strToArr( $params->{_DEFAULT} || $defaultSites );
    my $text = _siteIcons( $theWeb, $theTopic, @sites );

    return $text;
}

=pod

---++ _initSitesDef()

Initialize the site definitions from the plugin table

=cut

sub _initSitesDef {
    my $siteDefTopic = TWiki::Func::getPreferencesValue( "SHAREMEPLUGIN_SITEDEFINITIONS" );
    my( $defWeb, $defTopic ) = TWiki::Func::normalizeWebTopicName( $installWeb, $siteDefTopic );
    foreach( split( /\n/, TWiki::Func::readTopicText( $defWeb, $defTopic, undef, 1 ) ) ) {
        # example: | Technorati | %ATTACHURL%/technorati.png | http://technorati.com/faves?add=$link |
        if( /\| *(.*?) *\| *[^\/]*\/([^ \|]*) \| *(.*?) \|/ ) {
            $siteDefs->{$1} = {
                img => "$defWeb/$defTopic/$2",
                url => $3,
            };
        }
    }
    # add a dummy entry to avoid a re-init at each variable expansion in case of error
    $siteDefs->{_dummy} = { img => '', url => '' } unless $siteDefs;
    # Add style sheet to HTML head:
    my $text = "<style type=\"text/css\" media=\"all\">\n"
             . ".shareme-hover { width: 16px; height: 16px; opacity: .4; -moz-opacity: .4; filter: alpha(opacity=40); }\n"
             . ".shareme-hover:hover { opacity: 1; -moz-opacity: 1; filter: alpha(opacity=100); }\n"
             . "</style>";
    TWiki::Func::addToHEAD( "\U$pluginName\E_CSS", $text );
}

=pod

---++ _siteIcons()

Return HTML text with site icons

=cut

sub _siteIcons {
    my( $theWeb, $theTopic, @sites ) = @_;

    # no newlines so that icons can be placed in a TWiki table
    my $text = '<span class="shareme">';
    my $pubUrl = TWiki::Func::getPubUrlPath();
    my $link = "\%ENCODE{\%SCRIPTURL{view}\%/$theWeb/$theTopic}\%";
    my $title = "\%ENCODE{\%SPACEOUT{$theTopic}\%}\%";
    my $summary = "\%ENCODE{\%SPACEOUT{$theTopic}\% in $theWeb web on \%HTTP_HOST\%}%";
    foreach my $site ( @sites ) {
        next unless $siteDefs->{$site};
        my $url = $siteDefs->{$site}{url};
        $url =~ s/\$link/$link/g;
        $url =~ s/\$title/$title/g;
        $url =~ s/\$summary/$summary/g;
        $url =~ s/\$site/\%HTTP_HOST\%/g;
        $text .= "<a href='$url' target='_shareme' rel='nofollow' style='border-style: none;'>"
              . "<img src='$pubUrl/$siteDefs->{$site}{img}' alt='$site'"
              . " title='$site' class='shareme-hover'"
              . " style='background: transparent url($pubUrl/$siteDefs->{$site}{img});' />"
              . "</a> ";
    }
    $text .= "</span>";
    return $text;
}

=pod

---++ _strToArray()

Convert a comma-sapce delimited list to an array.

=cut

sub _strToArr {
    my( $str ) = @_;
    my @arr = map { s/^ *(.*?) */$1/; $_ } split( /, */, $str );
    return @arr;
}

1;
