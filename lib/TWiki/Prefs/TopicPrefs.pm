# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
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
# As per the GPL, removal of this notice is prohibited.

=pod

---+ UNPUBLISHED package TWiki::Prefs::TopicPrefs

This Prefs-internal class is used to cache preferences read in from a single
topic.

=cut

require TWiki;

use strict;
use TWiki::Prefs::Parser;

package TWiki::Prefs::TopicPrefs;

use Assert;

=pod

---++ ClassMethod new( $web, $topic )

Reads preferences from the specified topic into a new TopicPrefs object.

=cut

sub new {
    my( $class, $session, $theWeb, $theTopic ) = @_;
    ASSERT(ref($session) eq "TWiki") if DEBUG;
    my $self = bless( {}, $class );
    $self->{session} = $session;

    $self->{web} = $theWeb;
    $self->{topic} = $theTopic;

    $self->{prefs} = {};

    if( $session->{store}->topicExists( $theWeb, $theTopic )) {
        my( $meta, $text ) =
          $session->{store}->readTopic( undef,
                                         $theWeb, $theTopic,
                                         undef );
        my $parser = new TWiki::Prefs::Parser();
        $parser->parseText( $text, $self );
        $parser->parseMeta( $meta, $self );
    }

    return $self;
}

# Adds a key-value pair to the TopicPrefs object. Callback defined for
# the Prefs::Parser object.
sub insertPrefsValue {
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
