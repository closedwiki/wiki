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
# =========================
#
# This plugin is designed to help plugins authors understand the sequence
# of calls to their different plugin functions.
# The queue is flushed by a call to TWiki::Plugins::WtfPlugin::wtfReport().
# This returns a string containing the content of the queue at that point.
# This call can be hacked into the top level scripts to insert a report
# into the output, or write it to a stream.

package TWiki::Plugins::WtfPlugin;

use vars qw(
        $VERSION $pluginName $active @queue
    );

$VERSION = '1.000';
$pluginName = 'WtfPlugin';

sub initPlugin {
  my ( $topic, $web, $user, $installWeb ) = @_;

  # Get plugin debug flag
  $active = 1;#TWiki::Func::getPluginPreferencesFlag( "ACTIVE" );

  $#queue = -1;

  push(@queue, "initPlugin $web/$topic $user $installWeb") if $active;

  return 1;
}

sub earlyInitPlugin {
  push(@queue, "earlyInitPlugin");
}

sub initializeUserHandler {
  ### my ( $loginName, $url, $pathInfo ) = @_;

  push(@queue, "initializeUserHandler $_[0] $_[1] $_[2]") if $active;
}

sub registrationHandler {
  ### my ( $web, $wikiName, $loginName ) = @_;

  push(@queue, "registrationHandler $_[0] $_[1] $_[2]") if $active;
}

sub commonTagsHandler {
  ### my ( $text, $topic, $web ) = @_;
  push(@queue, "commonTagsHandler $_[2]/$_[1] ".substr($_[0], 0, 30) . "...") if $active;
}

sub startRenderingHandler {
  ### my ( $text, $web ) = @_;
  push(@queue, "startRenderingHandler $_[1] ".substr($_[0], 0, 30) . "...") if $active;
}

sub outsidePREHandler {
  ### my ( $text ) = @_;

  push(@queue, "outsidePREHandler ".substr($_[0], 0, 30) . "...") if $active;
}

sub insidePREHandler {
  ### my ( $text ) = @_;

  push(@queue, "insidePREHandler ".substr($_[0], 0, 30) . "...") if $active;
}

sub endRenderingHandler {
  ### my ( $text ) = @_;

  push(@queue, "endRenderingHandler ".substr($_[0], 0, 30) . "...") if $active;
}

sub beforeEditHandler {
  ### my ( $text, $topic, $web ) = @_;

  push(@queue, "beforeEditHandler $_[2]/$_[1] ".substr($_[0], 0, 30) . "...") if $active;
}

sub afterEditHandler {
  ### my ( $text, $topic, $web ) = @_;

  push(@queue, "afterEditHandler $_[2]/$_[1] ".substr($_[0], 0, 30) . "...") if $active;
}

sub beforeSaveHandler {
  ### my ( $text, $topic, $web ) = @_;

  push(@queue, "beforeSaveHandler $_[2]/$_[1] ".substr($_[0], 0, 30) . "...") if $active;
}

sub afterSaveHandler {
  ### my ( $text, $topic, $web, $error ) = @_;

  push(@queue, "afterSaveHandler $_[2]/$_[1] ".substr($_[0], 0, 30) . "...") if $active;
}

sub redirectCgiQueryHandler {
  ### my ( $query, $url ) = @_;

  push(@queue, "redirectCgiQueryHandler $_[1]") if $active;
  # this overrides the method in plugins
  print $_[0]->redirect( $_[1] );
  return 0;
}

#sub getSessionValueHandler {
#  ### my ( $key ) = @_;
#
#  push(@queue, "getSessionValueHandler $_[0]") if $active;
#}

#sub setSessionValueHandler {
#  ### my ( $key, $value ) = @_;
#
#  push(@queue, "setSessionValueHandler $_[0] $_[1]") if $active;
#}

sub writeHeaderHandler {
  ### my ( $query ) = @_;

  push(@queue, "writeHeaderHandler") if $active;

  return "";
}

sub wtfReport {
  my $report = join("\n", @queue);
  $report =~ s/&/&amp;/go;
  $report =~ s/</&lt;/go;
  $report =~ s/\"/&quot;/go;
  $report =~ s/\n/<br \/>/go;
  $#queue = -1;
  return $report;
}

1;
