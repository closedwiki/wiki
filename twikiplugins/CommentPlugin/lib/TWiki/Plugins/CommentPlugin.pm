# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Crawford Currie
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
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
#
# See Plugin topic for history and plugin information

package TWiki::Plugins::CommentPlugin;

use strict;

use TWiki::Func;

use vars qw( $VERSION $RELEASE );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

sub initPlugin {
    #my ( $topic, $web, $user, $installWeb ) = @_;

    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between CommentPlugin $VERSION and Plugins.pm $TWiki::Plugins::VERSION. Plugins.pm >= 1.026 required." );
    }

    TWiki::Func::registerTagHandler( "TIME", \&_TIME );

    return 1;
}

sub commonTagsHandler {
    my ( $text, $topic, $web ) = @_;

    require TWiki::Plugins::CommentPlugin::Comment;
    if ($@) {
        TWiki::Func::writeWarning( $@ );
        return 0;
    }

    my $query = TWiki::Func::getCgiQuery();
    return unless( defined( $query ));

    return unless $_[0] =~ m/%COMMENT({.*?})?%/o;

    # SMELL: Nasty, tacky way to find out where we were invoked from
    my $scriptname = $ENV{'SCRIPT_NAME'} || '';
    # SMELL: unreliable
    my $previewing = ($scriptname =~ /\/(preview|gnusave|rdiff)/);
    TWiki::Plugins::CommentPlugin::Comment::prompt( $previewing,
                                                    $_[0], $web, $topic );
}

=pod

---++ beforeSaveHandler($text, $topic, $web )
   * =$text= - text _with embedded meta-data tags_
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is called just before the save action. The text is populated
with 'meta-data tags' before this method is called. If you modify any of
these tags, or their contents, you may break meta-data. You have been warned!

=cut

sub beforeSaveHandler {
    #my ( $text, $topic, $web ) = @_;

    require TWiki::Plugins::CommentPlugin::Comment;
    if ($@) {
        TWiki::Func::writeWarning( $@ );
        return 0;
    }
    my $query = TWiki::Func::getCgiQuery();
    return unless $query;

    my $action = $query->param('comment_action');

    return unless( defined( $action ) && $action eq 'save' );
    TWiki::Plugins::CommentPlugin::Comment::save( @_ );
}

sub _TIME {
    return TWiki::Time::formatTime( time(), '$hour:$min' );
}

1;
