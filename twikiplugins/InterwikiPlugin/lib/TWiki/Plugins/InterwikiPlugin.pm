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

---+ package TWiki::Plugins::InterwikiPlugin

Recognises and processes special links to other sites defined
using "inter-site syntax".

The recognized syntax is:
<pre>
       InterSiteName:TopicName
</pre>

Sites must start with upper case and must be preceded by white
space, '-', '*' or '(', or be part of the link expression
in a [[link]] or [[link][text]] expression.

=cut

package TWiki::Plugins::InterwikiPlugin;

use strict;

use vars qw(
            $VERSION
            $interWeb
            $suppressTooltip
            $sitePattern
            $pagePattern
            %interSiteTable
    );

$VERSION = '$Rev$';

BEGIN {
    # 'Use locale' for internationalisation of Perl sorting and searching - 
    if( $TWiki::cfg{UseLocale} ) {
        require locale;
        import locale ();
    }
}

# Read preferences and get all InterWiki Site->URL mappings
sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    $interWeb = $installWeb;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between InterwikiPlugin and Plugins.pm" );
        return 0;
    }

    # Regexes for the Site:page format InterWiki reference
    my $man = TWiki::Func::getRegularExpression('mixedAlphaNum');
    my $ua = TWiki::Func::getRegularExpression('upperAlpha');
    $sitePattern    = "([$ua][$man]+)";
    $pagePattern    = "([${man}_\/][$man" . '\.\/\+\_\,\;\:\!\?\%\#-]+?)';

    # Get plugin preferences from InterwikiPlugin topic
    $suppressTooltip =
      TWiki::Func::getPreferencesFlag( 'INTERWIKIPLUGIN_SUPPRESSTOOLTIP' );

    my $interTopic =
      TWiki::Func::getPreferencesValue( 'INTERWIKIPLUGIN_RULESTOPIC' )
          || 'InterWikis';
    ( $interWeb, $interTopic ) =
      TWiki::Func::normalizeWebTopicName( $interWeb, $interTopic );
    if( $interTopic =~ s/^(.*)\.// ) {
        $interWeb = $1;
    }

    my $text = TWiki::Func::readTopicText( $interWeb, $interTopic, undef, 1 );

    # '| alias | URL | ...' table and extract into 'alias', "URL" list
    $text =~ s/^\|\s*$sitePattern\s*\|\s*(.*?)\s*\|\s*(.*?)\s*\|.*$/_map($1,$2,$3)/mego;

    $sitePattern = "(" . join( "|", keys %interSiteTable ) . ")";
    return 1;
}

sub _map {
    my( $site, $url, $help ) = @_;
    if( $site ) {
        $interSiteTable{$site}{url} = $url || '';
        $interSiteTable{$site}{help} = $help || '';
    }
    return '';
}

sub preRenderingHandler {
    # ref in [[ref]] or [[ref][
    $_[0] =~ s/(\[\[)$sitePattern:$pagePattern(\]\]|\]\[| )/_link($1,$2,$3,$4)/geo;
    # ref in text
    $_[0] =~ s/(^|[\s\-\*\(])$sitePattern:$pagePattern(?=[\s\.\,\;\:\!\?\)]*(\s|$))/_link($1,$2,$3)/geo;
}

sub _link {
    my( $prefix, $site, $page, $postfix ) = @_;

    $prefix ||= '';
    $site ||= '';
    $page ||= '';
    $postfix ||= '';

    my $text;
    if( defined( $interSiteTable{$site} ) ) {
        my $url = $interSiteTable{$site}{url};
        my $help = $interSiteTable{$site}{help};
        my $title = '';

        unless( $suppressTooltip ) {
            $help =~ s/<nop>/&nbsp;/goi;
            $help =~ s/[\"\<\>]*//goi;
            $help =~ s/\$page/$page/go;
            $title = " title=\"$help\"";
        }

        if( $url =~ s/\$page/$page/go ) {
            $text = $url;
        } else {
            $text = $url.$page;
        }
        if( $postfix ) {
            $text = "$prefix$text][";
            $text .= "$site\:$page]]" if( $postfix eq "]]" );
        } else {
            $text = "$prefix<a href=\"$text\"$title>$site\:$page</a>";
        }
    } else {
        $text = "$prefix$site\:$page$postfix";
    }
    return $text;
}

1;
