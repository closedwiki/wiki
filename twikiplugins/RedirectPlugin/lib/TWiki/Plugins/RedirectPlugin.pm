# TWiki RedirectPlugin
#
# Copyright (C) 2006 Meredith Lesly, msnomer@spamcop.net
# Copyright (C) 2003 Steve Mokris, smokris@softpixel.com
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

# =========================
package TWiki::Plugins::RedirectPlugin;

# =========================
use vars qw( $VERSION $RELEASE $debug);

$VERSION = '$Rev$';
$RELEASE = 'Dakar';

# =========================
sub initPlugin {
    #my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ($TWiki::Plugins::VERSION < 1.1) {
        TWiki::Func::writeWarning("Version mismatch between RedirectPlugin and Plugins.pm");
        return 0;
    }

    my $query = TWiki::Func::getCgiQuery();

    # this doesn't really have any meaning if we aren't being called as a CGI
    return 0 unless $query;

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("REDIRECTPLUGIN_DEBUG");

    TWiki::Func::registerTagHandler('REDIRECT', \&REDIRECT);
    return 1;
}



# =========================
sub REDIRECT {
    my ($session, $params, $topic, $web) = @_;

    my $context = TWiki::Func::getContext();
    my $newWeb = $web;
    my $newTopic;
    my $anchor = '';
    my $dest = $params->{'newtopic'} || $params->{_DEFAULT};

    #
    # Redirect only on view.
    #
    if ($context->{'view'} && $dest) {
        my $query = TWiki::Func::getCgiQuery();
        $dest = TWiki::Func::expandCommonVariables($dest);

        my $webNameRegex = TWiki::Func::getRegularExpression('webNameRegex');
        my $wikiWordRegex = TWiki::Func::getRegularExpression('wikiWordRegex');
        my $anchorRegex = TWiki::Func::getRegularExpression('anchorRegex');

        if ($dest =~ s/^($webNameRegex)\.// ) {
            $newWeb = $1;
        }

        if ($dest =~ s/^($wikiWordRegex)//) {
            $newTopic = $1;
        } elsif ($dest =~ s/^\.([a-zA-Z0-9]+)//) {
            $newTopic = $1;
        }
        if ($dest =~ /^($anchorRegex)$/) {
            $anchor = $1;
        }

        if ($newWeb eq $web && $newtopic eq $topic) {
            return "%RED%Can't redirect to same topic%ENDCOLOR%";
        } else {
            TWiki::Func::redirectCgiQuery($query, TWiki::Func::getViewUrl($newWeb, $newTopic) . $anchor);
        }
        return "%RED%Destination $dest not found";
    }
    return "";
}

1;
