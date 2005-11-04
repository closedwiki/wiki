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
use strict;
use TWiki::Contrib::DBCacheContrib;

package TWiki::Plugins::BlogPlugin::WebDB;
@TWiki::Plugins::BlogPlugin::WebDB::ISA = ("TWiki::Contrib::DBCacheContrib");

###############################################################################
sub new {
  my ( $class, $web ) = @_;
  my $this = bless( $class->SUPER::new($web, "_DBQueryWebDB"), $class );
  return $this;
}

###############################################################################
# called by superclass when one or more topics had
# to be reloaded from disc.
sub onReload {
  my ($this, $topics) = @_;

  foreach my $topicName (@$topics) {
    my $topic = $this->fastget($topicName);

    # createdate
    next if $topic->fastget('createdate');
    my ($createDate, $createUser) = &TWiki::Func::getRevisionInfo($this->{_web}, $topicName, 1);
    $topic->set('createdate', $createDate);
    $topic->set('createuser', $createUser);
  }
}
