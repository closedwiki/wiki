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

my $settingPrefPrefix = 'SETTING_';

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
    my( $this, $text, $prefs ) = @_;

    my $key = '';
    my $value ='';
    my $isKey = 0;
    foreach my $line ( split( /\r?\n/, $text ) ) {
        if( $line =~ m/$TWiki::regex{setVarRegex}/o ) {
            if( $isKey ) {
                $prefs->insertPrefsValue( $key, $value );
            }
            $key = $1;
            $value = (defined $2) ? $2 : '';
            $isKey = 1;
        } elsif( $isKey ) {
            if( $line =~ /^\s+/ && $line !~ m/$TWiki::regex{bulletRegex}/o ) {
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

Traverses through all SETTING attributes of the meta object, creating one 
setting named with $settingPrefPrefix . 'title' for each.  It also 
creates an entry named with the field 'name', which is a cleaned-up, 
space-removed version of the title.

Settings are added to the $prefs passed.

=cut

sub parseMeta {
    my( $this, $meta, $prefs ) = @_;

        my @fields = $meta->find( 'SETTING' );
        foreach my $field( @fields ) {
            my $title = $field->{title};
            my $prefixedTitle = $settingPrefPrefix . $title;
            my $value = $field->{value};
            $prefs->insertPrefsValue( $prefixedTitle, $value );
	    #SMELL: Why do we insert both based on title and name?
	    my $name = $field->{name};
	    $prefs->insertPrefsValue( $name, $value );
        }
}

1;
