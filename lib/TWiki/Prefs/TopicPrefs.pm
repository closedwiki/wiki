# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2004 Peter Thoeny, peter@thoeny.com
#
# For licensing info read license.txt file in the TWiki root.
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

=pod

---++ TopicPrefs Object

This Prefs-internal class is used to cache preferences read in from a single
topic.

=cut

require TWiki;

use strict;
use TWiki::Prefs::Parser;

package TWiki::Prefs::TopicPrefs;

use Assert;

=pod

---+++ sub new( $web, $topic )

Reads preferences from the specified topic into a new TopicPrefs object.

=cut

sub new {
    my( $class, $session, $theWeb, $theTopic ) = @_;
    ASSERT(ref($session) eq "TWiki") if DEBUG;
    my $self = bless( {}, $class );
    $self->{session} = $session;

    $self->{web} = $theWeb;
    $self->{topic} = $theTopic;

    $self->readPrefs();

    return $self;
}

sub store { my $this = shift; return $this->{session}->{store}; }

=pod

---+++ sub Prefs()

Rereads preferences from the topic, updating the TopicPrefs object.

=cut

sub readPrefs {
    my $self = shift;
    ASSERT(ref($self) eq "TWiki::Prefs::TopicPrefs") if DEBUG;

    my $theWeb = $self->{web};
    my $theTopic = $self->{topic};

    $self->{prefs} = {};

    return unless $self->store()->topicExists( $theWeb, $theTopic );

    my( $meta, $text ) =
      $self->store()->readTopic( undef,
                                 $theWeb, $theTopic,
                                 undef );

    my $parser = new TWiki::Prefs::Parser();
    $parser->parseText( $text, $self );
    $parser->parseMeta( $meta, $self );
}

=pod

---+++ sub _insertPrefsValue( $key, $value )

Adds a key-value pair to the TopicPrefs object.
SMELL: this is almost the same as insertPreference, below.

=cut

sub _insertPrefsValue {
    my( $self, $theKey, $theValue ) = @_;

    return if exists $self->{finalHash}{$theKey}; # key is final, may not be overridden

    $theValue =~ s/\t/ /g;                 # replace TAB by space
    $theValue =~ s/([^\\])\\n/$1\n/g;      # replace \n by new line
    $theValue =~ s/([^\\])\\\\n/$1\\n/g;   # replace \\n by \n
    $theValue =~ s/`//g;                   # filter out dangerous chars

    if( $theKey eq "FINALPREFERENCES" && defined( $self->{prefs}{$theKey} )) {

        # key exists, need to deal with existing preference
        # merge final preferences lists
        $theValue = $self->{prefs}{$theKey} . ", $theValue";
    }
    $self->{prefs}{$theKey} = $theValue;
}

1;
