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
use strict;

=pod

---++ TopicPrefs Object

This Prefs-internal class is used to cache preferences read in from a single
topic.

=cut

package TWiki::Prefs::TopicPrefs;

use TWiki::Prefs::Parser;

=pod

---+++ sub new( $web, $topic )

Reads preferences from the specified topic into a new TopicPrefs object.

=cut

sub new {
    my( $class, $theWeb, $theTopic ) = @_;
    my $self = {};
    bless $self, $class;

    $self->{web} = $theWeb;
    $self->{topic} = $theTopic;

    $self->readPrefs();

    return $self;
}

=pod

---+++ sub readPrefs()

Rereads preferences from the topic, updating the TopicPrefs object.

=cut

sub readPrefs {
    my $self = shift;

    my $theWeb = $self->{web};
    my $theTopic = $self->{topic};

    $self->{prefs} = {};

    return unless TWiki::Store::topicExists( $theWeb, $theTopic );

    my( $meta, $text ) =
      TWiki::Store::readTopic( $theWeb, $theTopic, undef, 1 );

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
