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

---+ UNPUBLISHED package TWiki::Prefs::Parser

This Prefs-internal class is used to parse * Set statements from arbitrary
text, and extract settings from meta objects.  It is used by TopicPrefs to
parse preference settings from topics.

This class does no validation or duplicate-checking on the settings; it
simply returns the recognized settings in the order it sees them in.

=cut

package TWiki::Prefs::Parser;

use Assert;

my $formPrefPrefix = "FORM_";

=pod

---++ ClassMethod new() -> topic parser object

Construct a new parser object.

=cut

sub new {
    return bless {}, $_[0];
}


=pod

---++ ObjectMethod parseText( $text, $prefs )

Parse settings from text and add them to the preferences in $prefs

=cut

sub parseText {
    my( $self, $text, $prefs ) = @_;

    my $key = "";
    my $value ="";
    my $isKey = 0;
    foreach my $line ( split( /\r?\n/, $text ) ) {
        if( $line =~ /^(\t|   )+\*\sSet\s(\w+)\s\=\s*(.*)$/ ) {
            if( $isKey ) {
                $prefs->insertPrefsValue( $key, $value );
            }
            $key = $2;
            $value = (defined $3) ? $3 : "";
            $isKey = 1;
        } elsif( $isKey ) {
            if( $line =~ /^\s+/ && $line !~ /^(\t|   )+\*/ ) {
                # follow up line, extending value
                $value .= "\n$line";
            } else {
                $prefs->insertPrefsValue( $key, $value );
                $isKey = 0;
            }
        }
    }
    if( $isKey ) {
        $prefs->insertPrefsValue( $key, $value );
    }
}

=pod

---++ ObjectMethod parseMeta( $metaObject, $prefs )

Traverses through all FIELD attributes of the meta object, creating one setting
named with $formPrefPrefix . $fieldTitle for each.  If the
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
            my $prefixedTitle = $formPrefPrefix . $title;
            my $value = $field->{"value"};
            $prefs->insertPrefsValue( $prefixedTitle, $value );
            my $attributes = $field->{"attributes"};
            if( $attributes && $attributes =~ /[S]/o ) {
                my $name = $field->{"name"};
                $prefs->insertPrefsValue( $name, $value );
            }
        }
    }
}

1;
