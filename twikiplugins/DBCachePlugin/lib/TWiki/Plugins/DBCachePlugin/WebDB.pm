# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 Michael Daum <micha@nats.informatik.uni-hamburg.de>
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
###############################################################################

package TWiki::Plugins::DBCachePlugin::WebDB;

use strict;
use TWiki::Contrib::DBCacheContrib;

@TWiki::Plugins::DBCachePlugin::WebDB::ISA = ("TWiki::Contrib::DBCacheContrib");

###############################################################################
sub new {
  my ( $class, $web, $cacheName ) = @_;
  $cacheName = '_DBCachePluginDB' unless $cacheName;
  my $this = bless($class->SUPER::new($web, $cacheName), $class);
  return $this;
}

###############################################################################
# called by superclass when one or more topics had
# to be reloaded from disc.
sub onReload {
  my ($this, $topics) = @_;

  #print STDERR "DEBUG: DBCachePlugin::WebDB - called onReload(@_)\n";

  foreach my $topicName (@$topics) {
    my $topic = $this->fastget($topicName);

    #print STDERR "DEBUG: reloading $topicName\n";

    # stored procedures
    my $text = $topic->fastget('text');

    # get default section
    my $defaultSection = $text;
    $defaultSection =~ s/.*?%STARTINCLUDE%//s;
    $defaultSection =~ s/%STOPINCLUDE%.*//s;
    applyGlue($defaultSection);
    $topic->set('_sectiondefault', $defaultSection);

    # get named sections
    while($text =~ s/%SECTION{[^}]*?"(.*?)"}%(.*?)%ENDSECTION{[^}]*?"(.*?)"}%//s) {
      my $name = $1;
      my $sectionText = $2;
      applyGlue($sectionText);
      $topic->set("_section$name", $sectionText);
    }
  }

  #print STDERR "DEBUG: DBCachePlugin::WebDB - done onReload()\n";
}

###############################################################################
# local copy from GluePlugin
sub applyGlue {

  $_[0] =~ s/%~~\s+([A-Z]+{)/%$1/gos;  # %~~
  $_[0] =~ s/\s*[\n\r]+~~~\s+/ /gos;   # ~~~
  $_[0] =~ s/\s*[\n\r]+\*~~\s+//gos;   # *~~
}

1;
