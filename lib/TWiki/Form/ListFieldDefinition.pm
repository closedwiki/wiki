# See bottom of file for license and copyright details
# Form field definitions that accept lists of values in the field definition.
# This is different to being multi-valued, which means the field type
# can *store* multiple values.
package TWiki::Form::ListFieldDefinition;
use base 'TWiki::Form::FieldDefinition';

use strict;
use Assert;

# PRIVATE

# PROTECTED - parse the {value} and extract a list of options.
# Done lazily.
sub expandOptions {
    # $web and $topic are where the form definition lives
    my $this = shift;

    return if $this->{options};

    ASSERT($this->{web}) if DEBUG;
    ASSERT($this->{topic}) if DEBUG;

    my @vals = ();

    @vals = split( /,/, $this->{value} );
    if( !scalar( @vals )) {
        my $topic = $this->{definingTopic} || $this->{name};
        my $session = $this->{session};
        my( $fieldWeb, $fieldTopic ) =
          $session->normalizeWebTopicName( $this->{web}, $topic );
        my $store = $session->{store};
        if ( $store->topicExists( $fieldWeb, $fieldTopic ) ) {
            my( $meta, $text ) =
              $store->readTopic( $session->{user},
                                 $fieldWeb, $fieldTopic, undef );
            # Process SEARCHES for Lists
            $text = $this->{session}->handleCommonTags(
                $text, $this->{web}, $topic, $meta);
            # SMELL: yet another table parser
            my $inBlock = 0;
            foreach( split( /\r?\n/, $text ) ) {
                if( /^\s*\|\s*\*Name\*\s*\|/ ) {
                    $inBlock = 1;
                } elsif( /^\s*\|\s*([^|]*?)\s*\|/ ) {
                    push( @vals, $1 ) if( $inBlock );
                } else {
                    $inBlock = 0;
                }
            }
        }
    }
    @vals = map { $_ =~ s/^\s*(.*)\s*$/$1/; $_; } @vals;

    $this->{options} = \@vals;
}

1;
__DATA__

Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/

Copyright (C) 2001-2007 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root of
this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

