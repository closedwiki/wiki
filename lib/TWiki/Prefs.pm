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
use Assert;

=pod

---+++ sub new( $webName )

Creates a new Prefs object, reading
preferences from TWiki::TWikiPreferences, Main::TWikiPreferences, and
$webName::WebPreferences.

=cut

sub new {
    my( $class, $session ) = @_;
    my $this = bless( {}, $class );
    assert(ref($session) eq "TWiki") if DEBUG;
    $this->{session} = $session;
    my $web = $session->{webName};

    $this->{WEBNAME} = $web;
    my $globs =  new TWiki::Prefs::PrefsCache($session, "global");
    $this->{GLOBAL} = $globs;
    my $webs = new TWiki::Prefs::PrefsCache($session, "web", $globs, $web);
    $this->{WEBS}{$web} = $webs;
    $this->{REQUEST} = new TWiki::Prefs::PrefsCache($session, "copy", $webs);

    return $this;
}

=pod

---+++ sub initializeUser( $wikiname, $usertopic )

STATIC Reads preferences from the user's personal topic.  The parameter
is the topic to read user-level preferences from (Generally
"Main.CurrentUserName").

=cut

sub initializeUser {
    my( $this, $wikiname, $topic ) = @_;
    assert(ref($this) eq "TWiki::Prefs") if DEBUG;

    $wikiname = "$TWiki::mainWebname.$TWiki::defaultWikiName" unless $wikiname;

    if( $wikiname =~ /^(.*)\.(.*)$/ ) {
        my $webPrefs = $this->{WEBS}{$this->{WEBNAME}};
        $this->{REQUEST} =
          new TWiki::Prefs::PrefsCache($this->{session},
                                       "request", $webPrefs,
                                       $topic, $2);
    }
}

=pod

---+++ sub getPrefsFromTopic( $web, $topic, $keyPrefix )

Reads preferences from the topic at =$theWeb.$theTopic=, prefixes them with
=$theKeyPrefix= if one is provided, and adds them to the preference cache.

=cut

sub getPrefsFromTopic {
    my( $this, $web, $topic, $keyPrefix ) = @_;
    assert(ref($this) eq "TWiki::Prefs") if DEBUG;
    $this->{REQUEST}->loadPrefsFromTopic( $web, $topic, $keyPrefix, 1 );
}

=pod

---+++ sub loadHash( \%hash )
Loads the top level of all the preferences into the passed
hash, in order to accelerate substitutions.

=cut

sub loadHash {
    my ( $this, $hashRef ) = @_;
    assert(ref($this) eq "TWiki::Prefs") if DEBUG;

    $this->{REQUEST}->loadHash( $hashRef );
}

# PACKAGE PRIVATE (called by PrefsCache)
# Returns 1 if the =$prefValue= is "on", and 0 otherwise.  "On" means set to
# something with a true Perl-truth-value, with the special cases that "off" and
# "no" are forced to false.  (Both of the latter are case-insensitive.)  Note
# also that leading and trailing whitespace on =$prefValue= will be stripped
# prior to this conversion.

sub _flag {
    my( $value ) = @_;

    return 0 unless ( defined( $value ));
    return 1 if ( $value =~ m/^\s*(on|1|true|yes)\s*$/i );
    return 0 if ( $value =~ m/^\s*(off|0|false|no)\s*$/i );

    $value =~ s/^\s*(.*?)\s*$/$1/i;
    return ( $value ? 1 : 0 );
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
    my( $this, $theKey, $theWeb ) = @_;
    assert(ref($this) eq "TWiki::Prefs") if DEBUG;

    my $sessionValue =
      $this->{session}->{plugins}->getSessionValueHandler( $theKey );

    if( defined( $sessionValue ) ) {
        return $sessionValue;
    }
    my $val;
    if( $theWeb ) {
        if (!exists $this->{WEBS}{$theWeb}) {
            $this->{WEBS}{$theWeb} =
              new TWiki::Prefs::PrefsCache($this->{session},
                                           "web", $this->{GLOBAL}, $theWeb);
        }
        $val = $this->{WEBS}{$theWeb}->{prefs}{$theKey};
    } else {
        if( defined( $this->{REQUEST} )) {
            $val = $this->{REQUEST}->{prefs}{$theKey};
        } elsif (exists( $this->{WEBS}{$this->{WEBNAME}} )) {
             # user/topic prefs not yet init'd
            $val = $this->{WEBS}{$this->{WEBNAME}}->{prefs}{$theKey};
        }
    }
    $val = "" unless( defined( $val ));
    return $val;
}

=pod

---+++ sub getPreferencesFlag( $theKey, $theWeb )

Returns the preference =$theKey= from =$theWeb= as a flag.  See
=getPreferencesValue= for the semantics of the parameters.
Returns 1 if the pref value is "on", and 0 otherwise.  "On" means set to
something with a true Perl-truth-value, with the special cases that "off" and
"no" are forced to false.  (Both of the latter are case-insensitive.)  Note
also that leading and trailing whitespace on the pref value will be stripped
prior to this conversion.

=cut

sub getPreferencesFlag {
    my( $this, $theKey, $theWeb ) = @_;
    assert(ref($this) eq "TWiki::Prefs") if DEBUG;

    my $value = $this->getPreferencesValue( $theKey, $theWeb );
    return _flag( $value );
}

=pod

---+++ sub getPreferencesNumber( $theKey, $theWeb )

Returns the preference =$theKey= from =$theWeb= as a flag.  See
=getPreferencesValue= for the semantics of the parameters.
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

sub getPreferencesNumber {
    my( $this, $theKey, $theWeb ) = @_;
    assert(ref($this) eq "TWiki::Prefs") if DEBUG;

    my $value = $this->getPreferencesValue( $theKey, $theWeb );

    return undef unless defined( $value );

    $value =~ s/[,\s]+//g;

    if( $value =~ /^0(\d|x|b)/i ) {
        return oct( $value ); # octal, 0x hex, 0b binary
    } elsif( $value =~ /^\d(\.\d+)?/) {
        return $value;      # decimal
    }
    return 0;              # empty/non-numeric
}

1;
