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

=begin twiki

---+ TWiki::Prefs Module

This module reads TWiki preferences of site-level, web-level and user-level
topics and implements routines to access those preferences.

SMELL: This implementation does far to much copying around of prefs
values. Inheritance should be handled by stacking the prefs object,
which will slow down accessing prefs values but that is a relatively
small part of the rendering process.

=cut

package TWiki::Prefs;

use TWiki::Prefs::PrefsCache;

use vars qw(
            $globalPrefs %webPrefs $requestPrefs $requestWeb
            $formPrefPrefix
          );

$formPrefPrefix = "FORM_";

=pod

---++ TWiki::Prefs package

This is the external interface to the Prefs module, and is how the rest of the
TWiki code accesses preferences.

---+++ sub initializePrefs( $webName )

Resets all preference globals (for mod_perl compatibility), and reads
preferences from TWiki::TWikiPreferences, Main::TWikiPreferences, and
$webName::WebPreferences.

=cut

sub initializePrefs {
    my( $theWebName ) = @_;

    TWiki::Prefs::PrefsCache::clearCache(); # for mod_perl compatibility

    $requestWeb = $theWebName;
    $globalPrefs = TWiki::Prefs::PrefsCache->new("global");
    $webPrefs{$requestWeb} =
      new TWiki::Prefs::PrefsCache("web", $globalPrefs, $requestWeb);
    $requestPrefs =
      new TWiki::Prefs::PrefsCache("copy", $webPrefs{$requestWeb});

    return;
}

# =========================

=pod

---+++ sub initializeUserPrefs( $userPrefsTopic )

Called after user is known (potentially by Plugin), this function reads
preferences from the user's personal topic.  The parameter is the topic to read
user-level preferences from (Generally "Main.CurrentUserName").

=cut

sub initializeUserPrefs {
    my( $theWikiUserName ) = @_;

    $theWikiUserName = "Main.TWikiGuest" unless $theWikiUserName;

    if( $theWikiUserName =~ /^(.*)\.(.*)$/ ) {
        $requestPrefs = TWiki::Prefs::PrefsCache->new("request", $webPrefs{$requestWeb}, $TWiki::topicName, $2);
    }

    return;
}


# =========================

=pod

---+++ sub getPrefsFromTopic( $web, $topic, $keyPrefix )

Reads preferences from the topic at =$theWeb.$theTopic=, prefixes them with
=$theKeyPrefix= if one is provided, and adds them to the preference cache.

=cut

sub getPrefsFromTopic {
    my( $web, $topic, $keyPrefix ) = @_;
    $requestPrefs->loadPrefsFromTopic( $web, $topic, $keyPrefix, 1 );
}

# =========================

=pod

---+++ sub updateSetFromForm( $meta, $text )
Return value: $newText

If there are any settings "Set SETTING = value" in =$text= for a setting
that is set in form metadata in =$meta=, these are changed so that the
value in the =$text= setting is the same as the one set in the =$meta= form.
=$text= is not modified; rather, a new copy with these changes is returned.

=cut

sub updateSetFromForm {
    my( $meta, $text ) = @_;
    my( $key, $value );

    my %form = $meta->findOne( "FORM" );
    if( %form ) {
        my @fields = $meta->find( "FIELD" );
        foreach my $field ( @fields ) {
            $key = $field->{"name"};
            $value = $field->{"value"};
            my $attributes = $field->{"attributes"};
            if( $attributes && $attributes =~ /[S]/o ) {
                $value =~ s/\n/\\\n/o;
                # SMELL: Worry about verbatim?  Multi-lines?
                $text =~ s/^(\t+\*\sSet\s$key\s\=\s*).*$/$1$value/gm;
            }
        }
    }

    return $text;
}

# =========================

=pod

---+++ sub expandPreferencesTags( \$text )

Replaces %PREF% and %<nop>VAR{"pref"}% syntax in $text

=cut

sub expandPreferencesTags {
    $requestPrefs->replacePreferencesTags( @_ );
}

sub loadHash {
    $requestPrefs->loadHash( @_ );
}

=pod

---+++ sub getWebVariable( $attributeString )

Returns the value for a %<nop>VAR{"foo" web="bar"}% syntax, given the stuff inside the {}'s.

=cut

sub getWebVariable {
    my( $attributeString ) = @_;

    my $key = &TWiki::extractNameValuePair( $attributeString );
    my $attrWeb = TWiki::extractNameValuePair( $attributeString, "web" );
    if( $attrWeb =~ /%[A-Z]+%/ ) { # handle %MAINWEB%-type cases 
        TWiki::handleInternalTags( $attrWeb, $requestWeb, "dummy" );
    }

    my $val = getPreferencesValue( $key, $attrWeb) || "";

    return $val;
}

=pod

---+++ sub formatAsFlag( $prefValue )

Returns 1 if the =$prefValue= is "on", and 0 otherwise.  "On" means set to
something with a true Perl-truth-value, with the special cases that "off" and
"no" are forced to false.  (Both of the latter are case-insensitive.)  Note
also that leading and trailing whitespace on =$prefValue= will be stripped
prior to this conversion.

=cut

sub formatAsFlag {
    my( $value ) = @_;

    return 0 unless ( defined( $value ));
    return 1 if ( $value =~ m/^\s*(on|1|true|yes)\s*$/i );
    return 0 if ( $value =~ m/^\s*(off|0|false|no)\s*$/i );

    $value =~ s/^\s*(.*?)\s*$/$1/i;
    return ( $value ? 1 : 0 );
}

=pod

---+++ sub formatAsNumber( $prefValue )

Converts the string =$prefValue= to a number.  First any whitespace and commas
are removed.  <em>L10N note: assumes thousands separator is comma and decimal
point is period.</em>  Then, if the first character is a zero, the value is
passed to oct(), which will interpret hex (0x prefix), octal (leading zero
only), or binary (0b prefix) numbers.  If the first character is a digit
greater than zero, the value is assumed to be a decimal number and returned.
If the =$prefValue= is empty or not a number, zero is returned.  Finally, if
=$prefValue= is undefined, an undefined value is returned.  <strong>Undefined
preferences are automatically converted to empty strings, and so this function
will always return zero for these, rather than 'undef'.</strong>

=cut

sub formatAsNumber {
    my( $strValue ) = @_;
    return undef unless defined( $strValue ); 

    $strValue =~ s/[,\s]+//g;    

    if( $strValue =~ /^0/ ) {
        return oct( $strValue ); # hex/octal/binary
    } elsif( $strValue =~ /^(\d|\.\d )/) {
        return $strValue;      # decimal
    } else {
        return 0;              # empty/non-numeric
    }
}

=pod

---+++ sub getPreferencesValue( $theKey, $theWeb )

Returns the value of the preference =$theKey=.  If =$theWeb= is also specified,
looks up the value with respect to that web instead of the current one; also,
in this case user/topic preferences are not considered.

In any case, if a plugin supports sessions and provides a value for =$theKey=,
this value overrides all preference settings in any web.

=cut

sub getPreferencesValue {
    my( $theKey, $theWeb ) = @_;

    my $sessionValue =
      TWiki::Plugins::getSessionValueHandler( $theKey );

    if( defined( $sessionValue ) ) {
        return $sessionValue;
    }
    my $val;
    if( $theWeb ) {
        if (!exists $webPrefs{$theWeb}) {
            $webPrefs{$theWeb} =
              new TWiki::Prefs::PrefsCache("web", $globalPrefs, $theWeb);
        }
        $val = $webPrefs{$theWeb}->{prefs}{$theKey};
    } else {
        if( defined( $requestPrefs )) {
            $val = $requestPrefs->{prefs}{$theKey};
        } elsif (exists( $webPrefs{$requestWeb} )) {
             # user/topic prefs not yet init'd
            $val = $webPrefs{$requestWeb}->{prefs}{$theKey};
        }
    }
    $val = "" unless( defined( $val ));
    return $val;
}

# =========================

=pod

---+++ sub getPreferencesFlag( $theKey, $theWeb )

Returns the preference =$theKey= from =$theWeb= as a flag.  See
=getPreferencesValue= for the semantics of the parameters, and
=[[#sub_formatAsFlag_prefValue][formatAsFlag]]= for the method of interpreting
a value as a flag.

=cut

sub getPreferencesFlag {
    my( $theKey, $theWeb ) = @_;

    my $value = getPreferencesValue( $theKey, $theWeb );
    return formatAsFlag( $value );
}

=pod

---+++ sub getPreferencesNumber( $theKey, $theWeb )

Returns the preference =$theKey= from =$theWeb= as a flag.  See
=getPreferencesValue= for the semantics of the parameters, and
=[[#sub_formatAsNumber_prefValue][formatAsNumber]]= for the method of
interpreting a value as a number.

=cut

sub getPreferencesNumber {
    my( $theKey, $theWeb ) = @_;

    my $value = getPreferencesValue( $theKey, $theWeb );
    return formatAsNumber( $value );
}

# =========================

1;

=end twiki

=cut

# EOF

