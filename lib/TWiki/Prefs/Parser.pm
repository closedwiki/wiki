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

---++ Prefs::Parser Object

This Prefs-internal class is used to parse * Set statements from arbitrary
text, and extract settings from meta objects.  It is used by TopicPrefs to
parse preference settings from topics.

This class does no validation or duplicate-checking on the settings; it
simply returns the recognized settings in the order it sees them in.

=cut

package TWiki::Prefs::Parser;

=pod

---+++ sub new()

Returns a new TopicParser object.

=cut

sub new {
    return bless {}, $_[0];
}


=pod

---+++ sub parseText( $text, $prefs )

Parse settings from text and add them to the preferences in $prefs

=cut

sub parseText {
    my( $self, $text, $prefs ) = @_;

    #$text =~ s/\r/\n/g;
    #$text =~ s/\n+/\n/g;

    my $key = "";
    my $value ="";
    my $isKey = 0;
    foreach( split( /\r?\n/, $text ) ) {
        if( /^\t+\*\sSet\s(\w+)\s\=\s*(.*)/ ) {
            if( $isKey ) {
                $prefs->_insertPrefsValue( $key, $value );
            }
            $key = $1;
            $value = defined $2 ? $2 : "";
            $isKey = 1;
        } elsif( $isKey ) {
            if(( /^\t+/ ) &&( ! /^\t+\*/ ) ) {
                # follow up line, extending value
                $value .= "\n$_";
            } else {
                $prefs->_insertPrefsValue( $key, $value );
                $isKey = 0;
            }
        }
    }
    if( $isKey ) {
        $prefs->_insertPrefsValue( $key, $value );
    }
}

=pod

---+++ sub parseMeta( $metaObject, $prefs )

Traverses through all FIELD attributes of the meta object, creating one setting
named with $TWiki::Prefs::formPrefPrefix . $fieldTitle for each.  If the
field's attribute list includes a 'S', it also creates an entry named with the
field "name", which is a cleaned-up, space-removed version of the title.

Settings are added to the $prefs passed.

=cut

sub parseMeta {
    my( $self, $meta, $prefs ) = @_;

    my %form = $meta->findOne( "FORM" );
    if( %form ) {
        my @fields = $meta->find( "FIELD" );
        foreach my $field( @fields ) {
            my $title = $field->{"title"};
            my $prefixedTitle = $TWiki::Prefs::formPrefPrefix . $title;
            my $value = $field->{"value"};
            $prefs->_insertPrefsValue( $prefixedTitle, $value );
            my $attributes = $field->{"attributes"};
            if( $attributes && $attributes =~ /[S]/o ) {
                my $name = $field->{"name"};
                $prefs->_insertPrefsValue( $name, $value );
            }
        }
    }
}

1;
