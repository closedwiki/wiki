# TWiki RedirectPlugin
#
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
    #return 0 unless TWiki::Func::getContext()->{view};
    my $query = TWiki::Func::getCgiQuery();

    # this doesn't really have any meaning if we aren't being called as a CGI
    return 0 unless $query;

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("REDIRECTPLUGIN_DEBUG");

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::RedirectPlugin::initPlugin( $web.$topic ) is OK") if $debug;

    TWiki::Func::registerTagHandler('REDIRECTTO', \&_REDIRECT);
    return 1;
}



# =========================
sub _REDIRECT {
    my ($session, $params, $topic, $web) = @_;

    TWiki::Func::writeDebug("- RedirectPlugin::_REDIRECT( $web.$topic)") if $debug;

    my $query = TWiki::Func::getCgiQuery();
    my $context = TWiki::Func::getContext();
    my $newTopic = $params->{'newtopic'} || $params->{_DEFAULT};

    #
    # Redirect only on view. Do we want to redirect otherwise?
    #
    if ($context->{'view'} && $newTopic) {
        my $webNameRegex = TWiki::Func::getRegularExpression('webNameRegex');
        if (($newTopic =~ /($webNameRegex)\.([A-Za-z0-9-]+)/) && TWiki::Func::topicExists($1, $2)) {
           TWiki::Func::redirectCgiQuery($query, TWiki::Func::getViewUrl($1, $2));
        }
        if (($newTopic =~ /([A-Za-z0-9-]+)/) && TWiki::Func::topicExists($web, $1)) {
            TWiki::Func::redirectCgiQuery($query, TWiki::Func::getViewUrl($web, $1));
        }
        return "%RED%Topic '$newTopic' not found%ENDCOLOR%";
    }
    return "";
}


1;
